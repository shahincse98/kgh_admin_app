import 'package:cloud_firestore/cloud_firestore.dart';

class StockInModel {
  final String id;
  final String productId;
  final String productName;
  final String image;
  final int quantity;
  final String source;
  final String note;
  final DateTime date;
  final DateTime createdAt;
  final String createdBy;

  StockInModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.image = '',
    required this.quantity,
    this.source = '',
    this.note = '',
    required this.date,
    required this.createdAt,
    this.createdBy = '',
  });

  factory StockInModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockInModel(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      image: data['image'] ?? '',
      quantity: (data['quantity'] ?? 0).toInt(),
      source: data['source'] ?? '',
      note: data['note'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
    );
  }
}
