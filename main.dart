import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';

const gold = Color(0xFFC99524);
const dark = Color(0xFF17130B);
const bg = Color(0xFFF8F7F3);

const apiBaseUrl = String.fromEnvironment('API_BASE_URL', defaultValue: 'https://api.example.com');

class AuthSession {
  static String? token;
  static String name = '';
  static String email = '';
  static String role = 'customer';
  static bool get signedIn => token != null;
  static void setUser(Map<String, dynamic> user, String authToken) {
    token = authToken; name = user['name'] ?? ''; email = user['email'] ?? ''; role = user['role'] ?? 'customer';
  }
  static void clear() { token = null; name = ''; email = ''; role = 'customer'; }
}

class ApexApi {
  static Uri uri(String path) => Uri.parse('$apiBaseUrl$path');
  static Map<String,String> headers({bool auth=true}) => {
    'Content-Type':'application/json',
    if (auth && AuthSession.token != null) 'Authorization':'Bearer ${AuthSession.token}',
  };
  static Future<Map<String,dynamic>> post(String path, Map<String,dynamic> body, {bool auth=true}) async {
    final r = await http.post(uri(path), headers: headers(auth:auth), body: jsonEncode(body)).timeout(const Duration(seconds:20));
    final data = r.body.isEmpty ? <String,dynamic>{} : jsonDecode(r.body) as Map<String,dynamic>;
    if (r.statusCode < 200 || r.statusCode >= 300) throw Exception(data['error'] ?? 'SERVER_ERROR');
    return data;
  }
}

void main() => runApp(const ApexApp());

class Product {
  final String name, category, price, oldPrice, image, sku;
  final double rating;
  final int reviews;
  const Product(this.name, this.category, this.price, this.oldPrice, this.image, this.rating, this.reviews, this.sku);
}

const products = <Product>[
  Product('هاتف APEX Pro 5G', 'إلكترونيات', '2,499', '2,799', '📱', 4.8, 124, 'APEX-PRO-5G'),
  Product('سماعات لاسلكية Pro', 'إلكترونيات', '599', '699', '🎧', 4.7, 86, 'APEX-AUDIO-PRO'),
  Product('ساعة ذكية Ultra', 'إلكترونيات', '899', '999', '⌚', 4.6, 71, 'APEX-WATCH-U'),
  Product('حقيبة فاخرة', 'أزياء', '349', '449', '👜', 4.9, 54, 'APEX-BAG-LUX'),
  Product('عطر ملكي 100ml', 'جمال', '279', '329', '🌹', 4.8, 93, 'APEX-PERF-100'),
  Product('كرسي مكتب مريح', 'منزل', '749', '899', '🪑', 4.5, 38, 'APEX-CHAIR-01'),
  Product('حذاء رياضي', 'رياضة', '299', '399', '👟', 4.7, 65, 'APEX-SHOE-SP'),
  Product('مجموعة ألعاب أطفال', 'أطفال', '189', '249', '🧸', 4.8, 42, 'APEX-TOYS-01'),
];

class CartItem {
  Product product;
  int qty;
  CartItem(this.product, [this.qty = 1]);
}

class CartModel extends ChangeNotifier {
  final List<CartItem> items = [];
  void add(Product p) {
    final i = items.indexWhere((e) => e.product.name == p.name);
    if (i >= 0) items[i].qty++; else items.add(CartItem(p));
    notifyListeners();
  }
  void remove(Product p) {
    final i = items.indexWhere((e) => e.product.name == p.name);
    if (i < 0) return;
    if (items[i].qty > 1) items[i].qty--; else items.removeAt(i);
    notifyListeners();
  }
  int get count => items.fold(0, (s, e) => s + e.qty);
  double get total => items.fold(0, (s, e) => s + double.parse(e.product.price.replaceAll(',', '')) * e.qty);
  void clear() { items.clear(); notifyListeners(); }
}

final cart = CartModel();

