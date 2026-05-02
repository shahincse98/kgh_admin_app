import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart' show Color, Colors;
import 'package:get/get.dart';
import '../model/sr_model.dart';
import '../model/sr_payment_model.dart';
import '../../user/model/user_model.dart';
import '../../user/controller/user_controller.dart';
import '../../../firebase_options.dart';

/// Per-SR monthly stats (computed after loading)
class SrMonthStats {
  final int totalDeliveries;
  final double totalRevenue;
  final double commissionDue;
  final double totalDue;      // salary + commission
  final double totalPaid;
  final double balance;       // totalDue - totalPaid
  final double totalDueFromCustomers; // total unpaid customer due assigned to this SR
  final double frozenAmount;  // salary frozen due to exceeding dueLimit
  final double netPayable;    // balance - frozenAmount

  const SrMonthStats({
    this.totalDeliveries = 0,
    this.totalRevenue = 0,
    this.commissionDue = 0,
    this.totalDue = 0,
    this.totalPaid = 0,
    this.balance = 0,
    this.totalDueFromCustomers = 0,
    this.frozenAmount = 0,
    this.netPayable = 0,
  });
}

class SrManagementController extends GetxController {
  final _db = FirebaseFirestore.instance;

  final srList = <SrModel>[].obs;
  final loading = true.obs;
  final searchText = ''.obs;

  @override
  void onInit() {
    super.onInit();
    fetchSrList();
  }

  Future<void> fetchSrList() async {
    loading.value = true;
    try {
      final snap = await _db.collection('sr_staff').orderBy('name').get();
      srList.value =
          snap.docs.map((e) => SrModel.fromFirestore(e)).toList();
    } finally {
      loading.value = false;
    }
  }

  List<SrModel> get filteredList {
    final q = searchText.value.trim().toLowerCase();
    if (q.isEmpty) return srList;
    return srList
        .where((s) =>
            s.name.toLowerCase().contains(q) || s.phone.contains(q))
        .toList();
  }

  // ── CRUD ──────────────────────────────────────────────────────────────────

  /// Creates a Firebase Auth account for the SR using a secondary app instance
  /// so the admin's active session is NOT interrupted.
  /// Returns the new user's UID, or throws on error.
  Future<String> _createAuthAccount(String email, String password) async {
    const secondaryAppName = 'sr_creation_app';

    // Initialize secondary app (or reuse existing)
    FirebaseApp? secondary;
    try {
      secondary = Firebase.app(secondaryAppName);
    } catch (_) {
      secondary = await Firebase.initializeApp(
        name: secondaryAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);
    try {
      final cred = await secondaryAuth.createUserWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );
      await secondaryAuth.signOut();
      return cred.user!.uid;
    } finally {
      // Keep the secondary app alive for re-use; do not delete it
    }
  }

