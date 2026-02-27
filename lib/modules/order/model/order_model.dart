import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String productId;
  final String productName;
  final String image;
  final int quantity;
  final num pricePerUnit;
  final num totalPrice;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.image,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalPrice,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      image: map['image'] ?? '',
      quantity: (map['quantity'] ?? 0).toInt(),
      pricePerUnit: map['pricePerUnit'] ?? 0,
      totalPrice: map['totalPrice'] ?? 0,
    );
  }
}

class OrderModel {
  final String id;
  final DateTime createdAt;
  final List<OrderItem> items;
  final String status;
  final num totalAmount;
  final num paidAmount;
  final String shopName;
  final String shopAddress;

  OrderModel({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    required this.shopName,
    required this.shopAddress,
  });

  factory OrderModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return OrderModel(
      id: doc.id,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      status: (data['status'] ?? 'pending').toString().toLowerCase(),
      totalAmount: data['totalAmount'] ?? 0,
      paidAmount: data['paidAmount'] ?? 0,
      shopName: data['shopName'] ?? '',
      shopAddress: data['shopAddress'] ?? '',
      items: (data['items'] as List? ?? [])
          .map((e) => OrderItem.fromMap(e))
          .toList(),
    );
  }
}