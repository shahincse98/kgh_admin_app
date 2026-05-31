import 'package:cloud_firestore/cloud_firestore.dart';

class SupplierModel {
  final String id;
  final String shopName;
  final String ownerName;
  final String phone;
  final String address;
  final DateTime? createdAt;

  const SupplierModel({
    required this.id,
    required this.shopName,
    required this.ownerName,
    required this.phone,
    required this.address,
    this.createdAt,
  });

  factory SupplierModel.fromFirestore(
      DocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data()!;
    return SupplierModel(
      id: doc.id,
      shopName: (d['shopName'] as String?) ?? '',
      ownerName: (d['ownerName'] as String?) ?? '',
      phone: (d['phone'] as String?) ?? '',
      address: (d['address'] as String?) ?? '',
      createdAt: (d['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() => {
        'shopName': shopName,
        'ownerName': ownerName,
        'phone': phone,
        'address': address,
      };

  SupplierModel copyWith({
    String? shopName,
    String? ownerName,
    String? phone,
    String? address,
  }) =>
      SupplierModel(
        id: id,
        shopName: shopName ?? this.shopName,
        ownerName: ownerName ?? this.ownerName,
        phone: phone ?? this.phone,
        address: address ?? this.address,
        createdAt: createdAt,
      );
}
