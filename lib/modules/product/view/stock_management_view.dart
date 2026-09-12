import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controller/product_controller.dart';
import '../model/product_model.dart';
import '../../replace/controller/admin_replace_controller.dart';
import 'stock_snapshot_view.dart';
import 'package:kgh_admin_app/widgets/app_drawer.dart';

enum _StockAppBarAction { history, resetAll, refresh, addInternal }

class StockManagementView extends StatefulWidget {
  const StockManagementView({super.key});

  @override
  State<StockManagementView> createState() => _StockManagementViewState();
}

class _StockManagementViewState extends State<StockManagementView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  late final AdminReplaceController _arc;
  final _search = TextEditingController();
  final _searchText = ''.obs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
    _arc = Get.isRegistered<AdminReplaceController>()
        ? Get.find<AdminReplaceController>()
        : Get.put(AdminReplaceController());
    _arc.fetchEntries();
    _search.addListener(() => _searchText.value = _search.text);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = Get.find<ProductController>();
    final cs = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.sizeOf(context).width < 720;

    return Scaffold(
      drawer: appDrawerFor(context),
      appBar: AppBar(
        title: Text('স্টক ম্যানেজমেন্ট'.tr),
        actions: [
          Obx(() {
            final q = _searchText.value.toLowerCase();
            // Regular: stock >= 1 only
            final regular = ctrl.products
                .where((p) =>
                    !p.isInternal &&
                    p.stock >= 1 &&
                    (q.isEmpty || p.name.toLowerCase().contains(q)))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
            // Internal: stock >= 1 only
            final internal = ctrl.products
                .where((p) =>
                    p.isInternal &&
                p.stock >= 1 &&
                    (q.isEmpty || p.name.toLowerCase().contains(q)))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
            // Replace stock: only entries currently at_shop, grouped by product
            final atShopEntries = _arc.atShop;
            final replaceMap = <String, int>{};
            for (final e in atShopEntries) {
              if (e.quantity >= 1 &&
                  (q.isEmpty || e.productName.toLowerCase().contains(q))) {
                replaceMap[e.productName] =
                    (replaceMap[e.productName] ?? 0) + e.quantity;
              }
            }
            final replaceStockList = replaceMap.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));
            final buf = StringBuffer();
            if (regular.isNotEmpty) {
              buf.writeln('── সকল পণ্য ──'.tr);
              for (final p in regular) {
                buf.writeln('${p.name}: ${p.stock}');
              }
            }
            if (internal.isNotEmpty) {
              if (buf.isNotEmpty) buf.writeln();
              buf.writeln('── ইন্টার্নাল পণ্য ──'.tr);
              for (final p in internal) {
                buf.writeln('${p.name}: ${p.stock}');
              }
            }
            if (replaceStockList.isNotEmpty) {
              if (buf.isNotEmpty) buf.writeln();
              buf.writeln('── রিপ্লেস পণ্য ──'.tr);
              for (final e in replaceStockList) {
                buf.writeln('${e.key}: ${e.value}');
              }
            }
            final copyText = buf.toString().trimRight();
            return IconButton(
              tooltip: 'স্টক লিস্ট কপি করুন'.tr,
              icon: Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: copyText));
                Get.snackbar(
                  'কপি হয়েছে!'.tr,
                  '${'সকল'.tr} ${regular.length}${'টি'.tr} + ${'ইন্টার্নাল'.tr} ${internal.length}${'টি'.tr} + ${'রিপ্লেস'.tr} ${replaceStockList.length}${'টি পণ্য কপি হয়েছে'.tr}',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: Duration(seconds: 2),
                );
              },
            );
          }),
          if (isCompact)
            PopupMenuButton<_StockAppBarAction>(
              tooltip: 'More actions'.tr,
              onSelected: (value) {
                switch (value) {
                  case _StockAppBarAction.history:
                    Get.to(() => StockSnapshotView());
                    break;
                  case _StockAppBarAction.resetAll:
                    _confirmResetAll(ctrl);
                    break;
                  case _StockAppBarAction.refresh:
                    ctrl.fetchProducts(forceRefresh: true);
                    _arc.fetchEntries(force: true);
                    break;
                  case _StockAppBarAction.addInternal:
                    _addInternalProductDialog(ctrl);
                    break;
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: _StockAppBarAction.history,
                  child: Text('স্টক স্ন্যাপশট ইতিহাস'.tr),
                ),
                PopupMenuItem(
                  value: _StockAppBarAction.resetAll,
                  child: Text('সব স্টক শূন্য করুন'.tr),
                ),
                PopupMenuItem(
                  value: _StockAppBarAction.refresh,
                  child: Text('Refresh'.tr),
                ),
                PopupMenuItem(
                  value: _StockAppBarAction.addInternal,
                  child: Text('নতুন ইন্টার্নাল পণ্য'.tr),
                ),
              ],
            )
          else ...[
            IconButton(
              tooltip: 'স্টক স্ন্যাপশট ইতিহাস'.tr,
              icon: const Icon(Icons.history_rounded),
              onPressed: () => Get.to(() => const StockSnapshotView()),
            ),
            IconButton(
              tooltip: 'সব স্টক শূন্য করুন'.tr,
              icon: const Icon(Icons.layers_clear_rounded),
              onPressed: () => _confirmResetAll(ctrl),
            ),
            IconButton(
              tooltip: 'Refresh'.tr,
              icon: const Icon(Icons.refresh_rounded),
              onPressed: () {
                ctrl.fetchProducts(forceRefresh: true);
                _arc.fetchEntries(force: true);
              },
            ),
            IconButton(
              tooltip: 'নতুন ইন্টার্নাল পণ্য'.tr,
              icon: Icon(Icons.add_box_rounded),
              onPressed: () => _addInternalProductDialog(ctrl),
            ),
          ],
        ],
        bottom: TabBar(
          controller: _tabs,
          isScrollable: isCompact,
          tabs: [
            Tab(text: 'সকল পণ্য'.tr),
            Tab(text: 'ইন্টার্নাল পণ্য'.tr),
          ],
        ),
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(isCompact ? 10 : 12, 10,
                    isCompact ? 10 : 12, 4),
                child: TextField(
                  controller: _search,
                  decoration: InputDecoration(
                    hintText: 'পণ্য খুঁজুন...'.tr,
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: Obx(() => _searchText.value.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded),
                            onPressed: () {
                              _search.clear();
                            },
                          )
                        : const SizedBox.shrink()),
                  ),
                ),
              ),
              Expanded(
                child: Obx(() {
                  final all = ctrl.products;
                  final q = _searchText.value.toLowerCase();

                  final regular = all
                      .where((p) =>
                          !p.isInternal &&
                          (q.isEmpty || p.name.toLowerCase().contains(q)))
                      .toList()
                    ..sort((a, b) => a.name.compareTo(b.name));

                  final internal = all
                      .where((p) =>
                          p.isInternal &&
                          (q.isEmpty || p.name.toLowerCase().contains(q)))
                      .toList()
                    ..sort((a, b) => a.name.compareTo(b.name));

                  if (ctrl.loading.value) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return TabBarView(
                    controller: _tabs,
                    children: [
                      _buildStockList(ctrl, regular, cs, isInternal: false),
                      _buildStockList(ctrl, internal, cs, isInternal: true),
                    ],
                  );
                }),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStockList(
    ProductController ctrl,
    List<ProductModel> list,
    ColorScheme cs, {
    required bool isInternal,
  }) {
    if (list.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.inventory_2_outlined,
                size: 56, color: cs.onSurface.withOpacity(0.3)),
            const SizedBox(height: 12),
            Text(
              isInternal
                  ? 'কোনো ইন্টার্নাল পণ্য নেই\n(+ বাটন দিয়ে যোগ করুন)'.tr
                  : 'কোনো পণ্য পাওয়া যায়নি'.tr,
              textAlign: TextAlign.center,
              style: TextStyle(color: cs.onSurface.withOpacity(0.5)),
            ),
          ],
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 6),
      itemBuilder: (context, i) => _StockTile(
        product: list[i],
        ctrl: ctrl,
      ),
    );
  }

  void _confirmResetAll(ProductController ctrl) {
    Get.dialog(
      AlertDialog(
        title: Text('সব স্টক শূন্য করবেন?'.tr),
        content: Text(
            'সব পণ্যের স্টক ০ হয়ে যাবে। এই কাজটি পূর্বাবস্থায় ফেরানো যাবে না।'.tr),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: Text('বাতিল'.tr),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Get.back();
              await ctrl.resetAllStockToZero();
              Get.snackbar(
                'সফল'.tr,
                'সব স্টক শূন্য করা হয়েছে'.tr,
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.orange.shade700,
                colorText: Colors.white,
              );
            },
            child: Text('হ্যাঁ, শূন্য করুন'.tr,
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _addInternalProductDialog(ProductController ctrl) {
    final name = TextEditingController();
    final cat = TextEditingController(text: 'ইন্টার্নাল'.tr);
    final brand = TextEditingController();
    final code = TextEditingController();
    final unit = TextEditingController();
    final stock = TextEditingController(text: '0');
    final purchasePrice = TextEditingController(text: '0');
    final wholesalePrice = TextEditingController(text: '0');
    final retailPrice = TextEditingController(text: '0');

    Get.dialog(
      AlertDialog(
        title: Text('নতুন ইন্টার্নাল পণ্য'.tr),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('পণ্যের তথ্য'.tr),
              _tf(name, 'পণ্যের নাম *'.tr),
              _tf(brand, 'ব্র্যান্ড'.tr),
              _tf(code, 'প্রোডাক্ট কোড'.tr),
              _tf(unit, 'ইউনিট (pcs/box/set)'.tr),
              const SizedBox(height: 8),
              _sectionTitle('ক্যাটাগরি ও স্টক'.tr),
              _tf(cat, 'ক্যাটাগরি'.tr),
              _tf(stock, 'স্টক'.tr, number: true),
              const SizedBox(height: 8),
              _sectionTitle('মূল্য'.tr),
              _priceTf(purchasePrice, 'ক্রয়মূল্য'.tr),
              _priceTf(wholesalePrice, 'পাইকারি মূল্য'.tr),
              _priceTf(retailPrice, 'খুচরা মূল্য'.tr),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              name.dispose();
              cat.dispose();
              brand.dispose();
              code.dispose();
              unit.dispose();
              stock.dispose();
              purchasePrice.dispose();
              wholesalePrice.dispose();
              retailPrice.dispose();
              Get.back();
            },
            child: Text('বাতিল'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                Get.snackbar('ত্রুটি'.tr, 'নাম আবশ্যক'.tr,
                    backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }
              await ctrl.addProduct({
                'name': name.text.trim(),
                'productCategory': cat.text.trim(),
                'brandName': brand.text.trim(),
                'productCode': code.text.trim(),
                'unit': unit.text.trim(),
                'stock': int.tryParse(stock.text) ?? 0,
                'purchasePrice': double.tryParse(purchasePrice.text.trim()) ?? 0,
                'wholesalePrice': double.tryParse(wholesalePrice.text.trim()) ?? 0,
                'retailPrice': double.tryParse(retailPrice.text.trim()) ?? 0,
                'isAvailable': false,
                'isHot': false,
                'isNew': false,
                'isInternal': true,
                'images': [],
                'productDetails': [],
                'quantityDiscount': {},
                'pendingStock': 0,
                'totalSold': 0,
                'totalOrders': 0,
                'monthlySold': 0,
                'replaceCount': 0,
                'productModel': '',
                'productVideo': '',
                'warranty': '',
              });
              Get.back();
              _tabs.animateTo(1);
              Get.snackbar('সফল'.tr, 'ইন্টার্নাল পণ্য যোগ হয়েছে'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white);
            },
            child: Text('যোগ করুন'.tr),
          ),
        ],
      ),
    );
  }

  void _editInternalProductDialog(ProductController ctrl, ProductModel product) {
    final name = TextEditingController(text: product.name);
    final cat = TextEditingController(text: product.productCategory);
    final brand = TextEditingController(text: product.brandName);
    final code = TextEditingController(text: product.productCode);
    final unit = TextEditingController(text: product.unit);
    final stock = TextEditingController(text: product.stock.toString());
    final purchasePrice = TextEditingController(text: product.purchasePrice.toString());
    final wholesalePrice = TextEditingController(text: product.wholesalePrice.toString());
    final retailPrice = TextEditingController(text: product.retailPrice.toString());

    Get.dialog(
      AlertDialog(
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _sectionTitle('পণ্যের তথ্য'.tr),
              _tf(name, 'পণ্যের নাম *'.tr),
              _tf(brand, 'ব্র্যান্ড'.tr),
              _tf(code, 'প্রোডাক্ট কোড'.tr),
              _tf(unit, 'ইউনিট (pcs/box/set)'.tr),
              const SizedBox(height: 8),
              _sectionTitle('ক্যাটাগরি ও স্টক'.tr),
              _tf(cat, 'ক্যাটাগরি'.tr),
              _tf(stock, 'স্টক'.tr, number: true),
              const SizedBox(height: 8),
              _sectionTitle('মূল্য'.tr),
              _priceTf(purchasePrice, 'ক্রয়মূল্য'.tr),
              _priceTf(wholesalePrice, 'পাইকারি মূল্য'.tr),
              _priceTf(retailPrice, 'খুচরা মূল্য'.tr),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              name.dispose();
              cat.dispose();
              brand.dispose();
              code.dispose();
              unit.dispose();
              stock.dispose();
              purchasePrice.dispose();
              wholesalePrice.dispose();
              retailPrice.dispose();
              Get.back();
            },
            child: Text('বাতিল'.tr),
          ),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                Get.snackbar('ত্রুটি'.tr, 'নাম আবশ্যক'.tr,
                    backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }
              await ctrl.updateProduct(product.id, {
                'name': name.text.trim(),
                'productCategory': cat.text.trim(),
                'brandName': brand.text.trim(),
                'productCode': code.text.trim(),
                'unit': unit.text.trim(),
                'stock': int.tryParse(stock.text) ?? 0,
                'purchasePrice': double.tryParse(purchasePrice.text.trim()) ?? 0,
                'wholesalePrice': double.tryParse(wholesalePrice.text.trim()) ?? 0,
                'retailPrice': double.tryParse(retailPrice.text.trim()) ?? 0,
              });
              Get.back();
              Get.snackbar('সফল'.tr, 'পণ্য আপডেট হয়েছে'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white);
            },
            child: Text('আপডেট করুন'.tr),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4, top: 4),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: Colors.grey,
        ),
      ),
    );
  }

  Widget _priceTf(TextEditingController c, String label) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: TextField(
        controller: c,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: label,
          prefixText: '৳ ',
          isDense: true,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }

  Widget _tf(TextEditingController c, String label,
      {bool number = false, bool decimal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: number
            ? TextInputType.numberWithOptions(decimal: decimal)
            : TextInputType.text,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
        ),
      ),
    );
  }
}