class ApexApp extends StatelessWidget {
  const ApexApp({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'APEX متجر إلكتروني',
        theme: ThemeData(useMaterial3: true, fontFamily: 'Arial', scaffoldBackgroundColor: bg,
          colorScheme: ColorScheme.fromSeed(seedColor: gold)),
        home: const AuthPage(),
      );
}

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});
  @override State<AuthPage> createState() => _AuthPageState();
}
class _AuthPageState extends State<AuthPage> {
  bool login = true; String role = 'عميل';
  final email = TextEditingController(), pass = TextEditingController(), name = TextEditingController();
  @override Widget build(BuildContext context) => Scaffold(body: SafeArea(child: Center(child: SingleChildScrollView(
    padding: const EdgeInsets.all(24), child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 520), child: Column(children: [
      _logo(), const SizedBox(height: 26),
      Text(login ? 'تسجيل الدخول إلى APEX' : 'إنشاء حساب APEX', style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8), Text(login ? 'تسوّق بثقة ووصل طلباتك بسهولة' : 'أنشئ حسابك وابدأ التسوق أو البيع', style: const TextStyle(color: Colors.black54)),
      const SizedBox(height: 24),
      if (!login) TextField(controller: name, decoration: _dec('الاسم الكامل', Icons.person_outline)),
      if (!login) const SizedBox(height: 12),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: _dec('البريد الإلكتروني أو الجوال', Icons.email_outlined)),
      const SizedBox(height: 12), TextField(controller: pass, obscureText: true, decoration: _dec('كلمة المرور', Icons.lock_outline)),
      if (!login) ...[const SizedBox(height: 18), const Align(alignment: Alignment.centerRight, child: Text('سيتم إنشاء حساب عميل. حسابات البائع والإدارة والتوصيل تُنشأ من لوحة الإدارة.', style: TextStyle(color: Colors.black54))),],
      const SizedBox(height: 22), SizedBox(width: double.infinity, height: 54, child: FilledButton(
        style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: dark),
        onPressed: _submit,
        child: Text(login ? 'دخول' : 'إنشاء الحساب', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
      const SizedBox(height: 12), TextButton(onPressed: () => setState(() => login = !login), child: Text(login ? 'ليس لديك حساب؟ إنشاء حساب' : 'لديك حساب؟ تسجيل الدخول', style: const TextStyle(color: gold, fontWeight: FontWeight.bold))),
      const SizedBox(height: 8), const Text('تطبيق APEX متصل بخادم آمن — لا تُدخل أسرار الدفع داخل التطبيق', style: TextStyle(fontSize: 12, color: Colors.black45)),
    ])))));
  Future<void> _submit() async {
    if (email.text.trim().isEmpty || pass.text.isEmpty || (!login && name.text.trim().isEmpty)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أكمل البيانات المطلوبة'))); return;
    }
    try {
      final data = login
          ? await ApexApi.post('/api/auth/login', {'email':email.text.trim(),'password':pass.text}, auth:false)
          : await ApexApi.post('/api/auth/register', {'name':name.text.trim(),'email':email.text.trim(),'password':pass.text}, auth:false);
      AuthSession.setUser(data['user'] as Map<String,dynamic>, data['token'] as String);
      final page = AuthSession.role == 'seller' ? const SellerDashboard() : AuthSession.role == 'admin' ? const AdminDashboard() : AuthSession.role == 'delivery' ? const DeliveryDashboard() : const HomePage();
      if (mounted) Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => page));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('تعذر تسجيل الدخول: ${e.toString().replaceFirst('Exception: ', '')}')));
    }
  }

  Widget _role(String t, bool active, VoidCallback f) => InkWell(onTap: f, borderRadius: BorderRadius.circular(16), child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: active ? const Color(0xFFFFF4D8) : Colors.white, border: Border.all(color: active ? gold : Colors.black12), borderRadius: BorderRadius.circular(16)), child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(active ? Icons.radio_button_checked : Icons.radio_button_off, color: gold), const SizedBox(width: 8), Text(t, style: const TextStyle(fontWeight: FontWeight.bold))]));
}

InputDecoration _dec(String hint, IconData icon) => InputDecoration(hintText: hint, prefixIcon: Icon(icon), filled: true, fillColor: Colors.white, border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none));
Widget _logo() => Container(width: 100, height: 100, decoration: BoxDecoration(gradient: const LinearGradient(colors: [dark, gold]), borderRadius: BorderRadius.circular(28), boxShadow: [BoxShadow(color: gold.withOpacity(.25), blurRadius: 20)]), child: const Center(child: Text('APEX', style: TextStyle(color: Colors.white, fontSize: 27, fontWeight: FontWeight.w900, letterSpacing: 2))));

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override State<HomePage> createState() => _HomeState();
}
class _HomeState extends State<HomePage> {
  int index = 0;
  String search = '';
  final searchController = TextEditingController();
  @override Widget build(BuildContext context) {
    final pages = [StorePage(search: search), const OrdersPage(), const CartPage(), const AccountPage()];
    return Directionality(textDirection: TextDirection.rtl, child: Scaffold(
      appBar: AppBar(backgroundColor: Colors.white, title: const Text('APEX', style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 2)),
        actions: [IconButton(onPressed: () => _searchDialog(), icon: const Icon(Icons.search)), Stack(children: [IconButton(onPressed: () => setState(() => index = 2), icon: const Icon(Icons.shopping_cart_outlined)), if (cart.count > 0) Positioned(right: 7, top: 7, child: CircleAvatar(radius: 9, backgroundColor: gold, child: Text('${cart.count}', style: const TextStyle(fontSize: 10, color: dark))))])]),
      body: pages[index],
      bottomNavigationBar: NavigationBar(selectedIndex: index, onDestinationSelected: (v) => setState(() => index = v), destinations: const [
        NavigationDestination(icon: Icon(Icons.storefront_outlined), selectedIcon: Icon(Icons.storefront), label: 'الرئيسية'),
        NavigationDestination(icon: Icon(Icons.local_shipping_outlined), selectedIcon: Icon(Icons.local_shipping), label: 'طلباتي'),
        NavigationDestination(icon: Icon(Icons.shopping_cart_outlined), selectedIcon: Icon(Icons.shopping_cart), label: 'السلة'),
        NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'حسابي')]),
    ));
  }
  void _searchDialog() { showDialog(context: context, builder: (_) => AlertDialog(title: const Text('البحث عن منتج'), content: TextField(controller: searchController, autofocus: true, decoration: _dec('مثال: هاتف أو أزياء', Icons.search)), actions: [TextButton(onPressed: () { Navigator.pop(context); setState(() => search = searchController.text.trim()); }, child: const Text('بحث'))])); }
}

