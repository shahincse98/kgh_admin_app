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

    final snapshot = await _db.collection('products').get();

    final list =
        snapshot.docs.map((e) => ProductModel.fromFirestore(e)).toList()
          ..sort((a, b) {
            final at = a.createdAt;
            final bt = b.createdAt;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return bt.compareTo(at);
          });

    products.assignAll(list);

    // Generate Categories (internal products excluded)
    final set = <String>{};
    for (var p in list) {
      if (!p.isInternal && p.productCategory.isNotEmpty) {
        set.add(p.productCategory);
      }
    }

    categories.assignAll(['All', '⚠ No Cost', ...set]);

    _loadedOnce = true;
    loading.value = false;
  }

  // 🔍 LOCAL FILTER (NO FIRESTORE HIT) — internal products excluded
  List<ProductModel> get filteredProducts {
    return products.where((p) {
      if (p.isInternal) return false;

      final matchSearch =
          p.name.toLowerCase().contains(searchText.value.toLowerCase());

      final matchCategory = selectedCategory.value == 'All' ||
          (selectedCategory.value == '⚠ No Cost'
              ? p.purchasePrice <= 0
              : p.productCategory == selectedCategory.value);

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

  /// Update stock locally for a single product (Firestore already updated via batch).
  /// Use this instead of fetchProducts(forceRefresh: true) after batch stock operations.
  void updateStockLocally(String productId, int delta) {
    final index = products.indexWhere((p) => p.id == productId);
    if (index != -1) {
      final p = products[index];
      products[index] = p.copyWithMap({'stock': p.stock + delta});
      products.refresh();
    }
  }

  /// Update stock locally for multiple products at once.
  void updateStockLocallyBatch(Map<String, int> deltas) {
    bool changed = false;
    for (final entry in deltas.entries) {
      final index = products.indexWhere((p) => p.id == entry.key);
      if (index != -1) {
        final p = products[index];
        products[index] = p.copyWithMap({'stock': p.stock + entry.value});
        changed = true;
      }
    }
    if (changed) products.refresh();
  }

  Future<void> deleteProduct(String id) async {
    await _db.collection('products').doc(id).delete();
    products.removeWhere((p) => p.id == id);
  }

  Future<void> addProduct(Map<String, dynamic> data) async {
    data['createdAt'] ??= FieldValue.serverTimestamp();
    final doc = await _db.collection('products').add(data);

    final newDoc =
        await _db.collection('products').doc(doc.id).get();

    products.insert(0, ProductModel.fromFirestore(newDoc));
  }

  // ── STOCK MANAGEMENT ──────────────────────────────────────────────────────

  /// Reset all product stocks to zero in a batch
  Future<void> resetAllStockToZero() async {
    final batch = _db.batch();
    for (final p in products) {
      batch.update(_db.collection('products').doc(p.id), {'stock': 0});
    }
    await batch.commit();

    for (var i = 0; i < products.length; i++) {
      products[i] = products[i].copyWithMap({'stock': 0});
    }
    products.refresh();
  }

  /// Add qty to a product's stock (stock-in / purchase)
  Future<void> addStock(String id, int qty) async {
    final index = products.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final newStock = products[index].stock + qty;
    await updateProduct(id, {'stock': newStock});
  }

  /// Deduct qty from a product's stock (sold / adjustment)
  Future<void> deductStock(String id, int qty) async {
    final index = products.indexWhere((p) => p.id == id);
    if (index == -1) return;
    final newStock = products[index].stock - qty;
    await updateProduct(id, {'stock': newStock});
  }

  /// Bulk update stocks: map of {productId: newStock}
  Future<void> bulkSetStocks(Map<String, int> stockMap) async {
    final batch = _db.batch();
    for (final entry in stockMap.entries) {
      batch.update(
          _db.collection('products').doc(entry.key), {'stock': entry.value});
    }
    await batch.commit();

    for (var i = 0; i < products.length; i++) {
      if (stockMap.containsKey(products[i].id)) {
        products[i] = products[i].copyWithMap({'stock': stockMap[products[i].id]!});
      }
    }
    products.refresh();
  }

  // ── NORMALISE ALL PRODUCT DOCUMENTS ───────────────────────────────────────

  /// Makes every product document in Firestore have the same set of fields.
  /// Documents that already have all fields are not touched.
  /// Returns the number of documents that were updated.
  Future<int> normalizeAllProducts() async {
    final snap = await _db.collection('products').get();

    // Canonical default values for every field (except createdAt, handled separately)
    final defaults = <String, dynamic>{
      'name': '',
      'brandName': '',
      'productCategory': '',
      'productCode': '',
      'productModel': '',
      'productVideo': '',
      'unit': '',
      'warranty': '',
      'purchasePrice': 0,
      'wholesalePrice': 0,
      'retailPrice': 0,
      'stock': 0,
      'pendingStock': 0,
      'totalSold': 0,
      'totalOrders': 0,
      'monthlySold': 0,
      'replaceCount': 0,
      'replaceStock': 0,
      'isAvailable': false,
      'isHot': false,
      'isNew': false,
      'isInternal': false,
      'images': <dynamic>[],
      'productDetails': <dynamic>[],
      'quantityDiscount': <String, dynamic>{},
    };

    // Collect docs that need patching
    final toUpdate = <DocumentReference, Map<String, dynamic>>{};

    for (final doc in snap.docs) {
      final data = doc.data();
      final patch = <String, dynamic>{};

      for (final entry in defaults.entries) {
        if (!data.containsKey(entry.key)) {
          patch[entry.key] = entry.value;
        }
      }

      // Add createdAt if missing (use serverTimestamp as best-effort)
      if (!data.containsKey('createdAt')) {
        patch['createdAt'] = FieldValue.serverTimestamp();
      }

      if (patch.isNotEmpty) {
        toUpdate[doc.reference] = patch;
      }
    }

    if (toUpdate.isEmpty) return 0;

    // Firestore batch limit is 500 — split into chunks of 400
    const chunkSize = 400;
    final entries = toUpdate.entries.toList();
    for (var i = 0; i < entries.length; i += chunkSize) {
      final chunk = entries.sublist(i,
          i + chunkSize > entries.length ? entries.length : i + chunkSize);
      final batch = _db.batch();
      for (final e in chunk) {
        batch.update(e.key, e.value);
      }
      await batch.commit();
    }

    // Refresh local cache so UI reflects new fields
    await fetchProducts(forceRefresh: true);

    return toUpdate.length;
  }
}