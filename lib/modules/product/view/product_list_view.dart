import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../controller/product_controller.dart';
import '../model/product_model.dart';
import 'product_form_view.dart';
import 'stock_management_view.dart';
import '../../replace/view/admin_replace_view.dart';
import '../../replace/controller/admin_replace_controller.dart';
import 'package:kgh_admin_app/widgets/app_drawer.dart';

class ProductListView extends GetView<ProductController> {
  const ProductListView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: appDrawerFor(context),
      appBar: AppBar(
        title: Text('Products'.tr),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => controller.fetchProducts(forceRefresh: true),
          ),
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => _addProductDialog(),
          ),
          PopupMenuButton<String>(
            tooltip: 'আরো'.tr,
            onSelected: (val) {
              if (val == 'normalize') _confirmNormalize();
            },
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'normalize',
                child: Row(
                  children: [
                    Icon(Icons.auto_fix_high_rounded, size: 18),
                    SizedBox(width: 10),
                    Text('সব ডকুমেন্ট ঠিক করুন'.tr),
                  ],
                ),
              ),
            ],
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
              label: Text('Stock List'.tr),
              onPressed: () => _showStockList(context),
            ),
            const SizedBox(width: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.swap_horiz_rounded, size: 18),
              label: Text('Replace List'.tr),
              onPressed: () => _showReplaceList(context),
            ),
          ],
        ),
      );
    });
  }

  void _showStockList(BuildContext context) {
    Get.to(() => const StockManagementView());
  }

  void _confirmNormalize() {
    Get.dialog(
      AlertDialog(
        title: Row(
          children: [
            Icon(Icons.auto_fix_high_rounded, size: 22),
            SizedBox(width: 8),
            Text('সব ডকুমেন্ট ঠিক করুন'.tr),
          ],
        ),
        content: Text(
          'সব product document-এ missing fields যোগ হবে (যেমন: isInternal, createdAt ইত্যাদি)। যেসব documents ইতিমধ্যে সম্পূর্ণ সেগুলো পরিবর্তন হবে না।'
              .tr,
        ),
        actions: [
          TextButton(onPressed: () => Get.back(), child: Text('বাতিল'.tr)),
          ElevatedButton.icon(
            icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
            label: Text('শুরু করুন'.tr),
            onPressed: () async {
              Get.back();
              Get.dialog(
                AlertDialog(
                  content: Row(
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(width: 16),
                      Text('Processing...'.tr),
                    ],
                  ),
                ),
                barrierDismissible: false,
              );
              try {
                final updated = await controller.normalizeAllProducts();
                Get.back();
                Get.snackbar(
                  'সম্পন্ন!'.tr,
                  updated == 0
                      ? 'সব ডকুমেন্ট ইতিমধ্যে সম্পূর্ণ ছিল।'.tr
                      : '$updated ${'টি ডকুমেন্ট আপডেট হয়েছে'.tr}।',
                  snackPosition: SnackPosition.BOTTOM,
                  backgroundColor: updated == 0 ? Colors.blue : Colors.green,
                  colorText: Colors.white,
                  duration: const Duration(seconds: 4),
                );
              } catch (e) {
                Get.back();
                Get.snackbar(
                  'ত্রুটি'.tr,
                  e.toString(),
                  backgroundColor: Colors.red,
                  colorText: Colors.white,
                );
              }
            },
          ),
        ],
      ),
    );
  }

  void _showReplaceList(BuildContext context) {
    try {
      Get.find<AdminReplaceController>();
    } catch (_) {
      Get.lazyPut<AdminReplaceController>(() => AdminReplaceController());
    }
    Get.to(() => const AdminReplaceView());
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
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy to clipboard'.tr,
                      icon: const Icon(Icons.copy_rounded),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: text));
                        Get.snackbar(
                          'Copied!'.tr,
                          'List copied to clipboard'.tr,
                          snackPosition: SnackPosition.BOTTOM,
                          duration: const Duration(seconds: 2),
                        );
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
                      title: Text(
                        r.label,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: r.sublabel.isNotEmpty
                          ? Text(
                              r.sublabel,
                              style: const TextStyle(fontSize: 11),
                            )
                          : null,
                      trailing: Text(
                        r.value,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 15,
                          color: r.valueColor,
                        ),
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
        decoration: InputDecoration(
          hintText: 'Search product...'.tr,
          prefixIcon: Icon(Icons.search_rounded),
        ),
      ),
    );
  }

  // ✅ FIXED CATEGORY SCROLL (Mobile + Web + Laptop)
  Widget _categoryChips() {
    return Obx(
      () => SizedBox(
        height: 52,
        child: ScrollConfiguration(
          behavior: const ScrollBehavior().copyWith(
            dragDevices: {PointerDeviceKind.touch, PointerDeviceKind.mouse},
          ),
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: controller.categories.length,
            itemBuilder: (context, index) {
              final c = controller.categories[index];
              final selected = controller.selectedCategory.value == c;

              return Padding(
                padding: const EdgeInsets.only(right: 7),
                child: ChoiceChip(
                  // 'All' একটি sentinel মান — শুধু দেখানোর সময় অনূদিত হয়
                  label: Text(c == 'All' ? 'All'.tr : c),
                  selected: selected,
                  showCheckmark: false,
                  onSelected: (_) => controller.selectedCategory.value = c,
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  // 📦 Product List
  Widget _productList() {
    return Obx(() {
      if (controller.loading.value) {
        return const Center(child: CircularProgressIndicator());
      }

      final list = controller.filteredProducts;

      if (list.isEmpty) {
        return Center(child: Text('No products found'.tr));
      }

      return RefreshIndicator(
        onRefresh: () => controller.fetchProducts(forceRefresh: true),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 1200
                ? 4
                : constraints.maxWidth >= 900
                ? 3
                : constraints.maxWidth >= 600
                ? 2
                : 1;

            return CustomScrollView(
              slivers: [
                // ── Regular Products ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 6, 12, 16),
                  sliver: SliverGrid(
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: columns,
                      mainAxisSpacing: 10,
                      crossAxisSpacing: 10,
                      // এক কলামে ঘরের উচ্চতা প্রস্থের অনুপাতে হিসাব করলে সরু
                      // ফোনে কার্ড ছোট পড়ে লেখা উপচে যায়। তাই সেখানে সরাসরি
                      // উচ্চতা দেওয়া হয়, প্রস্থ যাই হোক।
                      mainAxisExtent: columns == 1 ? 200 : null,
                      childAspectRatio: columns == 1 ? 2.2 : 1.25,
                    ),
                    delegate: SliverChildBuilderDelegate((context, index) {
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
                                      onChanged: (v) =>
                                          controller.updateProduct(p.id, {
                                            'isAvailable': v,
                                          }),
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
                                                errorBuilder:
                                                    (
                                                      context,
                                                      error,
                                                      stackTrace,
                                                    ) => Container(
                                                      width: 78,
                                                      height: 78,
                                                      color: Theme.of(context)
                                                          .colorScheme
                                                          .surfaceContainerHighest,
                                                      alignment:
                                                          Alignment.center,
                                                      child: const Icon(
                                                        Icons
                                                            .image_not_supported_rounded,
                                                      ),
                                                    ),
                                              )
                                            : Container(
                                                width: 78,
                                                height: 78,
                                                color: Theme.of(context)
                                                    .colorScheme
                                                    .surfaceContainerHighest,
                                                alignment: Alignment.center,
                                                child: const Icon(
                                                  Icons.image_rounded,
                                                ),
                                              ),
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            _line(
                                              'Category'.tr,
                                              p.productCategory,
                                            ),
                                            _line(
                                              'Stock'.tr,
                                              p.stock.toString(),
                                            ),
                                            _line(
                                              'Buy'.tr,
                                              '৳${p.purchasePrice}',
                                            ),
                                            _line(
                                              'Wholesale'.tr,
                                              '৳${p.wholesalePrice}',
                                            ),
                                            _line(
                                              'Retail'.tr,
                                              '৳${p.retailPrice}',
                                            ),
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
                    }, childCount: list.length),
                  ),
                ),
              ],
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

  // ✏️ EDIT PRODUCT
  void _editProductDialog(ProductModel p) {
    Get.to(() => ProductFormView(product: p));
  }

  void _addProductDialog() {
    Get.to(() => const ProductFormView());
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