class StorePage extends StatelessWidget {
  final String search;
  const StorePage({super.key, this.search = ''});
  @override Widget build(BuildContext context) {
    final filtered = products.where((p) => search.isEmpty || p.name.contains(search) || p.category.contains(search)).toList();
    return ListView(padding: const EdgeInsets.all(16), children: [
      Container(height: 170, padding: const EdgeInsets.all(22), decoration: BoxDecoration(gradient: const LinearGradient(colors: [dark, gold]), borderRadius: BorderRadius.circular(24)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [Text('APEX', style: TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.w900)), Text('متجرك الإلكتروني المتكامل', style: TextStyle(color: Colors.white70, fontSize: 16)), SizedBox(height: 12), Text('عروض حصرية • توصيل سريع • تسوق آمن', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))])),
      const SizedBox(height: 22), const Text('الأقسام', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: ['إلكترونيات','أزياء','منزل','جمال','أطفال','رياضة'].map((e) => ActionChip(label: Text(e), avatar: const Icon(Icons.category_outlined, size: 18), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CategoryPage(category: e)))).toList())),
      const SizedBox(height: 20), Text(search.isEmpty ? 'منتجات مميزة' : 'نتائج البحث: $search', style: const TextStyle(fontSize: 21, fontWeight: FontWeight.bold)), const SizedBox(height: 10),
      if (filtered.isEmpty) const Padding(padding: EdgeInsets.all(30), child: Center(child: Text('لا توجد منتجات مطابقة للبحث'))),
      GridView.builder(shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: filtered.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .67), itemBuilder: (_, i) => ProductCard(product: filtered[i])),
    ]);
  }
}

class CategoryPage extends StatelessWidget { final String category; const CategoryPage({super.key, required this.category}); @override Widget build(BuildContext c) { final list = products.where((p) => p.category == category).toList(); return Directionality(textDirection: TextDirection.rtl, child: Scaffold(appBar: AppBar(title: Text(category)), body: GridView.builder(padding: const EdgeInsets.all(16), itemCount: list.length, gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, mainAxisSpacing: 12, crossAxisSpacing: 12, childAspectRatio: .67), itemBuilder: (_, i) => ProductCard(product: list[i])))); } }

