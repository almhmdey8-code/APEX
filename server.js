import express from 'express';
import dotenv from 'dotenv';
import crypto from 'node:crypto';
import bcrypt from 'bcryptjs';
import jwt from 'jsonwebtoken';
import pg from 'pg';

dotenv.config();
const { Pool } = pg;
const app = express();
app.use(express.json({ limit: '1mb', verify: (req, _res, buf) => { if (req.originalUrl.startsWith('/api/webhooks/tamara')) req.rawBody = Buffer.from(buf); } }));
const pool = new Pool({ connectionString: process.env.DATABASE_URL, ssl: process.env.NODE_ENV === 'production' ? { rejectUnauthorized: false } : false });

const required = ['JWT_SECRET','DATABASE_URL'];
for (const k of required) if (!process.env[k]) console.warn(`Missing environment variable: ${k}`);

function sign(user) { return jwt.sign({ sub: user.id, role: user.role, email: user.email }, process.env.JWT_SECRET, { expiresIn: '7d' }); }
function auth(req, res, next) {
  const h = req.headers.authorization || '';
  if (!h.startsWith('Bearer ')) return res.status(401).json({ error: 'UNAUTHORIZED' });
  try { req.user = jwt.verify(h.slice(7), process.env.JWT_SECRET); next(); } catch { return res.status(401).json({ error: 'INVALID_TOKEN' }); }
}

app.get('/health', async (_req, res) => {
  try { await pool.query('SELECT 1'); res.json({ ok: true, service: 'apex-backend' }); }
  catch { res.status(503).json({ ok: false }); }
});

app.post('/api/auth/register', async (req, res) => {
  const { name, email, password } = req.body || {};
  if (!name || !email || !password || password.length < 8) return res.status(400).json({ error: 'INVALID_INPUT' });
  try {
    const hash = await bcrypt.hash(password, 12);
    const { rows } = await pool.query('INSERT INTO users(name,email,password_hash) VALUES($1,$2,$3) RETURNING id,name,email,role', [name.trim(), email.toLowerCase().trim(), hash]);
    res.status(201).json({ user: rows[0], token: sign(rows[0]) });
  } catch (e) {
    if (e.code === '23505') return res.status(409).json({ error: 'EMAIL_EXISTS' });
    res.status(500).json({ error: 'SERVER_ERROR' });
  }
});

app.post('/api/auth/login', async (req, res) => {
  const { email, password } = req.body || {};
  try {
    const { rows } = await pool.query('SELECT id,name,email,password_hash,role FROM users WHERE email=$1', [String(email||'').toLowerCase().trim()]);
    if (!rows[0] || !(await bcrypt.compare(password || '', rows[0].password_hash))) return res.status(401).json({ error: 'INVALID_CREDENTIALS' });
    const user = { id: rows[0].id, name: rows[0].name, email: rows[0].email, role: rows[0].role };
    res.json({ user, token: sign(user) });
  } catch { res.status(500).json({ error: 'SERVER_ERROR' }); }
});


async function createOrder(client, userId, items, totalSar, shippingAddress, paymentMethod) {
  const requested = Array.isArray(items) ? items : [];
  if (!requested.length || !Number.isFinite(Number(totalSar)) || !shippingAddress || !paymentMethod) throw Object.assign(new Error('INVALID_ORDER'), {status:400});
  const skus = requested.map(x => String(x.sku || ''));
  if (skus.some(x => !x)) throw Object.assign(new Error('INVALID_SKU'), {status:400});
  const { rows: products } = await client.query('SELECT id,sku,name,price_sar,stock FROM products WHERE sku = ANY($1) AND active=TRUE FOR UPDATE', [skus]);
  if (products.length !== skus.length) throw Object.assign(new Error('PRODUCT_NOT_FOUND'), {status:400});
  let calculated = 0;
  const normalized = [];
  for (const req of requested) {
    const product = products.find(p => p.sku === String(req.sku));
    const qty = Number(req.qty);
    if (!Number.isInteger(qty) || qty < 1 || product.stock < qty) throw Object.assign(new Error('OUT_OF_STOCK'), {status:409});
    const unit = Number(product.price_sar);
    calculated += unit * qty;
    normalized.push({ product, qty, unit });
  }
  if (Math.abs(calculated - Number(totalSar)) > 0.01) throw Object.assign(new Error('TOTAL_MISMATCH'), {status:400});
  const order = await client.query('INSERT INTO orders(user_id,payment_method,payment_status,total_sar,shipping_address) VALUES($1,$2,$3,$4,$5) RETURNING id,status,payment_status,total_sar', [userId,String(paymentMethod),'pending',calculated,shippingAddress]);
  for (const x of normalized) {
    await client.query('INSERT INTO order_items(order_id,product_id,product_name,quantity,unit_price_sar) VALUES($1,$2,$3,$4,$5)', [order.rows[0].id,x.product.id,x.product.name,x.qty,x.unit]);
    await client.query('UPDATE products SET stock=stock-$1,updated_at=NOW() WHERE id=$2',[x.qty,x.product.id]);
  }
  return order.rows[0];
}

