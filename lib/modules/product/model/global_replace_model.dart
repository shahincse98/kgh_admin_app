import 'package:cloud_firestore/cloud_firestore.dart';

class GlobalReplaceModel {
  final String id;
  final String userId;
  final String shopName;
  final String productName;
  final String productId;
  final int quantity;
  final String note;
  final DateTime date;
  final DateTime? createdAt;

  GlobalReplaceModel({
    required this.id,
    required this.userId,
    required this.shopName,
    required this.productName,
    required this.productId,
    required this.quantity,
    required this.note,
    required this.date,
    this.createdAt,
  });

  factory GlobalReplaceModel.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    String shopName = '',
  }) {
    final data = doc.data();
    final userId = doc.reference.parent.parent?.id ?? '';
    return GlobalReplaceModel(
      id: doc.id,
      userId: userId,
      shopName: shopName,
      productName: (data['productName'] as String?) ?? '',
      productId: (data['productId'] as String?) ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      note: (data['note'] as String?) ?? '',
      date: (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }
}
