import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get/get.dart';
import '../../sr/model/sr_model.dart';
import '../../user/model/user_model.dart';
import '../../product/model/product_model.dart';
import '../../product/controller/product_controller.dart';
import '../../order/model/order_model.dart';

/// Cart item for SR panel order placement
class SrCartItem {
  final ProductModel product;
  int quantity;
  SrCartItem({required this.product, required this.quantity});
  num get total => product.wholesalePrice * quantity;
}

class SrPanelController extends GetxController {
  final _db = FirebaseFirestore.instance;

  // ── Identity ───────────────────────────────────────────────────────────────
  final Rxn<SrModel> srProfile = Rxn<SrModel>();
  final loading = true.obs;
  final String srDocId;

  SrPanelController({required this.srDocId});

  // ── Month nav ──────────────────────────────────────────────────────────────
  final selectedMonth = DateTime.now().obs;

  // ── Dashboard stats ────────────────────────────────────────────────────────
  final totalDeliveries = 0.obs;
  final totalRevenue = 0.0.obs;
  final commissionDue = 0.0.obs;
  final totalSalary = 0.0.obs;
  final totalDue = 0.0.obs;
  final totalPaid = 0.0.obs;
  final balance = 0.0.obs;
  final totalCustomerDue = 0.0.obs;
  final frozenAmount = 0.0.obs;
  final netPayable = 0.0.obs;

  // ── My Orders ──────────────────────────────────────────────────────────────
  final myOrders = <OrderModel>[].obs;
  final ordersLoading = false.obs;
  final loadingOrders = false.obs;

  // ── Customer dues ──────────────────────────────────────────────────────────
  final customerDues = <CustomerDueSummary>[].obs;
  final loadingDues = false.obs;

  // ── Customers ─────────────────────────────────────────────────────────────
  final assignedShops = <UserModel>[].obs;
  final callContacts = <UserModel>[].obs;

  // ── Place Order ────────────────────────────────────────────────────────────
  final orderStep = 0.obs;
  final Rxn<UserModel> selectedCustomer = Rxn<UserModel>();
  final productSearch = ''.obs;
  final cart = <SrCartItem>[].obs;

  @override
  void onInit() {
    super.onInit();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    loading.value = true;
    try {
      final doc = await _db.collection('sr_staff').doc(srDocId).get();
      if (!doc.exists) return;
      srProfile.value = SrModel.fromFirestore(doc);
      await _loadCustomers();
      await Future.wait([
        loadDashboard(),
        loadMyOrders(),
        loadDues(),
        loadVisitLogs(),
      ]);
    } finally {
      loading.value = false;
    }
  }

  Future<void> _loadCustomers() async {
    final sr = srProfile.value;
    if (sr == null) return;
    if (sr.assignedShopIds.isEmpty && sr.callContactIds.isEmpty) return;

    final allIds = {...sr.assignedShopIds, ...sr.callContactIds}.toList();
    // Fetch in batches of 10 (Firestore whereIn limit)
    final users = <UserModel>[];
    for (var i = 0; i < allIds.length; i += 10) {
      final batch = allIds.sublist(
          i, i + 10 > allIds.length ? allIds.length : i + 10);
      final snap = await _db
          .collection('users')
          .where(FieldPath.documentId, whereIn: batch)
          .get();
      users.addAll(snap.docs.map(UserModel.fromFirestore));
    }

    assignedShops.value =
        users.where((u) => sr.assignedShopIds.contains(u.id)).toList();
    callContacts.value =
        users.where((u) => sr.callContactIds.contains(u.id)).toList();
  }

