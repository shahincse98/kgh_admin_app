import 'package:cloud_firestore/cloud_firestore.dart';

class UserReplaceModel {
  final String id;
  final String productName;
  final String productId;
  final int quantity;
  final String note;
  final DateTime date;

  UserReplaceModel({
    required this.id,
    required this.productName,
    required this.productId,
    required this.quantity,
    required this.note,
    required this.date,
  });

  factory UserReplaceModel.fromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return UserReplaceModel(
      id: doc.id,
      productName: (data['productName'] as String?) ?? '',
      productId: (data['productId'] as String?) ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      note: (data['note'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'productName': productName,
        'productId': productId,
        'quantity': quantity,
        'note': note,
        'date': Timestamp.fromDate(
            DateTime(date.year, date.month, date.day)),
        'createdAt': FieldValue.serverTimestamp(),
      };
}
