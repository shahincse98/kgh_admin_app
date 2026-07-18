import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../model/admin_replace_model.dart';
import '../../product/controller/product_controller.dart';

class AdminReplaceController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final entries = <AdminReplaceModel>[].obs;
  final loading = false.obs;
  bool _loadedOnce = false;

  @override
  void onInit() {
    super.onInit();
    fetchEntries();
  }

  // ─── FETCH ────────────────────────────────────────────────────────────────

  Future<void> fetchEntries({bool force = false}) async {
    if (_loadedOnce && !force) return;
    loading.value = true;
    try {
      final snap = await _db
          .collection('admin_replace_entries')
          .orderBy('createdAt', descending: true)
          .get();
      entries.assignAll(
          snap.docs.map((d) => AdminReplaceModel.fromDoc(d)).toList());
      entries.refresh();
      _loadedOnce = true;
    } finally {
      loading.value = false;
    }
  }

  // ─── FILTERS ──────────────────────────────────────────────────────────────

  List<AdminReplaceModel> get atShop =>
      entries.where((e) => e.status == 'at_shop').toList();

  List<AdminReplaceModel> get withSupplier =>
      entries.where((e) => e.status == 'with_supplier').toList();

  List<AdminReplaceModel> get resolved =>
      entries.where((e) => e.status == 'resolved').toList();

  /// Entries that have a customer + replacement product but not yet delivered
  List<AdminReplaceModel> get pendingCustomerDelivery =>
      entries.where((e) => e.pendingCustomerDelivery).toList();

  /// All customer-facing replace entries
  List<AdminReplaceModel> get customerEntries =>
      entries.where((e) => e.entryType == 'customer_in').toList();

  /// Force UI refresh (call after in-place entry mutations)
  void refreshUI() => entries.refresh();

  // ─── ADD FROM CUSTOMER ───────────────────────────────────────────────────

  Future<void> addCustomerIn({
    required String productId,
    required String productName,
    required int quantity,
    String customerId = '',
    required String customerName,
    required String customerPhone,
    String customerAddress = '',
    String replaceProductId = '',
    String replaceProductName = '',
    String customerResolutionType = '',
    int deductionAmount = 0,
    int defectiveProductPrice = 0,
    int replaceProductPrice = 0,
    required String note,
    required DateTime date,
  }) async {
    final ref = _db.collection('admin_replace_entries').doc();
    final entry = AdminReplaceModel(
      id: ref.id,
      productId: productId,
      productName: productName,
      quantity: quantity,
      entryType: 'customer_in',
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      replaceProductId: replaceProductId,
      replaceProductName: replaceProductName,
      deliveredToCustomer: false,
      customerResolutionType: customerResolutionType,
      deductionAmount: deductionAmount,
      defectiveProductPrice: defectiveProductPrice,
      replaceProductPrice: replaceProductPrice,
      supplierId: '',
      supplierName: '',
      status: 'at_shop',
      currentLocation: 'shop',
      resolution: '',
      resolvedQty: 0,
      note: note,
      date: date,
      createdAt: DateTime.now(),
    );
    await ref.set(entry.toMap());

    // Increment replaceCount on product (items awaiting processing)
    if (productId.isNotEmpty) {
      await _db
          .collection('products')
          .doc(productId)
          .update({'replaceCount': FieldValue.increment(quantity)});
      _localProductUpdate(productId, replaceCountDelta: quantity);
    }

    entries.insert(0, entry);
  }

  // ─── ADD TO AT SHOP (direct entry, no customer required) ────────────────

  Future<void> addAtShopEntry({
    required String productId,
    required String productName,
    required int quantity,
    String note = '',
    required DateTime date,
  }) async {
    final ref = _db.collection('admin_replace_entries').doc();
    final entry = AdminReplaceModel(
      id: ref.id,
      productId: productId,
      productName: productName,
      quantity: quantity,
      entryType: 'customer_in',
      customerId: '',
      customerName: '',
      customerPhone: '',
      customerAddress: '',
      supplierId: '',
      supplierName: '',
      status: 'at_shop',
      currentLocation: 'shop',
      resolution: '',
      resolvedQty: 0,
      note: note,
      date: date,
      createdAt: DateTime.now(),
    );
    await ref.set(entry.toMap());

    if (productId.isNotEmpty) {
      await _db
          .collection('products')
          .doc(productId)
          .update({'replaceCount': FieldValue.increment(quantity)});
      _localProductUpdate(productId, replaceCountDelta: quantity);
    }

    entries.insert(0, entry);
  }

  // ─── ADD DIRECTLY TO SUPPLIER ────────────────────────────────────────────

  /// Creates an entry that goes straight to 'with_supplier' — bypasses at_shop.
  Future<void> addDirectToSupplier({
    required String productId,
    required String productName,
    required int quantity,
    required String supplierId,
    required String supplierName,
    String customerId = '',
    String customerName = '',
    String customerPhone = '',
    String customerAddress = '',
    required String note,
    required DateTime date,
  }) async {
    final ref = _db.collection('admin_replace_entries').doc();
    final now = DateTime.now();
    final entry = AdminReplaceModel(
      id: ref.id,
      productId: productId,
      productName: productName,
      quantity: quantity,
      entryType: 'customer_in',
      customerId: customerId,
      customerName: customerName,
      customerPhone: customerPhone,
      customerAddress: customerAddress,
      supplierId: supplierId,
      supplierName: supplierName,
      status: 'with_supplier',
      currentLocation: 'supplier',
      resolution: '',
      resolvedQty: 0,
      note: note,
      date: date,
      createdAt: now,
      sentToSupplierDate: now,
    );
    await ref.set(entry.toMap());

    if (productId.isNotEmpty) {
      await _db
          .collection('products')
          .doc(productId)
          .update({'replaceCount': FieldValue.increment(quantity)});
      _localProductUpdate(productId, replaceCountDelta: quantity);
    }

    entries.insert(0, entry);
  }

  // ─── SEND TO SUPPLIER ─────────────────────────────────────────────────────

  Future<void> sendToSupplier({
    required AdminReplaceModel entry,
    required String supplierId,
    required String supplierName,
    required String note,
  }) async {
    final now = DateTime.now();
    final updateMap = {
      'status': 'with_supplier',
      'currentLocation': 'supplier',
      'supplierId': supplierId,
      'supplierName': supplierName,
      'sentToSupplierDate': Timestamp.fromDate(now),
      if (note.isNotEmpty) 'note': note,
    };

    await _db
        .collection('admin_replace_entries')
        .doc(entry.id)
        .update(updateMap);

    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      entries[idx] = AdminReplaceModel(
        id: entry.id,
        productId: entry.productId,
        productName: entry.productName,
        quantity: entry.quantity,
        entryType: entry.entryType,
        customerId: entry.customerId,
        customerName: entry.customerName,
        customerPhone: entry.customerPhone,
        customerAddress: entry.customerAddress,
        replaceProductId: entry.replaceProductId,
        replaceProductName: entry.replaceProductName,
        deliveredToCustomer: entry.deliveredToCustomer,
        deliveredToCustomerAt: entry.deliveredToCustomerAt,
        customerResolutionType: entry.customerResolutionType,
        deductionAmount: entry.deductionAmount,
        defectiveProductPrice: entry.defectiveProductPrice,
        replaceProductPrice: entry.replaceProductPrice,
        supplierId: supplierId,
        supplierName: supplierName,
        status: 'with_supplier',
        currentLocation: 'supplier',
        resolution: entry.resolution,
        resolvedQty: entry.resolvedQty,
        sentToSupplierDate: now,
        note: note.isNotEmpty ? note : entry.note,
        date: entry.date,
        createdAt: entry.createdAt,
      );
      entries.refresh();
    }
  }

  // ─── RESOLVE: ADD TO STOCK ────────────────────────────────────────────────

  /// [resolution]: 'added_to_regular_stock' | 'added_to_replace_stock' | 'scrapped'
  Future<void> resolveEntry({
    required AdminReplaceModel entry,
    required String resolution,
    required int resolvedQty,
    required String note,
  }) async {
    final now = DateTime.now();
    final updateMap = {
      'status': 'resolved',
      'resolution': resolution,
      'resolvedQty': resolvedQty,
      'resolvedAt': Timestamp.fromDate(now),
      if (note.isNotEmpty) 'note': note,
    };

    await _db
        .collection('admin_replace_entries')
        .doc(entry.id)
        .update(updateMap);

    // Update product counts
    if (entry.productId.isNotEmpty && resolution != 'scrapped') {
      final Map<String, dynamic> productUpdate = {
        'replaceCount': FieldValue.increment(-resolvedQty),
      };
      if (resolution == 'added_to_regular_stock') {
        productUpdate['stock'] = FieldValue.increment(resolvedQty);
      } else if (resolution == 'added_to_replace_stock') {
        productUpdate['replaceStock'] = FieldValue.increment(resolvedQty);
      }
      await _db
          .collection('products')
          .doc(entry.productId)
          .update(productUpdate);
      _localProductUpdate(
        entry.productId,
        replaceCountDelta: -resolvedQty,
        stockDelta: resolution == 'added_to_regular_stock' ? resolvedQty : 0,
        replaceStockDelta:
            resolution == 'added_to_replace_stock' ? resolvedQty : 0,
      );
    } else if (entry.productId.isNotEmpty && resolution == 'scrapped') {
      // Just remove from replaceCount
      await _db
          .collection('products')
          .doc(entry.productId)
          .update({'replaceCount': FieldValue.increment(-resolvedQty)});
      _localProductUpdate(entry.productId, replaceCountDelta: -resolvedQty);
    }

    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      entries[idx] = AdminReplaceModel(
        id: entry.id,
        productId: entry.productId,
        productName: entry.productName,
        quantity: entry.quantity,
        entryType: entry.entryType,
        customerId: entry.customerId,
        customerName: entry.customerName,
        customerPhone: entry.customerPhone,
        customerAddress: entry.customerAddress,
        replaceProductId: entry.replaceProductId,
        replaceProductName: entry.replaceProductName,
        deliveredToCustomer: entry.deliveredToCustomer,
        deliveredToCustomerAt: entry.deliveredToCustomerAt,
        customerResolutionType: entry.customerResolutionType,
        deductionAmount: entry.deductionAmount,
        defectiveProductPrice: entry.defectiveProductPrice,
        replaceProductPrice: entry.replaceProductPrice,
        supplierId: entry.supplierId,
        supplierName: entry.supplierName,
        status: 'resolved',
        currentLocation: entry.currentLocation,
        resolution: resolution,
        resolvedQty: resolvedQty,
        resolvedAt: now,
        sentToSupplierDate: entry.sentToSupplierDate,
        note: note.isNotEmpty ? note : entry.note,
        date: entry.date,
        createdAt: entry.createdAt,
      );
      entries.refresh();
    }
  }

  // ─── SET CUSTOMER RESOLUTION ─────────────────────────────────────────────

  /// Set or update how the customer replace is resolved:
  /// product replacement or money deduction.
  Future<void> setCustomerResolution({
    required AdminReplaceModel entry,
    required String resolutionType, // 'product_replace' | 'money_deduct'
    String replaceProductId = '',
    String replaceProductName = '',
    int deductionAmount = 0,
  }) async {
    final updateMap = <String, dynamic>{
      'customerResolutionType': resolutionType,
      'replaceProductId': replaceProductId,
      'replaceProductName': replaceProductName,
      'deductionAmount': deductionAmount,
    };
    await _db
        .collection('admin_replace_entries')
        .doc(entry.id)
        .update(updateMap);

    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      entries[idx] = AdminReplaceModel(
        id: entry.id,
        productId: entry.productId,
        productName: entry.productName,
        quantity: entry.quantity,
        entryType: entry.entryType,
        customerId: entry.customerId,
        customerName: entry.customerName,
        customerPhone: entry.customerPhone,
        customerAddress: entry.customerAddress,
        replaceProductId: replaceProductId,
        replaceProductName: replaceProductName,
        deliveredToCustomer: entry.deliveredToCustomer,
        deliveredToCustomerAt: entry.deliveredToCustomerAt,
        customerResolutionType: resolutionType,
        deductionAmount: deductionAmount,
        defectiveProductPrice: entry.defectiveProductPrice,
        replaceProductPrice: entry.replaceProductPrice,
        supplierId: entry.supplierId,
        supplierName: entry.supplierName,
        status: entry.status,
        currentLocation: entry.currentLocation,
        resolution: entry.resolution,
        resolvedQty: entry.resolvedQty,
        resolvedAt: entry.resolvedAt,
        sentToSupplierDate: entry.sentToSupplierDate,
        note: entry.note,
        date: entry.date,
        createdAt: entry.createdAt,
      );
      entries.refresh();
    }
  }

  // ─── DELIVER TO CUSTOMER ─────────────────────────────────────────────────

  Future<void> deliverToCustomer({
    required AdminReplaceModel entry,
    required String note,
  }) async {
    final now = DateTime.now();

    final batch = _db.batch();

    // 1. Mark delivered
    final updateMap = <String, dynamic>{
      'deliveredToCustomer': true,
      'deliveredToCustomerAt': Timestamp.fromDate(now),
      if (note.isNotEmpty) 'note': note,
    };
    batch.update(_db.collection('admin_replace_entries').doc(entry.id),
        updateMap);

    // 2. Deduct replace product from stock (if product_replace)
    if (entry.customerResolutionType == 'product_replace' &&
        entry.replaceProductId.isNotEmpty) {
      batch.update(
        _db.collection('products').doc(entry.replaceProductId),
        {'stock': FieldValue.increment(-entry.quantity)},
      );
    }

    await batch.commit();

    // 3. Refresh products globally
    try {
      Get.find<ProductController>().fetchProducts(forceRefresh: true);
    } catch (_) {}

    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      entries[idx] = AdminReplaceModel(
        id: entry.id,
        productId: entry.productId,
        productName: entry.productName,
        quantity: entry.quantity,
        entryType: entry.entryType,
        customerId: entry.customerId,
        customerName: entry.customerName,
        customerPhone: entry.customerPhone,
        customerAddress: entry.customerAddress,
        replaceProductId: entry.replaceProductId,
        replaceProductName: entry.replaceProductName,
        deliveredToCustomer: true,
        deliveredToCustomerAt: now,
        customerResolutionType: entry.customerResolutionType,
        deductionAmount: entry.deductionAmount,
        supplierId: entry.supplierId,
        supplierName: entry.supplierName,
        status: entry.status,
        currentLocation: entry.currentLocation,
        resolution: entry.resolution,
        resolvedQty: entry.resolvedQty,
        resolvedAt: entry.resolvedAt,
        sentToSupplierDate: entry.sentToSupplierDate,
        note: note.isNotEmpty ? note : entry.note,
        date: entry.date,
        createdAt: entry.createdAt,
      );
      entries.refresh();
    }
  }

  /// Set/Update the replace product for a pending customer replace entry.
  /// This is what the customer will receive back.  No money is involved.
  Future<void> setReplaceProduct({
    required AdminReplaceModel entry,
    required String replaceProductId,
    required String replaceProductName,
    int replaceProductPrice = 0,
  }) async {
    final updates = <String, dynamic>{
      'replaceProductId': replaceProductId,
      'replaceProductName': replaceProductName,
      'customerResolutionType': 'product_replace',
    };
    if (replaceProductPrice > 0) {
      updates['replaceProductPrice'] = replaceProductPrice;
    }
    await _db.collection('admin_replace_entries').doc(entry.id).update(updates);

    final idx = entries.indexWhere((e) => e.id == entry.id);
    if (idx != -1) {
      final e = entries[idx];
      entries[idx] = AdminReplaceModel(
        id: e.id,
        productId: e.productId,
        productName: e.productName,
        quantity: e.quantity,
        entryType: e.entryType,
        customerId: e.customerId,
        customerName: e.customerName,
        customerPhone: e.customerPhone,
        customerAddress: e.customerAddress,
        replaceProductId: replaceProductId,
        replaceProductName: replaceProductName,
        deliveredToCustomer: e.deliveredToCustomer,
        deliveredToCustomerAt: e.deliveredToCustomerAt,
        customerResolutionType: 'product_replace',
        deductionAmount: e.deductionAmount,
        defectiveProductPrice: e.defectiveProductPrice,
        replaceProductPrice: replaceProductPrice > 0 ? replaceProductPrice : e.replaceProductPrice,
        supplierId: e.supplierId,
        supplierName: e.supplierName,
        status: e.status,
        currentLocation: e.currentLocation,
        resolution: e.resolution,
        resolvedQty: e.resolvedQty,
        resolvedAt: e.resolvedAt,
        sentToSupplierDate: e.sentToSupplierDate,
        note: e.note,
        date: e.date,
        createdAt: e.createdAt,
      );
      entries.refresh();
    }
  }

  // ─── DELETE ENTRY ────────────────────────────────────────────────────────

  Future<void> deleteEntry(AdminReplaceModel entry) async {
    await _db
        .collection('admin_replace_entries')
        .doc(entry.id)
        .delete();

    // Reverse replaceCount if still pending
    if (entry.productId.isNotEmpty && entry.status != 'resolved') {
      await _db.collection('products').doc(entry.productId).update({
        'replaceCount': FieldValue.increment(-entry.quantity),
      });
      _localProductUpdate(entry.productId,
          replaceCountDelta: -entry.quantity);
    }

    entries.removeWhere((e) => e.id == entry.id);
    entries.refresh();
  }

  // ─── REPLACE STOCK ADJUSTMENT ────────────────────────────────────────────

  /// Directly adjust replace stock of a product (e.g. manual correction
  /// or when selling a replace product from stock)
  Future<void> adjustReplaceStock(String productId, int delta) async {
    await _db
        .collection('products')
        .doc(productId)
        .update({'replaceStock': FieldValue.increment(delta)});
    _localProductUpdate(productId, replaceStockDelta: delta);
  }

  // ─── LOCAL CACHE UPDATE ──────────────────────────────────────────────────

  void _localProductUpdate(
    String productId, {
    int replaceCountDelta = 0,
    int stockDelta = 0,
    int replaceStockDelta = 0,
  }) {
    try {
      final pc = Get.find<ProductController>();
      final idx = pc.products.indexWhere((p) => p.id == productId);
      if (idx != -1) {
        final p = pc.products[idx];
        pc.products[idx] = p.copyWithMap({
          'replaceCount': p.replaceCount + replaceCountDelta,
          'stock': p.stock + stockDelta,
          'replaceStock': (p.replaceStock) + replaceStockDelta,
        });
        pc.products.refresh();
      }
    } catch (_) {
      // ProductController may not be available in all contexts
    }
  }

  // ─── FETCH PENDING FOR CUSTOMER ──────────────────────────────────────────

  /// Fetches replace entries that are waiting to be delivered back to a
  /// specific customer (has a replacement product assigned but not yet
  /// handed over).  Used during order delivery to hand them over together
  /// with the order.
  Future<List<AdminReplaceModel>> fetchPendingForCustomer(
      String customerId) async {
    if (customerId.isEmpty) return [];
    try {
      final snap = await _db
          .collection('admin_replace_entries')
          .where('customerId', isEqualTo: customerId)
          .where('deliveredToCustomer', isEqualTo: false)
          .where('customerResolutionType', isEqualTo: 'product_replace')
          .get();
      final list = snap.docs
          .map((d) => AdminReplaceModel.fromDoc(d))
          .where((e) => e.replaceProductName.isNotEmpty)
          .toList();
      list.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return list;
    } catch (_) {
      return [];
    }
  }

  /// Fetches ALL customer replace entries (both pending & delivered).
  /// Used in order details page to show replace history for this customer.
  Future<List<AdminReplaceModel>> fetchAllForCustomer(
      String customerId) async {
    if (customerId.isEmpty) return [];
    try {
      final snap = await _db
          .collection('admin_replace_entries')
          .where('customerId', isEqualTo: customerId)
          .orderBy('createdAt', descending: true)
          .get();
      return snap.docs.map((d) => AdminReplaceModel.fromDoc(d)).toList();
    } catch (_) {
      return [];
    }
  }
}
