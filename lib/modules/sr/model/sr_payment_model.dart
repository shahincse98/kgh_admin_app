import 'package:cloud_firestore/cloud_firestore.dart';

class SrPaymentModel {
  final String id;
  final String month; // YYYY-MM
  final double amount;
  final String note;
  final DateTime? paidAt;

  SrPaymentModel({
    required this.id,
    required this.month,
    required this.amount,
    required this.note,
    this.paidAt,
  });

  factory SrPaymentModel.fromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return SrPaymentModel(
      id: doc.id,
      month: (data['month'] as String?) ?? '',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      note: (data['note'] as String?) ?? '',
      paidAt: (data['paidAt'] as Timestamp?)?.toDate(),
    );
  }
}
