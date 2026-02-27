import 'dart:ui' show PointerDeviceKind;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
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
          _searchBar(),
          _categoryChips(),
          Expanded(child: _productList()),
        ],
      ),
    );
  }

  // 🔍 Search
  Widget _searchBar() {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: TextField(
        onChanged: (v) => controller.searchText.value = v,
        decoration: InputDecoration(
          hintText: 'Search product...',
          prefixIcon: const Icon(Icons.search),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  // ✅ FIXED CATEGORY SCROLL (Mobile + Web + Laptop)
  Widget _categoryChips() {
    return Obx(() => SizedBox(
          height: 55,
          child: ScrollConfiguration(
            behavior: const ScrollBehavior().copyWith(
              dragDevices: {
                PointerDeviceKind.touch,
                PointerDeviceKind.mouse,
              },
            ),
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              itemCount: controller.categories.length,
              itemBuilder: (context, index) {
                final c = controller.categories[index];
                final selected =
                    controller.selectedCategory.value == c;

                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(c),
                    selected: selected,
                    selectedColor: Colors.blue,
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
        child: ListView.builder(
          itemCount: list.length,
          itemBuilder: (context, index) {
            final p = list[index];

            return Card(
              margin: const EdgeInsets.all(8),
              child: ListTile(
                leading: p.images.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          p.images.first,
                          width: 55,
                          height: 55,
                          fit: BoxFit.cover,
                        ),
                      )
                    : const Icon(Icons.image, size: 40),
                title: Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Stock: ${p.stock}'),
                    Text('Buy: ${p.purchasePrice}'),
                    Text('Wholesale: ${p.wholesalePrice}'),
                    Text('Retail: ${p.retailPrice}'),
                  ],
                ),
                trailing: Switch(
                  value: p.isAvailable,
                  onChanged: (v) => controller.updateProduct(
                      p.id, {'isAvailable': v}),
                ),
                onTap: () => _editProductDialog(p),
              ),
            );
          },
        ),
      );
    });
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

  void _addProductDialog() {}

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