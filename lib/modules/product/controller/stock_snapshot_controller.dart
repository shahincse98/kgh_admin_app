import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../model/stock_snapshot_model.dart';
import '../model/product_model.dart';
import '../../replace/controller/admin_replace_controller.dart';
import '../controller/product_controller.dart';
import '../../stock_in/controller/stock_in_controller.dart';
import '../../order/controller/order_controller.dart';

class StockSnapshotController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final snapshots = <StockSnapshotModel>[].obs;
  final loading = false.obs;
  final saving = false.obs;
  final restoring = false.obs;

  @override
  void onInit() {
    super.onInit();
    fetchSnapshots();
  }

  Future<void> fetchSnapshots() async {
    loading.value = true;
    try {
      final snap = await _db
          .collection('stock_snapshots')
          .orderBy('savedAt', descending: true)
          .get();
      snapshots.assignAll(
          snap.docs.map((e) => StockSnapshotModel.fromFirestore(e)));
    } finally {
      loading.value = false;
    }
  }

  Future<void> saveSnapshot(
      String label, List<ProductModel> products,
      {Map<String, int>? replaceMap}) async {
    saving.value = true;
    try {
      final items = products
          .map((p) => {
                'productId': p.id,
                'name': p.name,
                'category': p.productCategory,
                'stock': p.stock,
                'isInternal': p.isInternal,
              })
          .toList();

      final replaceItems = replaceMap == null
          ? <Map<String, dynamic>>[]
          : replaceMap.entries
              .map((e) => {'productName': e.key, 'quantity': e.value})
              .toList();

      final doc = await _db.collection('stock_snapshots').add({
        'label': label.trim(),
        'savedAt': FieldValue.serverTimestamp(),
        'items': items,
        'replaceItems': replaceItems,
      });

      final newDoc = await doc.get();
      snapshots.insert(0, StockSnapshotModel.fromFirestore(newDoc));
    } finally {
      saving.value = false;
    }
  }

  Future<void> deleteSnapshot(String id) async {
    await _db.collection('stock_snapshots').doc(id).delete();
    snapshots.removeWhere((s) => s.id == id);
  }

  /// Restores stock state from a selected snapshot:
  /// 1) Product stock for all products (non-listed items become 0)
  /// 2) At-shop replace stock (current at_shop entries are marked resolved,
  ///    then rebuilt from snapshot.replaceItems)
  Future<Map<String, int>> restoreFromSnapshot(StockSnapshotModel snapshot) async {
    if (restoring.value) return {'products': 0, 'replace': 0};
    restoring.value = true;
    try {
      // Build target product stock map from snapshot.
      final targetStocks = <String, int>{};
      for (final item in snapshot.items) {
        if (item.productId.isNotEmpty) {
          targetStocks[item.productId] = item.stock;
        }
      }

      // Apply stock to every product doc: snapshot value or 0.
      final allProducts = await _db.collection('products').get();
      const productChunk = 350;
      for (var i = 0; i < allProducts.docs.length; i += productChunk) {
        final end = (i + productChunk > allProducts.docs.length)
            ? allProducts.docs.length
            : i + productChunk;
        final batch = _db.batch();
        for (final doc in allProducts.docs.sublist(i, end)) {
          final newStock = targetStocks[doc.id] ?? 0;
          batch.update(doc.reference, {'stock': newStock});
        }
        await batch.commit();
      }

      // Replace stock restore: close existing at-shop entries.
      final now = DateTime.now();
      final atShopSnap = await _db
          .collection('admin_replace_entries')
          .where('status', isEqualTo: 'at_shop')
          .get();

      const replaceChunk = 350;
      for (var i = 0; i < atShopSnap.docs.length; i += replaceChunk) {
        final end = (i + replaceChunk > atShopSnap.docs.length)
            ? atShopSnap.docs.length
            : i + replaceChunk;
        final batch = _db.batch();
        for (final doc in atShopSnap.docs.sublist(i, end)) {
          final qty = (doc.data()['quantity'] as num?)?.toInt() ?? 0;
          batch.update(doc.reference, {
            'status': 'resolved',
            'currentLocation': 'snapshot_restore',
            'resolution': 'snapshot_restore_reset',
            'resolvedQty': qty,
            'resolvedAt': Timestamp.fromDate(now),
          });
        }
        await batch.commit();
      }

      // Recreate at-shop entries from snapshot replace items.
      final restoreReplaceItems =
          snapshot.replaceItems.where((e) => e.quantity > 0).toList();
      for (var i = 0; i < restoreReplaceItems.length; i += replaceChunk) {
        final end = (i + replaceChunk > restoreReplaceItems.length)
            ? restoreReplaceItems.length
            : i + replaceChunk;
        final batch = _db.batch();
        for (final item in restoreReplaceItems.sublist(i, end)) {
          final ref = _db.collection('admin_replace_entries').doc();
          batch.set(ref, {
            'productId': '',
            'productName': item.productName,
            'quantity': item.quantity,
            'entryType': 'snapshot_restore',
            'customerId': '',
            'customerName': '',
            'customerPhone': '',
            'customerAddress': '',
            'replaceProductId': '',
            'replaceProductName': '',
            'deliveredToCustomer': false,
            'deliveredToCustomerAt': null,
            'customerResolutionType': '',
            'deductionAmount': 0,
            'supplierId': '',
            'supplierName': '',
            'status': 'at_shop',
            'currentLocation': 'shop',
            'resolution': '',
            'resolvedQty': 0,
            'resolvedAt': null,
            'sentToSupplierDate': null,
            'note': 'Restored from snapshot: ${snapshot.label}',
            'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),
            'createdAt': FieldValue.serverTimestamp(),
          });
        }
        await batch.commit();
      }

      // Refresh local caches if controllers are active.
      if (Get.isRegistered<ProductController>()) {
        await Get.find<ProductController>().fetchProducts(forceRefresh: true);
      }
      if (Get.isRegistered<AdminReplaceController>()) {
        await Get.find<AdminReplaceController>().fetchEntries(force: true);
      }

      // Clean up stock_ins created AFTER snapshot date (stock reversed by restore)
      final stockInsAfterSnap = await _db
          .collection('stock_ins')
          .where('createdAt', isGreaterThan: Timestamp.fromDate(snapshot.savedAt))
          .get();

      int cleanedStockIns = 0;
      if (stockInsAfterSnap.docs.isNotEmpty) {
        const insChunk = 350;
        for (var i = 0; i < stockInsAfterSnap.docs.length; i += insChunk) {
          final end = (i + insChunk > stockInsAfterSnap.docs.length)
              ? stockInsAfterSnap.docs.length
              : i + insChunk;
          final batch = _db.batch();
          for (final doc in stockInsAfterSnap.docs.sublist(i, end)) {
            batch.delete(doc.reference);
          }
          await batch.commit();
        }
        cleanedStockIns = stockInsAfterSnap.docs.length;
      }

      // Refresh stock in controller cache
      if (Get.isRegistered<StockInController>()) {
        await Get.find<StockInController>().fetchEntries();
      }

      // Also revert dispatched orders after snapshot (un-dispatch: restore stock per order)
      final dispatchedAfterSnap = await _db
          .collection('orders')
          .where('status', isEqualTo: 'dispatched')
          .where('dispatchedAt', isGreaterThan: Timestamp.fromDate(snapshot.savedAt))
          .get();

      int revertedOrders = 0;
      if (dispatchedAfterSnap.docs.isNotEmpty) {
        const orderChunk = 350;
        for (var i = 0; i < dispatchedAfterSnap.docs.length; i += orderChunk) {
          final end = (i + orderChunk > dispatchedAfterSnap.docs.length)
              ? dispatchedAfterSnap.docs.length
              : i + orderChunk;
          final batch = _db.batch();
          for (final doc in dispatchedAfterSnap.docs.sublist(i, end)) {
            batch.update(doc.reference, {
              'status': 'approved',
              'memoNumber': FieldValue.delete(),
              'dispatchedAt': FieldValue.delete(),
              'dispatchedBy': FieldValue.delete(),
            });
          }
          await batch.commit();
        }
        revertedOrders = dispatchedAfterSnap.docs.length;
      }

      // Refresh order controller cache
      if (Get.isRegistered<OrderController>()) {
        await Get.find<OrderController>().fetchOrders();
      }

      return {
        'products': allProducts.docs.length,
        'replace': restoreReplaceItems.length,
        'revertedOrders': revertedOrders,
        'deletedStockIns': cleanedStockIns,
      };
    } finally {
      restoring.value = false;
    }
  }
}
