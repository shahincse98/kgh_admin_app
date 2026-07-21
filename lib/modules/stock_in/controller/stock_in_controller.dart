import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/stock_in_model.dart';
import '../../auth/controller/auth_controller.dart';
import '../../product/controller/product_controller.dart';

class StockInController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final entries = <StockInModel>[].obs;
  final loading = false.obs;
  final searchText = ''.obs;
  bool _loadedOnce = false;

  @override
  void onInit() {
    super.onInit();
    fetchEntries();
  }

  Future<void> fetchEntries({bool force = false}) async {
    if (_loadedOnce && !force) return;
    loading.value = true;
    try {
      final snap = await _db
          .collection('stock_ins')
          .orderBy('createdAt', descending: true)
          .get();

      entries.assignAll(
          snap.docs.map((e) => StockInModel.fromFirestore(e)).toList());
      _loadedOnce = true;
    } catch (_) {}
    loading.value = false;
  }

  List<StockInModel> get filteredEntries {
    var list = entries.toList();
    final q = searchText.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((e) =>
        e.productName.toLowerCase().contains(q) ||
        e.source.toLowerCase().contains(q) ||
        e.note.toLowerCase().contains(q) ||
        e.id.toLowerCase().contains(q)
      ).toList();
    }
    return list;
  }

  /// Total purchase value of all (filtered) entries
  num get totalPurchaseValue =>
      filteredEntries.fold(0, (s, e) => s + e.totalPrice);

  /// Total quantity of all (filtered) entries
  int get totalQuantity =>
      filteredEntries.fold(0, (s, e) => s + e.quantity);

  /// Total entries count
  int get totalEntries => filteredEntries.length;

  List<StockInGroup> get filteredGroups {
    final list = filteredEntries;
    final map = <String, StockInGroup>{};

    for (final e in list) {
      final key = '${e.date.toIso8601String().substring(0, 10)}|${e.source}';
      map.putIfAbsent(key, () => StockInGroup(
        date: e.date,
        source: e.source,
        note: e.note,
        entries: [],
      ));
      map[key]!.entries.add(e);
    }

    return map.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
  }

  Future<void> addStockIn({
    required String productId,
    required String productName,
    required int quantity,
    num unitPrice = 0,
    String image = '',
    String source = '',
    String note = '',
    required DateTime date,
  }) async {
    final currentUser = await _getCurrentUserId();
    final totalPrice = (unitPrice * quantity);

    final batch = _db.batch();

    // 1. Increment product stock + update purchase price
    if (productId.isNotEmpty) {
      final ref = _db.collection('products').doc(productId);
      final updates = <String, dynamic>{
        'stock': FieldValue.increment(quantity),
      };
      if (unitPrice > 0) {
        updates['purchasePrice'] = unitPrice;
      }
      batch.update(ref, updates);
    }

    // 2. Create stock-in entry
    final docRef = _db.collection('stock_ins').doc();
    batch.set(docRef, {
      'productId': productId,
      'productName': productName,
      'image': image,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': totalPrice,
      'source': source,
      'note': note,
      'date': Timestamp.fromDate(date),
      'createdAt': FieldValue.serverTimestamp(),
      'createdBy': currentUser,
    });

    await batch.commit();

    // Update product stock locally (no need to re-fetch all products)
    try {
      Get.find<ProductController>().updateStockLocally(productId, quantity);
    } catch (_) {}

    // Add to local cache
    entries.insert(0, StockInModel(
      id: docRef.id,
      productId: productId,
      productName: productName,
      image: image,
      quantity: quantity,
      unitPrice: unitPrice,
      totalPrice: totalPrice,
      source: source,
      note: note,
      date: date,
      createdAt: DateTime.now(),
      createdBy: currentUser,
    ));
  }

  Future<void> addMultipleStockIn({
    required DateTime date,
    required String source,
    String note = '',
    required List<Map<String, dynamic>> items,
    bool updatePurchasePrice = true,
  }) async {
    final currentUser = await _getCurrentUserId();
    final batch = _db.batch();

    for (final item in items) {
      final productId = item['productId'] as String? ?? '';
      final productName = item['productName'] as String? ?? '';
      final image = item['image'] as String? ?? '';
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      final unitPrice = (item['unitPrice'] as num?) ?? 0;
      if (productId.isEmpty || quantity <= 0) continue;

      final totalPrice = unitPrice * quantity;

      // Increment stock + update purchase price
      final updates = <String, dynamic>{
        'stock': FieldValue.increment(quantity),
      };
      if (unitPrice > 0 && updatePurchasePrice) {
        updates['purchasePrice'] = unitPrice;
      }
      batch.update(_db.collection('products').doc(productId), updates);

      // Create entry
      final docRef = _db.collection('stock_ins').doc();
      batch.set(docRef, {
        'productId': productId,
        'productName': productName,
        'image': image,
        'quantity': quantity,
        'unitPrice': unitPrice,
        'totalPrice': totalPrice,
        'source': source,
        'note': note,
        'date': Timestamp.fromDate(date),
        'createdAt': FieldValue.serverTimestamp(),
        'createdBy': currentUser,
      });
    }

    await batch.commit();

    // Update product stock locally (no need to re-fetch all products)
    try {
      final pc = Get.find<ProductController>();
      final deltas = <String, int>{};
      for (final item in items) {
        final productId = item['productId'] as String? ?? '';
        final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
        if (productId.isEmpty || quantity <= 0) continue;
        deltas[productId] = (deltas[productId] ?? 0) + quantity;
      }
      pc.updateStockLocallyBatch(deltas);
    } catch (_) {}

    // Mark entries need refresh
    _loadedOnce = false;
  }

  Future<void> deleteEntry(String id) async {
    final entry = entries.firstWhereOrNull((e) => e.id == id);
    if (entry != null && entry.productId.isNotEmpty) {
      final batch = _db.batch();
      // Restore stock
      batch.update(_db.collection('products').doc(entry.productId),
          {'stock': FieldValue.increment(-entry.quantity)});
      batch.delete(_db.collection('stock_ins').doc(id));
      await batch.commit();

      // Update product stock locally
      try {
        Get.find<ProductController>().updateStockLocally(entry.productId, -entry.quantity);
      } catch (_) {}
    } else {
      await _db.collection('stock_ins').doc(id).delete();
    }
    entries.removeWhere((e) => e.id == id);
  }

  Future<void> updateEntry({
    required String id,
    required String productId,
    required String productName,
    required int quantity,
    num unitPrice = 0,
    String source = '',
    String note = '',
    required DateTime date,
  }) async {
    final oldEntry = entries.firstWhereOrNull((e) => e.id == id);
    if (oldEntry == null) return;

    final newTotalPrice = unitPrice * quantity;

    final batch = _db.batch();

    // 1. Reverse old stock
    if (oldEntry.productId.isNotEmpty) {
      batch.update(_db.collection('products').doc(oldEntry.productId),
          {'stock': FieldValue.increment(-oldEntry.quantity)});
    }

    // 2. Apply new stock + update purchase price
    if (productId.isNotEmpty) {
      final updates = <String, dynamic>{
        'stock': FieldValue.increment(quantity),
      };
      if (unitPrice > 0) {
        updates['purchasePrice'] = unitPrice;
      }
      batch.update(_db.collection('products').doc(productId), updates);
    }

    // 3. Update entry
    batch.update(_db.collection('stock_ins').doc(id), {
      'productId': productId,
      'productName': productName,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalPrice': newTotalPrice,
      'source': source,
      'note': note,
      'date': Timestamp.fromDate(date),
    });

    await batch.commit();

    // Update product stock locally
    try {
      final pc = Get.find<ProductController>();
      if (oldEntry.productId.isNotEmpty) {
        pc.updateStockLocally(oldEntry.productId, -oldEntry.quantity);
      }
      if (productId.isNotEmpty) {
        pc.updateStockLocally(productId, quantity);
      }
    } catch (_) {}

    // Update local cache
    final idx = entries.indexWhere((e) => e.id == id);
    if (idx != -1) {
      entries[idx] = StockInModel(
        id: id,
        productId: productId,
        productName: productName,
        image: oldEntry.image,
        quantity: quantity,
        unitPrice: unitPrice,
        totalPrice: newTotalPrice,
        source: source,
        note: note,
        date: date,
        createdAt: oldEntry.createdAt,
        createdBy: oldEntry.createdBy,
      );
    }
  }

  Future<String> _getCurrentUserId() async {
    try {
      final auth = Get.find<AuthController>();
      return auth.currentUser?.uid ?? '';
    } catch (_) {}
    return '';
  }
}

class StockInGroup {
  final DateTime date;
  final String source;
  final String note;
  final List<StockInModel> entries;

  StockInGroup({
    required this.date,
    required this.source,
    required this.note,
    required this.entries,
  });

  int get totalQty => entries.fold(0, (s, e) => s + e.quantity);
  num get totalValue => entries.fold(0, (s, e) => s + e.totalPrice);
}
