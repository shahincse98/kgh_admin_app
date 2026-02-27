import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String shopName;
  final String proprietorName;
  final String phone;
  final String email;
  final String address;
  final String deliveryDay;
  final int totalDue;
  final int totalPayableToCustomer;
  final Timestamp? createdAt;

  UserModel({
    required this.id,
    required this.shopName,
    required this.proprietorName,
    required this.phone,
    required this.email,
    required this.address,
    required this.deliveryDay,
    required this.totalDue,
    required this.totalPayableToCustomer,
    required this.createdAt,
  });

  factory UserModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;

    return UserModel(
      id: doc.id,
      shopName: map['shopName'] ?? '',
      proprietorName: map['proprietorName'] ?? '',
      phone: map['phone'] ?? '',
      email: map['email'] ?? '',
      address: map['address'] ?? '',
      deliveryDay: map['deliveryDay'] ?? '',
      totalDue: (map['totalDue'] as num?)?.toInt() ?? 0,
      totalPayableToCustomer:
          (map['totalPayableToCustomer'] as num?)?.toInt() ?? 0,
      createdAt: map['createdAt'] as Timestamp?,
    );
  }
}