class ProductCard extends StatelessWidget { final Product product; const ProductCard({super.key, required this.product}); @override Widget build(BuildContext context) => Card(clipBehavior: Clip.antiAlias, child: InkWell(onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProductDetails(product: product))), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [Expanded(child: Container(color: const Color(0xFFF0ECE2), child: Center(child: Text(product.image, style: const TextStyle(fontSize: 64))))), Padding(padding: const EdgeInsets.fromLTRB(10, 8, 10, 10), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(product.name, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.bold)), const SizedBox(height: 5), Row(children: [const Icon(Icons.star, size: 16, color: gold), Text(' ${product.rating}')]), const SizedBox(height: 4), Row(children: [Text('${product.price} ر.س', style: const TextStyle(color: Color(0xFF9A6A08), fontWeight: FontWeight.w900)), const Spacer(), IconButton(onPressed: () { cart.add(product); ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج إلى السلة'))); }, icon: const Icon(Icons.add_shopping_cart, color: gold))])]))])); }

class ProductDetails extends StatelessWidget { final Product product; const ProductDetails({super.key, required this.product}); @override Widget build(BuildContext c) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(appBar: AppBar(title: const Text('تفاصيل المنتج')), body: ListView(padding: const EdgeInsets.all(18), children: [Container(height: 270, decoration: BoxDecoration(color: const Color(0xFFF0ECE2), borderRadius: BorderRadius.circular(24)), child: Center(child: Text(product.image, style: const TextStyle(fontSize: 120)))), const SizedBox(height: 18), Text(product.name, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900)), const SizedBox(height: 8), Row(children: [const Icon(Icons.star, color: gold), Text(' ${product.rating}  (${product.reviews} تقييم)')]), const SizedBox(height: 14), Text('${product.price} ر.س', style: const TextStyle(fontSize: 27, color: Color(0xFF9A6A08), fontWeight: FontWeight.w900)), if (product.oldPrice.isNotEmpty) Text('${product.oldPrice} ر.س', style: const TextStyle(decoration: TextDecoration.lineThrough, color: Colors.black45)), const SizedBox(height: 18), const Text('وصف المنتج', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), const SizedBox(height: 8), const Text('منتج مميز بجودة عالية، مناسب للاستخدام اليومي. يمكنك إضافة المنتج للسلة ثم إتمام الطلب والدفع من صفحة السلة.')), const SizedBox(height: 24), SizedBox(height: 54, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: dark), onPressed: () { cart.add(product); ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('تمت إضافة المنتج إلى السلة'))); }, icon: const Icon(Icons.shopping_cart), label: const Text('أضف إلى السلة', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold))))])); }

class OrdersPage extends StatefulWidget {
  const OrdersPage({super.key});
  @override State<OrdersPage> createState() => _OrdersState();
}
class _OrdersState extends State<OrdersPage> {
  late Future<List<dynamic>> future;
  @override void initState(){super.initState(); future=_load();}
  Future<List<dynamic>> _load() async {
    final r=await http.get(ApexApi.uri('/api/orders'),headers:ApexApi.headers()).timeout(const Duration(seconds:20));
    if(r.statusCode<200||r.statusCode>=300) throw Exception('تعذر تحميل الطلبات');
    return jsonDecode(r.body) as List<dynamic>;
  }
  @override Widget build(BuildContext c)=>FutureBuilder<List<dynamic>>(future:future,builder:(c,s){
    if(s.connectionState!=ConnectionState.done) return const Center(child:CircularProgressIndicator());
    if(s.hasError) return Center(child:Text('تعذر الاتصال بالخادم'));
    final rows=s.data!;
    return Directionality(textDirection:TextDirection.rtl,child:ListView(padding:const EdgeInsets.all(16),children:[
      const Text('طلباتي',style:TextStyle(fontSize:26,fontWeight:FontWeight.bold)),const SizedBox(height:16),
      if(rows.isEmpty) const Center(child:Padding(padding:EdgeInsets.all(30),child:Text('لا توجد طلبات بعد'))),
      ...rows.map((o)=>Card(child:ListTile(leading:const CircleAvatar(backgroundColor:Color(0xFFFFF2CF),child:Icon(Icons.local_shipping,color:gold)),title:Text('#${o['id'].toString().substring(0,8)}',style:const TextStyle(fontWeight:FontWeight.bold)),subtitle:Text('${o['status']} • ${o['payment_status']}'),trailing:Text('${o['total_sar']} ر.س',style:const TextStyle(fontWeight:FontWeight.bold)))))
    ]));
  });
}

class CartPage extends StatefulWidget { const CartPage({super.key}); @override State<CartPage> createState() => _CartState(); }
class _CartState extends State<CartPage> { @override Widget build(BuildContext c) => AnimatedBuilder(animation: cart, builder: (_, __) => cart.items.isEmpty ? const Center(child: Text('السلة فارغة', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))) : ListView(padding: const EdgeInsets.all(16), children: [const Text('سلة التسوق', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)), const SizedBox(height: 12), ...cart.items.map((item) => Card(child: ListTile(leading: Text(item.product.image, style: const TextStyle(fontSize: 38)), title: Text(item.product.name, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('${item.product.price} ر.س × ${item.qty}'), trailing: Row(mainAxisSize: MainAxisSize.min, children: [IconButton(onPressed: () { cart.remove(item.product); setState(() {}); }, icon: const Icon(Icons.remove_circle_outline)), Text('${item.qty}'), IconButton(onPressed: () { cart.add(item.product); setState(() {}); }, icon: const Icon(Icons.add_circle_outline))]))), const SizedBox(height: 12), Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('الإجمالي', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), Text('${cart.total.toStringAsFixed(0)} ر.س', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Color(0xFF9A6A08)))]), const SizedBox(height: 14), SizedBox(width: double.infinity, height: 52, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: dark), onPressed: () => Navigator.push(c, MaterialPageRoute(builder: (_) => const CheckoutPage())), child: const Text('إتمام الطلب')))]))])); }
}

