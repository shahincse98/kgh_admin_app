import 'dart:math';

import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/stock_in_model.dart';
import '../../auth/controller/auth_controller.dart';
import '../../product/controller/product_controller.dart';

class StockInController extends GetxController {
  StockInController({FirebaseFirestore? db})
      : _db = db ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  final entries = <StockInModel>[].obs;
  final loading = false.obs;
  final searchText = ''.obs;
  final selectedProductId = ''.obs;
  final selectedProductName = ''.obs;
  final fromDate = Rxn<DateTime>();
  final toDate = Rxn<DateTime>();
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
        snap.docs.map((e) => StockInModel.fromFirestore(e)).toList(),
      );
      _loadedOnce = true;
    } catch (_) {}
    loading.value = false;
  }

  List<StockInModel> get filteredEntries {
    var list = entries.toList();

    if (selectedProductId.value.isNotEmpty) {
      list = list.where((e) => e.productId == selectedProductId.value).toList();
    }

    if (fromDate.value != null) {
      list = list.where((e) => !e.date.isBefore(fromDate.value!)).toList();
    }
    if (toDate.value != null) {
      final toEnd = DateTime(
        toDate.value!.year,
        toDate.value!.month,
        toDate.value!.day,
        23,
        59,
        59,
      );
      list = list.where((e) => !e.date.isAfter(toEnd)).toList();
    }

    final q = searchText.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where(
            (e) =>
                e.productName.toLowerCase().contains(q) ||
                e.source.toLowerCase().contains(q) ||
                e.note.toLowerCase().contains(q) ||
                e.id.toLowerCase().contains(q),
          )
          .toList();
    }
    return list;
  }

  /// The filtered entries that count in the main stock. Inactive lists
  /// still show, but stay out of the totals.
  List<StockInModel> get activeFilteredEntries =>
      filteredEntries.where((e) => e.active).toList();

  /// Whether the filter holds any inactive entry left out of the totals.
  bool get hasInactiveFiltered => filteredEntries.any((e) => !e.active);

  /// Total purchase value of the active (filtered) entries
  num get totalPurchaseValue =>
      activeFilteredEntries.fold(0, (s, e) => s + e.totalPrice);

  /// Total quantity of the active (filtered) entries
  int get totalQuantity =>
      activeFilteredEntries.fold(0, (s, e) => s + e.quantity);

  /// Active entries count
  int get totalEntries => activeFilteredEntries.length;

  /// One list = one date and one source.
  static String groupKey(DateTime date, String source) =>
      '${date.toIso8601String().substring(0, 10)}|$source';

  List<StockInGroup> get filteredGroups {
    final list = filteredEntries;
    final map = <String, StockInGroup>{};

    for (final e in list) {
      final key = groupKey(e.date, e.source);
      map.putIfAbsent(
        key,
        () => StockInGroup(
          date: e.date,
          source: e.source,
          note: e.note,
          entries: [],
        ),
      );
      map[key]!.entries.add(e);
    }

    return map.values.toList()..sort((a, b) => b.date.compareTo(a.date));
  }

  /// Every entry of one date and source, whatever the list's search or
  /// product filter shows, so a date's page always holds its whole list.
  List<StockInModel> groupEntries(DateTime date, String source) {
    final key = groupKey(date, source);
    return entries.where((e) => groupKey(e.date, e.source) == key).toList();
  }

  /// Every entry of the lists with these [keys] (see [groupKey]).
  List<StockInModel> entriesOfGroups(Set<String> keys) =>
      entries.where((e) => keys.contains(groupKey(e.date, e.source))).toList();

  Future<void> addStockIn({
    required String productId,
    required String productName,
    required int quantity,
    num unitPrice = 0,
    String image = '',
    String source = '',
    String note = '',
    required DateTime date,
    bool active = true,
  }) async {
    final currentUser = await _getCurrentUserId();
    final totalPrice = (unitPrice * quantity);

    final batch = _db.batch();

    // 1. Increment product stock + update purchase price (an inactive list
    // leaves the product alone)
    if (productId.isNotEmpty && active) {
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
      'active': active,
    });

    await batch.commit();

    // Update product stock locally (no need to re-fetch all products)
    if (active) {
      try {
        Get.find<ProductController>().updateStockLocally(productId, quantity);
      } catch (_) {}
    }

    // Add to local cache
    entries.insert(
      0,
      StockInModel(
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
        active: active,
      ),
    );
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
        'active': true,
      });
    }

    await batch.commit();

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

    final newEntries = <StockInModel>[];
    for (final item in items) {
      final productId = item['productId'] as String? ?? '';
      final productName = item['productName'] as String? ?? '';
      final image = item['image'] as String? ?? '';
      final quantity = (item['quantity'] as num?)?.toInt() ?? 0;
      final unitPrice = (item['unitPrice'] as num?) ?? 0;
      if (productId.isEmpty || quantity <= 0) continue;
      newEntries.add(
        StockInModel(
          id: '',
          productId: productId,
          productName: productName,
          image: image,
          quantity: quantity,
          unitPrice: unitPrice,
          totalPrice: unitPrice * quantity,
          source: source,
          note: note,
          date: date,
          createdAt: DateTime.now(),
          createdBy: currentUser,
        ),
      );
    }
    entries.insertAll(0, newEntries);
  }

  Future<void> deleteEntry(String id) async {
    final entry = entries.firstWhereOrNull((e) => e.id == id);
    // An inactive entry never added to the stock, so nothing comes back out.
    if (entry != null && entry.productId.isNotEmpty && entry.active) {
      final batch = _db.batch();
      // Restore stock
      batch.update(_db.collection('products').doc(entry.productId), {
        'stock': FieldValue.increment(-entry.quantity),
      });
      batch.delete(_db.collection('stock_ins').doc(id));
      await batch.commit();

      // Update product stock locally
      try {
        Get.find<ProductController>().updateStockLocally(
          entry.productId,
          -entry.quantity,
        );
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
    // An inactive entry is not in the stock: editing it touches no product.
    final active = oldEntry.active;

    final batch = _db.batch();

    // 1. Reverse old stock
    if (oldEntry.productId.isNotEmpty && active) {
      batch.update(_db.collection('products').doc(oldEntry.productId), {
        'stock': FieldValue.increment(-oldEntry.quantity),
      });
    }

    // 2. Apply new stock + update purchase price
    if (productId.isNotEmpty && active) {
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
    if (active) {
      try {
        final pc = Get.find<ProductController>();
        if (oldEntry.productId.isNotEmpty) {
          pc.updateStockLocally(oldEntry.productId, -oldEntry.quantity);
        }
        if (productId.isNotEmpty) {
          pc.updateStockLocally(productId, quantity);
        }
      } catch (_) {}
    }

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
        active: active,
      );
    }
  }

  void clearFilters() {
    searchText.value = '';
    selectedProductId.value = '';
    selectedProductName.value = '';
    fromDate.value = null;
    toDate.value = null;
  }

  Future<void> updateGroupDate({
    required DateTime oldDate,
    required String source,
    required DateTime newDate,
  }) async {
    final groupEntries = entries
        .where((e) => e.date == oldDate && e.source == source)
        .toList();
    if (groupEntries.isEmpty) return;

    final batch = _db.batch();
    for (final e in groupEntries) {
      batch.update(_db.collection('stock_ins').doc(e.id), {
        'date': Timestamp.fromDate(newDate),
      });
    }
    await batch.commit();

    for (final e in groupEntries) {
      final idx = entries.indexWhere((x) => x.id == e.id);
      if (idx != -1) entries[idx] = e.copyWith(date: newDate);
    }
  }

  /// Entries a single Firestore transaction handles at once: each one is a
  /// write, and so is each product it touches, well under the 500 limit.
  static const _chunk = 200;

  /// Turns a whole date's list on or off. An active list is in the products'
  /// main stock: turning it off takes its pieces back out of stock, turning
  /// it back on puts them in again. Each entry's flag is read inside the
  /// transaction, so a list someone else just switched is not counted twice.
  Future<void> setGroupActive(
    DateTime date,
    String source,
    bool active,
  ) async {
    final targets =
        groupEntries(date, source).where((e) => e.active != active).toList();

    for (var i = 0; i < targets.length; i += _chunk) {
      final chunk = targets.sublist(i, min(i + _chunk, targets.length));
      final flipped = <String>[];
      final deltas = await _db.runTransaction<Map<String, int>>((tx) async {
        flipped.clear();
        final snaps = await Future.wait(
          chunk.map((e) => tx.get(_db.collection('stock_ins').doc(e.id))),
        );
        final deltas = <String, int>{};
        final toFlip = <DocumentReference<Map<String, dynamic>>>[];
        for (final s in snaps) {
          final d = s.data();
          if (d == null || (d['active'] != false) == active) continue;
          toFlip.add(s.reference);
          final productId = (d['productId'] ?? '').toString();
          final qty = (d['quantity'] as num?)?.toInt() ?? 0;
          if (productId.isNotEmpty && qty != 0) {
            deltas[productId] = (deltas[productId] ?? 0) + (active ? qty : -qty);
          }
        }
        final existing = await _existingProducts(tx, deltas.keys);
        deltas.removeWhere((id, _) => !existing.contains(id));

        for (final ref in toFlip) {
          tx.update(ref, {'active': active});
          flipped.add(ref.id);
        }
        deltas.forEach((id, delta) {
          tx.update(_db.collection('products').doc(id), {
            'stock': FieldValue.increment(delta),
          });
        });
        return deltas;
      });

      for (final id in flipped) {
        final idx = entries.indexWhere((e) => e.id == id);
        if (idx != -1) entries[idx] = entries[idx].copyWith(active: active);
      }
      try {
        Get.find<ProductController>().updateStockLocallyBatch(deltas);
      } catch (_) {}
    }
  }

  /// Deletes a whole date's list. With [adjustStock] the active entries'
  /// pieces leave the main stock, as deleting them one by one would; without
  /// it only the records go and every product's stock stays as it is.
  Future<void> deleteGroup(
    DateTime date,
    String source, {
    required bool adjustStock,
  }) =>
      deleteEntries(groupEntries(date, source), adjustStock: adjustStock);

  /// Deletes [targets], e.g. the entries of several marked lists at once;
  /// [adjustStock] works as in [deleteGroup].
  Future<void> deleteEntries(
    List<StockInModel> targets, {
    required bool adjustStock,
  }) async {
    for (var i = 0; i < targets.length; i += _chunk) {
      final chunk = targets.sublist(i, min(i + _chunk, targets.length));
      final deltas = await _db.runTransaction<Map<String, int>>((tx) async {
        final snaps = await Future.wait(
          chunk.map((e) => tx.get(_db.collection('stock_ins').doc(e.id))),
        );
        final deltas = <String, int>{};
        if (adjustStock) {
          for (final s in snaps) {
            final d = s.data();
            if (d == null || d['active'] == false) continue;
            final productId = (d['productId'] ?? '').toString();
            final qty = (d['quantity'] as num?)?.toInt() ?? 0;
            if (productId.isNotEmpty && qty != 0) {
              deltas[productId] = (deltas[productId] ?? 0) - qty;
            }
          }
          final existing = await _existingProducts(tx, deltas.keys);
          deltas.removeWhere((id, _) => !existing.contains(id));
        }

        for (final s in snaps) {
          if (s.exists) tx.delete(s.reference);
        }
        deltas.forEach((id, delta) {
          tx.update(_db.collection('products').doc(id), {
            'stock': FieldValue.increment(delta),
          });
        });
        return deltas;
      });

      // Entries already gone from Firestore leave the local list too.
      final chunkIds = chunk.map((e) => e.id).toSet();
      entries.removeWhere((e) => chunkIds.contains(e.id));
      if (deltas.isNotEmpty) {
        try {
          Get.find<ProductController>().updateStockLocallyBatch(deltas);
        } catch (_) {}
      }
    }
  }

  /// Which of [ids] still have a product document: updating a deleted
  /// product would fail the whole transaction.
  Future<Set<String>> _existingProducts(
    Transaction tx,
    Iterable<String> ids,
  ) async {
    final list = ids.toList();
    final snaps = await Future.wait(
      list.map((id) => tx.get(_db.collection('products').doc(id))),
    );
    return {
      for (var i = 0; i < list.length; i++)
        if (snaps[i].exists) list[i],
    };
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

  /// A list counts in the main stock while any of its entries does.
  bool get active => entries.any((e) => e.active);

  String get key => StockInController.groupKey(date, source);
}