// ─── Individual Stock Tile ────────────────────────────────────────────────────

class _StockTile extends StatelessWidget {
  final ProductModel product;
  final ProductController ctrl;

  const _StockTile({required this.product, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isCompact = MediaQuery.sizeOf(context).width < 420;
    final stockColor = product.stock < 0
        ? Colors.red
        : product.stock == 0
            ? Colors.orange
            : Colors.green.shade700;

    final card = Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.images.isNotEmpty
                  ? Image.network(
                      product.images.first,
                      width: isCompact ? 44 : 52,
                      height: isCompact ? 44 : 52,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _imagePlaceholder(cs),
                    )
                  : _imagePlaceholder(cs),
            ),
            const SizedBox(width: 10),
            // Product info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (product.isInternal)
                        Container(
                          margin: const EdgeInsets.only(right: 6),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: cs.tertiaryContainer,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'ইন্টার্নাল'.tr,
                            style: TextStyle(
                                fontSize: 10,
                                color: cs.onTertiaryContainer,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                      Expanded(
                        child: Text(
                          product.name,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 14.5),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    product.productCategory,
                    style: TextStyle(
                        fontSize: 11.5,
                        color: cs.onSurface.withOpacity(0.55)),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            // Stock badge
            GestureDetector(
              onTap: () => _editStockDialog(context),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: stockColor.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: stockColor.withOpacity(0.35)),
                ),
                child: Text(
                  '${product.stock}',
                  style: TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                      color: stockColor),
                ),
              ),
            ),
            const SizedBox(width: 8),
            // Action buttons
            _actionBtn(
              icon: Icons.remove_circle_outline_rounded,
              color: Colors.red,
              tooltip: 'স্টক কমান (বিক্রি/ব্যবহার)'.tr,
              compact: isCompact,
              onTap: () => _adjustStockDialog(context, isAdd: false),
            ),
            SizedBox(width: isCompact ? 2 : 4),
            _actionBtn(
              icon: Icons.add_circle_outline_rounded,
              color: Colors.green.shade700,
              tooltip: 'স্টক বাড়ান (ক্রয়/যোগ)'.tr,
              compact: isCompact,
              onTap: () => _adjustStockDialog(context, isAdd: true),
            ),
            if (product.isInternal) ...[
              SizedBox(width: isCompact ? 2 : 4),
              _actionBtn(
                icon: Icons.edit_outlined,
                color: Colors.blue.shade700,
                tooltip: 'পণ্য এডিট করুন'.tr,
                compact: isCompact,
                onTap: () => _editInternalProduct(context),
              ),
              SizedBox(width: isCompact ? 2 : 4),
              _actionBtn(
                icon: Icons.delete_outline_rounded,
                color: Colors.red.shade700,
                tooltip: 'পণ্য ডিলেট করুন'.tr,
                compact: isCompact,
                onTap: () => _confirmDelete(context),
              ),
            ],
          ],
        ),
      ),
    );

    if (product.isInternal) {
      return GestureDetector(
        onTap: () => _editInternalProduct(context),
        child: card,
      );
    }
    return card;
  }

  Widget _imagePlaceholder(ColorScheme cs) {
    final size = 52.0;
    return Container(
      width: size,
      height: size,
      color: cs.surfaceContainerHighest,
      alignment: Alignment.center,
      child: Icon(Icons.inventory_2_rounded,
          size: 22, color: cs.onSurface.withOpacity(0.35)),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required Color color,
    required String tooltip,
    required bool compact,
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 2 : 4),
          child: Icon(icon, color: color, size: compact ? 23 : 26),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: Text('পণ্য ডিলেট করবেন?'.tr),
        content: Text('"${product.name}" ${'স্থায়ীভাবে মুছে যাবে'.tr}।'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('বাতিল'.tr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Get.back();
              await ctrl.deleteProduct(product.id);
              Get.snackbar('ডিলেট হয়েছে'.tr, '"${product.name}" ${'মুছে ফেলা হয়েছে'.tr}',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.shade700,
                  colorText: Colors.white);
            },
            child: Text('ডিলেট করুন'.tr,
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _editInternalProduct(BuildContext context) {
    final name = TextEditingController(text: product.name);
    final cat = TextEditingController(text: product.productCategory);
    final brand = TextEditingController(text: product.brandName);
    final code = TextEditingController(text: product.productCode);
    final unitCtrl = TextEditingController(text: product.unit);
    final stockCtrl = TextEditingController(text: product.stock.toString());
    final purchaseCtrl =
        TextEditingController(text: product.purchasePrice.toString());
    final wholesaleCtrl =
        TextEditingController(text: product.wholesalePrice.toString());
    final retailCtrl =
        TextEditingController(text: product.retailPrice.toString());

    Widget tf(TextEditingController c, String label,
        {bool number = false, bool decimal = false, String? prefix}) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: TextField(
          controller: c,
          keyboardType: number
              ? TextInputType.numberWithOptions(decimal: decimal)
              : TextInputType.text,
          decoration: InputDecoration(
            labelText: label,
            prefixText: prefix,
            isDense: true,
            border:
                OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
          ),
        ),
      );
    }

    Widget section(String text) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 4, top: 4),
        child: Text(text,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, color: Colors.grey)),
      );
    }

    Get.dialog(
      AlertDialog(
        title:
            Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              section('পণ্যের তথ্য'.tr),
              tf(name, 'পণ্যের নাম *'.tr),
              tf(brand, 'ব্র্যান্ড'.tr),
              tf(code, 'প্রোডাক্ট কোড'.tr),
              tf(unitCtrl, 'ইউনিট (pcs/box/set)'.tr),
              const SizedBox(height: 8),
              section('ক্যাটাগরি ও স্টক'.tr),
              tf(cat, 'ক্যাটাগরি'.tr),
              tf(stockCtrl, 'স্টক'.tr, number: true),
              const SizedBox(height: 8),
              section('মূল্য'.tr),
              tf(purchaseCtrl, 'ক্রয়মূল্য'.tr,
                  number: true, decimal: true, prefix: '৳ '),
              tf(wholesaleCtrl, 'পাইকারি মূল্য'.tr,
                  number: true, decimal: true, prefix: '৳ '),
              tf(retailCtrl, 'খুচরা মূল্য'.tr,
                  number: true, decimal: true, prefix: '৳ '),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Get.back(), child: Text('বাতিল'.tr)),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                Get.snackbar('ত্রুটি'.tr, 'নাম আবশ্যক'.tr,
                    backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }
              await ctrl.updateProduct(product.id, {
                'name': name.text.trim(),
                'productCategory': cat.text.trim(),
                'brandName': brand.text.trim(),
                'productCode': code.text.trim(),
                'unit': unitCtrl.text.trim(),
                'stock': int.tryParse(stockCtrl.text) ?? 0,
                'purchasePrice':
                    double.tryParse(purchaseCtrl.text.trim()) ?? 0,
                'wholesalePrice':
                    double.tryParse(wholesaleCtrl.text.trim()) ?? 0,
                'retailPrice': double.tryParse(retailCtrl.text.trim()) ?? 0,
              });
              Get.back();
              Get.snackbar('সফল'.tr, 'পণ্য আপডেট হয়েছে'.tr,
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white);
            },
            child: Text('আপডেট করুন'.tr),
          ),
        ],
      ),
    );
  }

  void _editStockDialog(BuildContext context) {
    final stockCtrl = TextEditingController(text: product.stock.toString());
    Get.dialog(
      AlertDialog(
        title: Text(product.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        content: TextField(
          controller: stockCtrl,
          keyboardType: TextInputType.number,
          autofocus: true,
          decoration: InputDecoration(
            labelText: 'নতুন স্টক পরিমাণ'.tr,
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('বাতিল'.tr)),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(stockCtrl.text);
              if (val == null) return;
              await ctrl.updateProduct(product.id, {'stock': val});
              Get.back();
            },
            child: Text('সেট করুন'.tr),
          ),
        ],
      ),
    );
  }

  void _adjustStockDialog(BuildContext context, {required bool isAdd}) {
    final qtyCtrl = TextEditingController(text: '1');
    final purchaseCtrl = TextEditingController(
        text: product.purchasePrice > 0 ? product.purchasePrice.toString() : '');
    final wholesaleCtrl = TextEditingController(
        text: product.wholesalePrice > 0 ? product.wholesalePrice.toString() : '');
    final retailCtrl = TextEditingController(
        text: product.retailPrice > 0 ? product.retailPrice.toString() : '');

    final title = isAdd ? 'স্টক যোগ করুন'.tr : 'স্টক কমান'.tr;
    final hint = isAdd ? 'কত যোগ করবেন?'.tr : 'কত বাদ দেবেন?'.tr;
    final icon = isAdd ? Icons.add_circle_rounded : Icons.remove_circle_rounded;
    final color = isAdd ? Colors.green.shade700 : Colors.red;

    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                product.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                '${'বর্তমান স্টক'.tr}: ${product.stock}',
                style: const TextStyle(fontSize: 12.5, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: qtyCtrl,
                keyboardType: TextInputType.number,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: hint,
                  border: const OutlineInputBorder(),
                ),
              ),
              if (isAdd) ...[
                const SizedBox(height: 14),
                const Divider(),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'মূল্য আপডেট (ঐচ্ছিক)'.tr,
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey),
                  ),
                ),
                _priceTf(purchaseCtrl, 'ক্রয়মূল্য'.tr),
                const SizedBox(height: 8),
                _priceTf(wholesaleCtrl, 'পাইকারি মূল্য'.tr),
                const SizedBox(height: 8),
                _priceTf(retailCtrl, 'খুচরা মূল্য'.tr),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('বাতিল'.tr)),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white),
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text);
              if (qty == null || qty <= 0) {
                Get.snackbar('ত্রুটি'.tr, 'সঠিক পরিমাণ দিন'.tr,
                    backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }
              if (isAdd) {
                await ctrl.addStock(product.id, qty);
                // Update prices if any field is filled
                final updates = <String, dynamic>{};
                final pp = int.tryParse(purchaseCtrl.text);
                final wp = int.tryParse(wholesaleCtrl.text);
                final rp = int.tryParse(retailCtrl.text);
                if (pp != null) updates['purchasePrice'] = pp;
                if (wp != null) updates['wholesalePrice'] = wp;
                if (rp != null) updates['retailPrice'] = rp;
                if (updates.isNotEmpty) {
                  await ctrl.updateProduct(product.id, updates);
                }
              } else {
                await ctrl.deductStock(product.id, qty);
              }
              Get.back();
              Get.snackbar(
                isAdd ? 'যোগ হয়েছে'.tr : 'কমানো হয়েছে'.tr,
                '${product.name}: ${isAdd ? '+' : '-'}$qty',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: isAdd ? Colors.green : Colors.orange,
                colorText: Colors.white,
                duration: const Duration(seconds: 2),
              );
            },
            child: Text(isAdd ? 'যোগ করুন'.tr : 'কমান'.tr),
          ),
        ],
      ),
    );
  }

  Widget _priceTf(TextEditingController c, String label) {
    return TextField(
      controller: c,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        prefixText: '৳ ',
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }
}
