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

  // 🏷️ Category Chips
  Widget _categoryChips() {
    return Obx(() => SizedBox(
          height: 48,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            children: controller.categories.map((c) {
              final selected = controller.selectedCategory.value == c;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(c),
                  selected: selected,
                  onSelected: (_) =>
                      controller.selectedCategory.value = c,
                ),
              );
            }).toList(),
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

      return ListView.builder(
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
                        width: 50,
                        height: 50,
                        fit: BoxFit.cover,
                      ),
                    )
                  : const Icon(Icons.image),
              title: Text(p.name),
              subtitle: Text(
                'Stock: ${p.stock} | Buy: ${p.purchasePrice} | Sell: ${p.wholesalePrice}',
              ),
              trailing: Switch(
                value: p.isAvailable,
                onChanged: (v) =>
                    controller.updateProduct(p.id, {'isAvailable': v}),
              ),
              onTap: () => _editProductDialog(p),
            ),
          );
        },
      );
    });
  }

  // ✏️ EDIT PRODUCT POPUP
  void _editProductDialog(ProductModel p) {
    final name = TextEditingController(text: p.name);
    final cat = TextEditingController(text: p.productCategory);
    final stock = TextEditingController(text: p.stock.toString());
    final buy = TextEditingController(text: p.purchasePrice.toString());
    final sell = TextEditingController(text: p.wholesalePrice.toString());

    Get.defaultDialog(
      title: 'Edit Product',
      content: SizedBox(
        width: 400,
        child: SingleChildScrollView(
          child: Column(
            children: [
              _tf(name, 'Name'),
              _tf(cat, 'Category'),
              _tf(stock, 'Stock', number: true),
              _tf(buy, 'Purchase Price', number: true),
              _tf(sell, 'Wholesale Price', number: true),
              const SizedBox(height: 12),
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
              int.tryParse(sell.text) ?? p.wholesalePrice,
        });
        Get.back();
      },
    );
  }

  // ➕ ADD PRODUCT
  void _addProductDialog() {
    final name = TextEditingController();
    final cat = TextEditingController();
    final stock = TextEditingController();
    final buy = TextEditingController();
    final sell = TextEditingController();

    Get.defaultDialog(
      title: 'Add Product',
      content: SizedBox(
        width: 400,
        child: Column(
          children: [
            _tf(name, 'Name'),
            _tf(cat, 'Category'),
            _tf(stock, 'Stock', number: true),
            _tf(buy, 'Purchase Price', number: true),
            _tf(sell, 'Wholesale Price', number: true),
          ],
        ),
      ),
      textConfirm: 'Add',
      onConfirm: () async {
        await controller.addProduct({
          'name': name.text,
          'productCategory': cat.text,
          'stock': int.tryParse(stock.text) ?? 0,
          'purchasePrice': int.tryParse(buy.text) ?? 0,
          'wholesalePrice': int.tryParse(sell.text) ?? 0,
          'isAvailable': true,
          'createdAt': FieldValue.serverTimestamp(),
        });
        Get.back();
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