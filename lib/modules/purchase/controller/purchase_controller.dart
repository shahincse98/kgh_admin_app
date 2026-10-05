import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../model/purchase_entry_model.dart';
import '../model/shortage_item_model.dart';
import '../../product/model/product_model.dart';
import '../../product/controller/product_controller.dart';

class PurchaseController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final loading = false.obs;
  final selectedMonth = DateTime.now().obs;

  final entries = <PurchaseEntryModel>[].obs;
  final allProducts = <ProductModel>[].obs;

  /// Map of dateKey (yyyy-MM-dd) -> total purchase amount
  final dailyPurchase = <String, double>{}.obs;

  // ── Shortage list (from approved orders vs stock) ──────────────
  final shortageList = <ShortageItem>[].obs;
  final shortageLoading = false.obs;
  final approvedOrderCount = 0.obs;
  final shortageError = ''.obs;
  bool _shortageLoaded = false;

  @override
  void onInit() {
    super.onInit();
    _loadProductsFromCache();
    loadEntries();
    computeShortage();
  }

  /// Reuse already-loaded products from ProductController to avoid
  /// a redundant full-collection fetch on every purchase page visit.
  void _loadProductsFromCache() {
    try {
      final pc = Get.find<ProductController>();
      if (pc.products.isNotEmpty) {
        final sorted = List<ProductModel>.from(pc.products)
          ..sort((a, b) => a.name.compareTo(b.name));
        allProducts.assignAll(sorted);
        return;
      }
    } catch (_) {}
    // Fallback: fetch independently if ProductController isn't loaded
    _fetchProductsFromFirestore();
  }

  Future<void> _fetchProductsFromFirestore() async {
    try {
      final snap = await _db.collection('products').orderBy('name').get();
      allProducts.assignAll(
          snap.docs.map((d) => ProductModel.fromFirestore(d)).toList());
    } catch (_) {}
  }

  void prevMonth() {
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month - 1);
    loadEntries();
  }

  void nextMonth() {
    final m = selectedMonth.value;
    final next = DateTime(m.year, m.month + 1);
    final now = DateTime.now();
    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) {
      return;
    }
    selectedMonth.value = next;
    loadEntries();
  }

  Future<void> loadEntries() async {
    loading.value = true;
    try {
      final m = selectedMonth.value;
      final start = DateTime(m.year, m.month);
      final end = DateTime(m.year, m.month + 1);

      final snap = await _db
          .collection('stock_purchases')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .orderBy('date', descending: true)
          .get();

      final list =
          snap.docs.map(PurchaseEntryModel.fromFirestore).toList();
      entries.assignAll(list);
      _buildDailyMap(list);
    } finally {
      loading.value = false;
    }
  }

  void _buildDailyMap(List<PurchaseEntryModel> list) {
    final map = <String, double>{};
    for (final e in list) {
      final key =
          '${e.date.year}-${e.date.month.toString().padLeft(2, '0')}-${e.date.day.toString().padLeft(2, '0')}';
      map[key] = (map[key] ?? 0) + e.totalAmount;
    }
    dailyPurchase.assignAll(map);
  }

  double get monthTotal =>
      entries.fold(0.0, (s, e) => s + e.totalAmount);

  Future<void> addEntry({
    required String productName,
    required String productId,
    required int quantity,
    required double unitPrice,
    required String supplierId,
    required String supplier,
    required String note,
    required DateTime date,
  }) async {
    final total = quantity * unitPrice;
    final entryDate = DateTime(date.year, date.month, date.day);

    final batch = _db.batch();
    final ref = _db.collection('stock_purchases').doc();
    batch.set(ref, {
      'productName': productName,
      'productId': productId,
      'quantity': quantity,
      'unitPrice': unitPrice,
      'totalAmount': total,
      'supplierId': supplierId,
      'supplier': supplier,
      'note': note,
      'date': Timestamp.fromDate(entryDate),
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (productId.isNotEmpty) {
      batch.update(_db.collection('products').doc(productId),
          {'stock': FieldValue.increment(quantity)});
    }

    await batch.commit();

    // Insert locally — avoid full re-fetch
    final newEntry = PurchaseEntryModel(
      id: ref.id,
      productName: productName,
      productId: productId,
      quantity: quantity,
      unitPrice: unitPrice,
      totalAmount: total,
      supplierId: supplierId,
      supplier: supplier,
      note: note,
      date: entryDate,
      createdAt: DateTime.now(),
    );
    entries.insert(0, newEntry);
    _buildDailyMap(entries);
  }

  Future<void> addMultipleEntries({
    required List<Map<String, dynamic>> items,
    required String supplierId,
    required String supplier,
    required DateTime date,
  }) async {
    final batch = _db.batch();
    final entryDate = DateTime(date.year, date.month, date.day);
    final dateTs = Timestamp.fromDate(entryDate);
    final newEntries = <PurchaseEntryModel>[];

    for (final item in items) {
      final ref = _db.collection('stock_purchases').doc();
      final qty = item['quantity'] as int;
      final price = item['unitPrice'] as double;
      final total = qty * price;
      batch.set(ref, {
        'productName': item['productName'],
        'productId': item['productId'],
        'quantity': qty,
        'unitPrice': price,
        'totalAmount': total,
        'supplierId': supplierId,
        'supplier': supplier,
        'note': item['note'] ?? '',
        'date': dateTs,
        'createdAt': FieldValue.serverTimestamp(),
      });
      final productId = item['productId'] as String;
      if (productId.isNotEmpty) {
        batch.update(
          _db.collection('products').doc(productId),
          {'stock': FieldValue.increment(qty)},
        );
      }
      newEntries.add(PurchaseEntryModel(
        id: ref.id,
        productName: item['productName'] as String,
        productId: productId,
        quantity: qty,
        unitPrice: price,
        totalAmount: total,
        supplierId: supplierId,
        supplier: supplier,
        note: item['note'] ?? '',
        date: entryDate,
        createdAt: DateTime.now(),
      ));
    }

    await batch.commit();

    // Insert locally — avoid full re-fetch
    entries.insertAll(0, newEntries);
    _buildDailyMap(entries);
  }

  Future<void> deleteEntry(PurchaseEntryModel e) async {
    final batch = _db.batch();
    batch.delete(_db.collection('stock_purchases').doc(e.id));
    if (e.productId.isNotEmpty) {
      batch.update(_db.collection('products').doc(e.productId),
          {'stock': FieldValue.increment(-e.quantity)});
    }
    await batch.commit();
    entries.removeWhere((x) => x.id == e.id);
    _buildDailyMap(entries);
  }

  // ── SHORTAGE COMPUTATION ────────────────────────────────────────
  //
  // Aggregates all product quantities from approved orders, compares
  // with current stock, and produces a list of products that need to
  // be procured.  shortQty = orderedQty - stock  (only if > 0).

  /// Also count orders that are still pending (not approved yet).
  final includePending = false.obs;

  void setIncludePending(bool v) {
    includePending.value = v;
    computeShortage(force: true);
  }

  /// Which products must be bought: everything the approved (and optionally
  /// pending) orders need, minus what is in stock.
  Future<void> computeShortage({bool force = false}) async {
    if (shortageLoading.value) return;
    if (_shortageLoaded && !force) return;
    shortageLoading.value = true;
    shortageError.value = '';
    try {
      // 1. Ensure products are loaded
      try {
        final pc = Get.find<ProductController>();
        if (pc.products.isEmpty) await pc.fetchProducts();
      } catch (_) {}

      // 2. Fetch the orders that still have to be handed over
      final statuses = includePending.value ? ['approved', 'pending'] : ['approved'];
      final snap = await _db
          .collection('orders')
          .where('status', whereIn: statuses)
          .get();

      approvedOrderCount.value = snap.docs.length;

      // 3. Aggregate ordered quantities per productId
      final orderedMap = <String, int>{};
      final linesMap = <String, List<ShortageOrderLine>>{};
      final nameMap = <String, String>{}; // fallback name for deleted products
      for (final doc in snap.docs) {
        final data = doc.data();
        final items = data['items'] as List? ?? [];
        final shopName = (data['shopName'] ?? '').toString();
        final status = (data['status'] ?? '').toString();
        for (final item in items) {
          final productId = (item['productId'] ?? '').toString();
          final qty = (item['quantity'] as num?)?.toInt() ?? 0;
          if (productId.isEmpty || qty == 0) continue;
          orderedMap[productId] = (orderedMap[productId] ?? 0) + qty;
          nameMap[productId] = (item['productName'] ?? '').toString();
          linesMap.putIfAbsent(productId, () => []).add(ShortageOrderLine(
                orderId: doc.id,
                shopName: shopName,
                quantity: qty,
                status: status,
              ));
        }
      }

      // 4. Build shortage list by comparing with stock
      List<ProductModel> products;
      try {
        products = Get.find<ProductController>().products.toList();
      } catch (_) {
        products = allProducts.toList();
      }
      final byId = {for (final p in products) p.id: p};

      final result = <ShortageItem>[];
      orderedMap.forEach((productId, ordered) {
        final p = byId[productId];
        // A product that is no longer in the list has no stock to count.
        final stock = p?.stock ?? 0;
        final short = ordered - stock;
        if (short <= 0) return;
        final lines = linesMap[productId] ?? const <ShortageOrderLine>[];
        result.add(ShortageItem(
          productId: productId,
          productName: p?.name ?? (nameMap[productId] ?? 'অজানা প্রডাক্ট'.tr),
          brandName: p?.brandName ?? '',
          productCode: p?.productCode ?? '',
          unit: p?.unit ?? '',
          orderedQty: ordered,
          stockQty: stock,
          shortQty: short,
          orderCount: lines.map((l) => l.orderId).toSet().length,
          purchasePrice: p?.purchasePrice ?? 0,
          lines: lines,
          missingProduct: p == null,
        ));
      });

      // Sort: largest shortage first
      result.sort((a, b) => b.shortQty.compareTo(a.shortQty));
      shortageList.assignAll(result);
      _shortageLoaded = true;
    } catch (e) {
      shortageError.value = e.toString();
    } finally {
      shortageLoading.value = false;
    }
  }

  /// Money needed to buy the whole shortage list (products without a
  /// purchase price count as 0).
  num get shortageTotalCost =>
      shortageList.fold<num>(0, (s, e) => s + e.estimatedCost);

  /// Products in the list whose purchase price is not known.
  int get shortageWithoutPrice =>
      shortageList.where((e) => e.purchasePrice <= 0).length;

  String get shortageAsText {
    if (shortageList.isEmpty) return 'কোনো শর্ট প্রডাক্ট নেই'.tr;
    final now = DateTime.now();
    final dateStr =
        '${now.day}/${now.month}/${now.year}';
    final buf = StringBuffer();
    buf.writeln('${'সংগ্রহ তালিকা'.tr} — $dateStr');
    buf.writeln(includePending.value
        ? '${'Approved + পেন্ডিং অর্ডার'.tr}: $approvedOrderCount ${'টি'.tr}'
        : 'Approved ${'অর্ডার'.tr}: $approvedOrderCount ${'টি'.tr}');
    buf.writeln('${'শর্ট প্রডাক্ট'.tr}: ${shortageList.length} ${'টি'.tr}');
    buf.writeln('─────────────────────────────');
    for (var i = 0; i < shortageList.length; i++) {
      final item = shortageList[i];
      buf.writeln(
          '${i + 1}. ${item.displayName} — ${item.shortQty} ${'টি'.tr}'
          ' (${'অর্ডার'.tr}: ${item.orderedQty}, ${'স্টক'.tr}: ${item.stockQty}'
          '${item.estimatedCost > 0 ? ', ${'আনুমানিক'.tr}: ৳${item.estimatedCost.round()}' : ''})');
    }
    buf.writeln('─────────────────────────────');
    buf.writeln('${'আনুমানিক মোট খরচ'.tr}: ৳${shortageTotalCost.round()}');
    return buf.toString();
  }
}
