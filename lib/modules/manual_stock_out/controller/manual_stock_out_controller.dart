import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/manual_stock_out_model.dart';
import '../../auth/controller/auth_controller.dart';
import '../../product/controller/product_controller.dart';

class ManualStockOutController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final entries = <ManualStockOutModel>[].obs;
  final loading = false.obs;
  final searchText = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchEntries();
  }

  Future<void> fetchEntries() async {
    loading.value = true;
    try {
      final snap = await _db
          .collection('manual_stock_outs')
          .orderBy('createdAt', descending: true)
          .get();

      entries.assignAll(
          snap.docs.map((e) => ManualStockOutModel.fromFirestore(e)).toList());
    } catch (_) {}
    loading.value = false;
  }

  List<ManualStockOutModel> get filteredEntries {
    var list = entries.toList();
    final q = searchText.value.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list
          .where((e) =>
              e.customerName.toLowerCase().contains(q) ||
              e.memoNumber.toLowerCase().contains(q) ||
              e.customerPhone.contains(q) ||
              e.id.toLowerCase().contains(q) ||
              e.items.any((i) => i.productName.toLowerCase().contains(q)))
          .toList();
    }
    return list;
  }

  Future<void> submitStockOut({
    required DateTime stockOutDate,
    required String customerName,
    String customerPhone = '',
    String customerAddress = '',
    String memoNumber = '',
    String customerId = '',
    required List<Map<String, dynamic>> items,
    List<Map<String, dynamic>> replaceActions = const [],
  }) async {
    final currentUser = await _getCurrentUserId();

    final batch = _db.batch();

    // 1. Deduct stock from products
    for (final item in items) {
      final productId = item['productId'] as String? ?? '';
      final qty = (item['quantity'] as num?)?.toInt() ?? 0;
      if (productId.isEmpty || qty == 0) continue;
      final ref = _db.collection('products').doc(productId);
      batch.update(ref, {'stock': FieldValue.increment(-qty)});
    }

    // 2. Process replace actions
    for (final ra in replaceActions) {
      final type = ra['resolutionType'] as String? ?? '';
      final isNew = ra['newReplace'] as bool? ?? false;
      final now = DateTime.now();
      String entryId;

      if (isNew) {
        // Create new admin_replace_entries doc first
        final newRef = _db.collection('admin_replace_entries').doc();
        final defectiveProductId = ra['defectiveProductId'] as String? ?? '';
        final defectiveProductName = ra['defectiveProductName'] as String? ?? '';
        final defectiveQty = (ra['defectiveQty'] as num?)?.toInt() ?? 0;

        batch.set(newRef, {
          'productId': defectiveProductId,
          'productName': defectiveProductName,
          'quantity': defectiveQty,
          'entryType': 'customer_in',
          'customerId': customerId,
          'customerName': customerName,
          'customerPhone': customerPhone,
          'customerAddress': customerAddress,
          'status': 'at_shop',
          'currentLocation': 'shop',
          'date': Timestamp.fromDate(stockOutDate),
          'createdAt': FieldValue.serverTimestamp(),
          'note': '',
          'replaceProductId': '',
          'replaceProductName': '',
          'deliveredToCustomer': false,
          'customerResolutionType': '',
          'deductionAmount': 0,
          'supplierId': '',
          'supplierName': '',
          'resolution': '',
          'resolvedQty': 0,
          'sentToSupplierDate': null,
        });

        // Increment replaceCount on defective product
        if (defectiveProductId.isNotEmpty && defectiveQty > 0) {
          batch.update(_db.collection('products').doc(defectiveProductId),
              {'replaceCount': FieldValue.increment(defectiveQty)});
        }

        entryId = newRef.id;
      } else {
        entryId = ra['replaceEntryId'] as String? ?? '';
      }

      if (entryId.isEmpty) continue;
      final ref = _db.collection('admin_replace_entries').doc(entryId);

      if (type == 'product_replace') {
        final replaceProductId = ra['replaceProductId'] as String? ?? '';
        final replaceQty = (ra['replaceQty'] as num?)?.toInt() ?? 0;
        final replaceProductName = ra['replaceProductName'] as String? ?? '';
        final defectiveProductId = ra['defectiveProductId'] as String? ?? '';

        // Deduct replacement product stock
        if (replaceProductId.isNotEmpty && replaceQty > 0) {
          final prodRef = _db.collection('products').doc(replaceProductId);
          batch.update(prodRef, {'stock': FieldValue.increment(-replaceQty)});
        }

        // Decrement replaceCount on defective product
        if (defectiveProductId.isNotEmpty) {
          final defRef = _db.collection('products').doc(defectiveProductId);
          batch.update(defRef, {'replaceCount': FieldValue.increment(-replaceQty)});
        }

        // Update replace entry
        batch.update(ref, {
          'customerResolutionType': 'product_replace',
          'replaceProductId': replaceProductId,
          'replaceProductName': replaceProductName,
          'deliveredToCustomer': true,
          'deliveredToCustomerAt': Timestamp.fromDate(now),
        });
      } else if (type == 'money_deduct') {
        final amount = ra['deductionAmount'] as num? ?? 0;
        batch.update(ref, {
          'customerResolutionType': 'money_deduct',
          'deductionAmount': amount,
          'deliveredToCustomer': true,
          'deliveredToCustomerAt': Timestamp.fromDate(now),
        });
      }
    }

    // 3. Create manual stock out entry
    final docRef = _db.collection('manual_stock_outs').doc();
    batch.set(docRef, {
      'createdAt': FieldValue.serverTimestamp(),
      'stockOutDate': Timestamp.fromDate(stockOutDate),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'customerId': customerId,
      'memoNumber': memoNumber,
      'items': items,
      'replaceActions': replaceActions,
      'createdBy': currentUser,
    });

    await batch.commit();

    // Refresh product list everywhere (stock management etc.)
    try {
      Get.find<ProductController>().fetchProducts(forceRefresh: true);
    } catch (_) {}

    // Refresh list
    await fetchEntries();
  }

  Future<void> deleteEntry(String id) async {
    // Restore stock and undo replaces before deleting
    final entry = entries.firstWhereOrNull((e) => e.id == id);
    if (entry != null) {
      final batch = _db.batch();

      // Restore product stock
      for (final item in entry.items) {
        if (item.productId.isEmpty) continue;
        final ref = _db.collection('products').doc(item.productId);
        batch.update(ref, {'stock': FieldValue.increment(item.quantity)});
      }

      // Undo replace actions
      for (final ra in entry.replaceActions) {
        if (ra.replaceEntryId.isEmpty) continue;
        final ref = _db.collection('admin_replace_entries').doc(ra.replaceEntryId);

        if (ra.resolutionType == 'product_replace') {
          // Restore replacement product stock
          if (ra.replaceProductId.isNotEmpty && ra.replaceQty > 0) {
            batch.update(_db.collection('products').doc(ra.replaceProductId),
                {'stock': FieldValue.increment(ra.replaceQty)});
          }
          // Restore defective product replaceCount
          if (ra.defectiveProductId.isNotEmpty) {
            batch.update(_db.collection('products').doc(ra.defectiveProductId),
                {'replaceCount': FieldValue.increment(ra.replaceQty)});
          }
        }

        // Clear resolution
        batch.update(ref, {
          'customerResolutionType': FieldValue.delete(),
          'replaceProductId': FieldValue.delete(),
          'replaceProductName': FieldValue.delete(),
          'deductionAmount': FieldValue.delete(),
          'deliveredToCustomer': false,
          'deliveredToCustomerAt': FieldValue.delete(),
        });
      }

      batch.delete(_db.collection('manual_stock_outs').doc(id));
      await batch.commit();

      try {
        Get.find<ProductController>().fetchProducts(forceRefresh: true);
      } catch (_) {}
    } else {
      await _db.collection('manual_stock_outs').doc(id).delete();
    }
    entries.removeWhere((e) => e.id == id);
  }

  Future<void> updateEntry({
    required String id,
    required DateTime stockOutDate,
    required String customerName,
    String customerPhone = '',
    String customerAddress = '',
    String memoNumber = '',
    String customerId = '',
    required List<Map<String, dynamic>> newItems,
    List<Map<String, dynamic>> replaceActions = const [],
  }) async {
    final oldEntry = entries.firstWhereOrNull((e) => e.id == id);
    if (oldEntry == null) return;

    final batch = _db.batch();

    // 1. Restore stock from old items
    for (final oldItem in oldEntry.items) {
      if (oldItem.productId.isEmpty) continue;
      final ref = _db.collection('products').doc(oldItem.productId);
      batch.update(ref, {'stock': FieldValue.increment(oldItem.quantity)});
    }

    // 2. Deduct stock for new items
    for (final newItem in newItems) {
      final productId = newItem['productId'] as String? ?? '';
      final qty = (newItem['quantity'] as num?)?.toInt() ?? 0;
      if (productId.isEmpty || qty == 0) continue;
      final ref = _db.collection('products').doc(productId);
      batch.update(ref, {'stock': FieldValue.increment(-qty)});
    }

    // 3. Update entry document
    batch.update(_db.collection('manual_stock_outs').doc(id), {
      'stockOutDate': Timestamp.fromDate(stockOutDate),
      'customerName': customerName,
      'customerPhone': customerPhone,
      'customerAddress': customerAddress,
      'memoNumber': memoNumber,
      'customerId': customerId,
      'items': newItems,
      'replaceActions': replaceActions,
    });

    await batch.commit();

    // Refresh products
    try {
      Get.find<ProductController>().fetchProducts(forceRefresh: true);
    } catch (_) {}

    // Refresh list
    await fetchEntries();
  }

  Future<String> _getCurrentUserId() async {
    try {
      final auth = Get.find<AuthController>();
      return auth.currentUser?.uid ?? '';
    } catch (_) {}
    return '';
  }
}
