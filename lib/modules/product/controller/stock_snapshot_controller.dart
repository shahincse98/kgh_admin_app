import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../model/stock_snapshot_model.dart';
import '../model/product_model.dart';

class StockSnapshotController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final snapshots = <StockSnapshotModel>[].obs;
  final loading = false.obs;
  final saving = false.obs;

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
}
