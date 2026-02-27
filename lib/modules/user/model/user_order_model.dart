import 'package:cloud_firestore/cloud_firestore.dart';

class UserOrderModel {
  final String id;
  final String status;
  final int totalAmount;
  final int totalItems;
  final int paidAmount;
  final Timestamp? createdAt;
  final List<dynamic> items;

  UserOrderModel({
    required this.id,
    required this.status,
    required this.totalAmount,
    required this.totalItems,
    required this.paidAmount,
    required this.createdAt,
    required this.items,
  });

  factory UserOrderModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;

    return UserOrderModel(
      id: doc.id,
      status: map['status'] ?? '',
      totalAmount: (map['totalAmount'] as num?)?.toInt() ?? 0,
      totalItems: (map['totalItems'] as num?)?.toInt() ?? 0,
      paidAmount: (map['paidAmount'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] as Timestamp?,
      items: map['items'] ?? [],
    );
  }
}