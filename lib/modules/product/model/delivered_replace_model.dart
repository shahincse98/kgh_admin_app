import 'package:cloud_firestore/cloud_firestore.dart';

class DeliveredReplaceModel {
  final String id;
  final String userId;
  final String shopName;
  final String productName;
  final String productId;
  final int quantity;
  final String note;
  final DateTime deliveredAt;

  DeliveredReplaceModel({
    required this.id,
    required this.userId,
    required this.shopName,
    required this.productName,
    required this.productId,
    required this.quantity,
    required this.note,
    required this.deliveredAt,
  });

  factory DeliveredReplaceModel.fromDoc(
    QueryDocumentSnapshot<Map<String, dynamic>> doc, {
    String shopName = '',
  }) {
    final data = doc.data();
    final userId = doc.reference.parent.parent?.id ?? '';
    return DeliveredReplaceModel(
      id: doc.id,
      userId: userId,
      shopName: shopName,
      productName: (data['productName'] as String?) ?? '',
      productId: (data['productId'] as String?) ?? '',
      quantity: (data['quantity'] as num?)?.toInt() ?? 1,
      note: (data['note'] as String?) ?? '',
      deliveredAt:
          (data['deliveredAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
