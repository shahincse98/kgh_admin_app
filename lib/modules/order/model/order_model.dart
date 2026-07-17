import 'package:cloud_firestore/cloud_firestore.dart';

class OrderItem {
  final String productId;
  final String productName;
  final String image;
  final int quantity;
  final num pricePerUnit;
  final num totalPrice;
  final num purchasePrice;

  OrderItem({
    required this.productId,
    required this.productName,
    required this.image,
    required this.quantity,
    required this.pricePerUnit,
    required this.totalPrice,
    this.purchasePrice = 0,
  });

  factory OrderItem.fromMap(Map<String, dynamic> map) {
    return OrderItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      image: map['image'] ?? '',
      quantity: (map['quantity'] ?? 0).toInt(),
      pricePerUnit: map['pricePerUnit'] ?? 0,
      totalPrice: map['totalPrice'] ?? 0,
      purchasePrice: map['purchasePrice'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'image': image,
        'quantity': quantity,
        'pricePerUnit': pricePerUnit,
        'totalPrice': totalPrice,
        'purchasePrice': purchasePrice,
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
  final String deliveryAssignedSrId;   // SR assigned to deliver this order
  final String deliveryAssignedSrName; // SR display name for delivery
  final String memoNumber;             // Memo/challan number for dispatch
  final DateTime? dispatchedAt;        // When products physically left warehouse
  final String dispatchedBy;           // UID of admin who dispatched
  final DateTime? deliveredAt;         // When the order was delivered to customer
  final String localMemo;              // Local memo number (e.g. 233)
  final num returnAmount;              // Total value of returned products
  final num deductionAmount;           // Total replace cash deduction
  final num discountAmount;            // Discount given at delivery
  final String paymentMethod;           // নগদ / বিকাশ / রকেট / SR হাতে
  final List<Map<String, dynamic>> payments; // Multiple payment entries [{amount, method}]
  final int previousDue;               // User's due at time of delivery
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
    this.deliveryAssignedSrId = '',
    this.deliveryAssignedSrName = '',
    this.memoNumber = '',
    this.dispatchedAt,
    this.dispatchedBy = '',
    this.deliveredAt,
    this.localMemo = '',
    this.returnAmount = 0,
    this.deductionAmount = 0,
    this.discountAmount = 0,
    this.paymentMethod = '',
    this.payments = const [],
    this.previousDue = 0,
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
      deliveryAssignedSrId: data['deliveryAssignedSrId'] ?? '',
      deliveryAssignedSrName: data['deliveryAssignedSrName'] ?? '',
      memoNumber: data['memoNumber'] ?? '',
      dispatchedAt: data['dispatchedAt'] is Timestamp
          ? (data['dispatchedAt'] as Timestamp).toDate()
          : null,
      dispatchedBy: data['dispatchedBy'] ?? '',
      deliveredAt: data['deliveredAt'] is Timestamp
          ? (data['deliveredAt'] as Timestamp).toDate()
          : null,
      localMemo: data['localMemo'] ?? '',
      returnAmount: data['returnAmount'] ?? 0,
      deductionAmount: data['deductionAmount'] ?? 0,
      discountAmount: data['discountAmount'] ?? 0,
      paymentMethod: data['paymentMethod'] ?? '',
      payments: (data['payments'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      previousDue: (data['previousDue'] as num?)?.toInt() ?? 0,
      userPhone: data['userPhone'] ?? data['orderedByPhone'] ?? '',
      items: (data['items'] as List? ?? [])
          .map((e) => OrderItem.fromMap(e))
          .toList(),
    );
  }
}