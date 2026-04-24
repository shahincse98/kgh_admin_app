import 'package:cloud_firestore/cloud_firestore.dart';

class ExpenseModel {
  final String id;
  final String type; // rent | electricity | transport | salary | misc
  final double amount;
  final String note;
  final DateTime date;
  final DateTime createdAt;

  ExpenseModel({
    required this.id,
    required this.type,
    required this.amount,
    required this.note,
    required this.date,
    required this.createdAt,
  });

  factory ExpenseModel.fromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return ExpenseModel(
      id: doc.id,
      type: (data['type'] as String?) ?? 'misc',
      amount: (data['amount'] as num?)?.toDouble() ?? 0,
      note: (data['note'] as String?) ?? '',
      date: (data['date'] as Timestamp).toDate(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'type': type,
        'amount': amount,
        'note': note,
        'date': Timestamp.fromDate(
            DateTime(date.year, date.month, date.day)),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