  /// Updates Firebase Auth password for an SR. Uses secondary app instance.
  Future<void> _updateAuthPassword(
      String email, String oldPassword, String newPassword) async {
    // Re-authenticate via secondary app and update password
    const secondaryAppName = 'sr_creation_app';
    FirebaseApp? secondary;
    try {
      secondary = Firebase.app(secondaryAppName);
    } catch (_) {
      secondary = await Firebase.initializeApp(
        name: secondaryAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final secondaryAuth = FirebaseAuth.instanceFor(app: secondary);
    final cred = await secondaryAuth.signInWithEmailAndPassword(
      email: email.trim(),
      password: oldPassword,
    );
    await cred.user!.updatePassword(newPassword);
    await secondaryAuth.signOut();
  }

  Future<void> addSr(Map<String, dynamic> data,
      {required String password}) async {
    final email = (data['email'] as String? ?? '').trim();
    if (email.isEmpty) {
      Get.snackbar('ত্রুটি', 'SR এর ইমেইল আবশ্যক',
          snackPosition: SnackPosition.BOTTOM);
      return;
    }

    // Create Firebase Auth account
    late String uid;
    try {
      uid = await _createAuthAccount(email, password);
    } on FirebaseAuthException catch (e) {
      final msg = e.code == 'email-already-in-use'
          ? 'এই ইমেইল ইতিমধ্যে ব্যবহৃত হচ্ছে'
          : 'অ্যাকাউন্ট তৈরি ব্যর্থ: ${e.message}';
      Get.snackbar('ত্রুটি', msg,
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Color(0xFFDC2626),
          colorText: Colors.white);
      return;
    }

    data['uid'] = uid;
    data['createdAt'] = FieldValue.serverTimestamp();
    data['assignedShopIds'] ??= <String>[];
    data['callContactIds'] ??= <String>[];
    final ref = await _db.collection('sr_staff').doc(uid).set(data).then(
        (_) => _db.collection('sr_staff').doc(uid));
    final doc = await ref.get();
    srList.add(SrModel.fromFirestore(doc));
    srList.refresh();
    Get.snackbar('সফল', '${data['name']} এর অ্যাকাউন্ট তৈরি হয়েছে',
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Color(0xFF10B981),
        colorText: Colors.white);
  }

  Future<void> updateSr(String id, Map<String, dynamic> data) async {
    await _db.collection('sr_staff').doc(id).update(data);
    final idx = srList.indexWhere((s) => s.id == id);
    if (idx != -1) {
      final old = srList[idx];
      srList[idx] = SrModel(
        id: old.id,
        name: data['name'] ?? old.name,
        phone: data['phone'] ?? old.phone,
        email: data['email'] ?? old.email,
        monthlyFixedSalary: (data['monthlyFixedSalary'] as num?)
                ?.toDouble() ??
            old.monthlyFixedSalary,
        commissionPercent:
            (data['commissionPercent'] as num?)?.toDouble() ??
                old.commissionPercent,
        dueLimit:
            (data['dueLimit'] as num?)?.toDouble() ?? old.dueLimit,
        isActive: data['isActive'] as bool? ?? old.isActive,
        assignedShopIds:
            List<String>.from(data['assignedShopIds'] ?? old.assignedShopIds),
        callContactIds:
            List<String>.from(data['callContactIds'] ?? old.callContactIds),
        shopDeliveryDays: data['shopDeliveryDays'] != null
            ? Map<String, String>.from(data['shopDeliveryDays'])
            : old.shopDeliveryDays,
        uid: old.uid,
        createdAt: old.createdAt,
      );
      srList.refresh();
    }
  }

  /// Set a delivery day for a specific shop in an SR's assignment
  Future<void> setShopDeliveryDay(
      String srId, String shopId, String day) async {
    await _db
        .collection('sr_staff')
        .doc(srId)
        .update({'shopDeliveryDays.$shopId': day});
    final idx = srList.indexWhere((s) => s.id == srId);
    if (idx != -1) {
      final old = srList[idx];
      final updated = Map<String, String>.from(old.shopDeliveryDays)
        ..[shopId] = day;
      srList[idx] = SrModel(
        id: old.id,
        name: old.name,
        phone: old.phone,
        email: old.email,
        monthlyFixedSalary: old.monthlyFixedSalary,
        commissionPercent: old.commissionPercent,
        dueLimit: old.dueLimit,
        isActive: old.isActive,
        assignedShopIds: old.assignedShopIds,
        callContactIds: old.callContactIds,
        shopDeliveryDays: updated,
        uid: old.uid,
        createdAt: old.createdAt,
      );
      srList.refresh();
    }
  }

  /// Remove a shop's delivery day
  Future<void> removeShopDeliveryDay(String srId, String shopId) async {
    await _db
        .collection('sr_staff')
        .doc(srId)
        .update({'shopDeliveryDays.$shopId': FieldValue.delete()});
    final idx = srList.indexWhere((s) => s.id == srId);
    if (idx != -1) {
      final old = srList[idx];
      final updated = Map<String, String>.from(old.shopDeliveryDays)
        ..remove(shopId);
      srList[idx] = SrModel(
        id: old.id,
        name: old.name,
        phone: old.phone,
        email: old.email,
        monthlyFixedSalary: old.monthlyFixedSalary,
        commissionPercent: old.commissionPercent,
        dueLimit: old.dueLimit,
        isActive: old.isActive,
        assignedShopIds: old.assignedShopIds,
        callContactIds: old.callContactIds,
        shopDeliveryDays: updated,
        uid: old.uid,
        createdAt: old.createdAt,
      );
      srList.refresh();
    }
  }

  /// Admin resets an SR's login password using Firebase Admin-level operation.
  /// Since we store the SR doc ID == UID, we sign in as SR in secondary app
  /// with current password and update to new password.
  Future<bool> resetSrPassword({
    required SrModel sr,
    required String newPassword,
  }) async {
    if (sr.uid.isEmpty) {
      Get.snackbar('ত্রুটি', 'SR এর অ্যাকাউন্ট এখনো তৈরি হয়নি',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
    if (sr.email.isEmpty) {
      Get.snackbar('ত্রুটি', 'SR এর ইমেইল নেই',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }

    const secondaryAppName = 'sr_creation_app';
    FirebaseApp? secondary;
    try {
      secondary = Firebase.app(secondaryAppName);
    } catch (_) {
      secondary = await Firebase.initializeApp(
        name: secondaryAppName,
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }

    try {
      // Use sendPasswordResetEmail — works without knowing current password
      await FirebaseAuth.instance.sendPasswordResetEmail(email: sr.email);
      Get.snackbar(
          'পাসওয়ার্ড রিসেট লিংক পাঠানো হয়েছে',
          '${sr.email} এ একটি রিসেট লিংক পাঠানো হয়েছে',
          snackPosition: SnackPosition.BOTTOM,
          duration: const Duration(seconds: 5),
          backgroundColor: Color(0xFF0891B2),
          colorText: Colors.white);
      return true;
    } on FirebaseAuthException catch (e) {
      Get.snackbar('ত্রুটি', e.message ?? 'ব্যর্থ হয়েছে',
          snackPosition: SnackPosition.BOTTOM);
      return false;
    }
  }

  Future<void> toggleActive(SrModel sr) async {
    await updateSr(sr.id, {'isActive': !sr.isActive});
  }

  Future<void> deleteSr(String id) async {
    await _db.collection('sr_staff').doc(id).delete();
    srList.removeWhere((s) => s.id == id);
  }

  // ── Monthly stats for a single SR ─────────────────────────────────────────

  Future<SrMonthStats> loadMonthStats(SrModel sr, DateTime month) async {
    final start = DateTime(month.year, month.month);
    final end = DateTime(month.year, month.month + 1);

    // Delivered orders placed by this SR (orderedBy == sr uid or srId field)
    final ordersSnap = await _db
        .collection('orders')
        .where('status', isEqualTo: 'delivered')
        .get();

    int deliveries = 0;
    double revenue = 0;
    for (final doc in ordersSnap.docs) {
      final data = doc.data();
      final srId = data['srId'] ?? data['orderedBy'] ?? '';
      if (srId != sr.id) continue;
      final ts = data['createdAt'];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.isBefore(start) || !dt.isBefore(end)) continue;
      deliveries++;
      revenue += (data['totalAmount'] as num?)?.toDouble() ?? 0;
    }

    final commission = revenue * (sr.commissionPercent / 100.0);
    final totalDue = commission + sr.monthlyFixedSalary;

    // Payments this month
    final monthKey =
        '${month.year}-${month.month.toString().padLeft(2, '0')}';
    final paidSnap = await _db
        .collection('sr_payments')
        .where('srId', isEqualTo: sr.id)
        .where('month', isEqualTo: monthKey)
        .get();
    final totalPaid =
        paidSnap.docs.fold<double>(0, (s, d) => s + ((d.data()['amount'] as num?)?.toDouble() ?? 0));

    final balance = totalDue - totalPaid;

    // Total customer due for shops assigned to this SR
    double customerDueTotal = 0;
    try {
      final uc = Get.find<UserController>();
      for (final uid in sr.assignedShopIds) {
        final user = uc.users.firstWhereOrNull((u) => u.id == uid);
        if (user != null) {
          customerDueTotal += user.totalDue;
        }
      }
    } catch (_) {}

    // Frozen amount: if customer due exceeds limit, freeze the excess from SR salary
    final excess =
        (customerDueTotal - sr.dueLimit).clamp(0.0, double.infinity);
    final frozen = excess.clamp(0.0, balance);
    final netPayable = balance - frozen;

    return SrMonthStats(
      totalDeliveries: deliveries,
      totalRevenue: revenue,
      commissionDue: commission,
      totalDue: totalDue,
      totalPaid: totalPaid,
      balance: balance,
      totalDueFromCustomers: customerDueTotal,
      frozenAmount: frozen,
      netPayable: netPayable,
    );
  }

  // ── Payments ───────────────────────────────────────────────────────────────

  Future<List<SrPaymentModel>> loadPayments(
      String srId, String monthKey) async {
    final snap = await _db
        .collection('sr_payments')
        .where('srId', isEqualTo: srId)
        .where('month', isEqualTo: monthKey)
        .get();
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final ta =
            (a.data()['paidAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb =
            (b.data()['paidAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });
    return docs.map(SrPaymentModel.fromFirestore).toList();
  }

  Future<void> recordPayment(
      {required String srId,
      required String monthKey,
      required double amount,
      required String note}) async {
    await _db.collection('sr_payments').add({
      'srId': srId,
      'month': monthKey,
      'amount': amount,
      'note': note,
      'paidAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> deletePayment(String paymentId) async {
    await _db.collection('sr_payments').doc(paymentId).delete();
  }

  /// Update assigned shops or call contacts
  Future<void> updateAssignments(String srId,
      {List<String>? shopIds, List<String>? callIds}) async {
    final data = <String, dynamic>{};
    if (shopIds != null) data['assignedShopIds'] = shopIds;
    if (callIds != null) data['callContactIds'] = callIds;
    if (data.isNotEmpty) await updateSr(srId, data);
  }

  List<UserModel> getAssignedShops(SrModel sr) {
    try {
      final uc = Get.find<UserController>();
      return uc.users
          .where((u) => sr.assignedShopIds.contains(u.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<UserModel> getCallContacts(SrModel sr) {
    try {
      final uc = Get.find<UserController>();
      return uc.users
          .where((u) => sr.callContactIds.contains(u.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  List<UserModel> getUnassignedShops(SrModel sr) {
    try {
      final uc = Get.find<UserController>();
      return uc.users
          .where((u) => !sr.assignedShopIds.contains(u.id))
          .toList();
    } catch (_) {
      return [];
    }
  }

  // ── Visit logs ─────────────────────────────────────────────────────────────
  // key: "$srId/$shopId" → status string
  final _visitLogs = <String, String>{}.obs;

  /// Load today's visit logs for a given SR
  Future<void> loadVisitLogs(String srId) async {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final snap = await _db
        .collection('sr_visit_logs')
        .where('srId', isEqualTo: srId)
        .where('date', isEqualTo: dateKey)
        .get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final shopId = data['shopId'] as String? ?? '';
      final status = data['status'] as String? ?? '';
      if (shopId.isNotEmpty) {
        _visitLogs['$srId/$shopId'] = status;
      }
    }
    _visitLogs.refresh();
  }

  String? getVisitStatus(String srId, String shopId) =>
      _visitLogs['$srId/$shopId'];

  Future<void> setVisitStatus(
      String srId, String shopId, String status) async {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    // Upsert by composite ID
    final docId = '${srId}_${shopId}_$dateKey';
    await _db.collection('sr_visit_logs').doc(docId).set({
      'srId': srId,
      'shopId': shopId,
      'date': dateKey,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    _visitLogs['$srId/$shopId'] = status;
    _visitLogs.refresh();
  }
}
