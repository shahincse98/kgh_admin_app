import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../model/supplier_model.dart';
import '../../purchase/model/purchase_entry_model.dart';

class SupplierController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final suppliers = <SupplierModel>[].obs;
  final loading = false.obs;
  bool _loadedOnce = false;

  @override
  void onInit() {
    super.onInit();
    fetchSuppliers();
  }

  Future<void> fetchSuppliers({bool force = false}) async {
    if (_loadedOnce && !force) return;
    loading.value = true;
    try {
      final snap =
          await _db.collection('suppliers').orderBy('shopName').get();
      suppliers.assignAll(
          snap.docs.map((d) => SupplierModel.fromFirestore(d)).toList());
      _loadedOnce = true;
    } finally {
      loading.value = false;
    }
  }

  Future<SupplierModel> addSupplier({
    required String shopName,
    required String ownerName,
    required String phone,
    required String address,
  }) async {
    final ref = _db.collection('suppliers').doc();
    final map = SupplierModel(
      id: ref.id,
      shopName: shopName,
      ownerName: ownerName,
      phone: phone,
      address: address,
    ).toMap();
    await ref.set({...map, 'createdAt': FieldValue.serverTimestamp()});

    final s = SupplierModel(
      id: ref.id,
      shopName: shopName,
      ownerName: ownerName,
      phone: phone,
      address: address,
      createdAt: DateTime.now(),
    );
    suppliers.add(s);
    suppliers.sort((a, b) => a.shopName.compareTo(b.shopName));
    return s;
  }

  Future<void> updateSupplier(
    SupplierModel s, {
    required String shopName,
    required String ownerName,
    required String phone,
    required String address,
  }) async {
    await _db.collection('suppliers').doc(s.id).update({
      'shopName': shopName,
      'ownerName': ownerName,
      'phone': phone,
      'address': address,
    });
    final idx = suppliers.indexWhere((x) => x.id == s.id);
    if (idx != -1) {
      suppliers[idx] = s.copyWith(
        shopName: shopName,
        ownerName: ownerName,
        phone: phone,
        address: address,
      );
      suppliers.sort((a, b) => a.shopName.compareTo(b.shopName));
    }
  }

  Future<void> deleteSupplier(SupplierModel s) async {
    await _db.collection('suppliers').doc(s.id).delete();
    suppliers.removeWhere((x) => x.id == s.id);
  }

  /// Purchase history for a specific supplier (by supplierId).
  Future<List<PurchaseEntryModel>> getSupplierPurchases(
      SupplierModel s) async {
    final snap = await _db
        .collection('stock_purchases')
        .where('supplierId', isEqualTo: s.id)
        .get();
    final list = snap.docs.map(PurchaseEntryModel.fromFirestore).toList();
    list.sort((a, b) => b.date.compareTo(a.date));
    return list;
  }
}
