import 'package:cloud_firestore/cloud_firestore.dart';

class PurchaseEntryModel {
  final String id;
  final String productName;
  final String productId;
  final int quantity;
  final double unitPrice;
  final double totalAmount;
  final String supplier;
  final String note;
  final DateTime date;
  final DateTime createdAt;

  PurchaseEntryModel({
    required this.id,
    required this.productName,
    required this.productId,
    required this.quantity,
    required this.unitPrice,
    required this.totalAmount,
    required this.supplier,
    required this.note,
    required this.date,
    required this.createdAt,
  });

  factory PurchaseEntryModel.fromFirestore(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    return PurchaseEntryModel(
      id: doc.id,
      productName: (data['productName'] as String?) ?? '',
      productId: (data['productId'] as String?) ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 0,
      unitPrice: (data['unitPrice'] as num?)?.toDouble() ?? 0,
      totalAmount: (data['totalAmount'] as num?)?.toDouble() ?? 0,
      supplier: (data['supplier'] as String?) ?? '',
      note: (data['note'] as String?) ?? '',
      date: (data['date'] as Timestamp).toDate(),
      createdAt:
          (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