class PaymentMethod {
  final String title, subtitle;
  final IconData icon;
  const PaymentMethod(this.title, this.subtitle, this.icon);
}

const paymentMethods = <PaymentMethod>[
  PaymentMethod('Google Pay', 'الدفع السريع عبر Google Pay', Icons.account_balance_wallet_outlined),
  PaymentMethod('PayPal', 'الدفع الآمن عبر PayPal', Icons.account_balance_wallet_outlined),
  PaymentMethod('Visa / Mastercard', 'بطاقة بنكية عبر بوابة دفع آمنة', Icons.credit_card_outlined),
  PaymentMethod('تابي', 'الدفع بالتقسيط عبر تابي', Icons.calendar_month_outlined),
  PaymentMethod('تمارا', 'الدفع بالتقسيط عبر تمارا', Icons.calendar_month_outlined),
  PaymentMethod('الدفع عند الاستلام', 'الدفع نقدًا عند وصول الطلب', Icons.payments_outlined),
];

class CheckoutPage extends StatefulWidget {
  const CheckoutPage({super.key});
  @override State<CheckoutPage> createState() => _CheckoutState();
}

class _CheckoutState extends State<CheckoutPage> {
  String method = 'الدفع عند الاستلام';
  final address = TextEditingController();
  final city = TextEditingController();
  final phone = TextEditingController();

  Future<void> _continuePayment() async {
    if (!AuthSession.signedIn) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('سجل الدخول أولاً'))); return; }
    if (city.text.trim().isEmpty || address.text.trim().isEmpty || phone.text.trim().isEmpty) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('أدخل المدينة والعنوان ورقم الجوال أولاً'))); return; }
    try {
      final items=cart.items.map((x)=>{'name':x.product.name,'qty':x.qty,'price':double.parse(x.product.price.replaceAll(',','')),'category':x.product.category,'sku':x.product.sku}).toList();
      final total=cart.total;
      final base={'items':items,'totalSar':total,'shippingAddress':{'city':city.text.trim(),'address':address.text.trim(),'zip':'00000','phone':phone.text.trim()}};
      if(method=='الدفع عند الاستلام'){
        final data=await ApexApi.post('/api/orders/cod',base);
        cart.clear();
        if(!mounted)return;
        await showDialog(context:context,builder:(_)=>AlertDialog(title:const Text('تم إنشاء الطلب 🎉'),content:Text('رقم الطلب: ${data['id']}\nسيتم الدفع عند الاستلام.'),actions:[TextButton(onPressed:()=>Navigator.pop(context),child:const Text('حسنًا'))]));
        if(mounted) Navigator.pop(context);
        return;
      }
      final pendingBody=<String,dynamic>{...base,'paymentMethod':method};
      final pending=await ApexApi.post('/api/orders/pending',pendingBody);
      final orderId=pending['id'] as String;
      Map<String,dynamic> result;
      if(method=='تابي'){
        result=await ApexApi.post('/api/payments/tabby/session',{'amountSar':total,'orderId':orderId,'customer':{'name':AuthSession.name,'email':AuthSession.email,'phone':phone.text.trim()},'items':items,'shippingAddress':base['shippingAddress']});
      } else if(method=='تمارا'){
        result=await ApexApi.post('/api/payments/tamara/session',{'payload':{'total_amount':{'amount':total.toStringAsFixed(2),'currency':'SAR'},'shipping_amount':{'amount':'0.00','currency':'SAR'},'tax_amount':{'amount':'0.00','currency':'SAR'},'order_reference_id':orderId,'order_number':orderId,'items':items.map((x)=>{'name':x['name'],'quantity':x['qty'],'reference_id':x['sku'],'type':'Physical','sku':x['sku'],'unit_price':{'amount':(x['price'] as double).toStringAsFixed(2),'currency':'SAR'},'tax_amount':{'amount':'0.00','currency':'SAR'},'discount_amount':{'amount':'0.00','currency':'SAR'},'total_amount':{'amount':((x['price'] as double)*(x['qty'] as int)).toStringAsFixed(2),'currency':'SAR'}}).toList(),'consumer':{'email':AuthSession.email,'first_name':AuthSession.name,'last_name':'APEX','phone_number':phone.text.trim()},'country_code':'SA','description':'APEX Order $orderId','merchant_url':{'success':'$apiBaseUrl/payment/success','failure':'$apiBaseUrl/payment/failure','cancel':'$apiBaseUrl/payment/cancel'},'shipping_address':{'city':city.text.trim(),'address':address.text.trim(),'country_code':'SA','phone_number':phone.text.trim()},'platform':'APEX','is_mobile':true,'locale':'ar_SA'}});
      } else if(method=='PayPal'){
        result=await ApexApi.post('/api/payments/paypal/order',{'order':{'intent':'CAPTURE','purchase_units':[{'reference_id':orderId,'amount':{'currency_code':'SAR','value':total.toStringAsFixed(2)}}],'application_context':{'user_action':'PAY_NOW'}}});
      } else {
        throw Exception('طريقة الدفع هذه تحتاج ربط بوابة بطاقات معتمدة قبل تفعيلها.');
      }
      String? url = (result['webUrl'] ?? result['checkout_url'] ?? result['approvalUrl'])?.toString();
      if (url == null && result['links'] is List) { for (final link in (result['links'] as List)) { if (link is Map && link['rel'] == 'approve') { url = link['href']?.toString(); break; } } }
      if(url==null||url.isEmpty) throw Exception('لم تُرجع بوابة الدفع رابط الدفع');
      if(!await launchUrl(Uri.parse(url),mode:LaunchMode.externalApplication)) throw Exception('تعذر فتح بوابة الدفع');
      cart.clear();
    } catch(e){ if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('تعذر إتمام الدفع: ${e.toString().replaceFirst('Exception: ','')}'))); }
  }

  @override
  Widget build(BuildContext c) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('إتمام الطلب')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('بيانات التوصيل', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      TextField(controller: city, decoration: _dec('المدينة', Icons.location_city_outlined)),
      const SizedBox(height: 10),
      TextField(controller: phone, keyboardType: TextInputType.phone, decoration: _dec('رقم الجوال', Icons.phone_outlined)),
      const SizedBox(height: 10),
      TextField(controller: address, maxLines: 2, decoration: _dec('الحي والعنوان بالتفصيل', Icons.location_on_outlined)),
      const SizedBox(height: 20),
      const Text('خيارات الدفع', style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      ...paymentMethods.map((m) => Card(
        child: RadioListTile<String>(
          value: m.title, groupValue: method, onChanged: (v) => setState(() => method = v!),
          secondary: CircleAvatar(backgroundColor: const Color(0xFFFFF2CF), child: Icon(m.icon, color: gold)),
          title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(m.subtitle),
        ),
      )),
      const SizedBox(height: 10),
      Card(child: ListTile(title: const Text('إجمالي الطلب'), trailing: Text('${cart.total.toStringAsFixed(0)} ر.س', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900)))),
      const SizedBox(height: 18),
      SizedBox(height: 54, child: FilledButton(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: dark), onPressed: _continuePayment,
        child: Text(method == 'الدفع عند الاستلام' ? 'تأكيد الطلب' : 'المتابعة إلى الدفع', style: const TextStyle(fontSize: 17, fontWeight: FontWeight.bold)))),
    ],
  ));
}