app.get('/api/products', async (_req,res)=>{ const {rows}=await pool.query('SELECT sku,name,category,price_sar,stock FROM products WHERE active=TRUE ORDER BY created_at DESC'); res.json(rows); });

app.get('/api/orders', auth, async (req, res) => {
  const { rows } = await pool.query('SELECT id,status,payment_method,payment_status,total_sar,shipping_address,provider,provider_order_id,created_at FROM orders WHERE user_id=$1 ORDER BY created_at DESC', [req.user.sub]);
  res.json(rows);
});

app.post('/api/orders/pending', auth, async (req, res) => {
  const client = await pool.connect();
  try { await client.query('BEGIN'); const order=await createOrder(client,req.user.sub,req.body?.items,Number(req.body?.totalSar),req.body?.shippingAddress,req.body?.paymentMethod); await client.query('COMMIT'); res.status(201).json(order); }
  catch(e){ await client.query('ROLLBACK'); res.status(e.status||500).json({error:e.message||'ORDER_CREATE_FAILED'}); }
  finally { client.release(); }
});

app.post('/api/orders/cod', auth, async (req, res) => {
  const client = await pool.connect();
  try { await client.query('BEGIN'); const order=await createOrder(client,req.user.sub,req.body?.items,Number(req.body?.totalSar),req.body?.shippingAddress,'cod'); await client.query('COMMIT'); res.status(201).json(order); }
  catch(e){ await client.query('ROLLBACK'); res.status(e.status||500).json({error:e.message||'ORDER_CREATE_FAILED'}); }
  finally { client.release(); }
});

async function providerJson(url, options) {
  const r = await fetch(url, options); const text = await r.text(); let body; try { body = JSON.parse(text); } catch { body = { raw: text }; }
  if (!r.ok) { const err = new Error('PROVIDER_ERROR'); err.status = r.status; err.body = body; throw err; }
  return body;
}

app.post('/api/payments/tabby/session', auth, async (req,res) => {
  const { amountSar, customer, items, shippingAddress, orderId } = req.body || {};
  if (!process.env.TABBY_SECRET_KEY || !process.env.TABBY_MERCHANT_CODE) return res.status(503).json({ error:'TABBY_NOT_CONFIGURED' });
  try {
    const base = process.env.TABBY_API_BASE || 'https://api.tabby.sa';
    const data = await providerJson(`${base}/api/v2/checkout`, { method:'POST', headers:{'Authorization':`Bearer ${process.env.TABBY_SECRET_KEY}`,'Content-Type':'application/json'}, body: JSON.stringify({
      payment:{ amount:Number(amountSar).toFixed(2), currency:'SAR', buyer:{name:customer.name,email:customer.email,phone:customer.phone}, shipping_address:{city:shippingAddress.city,address:shippingAddress.address,zip:shippingAddress.zip||'00000'}, order:{reference_id:orderId,items:items.map(x=>({title:x.name,quantity:Number(x.qty),unit_price:Number(x.price).toFixed(2),reference_id:x.sku||x.name,category:x.category||'General',description:x.description||x.name,is_refundable:true}))}},
      lang:'ar', merchant_code:process.env.TABBY_MERCHANT_CODE, merchant_urls:{success:`${process.env.APP_BASE_URL}/payment/success`,cancel:`${process.env.APP_BASE_URL}/payment/cancel`,failure:`${process.env.APP_BASE_URL}/payment/failure`}
    })});
    await pool.query('UPDATE orders SET provider=$1,provider_order_id=$2,updated_at=NOW() WHERE id=$3',['tabby',data.payment?.id || data.id,orderId]);
    res.json({ sessionId:data.id, status:data.status, webUrl:data.configuration?.available_products?.installments?.[0]?.web_url || null, paymentId:data.payment?.id });
  } catch(e) { res.status(e.status||502).json({ error:'TABBY_ERROR', details:e.body||null }); }
});

