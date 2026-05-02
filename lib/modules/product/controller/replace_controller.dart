import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/global_replace_model.dart';
import '../model/delivered_replace_model.dart';
import '../model/product_model.dart';
import 'product_controller.dart';
import '../../user/controller/user_controller.dart';

class ReplaceController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final allReplaces = <GlobalReplaceModel>[].obs;
  final allDelivered = <DeliveredReplaceModel>[].obs;
  final loading = false.obs;

  // ────────────────────────────────────────────────
  // FETCH ALL PENDING REPLACES (collectionGroup)
  // ────────────────────────────────────────────────
  Future<void> fetchAllReplaces() async {
    loading.value = true;
    try {
      final userCtrl = Get.find<UserController>();

      final results = await Future.wait([
        _db.collectionGroup('replaces').get(),
        _db.collectionGroup('replacesDelivered').get(),
      ]);

      final pendingSnap = results[0];
      final deliveredSnap = results[1];

      final pendingList = pendingSnap.docs.map((doc) {
        final userId = doc.reference.parent.parent?.id ?? '';
        final user =
            userCtrl.users.firstWhereOrNull((u) => u.id == userId);
        return GlobalReplaceModel.fromDoc(
          doc,
          shopName: user?.shopName ?? userId,
        );
      }).toList()
        ..sort((a, b) {
          final aTime = a.createdAt ?? DateTime(0);
          final bTime = b.createdAt ?? DateTime(0);
          return bTime.compareTo(aTime);
        });

      final deliveredList = deliveredSnap.docs.map((doc) {
        final userId = doc.reference.parent.parent?.id ?? '';
        final user =
            userCtrl.users.firstWhereOrNull((u) => u.id == userId);
        return DeliveredReplaceModel.fromDoc(
          doc,
          shopName: user?.shopName ?? userId,
        );
      }).toList()
        ..sort((a, b) => b.deliveredAt.compareTo(a.deliveredAt));

      allReplaces.assignAll(pendingList);
      allDelivered.assignAll(deliveredList);
    } finally {
      loading.value = false;
    }
  }

  // ────────────────────────────────────────────────
  // ADD REPLACE (পেন্ডিং তালিকায় যোগ)
  // শুধু replaceCount++ — stock অপরিবর্তিত
  // ────────────────────────────────────────────────
  Future<void> addReplace({
    required String userId,
    required String shopName,
    required String productId,
    required String productName,
    required int quantity,
    required String note,
    required DateTime date,
  }) async {
    final batch = _db.batch();

    final replaceRef = _db
        .collection('users')
        .doc(userId)
        .collection('replaces')
        .doc();

    batch.set(replaceRef, {
      'productName': productName,
      'productId': productId,
      'quantity': quantity,
      'note': note,
      'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'createdAt': FieldValue.serverTimestamp(),
    });

    // replaceCount++ only — stock unchanged (item not delivered yet)
    if (productId.isNotEmpty) {
      batch.update(_db.collection('products').doc(productId), {
        'replaceCount': FieldValue.increment(quantity),
      });
    }

    await batch.commit();

    if (productId.isNotEmpty) {
      _localProductUpdate(productId, stockDelta: 0, replaceDelta: quantity);
    }

    allReplaces.insert(
      0,
      GlobalReplaceModel(
        id: replaceRef.id,
        userId: userId,
        shopName: shopName,
        productName: productName,
        productId: productId,
        quantity: quantity,
        note: note,
        date: date,
        createdAt: DateTime.now(),
      ),
    );
  }

  // ────────────────────────────────────────────────
  // DELIVER REPLACE (ডেলিভারি দেওয়া হয়েছে)
  // stock-- + replaceCount-- + pending মুছুন + delivered-এ যোগ
  // ────────────────────────────────────────────────
  Future<void> deliverReplace({
    required String replaceId,
    required String userId,
    required String shopName,
    required String productId,
    required String productName,
    required int quantity,
    required String note,
    required DateTime deliveredAt,
  }) async {
    final batch = _db.batch();

    // Delete from pending
    batch.delete(
      _db
          .collection('users')
          .doc(userId)
          .collection('replaces')
          .doc(replaceId),
    );

    // Add to delivered history
    final deliveredRef = _db
        .collection('users')
        .doc(userId)
        .collection('replacesDelivered')
        .doc();

    batch.set(deliveredRef, {
      'productName': productName,
      'productId': productId,
      'quantity': quantity,
      'note': note,
      'deliveredAt': Timestamp.fromDate(deliveredAt),
    });

    // stock-- AND replaceCount-- (item physically given to customer)
    if (productId.isNotEmpty) {
      batch.update(_db.collection('products').doc(productId), {
        'replaceCount': FieldValue.increment(-quantity),
        'stock': FieldValue.increment(-quantity),
      });
    }

    await batch.commit();

    if (productId.isNotEmpty) {
      _localProductUpdate(productId, stockDelta: -quantity, replaceDelta: -quantity);
    }

    // Update local lists
    allReplaces.removeWhere(
        (r) => r.id == replaceId && r.userId == userId);

    allDelivered.insert(
      0,
      DeliveredReplaceModel(
        id: deliveredRef.id,
        userId: userId,
        shopName: shopName,
        productName: productName,
        productId: productId,
        quantity: quantity,
        note: note,
        deliveredAt: deliveredAt,
      ),
    );
  }

  // ────────────────────────────────────────────────
  // CANCEL REPLACE (বাতিল — stock অপরিবর্তিত)
  // শুধু replaceCount--
  // ────────────────────────────────────────────────
  Future<void> cancelReplace({
    required String replaceId,
    required String userId,
    required String productId,
    required int quantity,
  }) async {
    final batch = _db.batch();

    batch.delete(
      _db
          .collection('users')
          .doc(userId)
          .collection('replaces')
          .doc(replaceId),
    );

    // replaceCount-- only — stock unchanged (nothing was given)
    if (productId.isNotEmpty) {
      batch.update(_db.collection('products').doc(productId), {
        'replaceCount': FieldValue.increment(-quantity),
      });
    }

    await batch.commit();

    if (productId.isNotEmpty) {
      _localProductUpdate(productId, stockDelta: 0, replaceDelta: -quantity);
    }

    allReplaces.removeWhere(
        (r) => r.id == replaceId && r.userId == userId);
  }

  // ────────────────────────────────────────────────
  // DELETE DELIVERED RECORD (শুধু ইতিহাস মুছুন)
  // ────────────────────────────────────────────────
  Future<void> deleteDeliveredRecord({
    required String deliveredId,
    required String userId,
  }) async {
    await _db
        .collection('users')
        .doc(userId)
        .collection('replacesDelivered')
        .doc(deliveredId)
        .delete();

    allDelivered.removeWhere(
        (r) => r.id == deliveredId && r.userId == userId);
  }

  // Backwards-compat: old deleteReplace calls now cancel
  Future<void> deleteReplace({
    required String replaceId,
    required String userId,
    required String productId,
    required int quantity,
  }) =>
      cancelReplace(
        replaceId: replaceId,
        userId: userId,
        productId: productId,
        quantity: quantity,
      );

  // ────────────────────────────────────────────────
  // LOCAL CACHE UPDATE
  // ────────────────────────────────────────────────
  void _localProductUpdate(
    String productId, {
    required int stockDelta,
    required int replaceDelta,
  }) {
    final pc = Get.find<ProductController>();
    final idx = pc.products.indexWhere((p) => p.id == productId);
    if (idx != -1) {
      final p = pc.products[idx];
      pc.products[idx] = p.copyWithMap(<String, dynamic>{
        'stock': p.stock + stockDelta,
        'replaceCount': p.replaceCount + replaceDelta,
      });
      pc.products.refresh();
    }
  }

  // ────────────────────────────────────────────────
  // UI HELPERS
  // ────────────────────────────────────────────────
  List<ProductModel> get replaceProductSummary {
    return Get.find<ProductController>()
        .products
        .where((p) => p.replaceCount > 0)
        .toList()
      ..sort((a, b) => b.replaceCount.compareTo(a.replaceCount));
  }
}

