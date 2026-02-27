import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/product_model.dart';

class ProductController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final products = <ProductModel>[].obs;
  final loading = true.obs;

  final searchText = ''.obs;
  final selectedCategory = 'All'.obs;
  final categories = <String>['All'].obs;

  bool _loadedOnce = false;

  @override
  void onInit() {
    super.onInit();
    fetchProducts();
  }

  // 🔥 LOAD ALL PRODUCTS ONLY ONCE
  Future<void> fetchProducts({bool forceRefresh = false}) async {
    if (_loadedOnce && !forceRefresh) return;

    loading.value = true;

    final snapshot = await _db
        .collection('products')
        .orderBy('createdAt', descending: true)
        .get();

    final list =
        snapshot.docs.map((e) => ProductModel.fromFirestore(e)).toList();

    products.assignAll(list);

    // Generate Categories
    final set = <String>{};
    for (var p in list) {
      if (p.productCategory.isNotEmpty) {
        set.add(p.productCategory);
      }
    }

    categories.assignAll(['All', ...set]);

    _loadedOnce = true;
    loading.value = false;
  }

  // 🔍 LOCAL FILTER (NO FIRESTORE HIT)
  List<ProductModel> get filteredProducts {
    return products.where((p) {
      final matchSearch =
          p.name.toLowerCase().contains(searchText.value.toLowerCase());

      final matchCategory = selectedCategory.value == 'All' ||
          p.productCategory == selectedCategory.value;

      return matchSearch && matchCategory;
    }).toList();
  }

  // 🔄 Local update (No re-read)
  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    await _db.collection('products').doc(id).update(data);

    final index = products.indexWhere((p) => p.id == id);
    if (index != -1) {
      products[index] = products[index].copyWithMap(data);
      products.refresh();
    }
  }

  Future<void> deleteProduct(String id) async {
    await _db.collection('products').doc(id).delete();
    products.removeWhere((p) => p.id == id);
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    final doc = await _db.collection('products').add(data);

    final newDoc =
        await _db.collection('products').doc(doc.id).get();

    products.insert(0, ProductModel.fromFirestore(newDoc));
  }
}