  Future<void> loadDashboard() async {
    final sr = srProfile.value;
    if (sr == null) return;
    final m = selectedMonth.value;
    final start = DateTime(m.year, m.month);
    final end = DateTime(m.year, m.month + 1);

    final snap = await _db
        .collection('orders')
        .where('orderedBy', isEqualTo: srDocId)
        .where('status', isEqualTo: 'delivered')
        .get();

    int count = 0;
    double rev = 0;
    for (final doc in snap.docs) {
      final ts = doc.data()['createdAt'];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.isBefore(start) || !dt.isBefore(end)) continue;
      count++;
      rev += (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
    }

    totalDeliveries.value = count;
    totalRevenue.value = rev;
    commissionDue.value = rev * (sr.commissionPercent / 100);
    totalSalary.value = sr.monthlyFixedSalary;
    totalDue.value = commissionDue.value + totalSalary.value;

    final monthKey =
        '${m.year}-${m.month.toString().padLeft(2, '0')}';
    final paidSnap = await _db
        .collection('sr_payments')
        .where('srId', isEqualTo: srDocId)
        .where('month', isEqualTo: monthKey)
        .get();
    totalPaid.value = paidSnap.docs
        .fold(0.0, (s, d) => s + ((d.data()['amount'] as num?)?.toDouble() ?? 0));
    balance.value = totalDue.value - totalPaid.value;

    // Customer due sum
    double custDue = 0;
    for (final u in assignedShops) {
      custDue += u.totalDue;
    }
    totalCustomerDue.value = custDue;
    final excess = (custDue - sr.dueLimit).clamp(0.0, double.infinity);
    frozenAmount.value = excess.clamp(0.0, balance.value);
    netPayable.value = balance.value - frozenAmount.value;
  }

  Future<void> loadOrders() => loadMyOrders();

  Future<void> loadDues() async {
    loadingDues.value = true;
    try {
      final sr = srProfile.value;
      if (sr == null) return;
      final dues = <CustomerDueSummary>[];
      for (final u in assignedShops) {
        // Sum unpaid orders for this customer from this SR
        final snap = await _db
            .collection('orders')
            .where('userId', isEqualTo: u.id)
            .where('orderedBy', isEqualTo: srDocId)
            .where('status', whereNotIn: ['delivered', 'cancelled'])
            .get();
        num totalDue = 0;
        for (final doc in snap.docs) {
          final data = doc.data();
          final total = (data['totalAmount'] as num?) ?? 0;
          final paid = (data['paidAmount'] as num?) ?? 0;
          totalDue += (total - paid).clamp(0, double.infinity);
        }
        if (totalDue > 0) {
          dues.add(CustomerDueSummary(
            userId: u.id,
            shopName: u.shopName.isNotEmpty ? u.shopName : u.proprietorName,
            proprietorName: u.proprietorName,
            totalDue: totalDue,
            pendingOrders: snap.docs.length,
          ));
        }
      }
      customerDues.value = dues;
    } finally {
      loadingDues.value = false;
    }
  }

  Future<void> loadMyOrders() async {
    loadingOrders.value = true;
    ordersLoading.value = true;
    try {
      final snap = await _db
          .collection('orders')
          .where('orderedBy', isEqualTo: srDocId)
          .limit(50)
          .get();
      final orders = snap.docs.map(OrderModel.fromFirestore).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      myOrders.value = orders;
    } finally {
      ordersLoading.value = false;
      loadingOrders.value = false;
    }
  }

