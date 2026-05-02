import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/user_model.dart';
import '../model/user_order_model.dart';
import '../model/user_replace_model.dart';
import '../../product/controller/replace_controller.dart';

class UserController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final users = <UserModel>[].obs;
  final loading = true.obs;
  final searchText = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchUsers();
  }

  Future<void> fetchUsers() async {
    loading.value = true;
    final snap = await _db.collection('users').get();
    users.value =
        snap.docs.map((e) => UserModel.fromFirestore(e)).toList();
    loading.value = false;
  }

  List<UserModel> get filteredUsers {
    final q = searchText.value.trim().toLowerCase();
    if (q.isEmpty) return users;
    return users
        .where((u) =>
            u.shopName.toLowerCase().contains(q) ||
            u.proprietorName.toLowerCase().contains(q) ||
            u.phone.contains(q))
        .toList();
  }

  Future<void> toggleBlock(UserModel user) async {
    final newVal = !user.isBlocked;
    await _db
        .collection('users')
        .doc(user.id)
        .update({'isBlocked': newVal});

    final idx = users.indexWhere((u) => u.id == user.id);
    if (idx != -1) {
      final u = users[idx];
      users[idx] = UserModel(
        id: u.id,
        shopName: u.shopName,
        proprietorName: u.proprietorName,
        phone: u.phone,
        email: u.email,
        address: u.address,
        deliveryDay: u.deliveryDay,
        totalDue: u.totalDue,
        totalPayableToCustomer: u.totalPayableToCustomer,
        isBlocked: newVal,
        createdAt: u.createdAt,
      );
      users.refresh();
    }
  }

  Future<List<UserOrderModel>> fetchUserOrders(String userId) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('userOrders')
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((e) => UserOrderModel.fromFirestore(e))
        .toList();
  }

  Future<void> updateUser(String id, Map<String, dynamic> data) async {
    await _db.collection('users').doc(id).update(data);
  }

  Future<void> updateTotalDue(String userId, int newAmount) async {
    await _db
        .collection('users')
        .doc(userId)
        .update({'totalDue': newAmount});

    final idx = users.indexWhere((u) => u.id == userId);
    if (idx != -1) {
      final u = users[idx];
      users[idx] = UserModel(
        id: u.id,
        shopName: u.shopName,
        proprietorName: u.proprietorName,
        phone: u.phone,
        email: u.email,
        address: u.address,
        deliveryDay: u.deliveryDay,
        totalDue: newAmount,
        totalPayableToCustomer: u.totalPayableToCustomer,
        isBlocked: u.isBlocked,
        createdAt: u.createdAt,
      );
      users.refresh();
    }
  }

  // ---------- User Replaces ----------

  Future<List<UserReplaceModel>> fetchUserReplaces(String userId) async {
    final snap = await _db
        .collection('users')
        .doc(userId)
        .collection('replaces')
        .orderBy('createdAt', descending: true)
        .get();
    return snap.docs.map(UserReplaceModel.fromFirestore).toList();
  }

  /// Delegates to [ReplaceController] — handles stock, replaceCount & local cache
  Future<void> addUserReplace(
    String userId, {
    required String shopName,
    required String productName,
    required String productId,
    required int quantity,
    required String note,
    required DateTime date,
  }) =>
      Get.find<ReplaceController>().addReplace(
        userId: userId,
        shopName: shopName,
        productId: productId,
        productName: productName,
        quantity: quantity,
        note: note,
        date: date,
      );

  /// Delegates to [ReplaceController] — handles stock, replaceCount & local cache
  Future<void> deleteUserReplace(
    String userId,
    String replaceId,
    String productId,
    int quantity,
  ) =>
      Get.find<ReplaceController>().deleteReplace(
        replaceId: replaceId,
        userId: userId,
        productId: productId,
        quantity: quantity,
      );
}
