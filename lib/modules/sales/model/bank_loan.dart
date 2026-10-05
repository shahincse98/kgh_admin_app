import 'package:cloud_firestore/cloud_firestore.dart';

/// The business's bank loan: the total taken, and what is paid against it.
/// One trip to the bank usually pays two things at once — an instalment
/// (৮০০) that pays down the loan, and a savings deposit (১০০) that the
/// business keeps. Both are kept in their own collection so they never mix
/// with expenses: neither is a business cost, so both must stay out of the
/// profit figures.
class BankLoan {
  BankLoan._();

  static const collection = 'bank_installments';

  /// The savings part of one deposit: money kept at the bank, so it does
  /// not lower the loan.
  static num savingsOf(Map<String, dynamic> d) => (d['savings'] as num?) ?? 0;

  /// The part that pays down the loan. Entries saved before savings were
  /// recorded put their whole amount into the loan.
  static num installmentOf(Map<String, dynamic> d) {
    final i = d['installment'];
    if (i is num) return i;
    return (((d['amount'] as num?) ?? 0) - savingsOf(d))
        .clamp(0, double.infinity);
  }

  /// All the cash that left the till for one deposit (instalment + savings).
  static num paidOf(Map<String, dynamic> d) {
    final a = d['amount'];
    if (a is num) return a;
    return installmentOf(d) + savingsOf(d);
  }

  static DocumentReference<Map<String, dynamic>> get _settings =>
      FirebaseFirestore.instance.collection('admin_settings').doc('bank_loan');

  /// Total loan amount the bank gave (set by the admin).
  static Future<num> totalAmount() async {
    try {
      final d = (await _settings.get()).data();
      return (d?['totalAmount'] as num?) ?? 0;
    } catch (_) {
      return 0;
    }
  }

  static Future<void> saveTotalAmount(num amount, {String note = ''}) async {
    await _settings.set({
      'totalAmount': amount,
      if (note.isNotEmpty) 'note': note,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Everything paid so far, split into the loan part (for "how much the
  /// bank is still owed") and the savings part (which only grows).
  static Future<({num installment, num savings})> paidSoFar() async {
    try {
      final snap =
          await FirebaseFirestore.instance.collection(collection).get();
      var installment = 0 as num;
      var savings = 0 as num;
      for (final d in snap.docs) {
        installment += installmentOf(d.data());
        savings += savingsOf(d.data());
      }
      return (installment: installment, savings: savings);
    } catch (_) {
      return (installment: 0, savings: 0);
    }
  }

  /// Loan total, instalments paid, what is left, and the savings built up.
  static Future<({num total, num paid, num outstanding, num savings})>
      status() async {
    final total = await totalAmount();
    final paid = await paidSoFar();
    return (
      total: total,
      paid: paid.installment,
      outstanding: total - paid.installment,
      savings: paid.savings,
    );
  }
}
