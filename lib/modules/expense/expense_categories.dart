import 'package:cloud_firestore/cloud_firestore.dart';

import '../sales/model/day_summary.dart';

/// Expense categories (খাত) shown in the add-expense dropdowns.
///
/// Custom categories and the last used one are kept in
/// `admin_settings/expense_categories`, so a category added once stays in the
/// list and the last used one is pre-selected next time.
class ExpenseCategories {
  ExpenseCategories._();

  static DocumentReference<Map<String, dynamic>> get _doc =>
      FirebaseFirestore.instance.collection('admin_settings').doc('expense_categories');

  /// Default + saved categories, and the one to pre-select.
  static Future<({List<String> items, String lastUsed})> load() async {
    final items = [...defaultExpenseCategories];
    var lastUsed = '';
    try {
      final d = (await _doc.get()).data();
      for (final c in (d?['items'] as List?) ?? const []) {
        final name = c.toString().trim();
        if (name.isNotEmpty && !items.contains(name)) items.add(name);
      }
      lastUsed = (d?['lastUsed'] ?? '').toString();
    } catch (_) {
      // Settings unreadable — the defaults still work.
    }
    if (!items.contains(lastUsed)) lastUsed = items.first;
    return (items: items, lastUsed: lastUsed);
  }

  /// Saves [category] into the list (if new) and as the default.
  /// The expense itself is already saved, so a failure here is ignored.
  static Future<void> remember(String category) async {
    try {
      await _doc.set({
        'items': FieldValue.arrayUnion([category]),
        'lastUsed': category,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }
}
