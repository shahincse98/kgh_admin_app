import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:get/get.dart';
import '../model/expense_model.dart';
import '../expense_categories.dart';
import '../../sales/model/day_summary.dart';

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

  /// Total per খাত (category), largest first.
  List<MapEntry<String, double>> get byCategory {
    final map = <String, double>{};
    for (final e in expenses) {
      map[e.category] = (map[e.category] ?? 0) + e.amount;
    }
    return map.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
  }

  Future<void> addExpense({
    required String category,
    required double amount,
    required String note,
    required DateTime date,
  }) async {
    final expDate = DateTime(date.year, date.month, date.day);
    // Keep the old type code too, for anything still reading it.
    final type = expenseTypeOf(category);
    final ref = await _db.collection('expenses').add({
      'type': type,
      'category': category,
      'amount': amount,
      'note': note,
      'date': Timestamp.fromDate(expDate),
      'createdAt': FieldValue.serverTimestamp(),
    });
    // Insert locally — avoid full Firestore re-fetch
    final newExpense = ExpenseModel(
      id: ref.id,
      type: type,
      category: category,
      amount: amount,
      note: note,
      date: expDate,
      createdAt: DateTime.now(),
    );
    expenses.insert(0, newExpense);
    await ExpenseCategories.remember(category);
  }

  Future<void> deleteExpense(String id) async {
    await _db.collection('expenses').doc(id).delete();
    expenses.removeWhere((e) => e.id == id);
  }
}
