CREATE EXTENSION IF NOT EXISTS pgcrypto;

CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT NOT NULL,
  email TEXT UNIQUE NOT NULL,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL DEFAULT 'customer' CHECK (role IN ('customer','seller','admin','delivery')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS products (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  sku TEXT UNIQUE NOT NULL,
  name TEXT NOT NULL,
  category TEXT NOT NULL,
  price_sar NUMERIC(12,2) NOT NULL CHECK (price_sar >= 0),
  stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
  active BOOLEAN NOT NULL DEFAULT TRUE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES users(id),
  status TEXT NOT NULL DEFAULT 'pending',
  payment_method TEXT NOT NULL,
  payment_status TEXT NOT NULL DEFAULT 'pending',
  total_sar NUMERIC(12,2) NOT NULL,
  shipping_address JSONB NOT NULL,
  provider TEXT,
  provider_order_id TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS order_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  order_id UUID NOT NULL REFERENCES orders(id) ON DELETE CASCADE,
  product_id UUID REFERENCES products(id),
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price_sar NUMERIC(12,2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_orders_user_id ON orders(user_id);
CREATE INDEX IF NOT EXISTS idx_orders_provider_order_id ON orders(provider_order_id);

INSERT INTO products(sku,name,category,price_sar,stock) VALUES
('APEX-PRO-5G','هاتف APEX Pro 5G','إلكترونيات',2499,25),
('APEX-AUDIO-PRO','سماعات لاسلكية Pro','إلكترونيات',599,40),
('APEX-WATCH-U','ساعة ذكية Ultra','إلكترونيات',899,30),
('APEX-BAG-LUX','حقيبة فاخرة','أزياء',349,35),
('APEX-PERF-100','عطر ملكي 100ml','جمال',279,50),
('APEX-CHAIR-01','كرسي مكتب مريح','منزل',749,20),
('APEX-SHOE-SP','حذاء رياضي','رياضة',299,45),
('APEX-TOYS-01','مجموعة ألعاب أطفال','أطفال',189,35)
ON CONFLICT (sku) DO NOTHING;
