import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../model/expense_model.dart';

class ExpenseController extends GetxController {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  final loading = false.obs;
  final expenses = <ExpenseModel>[].obs;
  final selectedMonth = DateTime.now().obs;

  @override
  void onInit() {
    super.onInit();
    loadExpenses();
  }

  Future<void> loadExpenses() async {
    loading.value = true;
    try {
      final m = selectedMonth.value;
      final start = DateTime(m.year, m.month);
      final end = DateTime(m.year, m.month + 1);

      final snap = await _db
          .collection('expenses')
          .where('date',
              isGreaterThanOrEqualTo: Timestamp.fromDate(start))
          .where('date', isLessThan: Timestamp.fromDate(end))
          .orderBy('date', descending: true)
          .get();

      expenses.value =
          snap.docs.map(ExpenseModel.fromFirestore).toList();
    } finally {
      loading.value = false;
    }
  }

  void prevMonth() {
    final m = selectedMonth.value;
    selectedMonth.value = DateTime(m.year, m.month - 1);
    loadExpenses();
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
    loadExpenses();
  }

  double get totalExpenses =>
      expenses.fold(0.0, (s, e) => s + e.amount);

  Map<String, double> get byType {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.type] = (map[e.type] ?? 0) + e.amount;
    }
    return map;
  }

  Future<void> addExpense({
    required String type,
    required double amount,
    required String note,
    required DateTime date,
  }) async {
    await _db.collection('expenses').add({
      'type': type,
      'amount': amount,
      'note': note,
      'date':
          Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
      'createdAt': FieldValue.serverTimestamp(),
    });
    await loadExpenses();
  }

  Future<void> deleteExpense(String id) async {
    await _db.collection('expenses').doc(id).delete();
    expenses.removeWhere((e) => e.id == id);
  }
}