class AccountPage extends StatelessWidget {
  const AccountPage({super.key});
  @override Widget build(BuildContext c) => ListView(padding: const EdgeInsets.all(16), children: [
    const CircleAvatar(radius: 42, backgroundColor: Color(0xFFFFF2CF), child: Icon(Icons.person, size: 46, color: gold)),
    const SizedBox(height: 12), const Center(child: Text('حساب العميل', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
    const SizedBox(height: 22),
    ...[
      ['بيانات الحساب', Icons.person_outline], ['العناوين', Icons.location_on_outlined],
      ['طرق الدفع', Icons.credit_card_outlined], ['العملة: ريال سعودي', Icons.currency_exchange],
      ['اللغة: العربية', Icons.language], ['الأمان والخصوصية', Icons.security]
    ].map((x) => Card(child: ListTile(leading: Icon(x[1] as IconData, color: gold), title: Text(x[0] as String), trailing: const Icon(Icons.chevron_left),
      onTap: () { if (x[0] == 'طرق الدفع') Navigator.push(c, MaterialPageRoute(builder: (_) => const PaymentSettingsPage())); }))),
  ]);
}

class PaymentSettingsPage extends StatefulWidget {
  const PaymentSettingsPage({super.key});
  @override State<PaymentSettingsPage> createState() => _PaymentSettingsState();
}

class _PaymentSettingsState extends State<PaymentSettingsPage> {
  final email = TextEditingController(text: 'almhmdey8@yahoo.com');
  bool googlePay = true, paypal = true, payoneer = true, cards = true, tabby = true, tamara = true, cod = true;

  Widget _account(String title, String subtitle, IconData icon, bool enabled, ValueChanged<bool> onChanged) => Card(
    child: SwitchListTile(
      value: enabled, onChanged: onChanged,
      secondary: CircleAvatar(backgroundColor: const Color(0xFFFFF2CF), child: Icon(icon, color: gold)),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(subtitle),
    ),
  );

  @override Widget build(BuildContext c) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('طرق الدفع والحسابات')),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('حساب استلام الأموال', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      const Text('هذا البريد يُستخدم كبيان للحساب المستهدف. الربط الفعلي يتم عبر تسجيل الدخول/OAuth ومفاتيح الخادم، وليس بكلمة مرور داخل التطبيق.', style: TextStyle(color: Colors.black54)),
      const SizedBox(height: 12),
      TextField(controller: email, keyboardType: TextInputType.emailAddress, decoration: _dec('البريد الإلكتروني للحساب', Icons.email_outlined)),
      const SizedBox(height: 18),
      _account('PayPal', 'استلام الأموال عبر PayPal', Icons.account_balance_wallet_outlined, paypal, (v) => setState(() => paypal = v)),
      _account('Payoneer', 'استلام المستحقات عبر Payoneer', Icons.account_balance_outlined, payoneer, (v) => setState(() => payoneer = v)),
      const SizedBox(height: 12),
      const Text('خيارات الدفع للعملاء', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      _account('Google Pay', 'الدفع السريع من أجهزة Android المدعومة', Icons.account_balance_wallet_outlined, googlePay, (v) => setState(() => googlePay = v)),
      _account('Visa / Mastercard', 'دفع البطاقات عبر بوابة دفع آمنة', Icons.credit_card_outlined, cards, (v) => setState(() => cards = v)),
      _account('تابي', 'الدفع بالتقسيط عبر تابي', Icons.calendar_month_outlined, tabby, (v) => setState(() => tabby = v)),
      _account('تمارا', 'الدفع بالتقسيط عبر تمارا', Icons.calendar_month_outlined, tamara, (v) => setState(() => tamara = v)),
      _account('الدفع عند الاستلام', 'الدفع نقدًا عند استلام الطلب', Icons.payments_outlined, cod, (v) => setState(() => cod = v)),
      const SizedBox(height: 16),
      Card(child: ListTile(leading: const Icon(Icons.link, color: gold), title: const Text('ربط البطاقة عبر PayPal'), subtitle: const Text('يتم الربط من داخل PayPal عند تسجيل الدخول. لا تضع رقم البطاقة أو رمزها هنا.'), trailing: const Icon(Icons.open_in_new))),
      const SizedBox(height: 12),
      FilledButton(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: dark), onPressed: () => ScaffoldMessenger.of(c).showSnackBar(const SnackBar(content: Text('تم حفظ إعدادات الدفع محليًا. التفعيل الحقيقي يحتاج مفاتيح البوابات وخادمًا آمنًا.'))), child: const Text('حفظ إعدادات الدفع')),
    ],
  ));
}


