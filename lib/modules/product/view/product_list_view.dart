import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controller/product_controller.dart';
import '../model/product_model.dart';

class ProductListView extends GetView<ProductController> {
  const ProductListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Products'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.fetchProducts(forceRefresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addProductDialog(),
          ),
        ],
      ),
      body: Column(
        children: [
          _topActionRow(context),
          _searchBar(),
          _categoryChips(),
          const SizedBox(height: 4),
          Expanded(child: _productList()),
        ],
      ),
    );
  }

  Widget _topActionRow(BuildContext context) {
    return Obx(() {
      if (controller.loading.value) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        child: Row(
          children: [
            OutlinedButton.icon(
              icon: const Icon(Icons.inventory_2_rounded, size: 18),
              label: const Text('Stock List'),
              onPressed: () => _showStockList(context),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: const Text('Replace List'),
              onPressed: () => _showReplaceList(context),
            ),
          ],
        ),
      );
    });
  }

  void _showStockList(BuildContext context) {
    final all = controller.products;
    final sorted = [...all]..sort((a, b) => a.name.compareTo(b.name));
    final text = sorted
        .map((p) => '${p.name}: ${p.stock}')
        .join('\n');

    _showCopyableList(
      context: context,
      title: 'Stock List (${sorted.length})',
      text: text,
      rows: sorted
          .map((p) => _ListRow(
                label: p.name,
                sublabel: p.productCategory,
                value: '${p.stock}',
                valueColor: p.stock < 0
                    ? Colors.red
                    : p.stock == 0
                        ? Colors.orange
                        : Colors.green.shade700,
              ))
          .toList(),
    );
  }

  void _showReplaceList(BuildContext context) {
    final all = controller.products.where((p) => p.replaceCount > 0).toList()
      ..sort((a, b) => b.replaceCount.compareTo(a.replaceCount));
    if (all.isEmpty) {
      Get.snackbar('Replace List', 'কোনো replace product নেই',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }
    final text = all
        .map((p) => '${p.name}: ${p.replaceCount}টি')
        .join('\n');

    _showCopyableList(
      context: context,
      title: 'Replace List (${all.length})',
      text: text,
      rows: all
          .map((p) => _ListRow(
                label: p.name,
                sublabel: p.productCategory,
                value: '${p.replaceCount}টি',
                valueColor: Colors.orange.shade700,
              ))
          .toList(),
    );
  }

  void _showCopyableList({
    required BuildContext context,
    required String title,
    required String text,
    required List<_ListRow> rows,
  }) {
    Get.dialog(
      Dialog(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480, maxHeight: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(title,
                          style: const TextStyle(
                              fontWeight: FontWeight.w700, fontSize: 16)),
                    ),
                    IconButton(
                      tooltip: 'Copy to clipboard',
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: text));
                        Get.snackbar('Copied!', 'List copied to clipboard',
                            snackPosition: SnackPosition.BOTTOM,
                            duration: const Duration(seconds: 2));
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Get.back(),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  itemCount: rows.length,
                  separatorBuilder: (context, index) =>
                      const Divider(height: 1, indent: 16, endIndent: 16),
                  itemBuilder: (context, i) {
                    final r = rows[i];
                    return ListTile(
                      dense: true,
                      title: Text(r.label,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: r.sublabel.isNotEmpty
                          ? Text(r.sublabel,
                              style: const TextStyle(fontSize: 11))
                          : null,
                      trailing: Text(
                        r.value,
                        style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                            color: r.valueColor),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // 🔍 Search
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 6),
      child: TextField(
        onChanged: (v) => controller.searchText.value = v,
        decoration: const InputDecoration(
          hintText: 'Search product...',
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
    );
  }

  // ✅ FIXED CATEGORY SCROLL (Mobile + Web + Laptop)
  Widget _categoryChips() {
    return Obx(() => SizedBox(
          height: 52,
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: controller.categories.length,
              itemBuilder: (context, index) {
                final c = controller.categories[index];
                final selected =
                    controller.selectedCategory.value == c;

                return Padding(
                  padding: const EdgeInsets.only(right: 7),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    showCheckmark: false,
                    onSelected: (_) =>
                        controller.selectedCategory.value = c,
                  ),
                );
              },
            ),
          ),
        ));
  }

  // 📦 Product List
  Widget _productList() {
    return Obx(() {
      if (controller.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final list = controller.filteredProducts;

      if (list.isEmpty) {
        return const Center(child: Text('No products found'));
      }

      return RefreshIndicator(
        onRefresh: () =>
            controller.fetchProducts(forceRefresh: true),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1200
                ? 4
                : constraints.maxWidth >= 900
                    ? 3
                    : constraints.maxWidth >= 600
                        ? 2
                        : 1;

            return GridView.builder(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: columns,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: columns == 1 ? 2.2 : 1.25,
              ),
              itemCount: list.length,
              itemBuilder: (context, index) {
                final p = list[index];

                return Card(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(18),
                    onTap: () => _editProductDialog(p),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 15,
                                  ),
                                ),
                              ),
                              Switch(
                                value: p.isAvailable,
                                onChanged: (v) => controller.updateProduct(
                                  p.id,
                                  {'isAvailable': v},
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Expanded(
                            child: Row(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: p.images.isNotEmpty
                                      ? Image.network(
                                          p.images.first,
                                          width: 78,
                                          height: 78,
                                          fit: BoxFit.cover,
                                        errorBuilder: (context, error, stackTrace) => Container(
                                            width: 78,
                                            height: 78,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .surfaceContainerHighest,
                                            alignment: Alignment.center,
                                            child: const Icon(Icons.image_not_supported_rounded),
                                          ),
                                        )
                                      : Container(
                                          width: 78,
                                          height: 78,
                                          color: Theme.of(context)
                                              .colorScheme
                                              .surfaceContainerHighest,
                                          alignment: Alignment.center,
                                          child: const Icon(Icons.image_rounded),
                                        ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      _line('Category', p.productCategory),
                                      _line('Stock', p.stock.toString()),
                                      _line('Buy', '৳${p.purchasePrice}'),
                                      _line('Wholesale', '৳${p.wholesalePrice}'),
                                      _line('Retail', '৳${p.retailPrice}'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      );
    });
  }

  Widget _line(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        '$label: $value',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(fontSize: 12.5),
      ),
    );
  }

  // ✏️ EDIT PRODUCT (Retail Added)
  void _editProductDialog(ProductModel p) {
    final name = TextEditingController(text: p.name);
    final cat = TextEditingController(text: p.productCategory);
    final stock = TextEditingController(text: p.stock.toString());
    final buy = TextEditingController(text: p.purchasePrice.toString());
    final wholesale =
        TextEditingController(text: p.wholesalePrice.toString());
    final retail =
        TextEditingController(text: p.retailPrice.toString());

    Get.defaultDialog(
      title: 'Edit Product',
      content: SingleChildScrollView(
        child: Column(
          children: [
            _tf(name, 'Name'),
            _tf(cat, 'Category'),
            _tf(stock, 'Stock', number: true),
            _tf(buy, 'Purchase Price', number: true),
            _tf(wholesale, 'Wholesale Price', number: true),
            _tf(retail, 'Retail Price', number: true),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red),
              icon: const Icon(Icons.delete),
              label: const Text('Delete'),
              onPressed: () async {
                await controller.deleteProduct(p.id);
                Get.back();
              },
            ),
          ],
        ),
      ),
      textConfirm: 'Save',
      onConfirm: () async {
        await controller.updateProduct(p.id, {
          'name': name.text,
          'productCategory': cat.text,
          'stock': int.tryParse(stock.text) ?? p.stock,
          'purchasePrice':
              int.tryParse(buy.text) ?? p.purchasePrice,
          'wholesalePrice':
              int.tryParse(wholesale.text) ?? p.wholesalePrice,
          'retailPrice':
              int.tryParse(retail.text) ?? p.retailPrice,
        });
        Get.back();
      },
    );
  }

  void _addProductDialog() {
    final name = TextEditingController();
    final cat = TextEditingController();
    final brand = TextEditingController();
    final stock = TextEditingController(text: '0');
    final buy = TextEditingController(text: '0');
    final wholesale = TextEditingController(text: '0');
    final retail = TextEditingController(text: '0');

    Get.defaultDialog(
      title: 'নতুন Product যোগ করুন',
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _tf(name, 'Product Name *'),
            _tf(cat, 'Category *'),
            _tf(brand, 'Brand'),
            _tf(stock, 'Stock', number: true),
            _tf(buy, 'Purchase Price', number: true),
            _tf(wholesale, 'Wholesale Price', number: true),
            _tf(retail, 'Retail Price', number: true),
          ],
        ),
      ),
      textCancel: 'বাতিল',
      textConfirm: 'যোগ করুন',
      onConfirm: () async {
        if (name.text.trim().isEmpty || cat.text.trim().isEmpty) {
          Get.snackbar('Error', 'Name ও Category আবশ্যক',
              backgroundColor: Colors.red,
              colorText: Colors.white);
          return;
        }
        await controller.addProduct({
          'name': name.text.trim(),
          'productCategory': cat.text.trim(),
          'brandName': brand.text.trim(),
          'stock': int.tryParse(stock.text) ?? 0,
          'purchasePrice': int.tryParse(buy.text) ?? 0,
          'wholesalePrice': int.tryParse(wholesale.text) ?? 0,
          'retailPrice': int.tryParse(retail.text) ?? 0,
          'isAvailable': true,
          'isHot': false,
          'isNew': true,
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
        Get.snackbar('সফল', 'Product সফলভাবে যোগ হয়েছে',
            backgroundColor: Colors.green,
            colorText: Colors.white);
      },
    );
  }

  Widget _tf(TextEditingController c, String l,
      {bool number = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        keyboardType:
            number ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(
          labelText: l,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
    );
  }
}

class _ListRow {
  final String label;
  final String sublabel;
  final String value;
  final Color valueColor;

  const _ListRow({
    required this.label,
    required this.sublabel,
    required this.value,
    required this.valueColor,
  });
}