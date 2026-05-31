import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controller/product_controller.dart';
import '../model/product_model.dart';
import '../../replace/controller/admin_replace_controller.dart';
import 'stock_snapshot_view.dart';

class StockManagementView extends StatefulWidget {
  const StockManagementView({super.key});

  @override
  State<StockManagementView> createState() => _StockManagementViewState();
}

class _StockManagementViewState extends State<StockManagementView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _search = TextEditingController();
  final _searchText = ''.obs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 2, vsync: this);
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

    return Scaffold(
      appBar: AppBar(
        title: const Text('স্টক ম্যানেজমেন্ট'),
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
            // Internal: all (regardless of stock)
            final internal = ctrl.products
                .where((p) =>
                    p.isInternal &&
                    (q.isEmpty || p.name.toLowerCase().contains(q)))
                .toList()
              ..sort((a, b) => a.name.compareTo(b.name));
            // Replace stock: only entries currently at_shop, grouped by product
            AdminReplaceController? arc;
            try { arc = Get.find<AdminReplaceController>(); } catch (_) {}
            final atShopEntries = arc?.atShop ?? [];
            final replaceMap = <String, int>{};
            for (final e in atShopEntries) {
              if (q.isEmpty || e.productName.toLowerCase().contains(q)) {
                replaceMap[e.productName] =
                    (replaceMap[e.productName] ?? 0) + e.quantity;
              }
            }
            final replaceStockList = replaceMap.entries.toList()
              ..sort((a, b) => a.key.compareTo(b.key));
            final buf = StringBuffer();
            if (regular.isNotEmpty) {
              buf.writeln('── সকল পণ্য ──');
              for (final p in regular) {
                buf.writeln('${p.name}: ${p.stock}');
              }
            }
            if (internal.isNotEmpty) {
              if (buf.isNotEmpty) buf.writeln();
              buf.writeln('── ইন্টার্নাল পণ্য ──');
              for (final p in internal) {
                buf.writeln('${p.name}: ${p.stock}');
              }
            }
            if (replaceStockList.isNotEmpty) {
              if (buf.isNotEmpty) buf.writeln();
              buf.writeln('── রিপ্লেস পণ্য ──');
              for (final e in replaceStockList) {
                buf.writeln('${e.key}: ${e.value}');
              }
            }
            final copyText = buf.toString().trimRight();
            return IconButton(
              tooltip: 'স্টক লিস্ট কপি করুন',
              icon: const Icon(Icons.copy_rounded),
              onPressed: () {
                Clipboard.setData(ClipboardData(text: copyText));
                Get.snackbar(
                  'কপি হয়েছে!',
                  'সকল ${regular.length}টি + ইন্টার্নাল ${internal.length}টি + রিপ্লেস ${replaceStockList.length}টি পণ্য কপি হয়েছে',
                  snackPosition: SnackPosition.BOTTOM,
                  duration: const Duration(seconds: 2),
                );
              },
            );
          }),
          IconButton(
            tooltip: 'স্টক স্ন্যাপশট ইতিহাস',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => Get.to(() => const StockSnapshotView()),
          ),
          IconButton(
            tooltip: 'সব স্টক শূন্য করুন',
            icon: const Icon(Icons.layers_clear_rounded),
            onPressed: () => _confirmResetAll(ctrl),
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded),
            onPressed: () => ctrl.fetchProducts(forceRefresh: true),
          ),
          IconButton(
            tooltip: 'নতুন ইন্টার্নাল পণ্য',
            icon: const Icon(Icons.add_box_rounded),
            onPressed: () => _addInternalProductDialog(ctrl),
          ),
        ],
        bottom: TabBar(
          controller: _tabs,
          tabs: const [
            Tab(text: 'সকল পণ্য'),
            Tab(text: 'ইন্টার্নাল পণ্য'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'পণ্য খুঁজুন...',
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
                  ? 'কোনো ইন্টার্নাল পণ্য নেই\n(+ বাটন দিয়ে যোগ করুন)'
                  : 'কোনো পণ্য পাওয়া যায়নি',
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
        title: const Text('সব স্টক শূন্য করবেন?'),
        content: const Text(
            'সব পণ্যের স্টক ০ হয়ে যাবে। এই কাজটি পূর্বাবস্থায় ফেরানো যাবে না।'),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Get.back();
              await ctrl.resetAllStockToZero();
              Get.snackbar(
                'সফল',
                'সব স্টক শূন্য করা হয়েছে',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: Colors.orange.shade700,
                colorText: Colors.white,
              );
            },
            child: const Text('হ্যাঁ, শূন্য করুন',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _addInternalProductDialog(ProductController ctrl) {
    final name = TextEditingController();
    final cat = TextEditingController(text: 'ইন্টার্নাল');
    final stock = TextEditingController(text: '0');
    final price = TextEditingController(text: '0');
    final note = TextEditingController();

    Get.dialog(
      AlertDialog(
        title: const Text('ইন্টার্নাল পণ্য যোগ করুন'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _tf(name, 'পণ্যের নাম *'),
              _tf(cat, 'ক্যাটাগরি'),
              _tf(stock, 'স্টক', number: true),
              _tf(price, 'মূল্য (ঐচ্ছিক)', number: true),
              _tf(note, 'নোট (ঐচ্ছিক)'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('বাতিল'),
          ),
          ElevatedButton(
            onPressed: () async {
              if (name.text.trim().isEmpty) {
                Get.snackbar('ত্রুটি', 'নাম আবশ্যক',
                    backgroundColor: Colors.red, colorText: Colors.white);
                return;
              }
              await ctrl.addProduct({
                'name': name.text.trim(),
                'productCategory': cat.text.trim(),
                'brandName': note.text.trim(),
                'stock': int.tryParse(stock.text) ?? 0,
                'purchasePrice': int.tryParse(price.text) ?? 0,
                'wholesalePrice': 0,
                'retailPrice': 0,
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
                'productCode': '',
                'productModel': '',
                'productVideo': '',
                'unit': '',
                'warranty': '',
              });
              Get.back();
              _tabs.animateTo(1); // switch to internal tab
              Get.snackbar('সফল', 'ইন্টার্নাল পণ্য যোগ হয়েছে',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.green,
                  colorText: Colors.white);
            },
            child: const Text('যোগ করুন'),
          ),
        ],
      ),
    );
  }

  Widget _tf(TextEditingController c, String label, {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType: number ? TextInputType.number : TextInputType.text,
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
    final stockColor = product.stock < 0
        ? Colors.red
        : product.stock == 0
            ? Colors.orange
            : Colors.green.shade700;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            // Product thumbnail
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: product.images.isNotEmpty
                  ? Image.network(
                      product.images.first,
                      width: 52,
                      height: 52,
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
                            'ইন্টার্নাল',
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
              tooltip: 'স্টক কমান (বিক্রি/ব্যবহার)',
              onTap: () => _adjustStockDialog(context, isAdd: false),
            ),
            const SizedBox(width: 4),
            _actionBtn(
              icon: Icons.add_circle_outline_rounded,
              color: Colors.green.shade700,
              tooltip: 'স্টক বাড়ান (ক্রয়/যোগ)',
              onTap: () => _adjustStockDialog(context, isAdd: true),
            ),
            if (product.isInternal) ...[
              const SizedBox(width: 4),
              _actionBtn(
                icon: Icons.delete_outline_rounded,
                color: Colors.red.shade700,
                tooltip: 'পণ্য ডিলেট করুন',
                onTap: () => _confirmDelete(context),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _imagePlaceholder(ColorScheme cs) {
    return Container(
      width: 52,
      height: 52,
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
    required VoidCallback onTap,
  }) {
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Icon(icon, color: color, size: 26),
        ),
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    Get.dialog(
      AlertDialog(
        title: const Text('পণ্য ডিলেট করবেন?'),
        content: Text('"${product.name}" স্থায়ীভাবে মুছে যাবে।'),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Get.back();
              await ctrl.deleteProduct(product.id);
              Get.snackbar('ডিলেট হয়েছে', '"${product.name}" মুছে ফেলা হয়েছে',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: Colors.red.shade700,
                  colorText: Colors.white);
            },
            child: const Text('ডিলেট করুন',
                style: TextStyle(color: Colors.white)),
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
          decoration: const InputDecoration(
            labelText: 'নতুন স্টক পরিমাণ',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('বাতিল')),
          ElevatedButton(
            onPressed: () async {
              final val = int.tryParse(stockCtrl.text);
              if (val == null) return;
              await ctrl.updateProduct(product.id, {'stock': val});
              Get.back();
            },
            child: const Text('সেট করুন'),
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

    final title = isAdd ? 'স্টক যোগ করুন' : 'স্টক কমান';
    final hint = isAdd ? 'কত যোগ করবেন?' : 'কত বাদ দেবেন?';
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
                'বর্তমান স্টক: ${product.stock}',
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
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    'মূল্য আপডেট (ঐচ্ছিক)',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey),
                  ),
                ),
                _priceTf(purchaseCtrl, 'ক্রয়মূল্য'),
                const SizedBox(height: 8),
                _priceTf(wholesaleCtrl, 'পাইকারি মূল্য'),
                const SizedBox(height: 8),
                _priceTf(retailCtrl, 'খুচরা মূল্য'),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: const Text('বাতিল')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
                backgroundColor: color, foregroundColor: Colors.white),
            onPressed: () async {
              final qty = int.tryParse(qtyCtrl.text);
              if (qty == null || qty <= 0) {
                Get.snackbar('ত্রুটি', 'সঠিক পরিমাণ দিন',
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
                isAdd ? 'যোগ হয়েছে' : 'কমানো হয়েছে',
                '${product.name}: ${isAdd ? '+' : '-'}$qty',
                snackPosition: SnackPosition.BOTTOM,
                backgroundColor: isAdd ? Colors.green : Colors.orange,
                colorText: Colors.white,
                duration: const Duration(seconds: 2),
              );
            },
            child: Text(isAdd ? 'যোগ করুন' : 'কমান'),
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
