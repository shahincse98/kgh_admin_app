import 'dart:async';
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

  StreamSubscription<QuerySnapshot>? _sub;

  @override
  void onInit() {
    super.onInit();
    _listenProducts();
  }

  void _listenProducts() {
    loading.value = true;
    _sub = _db.collection('products').snapshots().listen((snapshot) {
      final list =
          snapshot.docs.map((e) => ProductModel.fromFirestore(e)).toList();

      products.assignAll(list);

      final set = <String>{};
      for (var p in list) {
        if (p.productCategory.isNotEmpty) set.add(p.productCategory);
      }
      categories.assignAll(['All', ...set]);

      loading.value = false;
    });
  }

  List<ProductModel> get filteredProducts {
    return products.where((p) {
      final matchSearch =
          p.name.toLowerCase().contains(searchText.value.toLowerCase());

      final matchCategory = selectedCategory.value == 'All' ||
          p.productCategory == selectedCategory.value;

      return matchSearch && matchCategory;
    }).toList();
  }

  Future<void> updateProduct(String id, Map<String, dynamic> data) async {
    await _db.collection('products').doc(id).update(data);
  }

  Future<void> deleteProduct(String id) async {
    await _db.collection('products').doc(id).delete();
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    await _db.collection('products').add(data);
  }

  @override
  void onClose() {
    _sub?.cancel();
    super.onClose();
  }
}