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

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'image': image,
        'quantity': quantity,
        'pricePerUnit': pricePerUnit,
        'totalPrice': totalPrice,
      };
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
  final String shopPhone;
  final String userId;         // Customer's user document ID
  final String orderedBy;      // UID of SR/admin who placed the order
  final String orderedByEmail; // Email of SR/admin who placed the order
  final String deliveredBySrId;     // SR doc ID that delivered this order
  final bool commissionConfirmed;   // Admin confirmed delivery for commission
  final DateTime? scheduledDeliveryDate; // Admin-set delivery date for SR
  String userPhone;            // resolved after load from users collection
  int userDue;                 // resolved after load from users collection

  OrderModel({
    required this.id,
    required this.createdAt,
    required this.items,
    required this.status,
    required this.totalAmount,
    required this.paidAmount,
    required this.shopName,
    required this.shopAddress,
    this.shopPhone = '',
    this.userId = '',
    this.orderedBy = '',
    this.orderedByEmail = '',
    this.deliveredBySrId = '',
    this.commissionConfirmed = false,
    this.scheduledDeliveryDate,
    this.userPhone = '',
    this.userDue = 0,
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
      shopPhone: data['shopPhone'] ?? data['phone'] ?? '',
      userId: data['userId'] ?? data['uid'] ?? '',
      orderedBy: data['orderedBy'] ?? '',
      orderedByEmail: data['orderedByEmail'] ?? '',
      deliveredBySrId: data['deliveredBySrId'] ?? '',
      commissionConfirmed: data['commissionConfirmed'] as bool? ?? false,
      scheduledDeliveryDate: data['scheduledDeliveryDate'] is Timestamp
          ? (data['scheduledDeliveryDate'] as Timestamp).toDate()
          : null,
      userPhone: data['userPhone'] ?? data['orderedByPhone'] ?? '',
      items: (data['items'] as List? ?? [])
          .map((e) => OrderItem.fromMap(e))
          .toList(),
    );
  }
}