app.post('/api/payments/tamara/session', auth, async (req,res) => {
  const { payload } = req.body || {};
  if (!process.env.TAMARA_API_TOKEN) return res.status(503).json({ error:'TAMARA_NOT_CONFIGURED' });
  try {
    const base = process.env.TAMARA_API_BASE || 'https://api.tamara.co';
    const data = await providerJson(`${base}/checkout`, { method:'POST', headers:{'Authorization':`Bearer ${process.env.TAMARA_API_TOKEN}`,'Content-Type':'application/json'}, body: JSON.stringify(payload) });
    await pool.query('UPDATE orders SET provider=$1,provider_order_id=$2,updated_at=NOW() WHERE id=$3',['tamara',data.order_id || data.checkout_id, payload.order_reference_id]);
    res.json(data);
  } catch(e) { res.status(e.status||502).json({ error:'TAMARA_ERROR', details:e.body||null }); }
});

app.post('/api/payments/paypal/order', auth, async (req,res) => {
  if (!process.env.PAYPAL_CLIENT_ID || !process.env.PAYPAL_CLIENT_SECRET) return res.status(503).json({ error:'PAYPAL_NOT_CONFIGURED' });
  try {
    const base = process.env.PAYPAL_API_BASE || 'https://api-m.paypal.com';
    const token = await providerJson(`${base}/v1/oauth2/token`, {method:'POST', headers:{Authorization:'Basic '+Buffer.from(`${process.env.PAYPAL_CLIENT_ID}:${process.env.PAYPAL_CLIENT_SECRET}`).toString('base64'),'Content-Type':'application/x-www-form-urlencoded'}, body:'grant_type=client_credentials'});
    const order = await providerJson(`${base}/v2/checkout/orders`, {method:'POST', headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'}, body:JSON.stringify(req.body.order)});
    const ref = order.purchase_units?.[0]?.reference_id; if(ref && order.id) await pool.query('UPDATE orders SET provider=$1,provider_order_id=$2,updated_at=NOW() WHERE id=$3',['paypal',order.id,ref]);
    res.json(order);
  } catch(e) { res.status(e.status||502).json({error:'PAYPAL_ERROR',details:e.body||null}); }
});

app.get('/api/payments/paypal/return', async (req,res) => {
  const orderId = String(req.query.token || '');
  if (!orderId || !process.env.PAYPAL_CLIENT_ID || !process.env.PAYPAL_CLIENT_SECRET) return res.status(400).send('Invalid PayPal return.');
  try {
    const base = process.env.PAYPAL_API_BASE || 'https://api-m.paypal.com';
    const token = await providerJson(`${base}/v1/oauth2/token`, {method:'POST', headers:{Authorization:'Basic '+Buffer.from(`${process.env.PAYPAL_CLIENT_ID}:${process.env.PAYPAL_CLIENT_SECRET}`).toString('base64'),'Content-Type':'application/x-www-form-urlencoded'}, body:'grant_type=client_credentials'});
    const result = await providerJson(`${base}/v2/checkout/orders/${orderId}/capture`, {method:'POST', headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'}, body:'{}'});
    await pool.query('UPDATE orders SET payment_status=$1,updated_at=NOW() WHERE provider_order_id=$2',[result.status === 'COMPLETED' ? 'paid' : 'pending',orderId]);
    res.send('<!doctype html><html lang="ar"><meta charset="utf-8"><title>APEX</title><body style="font-family:Arial;text-align:center;padding:60px"><h1>تم استلام نتيجة الدفع</h1><p>يمكنك العودة إلى تطبيق APEX لمتابعة الطلب.</p></body></html>');
  } catch(e) { res.status(e.status||502).send('PayPal payment could not be completed.'); }
});

app.post('/api/payments/paypal/capture', auth, async (req,res) => {
  const { orderId } = req.body || {};
  if (!process.env.PAYPAL_CLIENT_ID || !process.env.PAYPAL_CLIENT_SECRET || !orderId) return res.status(400).json({error:'INVALID_REQUEST'});
  try {
    const base = process.env.PAYPAL_API_BASE || 'https://api-m.paypal.com';
    const token = await providerJson(`${base}/v1/oauth2/token`, {method:'POST', headers:{Authorization:'Basic '+Buffer.from(`${process.env.PAYPAL_CLIENT_ID}:${process.env.PAYPAL_CLIENT_SECRET}`).toString('base64'),'Content-Type':'application/x-www-form-urlencoded'}, body:'grant_type=client_credentials'});
    const result = await providerJson(`${base}/v2/checkout/orders/${orderId}/capture`, {method:'POST', headers:{Authorization:`Bearer ${token.access_token}`,'Content-Type':'application/json'}, body:'{}'});
    await pool.query('UPDATE orders SET payment_status=$1,updated_at=NOW() WHERE provider_order_id=$2',['paid',orderId]);
    res.json(result);
  } catch(e) { res.status(e.status||502).json({error:'PAYPAL_CAPTURE_ERROR',details:e.body||null}); }
});

function timingSafeEqual(a,b){ const aa=Buffer.from(a||''); const bb=Buffer.from(b||''); return aa.length===bb.length && crypto.timingSafeEqual(aa,bb); }
app.post('/api/webhooks/tamara', async (req,res)=>{
  const token = String(req.query.tamaraToken || (req.headers.authorization||'').replace(/^Bearer\s+/i,''));
  if (!process.env.TAMARA_NOTIFICATION_TOKEN || !token) return res.status(401).send('invalid token');
  try { jwt.verify(token, process.env.TAMARA_NOTIFICATION_TOKEN, {algorithms:['HS256']}); } catch { return res.status(401).send('invalid token'); }
  const payload = req.body;
  const status = String(payload?.status || '').toLowerCase();
  const paymentStatus = ['approved','authorised','authorized','fully_captured','partially_captured'].includes(status) ? 'paid' : (['declined','canceled','cancelled','voided'].includes(status) ? 'failed' : 'pending');
  if (payload?.order_id || payload?.orderId) await pool.query('UPDATE orders SET payment_status=$1,updated_at=NOW() WHERE provider_order_id=$2',[paymentStatus,payload.order_id||payload.orderId]);
  res.sendStatus(204);
});

app.post('/api/webhooks/tabby', async (req,res)=>{
  // Configure Tabby to sign this endpoint with the same arbitrary secret header value.
  const headerName = process.env.TABBY_WEBHOOK_HEADER || 'x-apex-tabby-signature';
  if (process.env.TABBY_WEBHOOK_SECRET && !timingSafeEqual(req.headers[headerName], process.env.TABBY_WEBHOOK_SECRET)) return res.status(401).send('invalid signature');
  const p=req.body||{}; const ref=p?.payment?.order?.reference_id || p?.order?.reference_id || p?.reference_id;
  const status=String(p?.payment?.status||p?.status||'').toLowerCase();
  if(ref && status) await pool.query('UPDATE orders SET payment_status=$1,updated_at=NOW() WHERE id::text=$2 OR provider_order_id=$2',[status,ref]);
  res.sendStatus(204);
});

app.use((err,_req,res,_next)=>{ console.error(err); res.status(500).json({error:'SERVER_ERROR'}); });
const port=Number(process.env.PORT||8080);
app.listen(port,()=>console.log(`APEX backend listening on :${port}`));