class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});
  @override Widget build(BuildContext c) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('APEX Admin', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: () => Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => const AuthPage())), icon: const Icon(Icons.logout))]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      const Text('لوحة الإدارة', style: TextStyle(fontSize: 27, fontWeight: FontWeight.w900)), const SizedBox(height: 16),
      ...[['المستخدمون','12,450',Icons.people_outline],['البائعون','384',Icons.storefront],['الطلبات','8,920',Icons.shopping_bag_outlined],['المدفوعات','1.8M ر.س',Icons.payments_outlined],['العمولات','126K ر.س',Icons.percent],['الشحن','7,540',Icons.local_shipping_outlined]].map((x) => Card(child: ListTile(leading: Icon(x[2] as IconData, color: gold), title: Text(x[0] as String), trailing: Text(x[1] as String, style: const TextStyle(fontWeight: FontWeight.w900))))),
      const SizedBox(height: 10), const Card(child: ListTile(leading: Icon(Icons.verified, color: gold), title: Text('3 متاجر بانتظار التحقق'), subtitle: Text('راجع بيانات البائعين قبل التفعيل.'))),
    ]));
}

class DeliveryDashboard extends StatelessWidget {
  const DeliveryDashboard({super.key});
  @override Widget build(BuildContext c) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(
    appBar: AppBar(title: const Text('APEX Delivery', style: TextStyle(fontWeight: FontWeight.w900)), actions: [IconButton(onPressed: () => Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => const AuthPage())), icon: const Icon(Icons.logout))]),
    body: ListView(padding: const EdgeInsets.all(16), children: [
      Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [dark, gold]), borderRadius: BorderRadius.circular(24)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('مهام التوصيل', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)), SizedBox(height: 6), Text('تابع الطلبات وتواصل مع العملاء', style: TextStyle(color: Colors.white70))])),
      const SizedBox(height: 14), ...['#APX-2041 • الرياض','#APX-2042 • جدة','#APX-2043 • الدمام'].map((x) => Card(child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFFFF2CF), child: Icon(Icons.location_on, color: gold)), title: Text(x, style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: const Text('قيد التوصيل'), trailing: const Icon(Icons.chevron_left))))
    ]));
}

