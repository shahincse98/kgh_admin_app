import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../model/sr_payment_model.dart';

class SrController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final loading = false.obs;
  final selectedMonth = DateTime.now().obs;

  // Settings
  final commissionPercent = 6.0.obs;
  final monthlyFixedSalary = 0.0.obs;

  // Delivery stats
  final totalDeliveries = 0.obs;
  final totalRevenue = 0.0.obs;
  final commissionDue = 0.0.obs;
  final totalDue = 0.0.obs; // commissionDue + monthlyFixedSalary

  // Payments
  final payments = <SrPaymentModel>[].obs;
  final totalPaid = 0.0.obs;
  final balance = 0.0.obs; // totalDue - totalPaid (positive = still owed)

  @override
  void onInit() {
    super.onInit();
    loadData();
  }

  void prevMonth() {
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month - 1);
    loadData();
  }

  void nextMonth() {
    final m = selectedMonth.value;
    final next = DateTime(m.year, m.month + 1);
    final now = DateTime.now();
    if (next.year > now.year ||
        (next.year == now.year && next.month > now.month)) {
      return;
    }
    selectedMonth.value = next;
    loadData();
  }

  Future<void> loadData() async {
    loading.value = true;
    try {
      await Future.wait([
        _loadSettings(),
        _loadDeliveries(),
      ]);
      await _loadPayments();
      _calcBalance();
    } finally {
      loading.value = false;
    }
  }

  Future<void> _loadSettings() async {
    final doc =
        await _db.collection('admin_settings').doc('finance').get();
    final data = doc.data();
    commissionPercent.value =
        (data?['srCommissionPercent'] as num?)?.toDouble() ?? 6.0;
    monthlyFixedSalary.value =
        (data?['srMonthlyFixedSalary'] as num?)?.toDouble() ?? 0.0;
  }

  Future<void> _loadDeliveries() async {
    final m = selectedMonth.value;
    final start = DateTime(m.year, m.month);
    final end = DateTime(m.year, m.month + 1);

    // Fetch all delivered orders and filter in memory to avoid composite index
    final snap = await _db
        .collection('orders')
        .where('status', isEqualTo: 'delivered')
        .get();

    int count = 0;
    double revenue = 0;
    for (final doc in snap.docs) {
      final ts = doc.data()['createdAt'];
      if (ts is! Timestamp) continue;
      final dt = ts.toDate();
      if (dt.isBefore(start) || !dt.isBefore(end)) continue;
      count++;
      revenue += (doc.data()['totalAmount'] as num?)?.toDouble() ?? 0;
    }

    totalDeliveries.value = count;
    totalRevenue.value = revenue;
    commissionDue.value = revenue * (commissionPercent.value / 100.0);
    totalDue.value = commissionDue.value + monthlyFixedSalary.value;
  }

  Future<void> _loadPayments() async {
    final m = selectedMonth.value;
    final monthKey =
        '${m.year}-${m.month.toString().padLeft(2, '0')}';

    // Single equality filter – no composite index needed
    final snap = await _db
        .collection('sr_payments')
        .where('month', isEqualTo: monthKey)
        .get();

    // Sort by paidAt descending in memory
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final ta = (a.data()['paidAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        final tb = (b.data()['paidAt'] as Timestamp?)?.millisecondsSinceEpoch ?? 0;
        return tb.compareTo(ta);
      });

    payments.value = docs.map(SrPaymentModel.fromFirestore).toList();
    totalPaid.value = payments.fold(0.0, (s, p) => s + p.amount);
  }

  void _calcBalance() {
    balance.value = totalDue.value - totalPaid.value;
  }

  Future<void> recordPayment(
      {required double amount, required String note}) async {
    final m = selectedMonth.value;
    final monthKey =
        '${m.year}-${m.month.toString().padLeft(2, '0')}';

    await _db.collection('sr_payments').add({
      'month': monthKey,
      'amount': amount,
      'note': note,
      'paidAt': FieldValue.serverTimestamp(),
    });

    await _loadPayments();
    _calcBalance();
  }

  Future<void> deletePayment(String id) async {
    await _db.collection('sr_payments').doc(id).delete();
    payments.removeWhere((p) => p.id == id);
    totalPaid.value = payments.fold(0.0, (s, p) => s + p.amount);
    _calcBalance();
  }
}
