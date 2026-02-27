import 'package:get/get.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../model/user_model.dart';
import '../model/user_order_model.dart';

class UserController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final users = <UserModel>[].obs;
  final loading = true.obs;

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
}