class SellerDashboard extends StatefulWidget { const SellerDashboard({super.key}); @override State<SellerDashboard> createState() => _SellerState(); }
class _SellerState extends State<SellerDashboard> { int tab = 0; final tabs = ['نظرة عامة','الطلبات','المنتجات','المتجر']; @override Widget build(BuildContext c) => Directionality(textDirection: TextDirection.rtl, child: Scaffold(appBar: AppBar(title: const Text('APEX Seller', style: TextStyle(fontWeight: FontWeight.w900)), backgroundColor: Colors.white, actions: [IconButton(onPressed: () => Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => const AuthPage())), icon: const Icon(Icons.logout))]), body: ListView(padding: const EdgeInsets.all(16), children: [Container(padding: const EdgeInsets.all(20), decoration: BoxDecoration(gradient: const LinearGradient(colors: [dark, gold]), borderRadius: BorderRadius.circular(24)), child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text('متجرك في APEX', style: TextStyle(color: Colors.white, fontSize: 25, fontWeight: FontWeight.w900)), SizedBox(height: 6), Text('أدر منتجاتك وطلباتك ومبيعاتك من مكان واحد', style: TextStyle(color: Colors.white70))])), const SizedBox(height: 16), SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: List.generate(tabs.length, (i) => Padding(padding: const EdgeInsets.only(left: 8), child: ChoiceChip(label: Text(tabs[i]), selected: tab == i, onSelected: (_) => setState(() => tab = i))))), const SizedBox(height: 16), if (tab == 0) _overview() else if (tab == 1) _sellerOrders() else if (tab == 2) _products() else _store()]));
Widget _stat(String t, String v, IconData ic) => Expanded(child: Card(child: Padding(padding: const EdgeInsets.all(15), child: Column(children: [CircleAvatar(backgroundColor: const Color(0xFFFFF2CF), child: Icon(ic, color: gold)), const SizedBox(height: 8), Text(v, style: const TextStyle(fontSize: 21, fontWeight: FontWeight.w900)), Text(t, style: const TextStyle(color: Colors.black54))]))));
Widget _overview() => Column(children: [Row(children: [_stat('مبيعات اليوم','12,850 ر.س',Icons.payments_outlined), const SizedBox(width: 8), _stat('طلبات جديدة','28',Icons.shopping_bag_outlined)]), const SizedBox(height: 8), Row(children: [_stat('قيد الشحن','14',Icons.local_shipping_outlined), const SizedBox(width: 8), _stat('الرصيد','84,250 ر.س',Icons.account_balance_wallet_outlined)]), const SizedBox(height: 18), const Card(child: ListTile(leading: Icon(Icons.verified, color: gold), title: Text('متجرك قيد المراجعة', style: TextStyle(fontWeight: FontWeight.bold)), subtitle: Text('أكمل بيانات المتجر ووثائق التحقق لبدء البيع.')))]);
Widget _sellerOrders() => Column(children: List.generate(5, (i) => Card(child: ListTile(leading: const CircleAvatar(backgroundColor: Color(0xFFFFF2CF), child: Icon(Icons.inventory_2, color: gold)), title: Text('#APX-20${i + 1}', style: const TextStyle(fontWeight: FontWeight.bold)), subtitle: Text(['جديد','قيد التجهيز','تم الشحن','قيد التوصيل','تم التسليم'][i]), trailing: const Text('1,299 ر.س', style: TextStyle(fontWeight: FontWeight.bold))))));
Widget _products() => Column(children: [SizedBox(width: double.infinity, child: FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: gold, foregroundColor: dark), onPressed: () {}, icon: const Icon(Icons.add), label: const Text('إضافة منتج جديد'))), const SizedBox(height: 10), ...products.take(5).map((p) => Card(child: ListTile(leading: Text(p.image, style: const TextStyle(fontSize: 30)), title: Text(p.name), subtitle: Text('${p.price} ر.س • متوفر 25 قطعة'), trailing: const Icon(Icons.more_vert))))]);
Widget _store() => Column(children: [const Card(child: ListTile(title: Text('اسم المتجر'), subtitle: Text('APEX Store'))), const Card(child: ListTile(title: Text('حالة المتجر'), subtitle: Text('نشط بعد اكتمال التحقق'))), SizedBox(width: double.infinity, child: OutlinedButton(onPressed: () {}, child: const Text('تعديل بيانات المتجر')))]);
}