  void prevMonth() {
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month - 1);
    loadDashboard();
  }

  void nextMonth() {
    final m = selectedMonth.value;
    final next = DateTime(m.year, m.month + 1);
    final now = DateTime.now();
    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) return;
    selectedMonth.value = next;
    loadDashboard();
  }

  // ── Place Order helpers ────────────────────────────────────────────────────

  void addToCart(ProductModel p) {
    final idx = cart.indexWhere((c) => c.product.id == p.id);
    if (idx != -1) {
      cart[idx].quantity += 1;
      cart.refresh();
    } else {
      cart.add(SrCartItem(product: p, quantity: 1));
    }
  }

  void updateQty(String productId, int qty) {
    if (qty <= 0) {
      cart.removeWhere((c) => c.product.id == productId);
      return;
    }
    final idx = cart.indexWhere((c) => c.product.id == productId);
    if (idx != -1) {
      cart[idx].quantity = qty;
      cart.refresh();
    }
  }

  num get cartTotal =>
      cart.fold<num>(0, (s, c) => s + c.total);

  int get cartCount =>
      cart.fold<int>(0, (s, c) => s + c.quantity);

  final submitting = false.obs;
  final orderError = ''.obs;

  Future<bool> submitOrder(num paid, {DateTime? scheduledDate}) async {
    final cust = selectedCustomer.value;
    if (cust == null || cart.isEmpty) return false;
    submitting.value = true;
    orderError.value = '';
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
      final email = FirebaseAuth.instance.currentUser?.email ?? '';
      final orderData = <String, dynamic>{
        'userId': cust.id,
        'shopName': cust.shopName,
        'shopAddress': cust.address,
        'shopPhone': cust.phone,
        'srId': srDocId,
        'orderedBy': srDocId,
        'orderedByEmail': email,
        'orderedByUid': uid,
        'items': cart
            .map((c) => OrderItem(
                  productId: c.product.id,
                  productName: c.product.name,
                  image: c.product.images.isNotEmpty
                      ? c.product.images.first
                      : '',
                  quantity: c.quantity,
                  pricePerUnit: c.product.wholesalePrice,
                  totalPrice: c.total,
                ).toMap())
            .toList(),
        'totalAmount': cartTotal,
        'paidAmount': paid,
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      };
      if (scheduledDate != null) {
        orderData['scheduledDeliveryDate'] =
            Timestamp.fromDate(scheduledDate);
      }
      await _db.collection('orders').add(orderData);
      // Auto-set visit status to 'ordered' if this is an assigned shop
      final isAssigned = assignedShops.any((s) => s.id == cust.id);
      if (isAssigned) {
        await setVisitStatus(cust.id, 'ordered');
      }
      // Reset cart
      cart.clear();
      selectedCustomer.value = null;
      orderStep.value = 0;
      await loadMyOrders();
      return true;
    } catch (e) {
      orderError.value = 'অর্ডার করতে ব্যর্থ: $e';
      return false;
    } finally {
      submitting.value = false;
    }
  }

  void resetOrder() {
    cart.clear();
    selectedCustomer.value = null;
    orderStep.value = 0;
    orderError.value = '';
    productSearch.value = '';
  }

  // ── Visit status (today) ───────────────────────────────────────────────────
  /// key: shopId → status
  final visitLogs = <String, String>{}.obs;

  Future<void> loadVisitLogs() async {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final snap = await _db
        .collection('sr_visit_logs')
        .where('srId', isEqualTo: srDocId)
        .where('date', isEqualTo: dateKey)
        .get();
    for (final doc in snap.docs) {
      final data = doc.data();
      final shopId = data['shopId'] as String? ?? '';
      final status = data['status'] as String? ?? '';
      if (shopId.isNotEmpty) visitLogs[shopId] = status;
    }
    visitLogs.refresh();
  }

  Future<void> setVisitStatus(String shopId, String status) async {
    final today = DateTime.now();
    final dateKey =
        '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    final docId = '${srDocId}_${shopId}_$dateKey';
    await _db.collection('sr_visit_logs').doc(docId).set({
      'srId': srDocId,
      'shopId': shopId,
      'date': dateKey,
      'status': status,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    visitLogs[shopId] = status;
    visitLogs.refresh();
  }

  /// Remove a shop from this SR's assigned shops list
  Future<void> removeAssignedShop(String shopId) async {
    await _db.collection('sr_staff').doc(srDocId).update({
      'assignedShopIds': FieldValue.arrayRemove([shopId]),
    });
    assignedShops.removeWhere((u) => u.id == shopId);
  }
}

class CustomerDueSummary {
  final String userId;
  final String shopName;
  final String proprietorName;
  final num totalDue;
  final int pendingOrders;

  CustomerDueSummary({
    required this.userId,
    required this.shopName,
    required this.proprietorName,
    required this.totalDue,
    required this.pendingOrders,
  });
}
