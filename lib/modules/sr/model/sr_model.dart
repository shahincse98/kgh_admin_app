import 'package:cloud_firestore/cloud_firestore.dart';

class SrModel {
  final String id;
  final String name;
  final String phone;
  final String email;
  final double monthlyFixedSalary;
  final double commissionPercent;
  final double dueLimit; // monthly due collection limit (টাকা)
  final bool isActive;

  // Assigned shops & contacts (user IDs from users collection)
  final List<String> assignedShopIds;   // দোকান ভিজিট তালিকা
  final List<String> callContactIds;    // কল করার তালিকা

  // Delivery days per shop: {shopId: 'রবিবার'}
  final Map<String, String> shopDeliveryDays;

  final String uid; // Firebase Auth UID (set when login account is created)
  final Timestamp? createdAt;

  SrModel({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    required this.monthlyFixedSalary,
    required this.commissionPercent,
    required this.dueLimit,
    this.isActive = true,
    this.assignedShopIds = const [],
    this.callContactIds = const [],
    this.shopDeliveryDays = const {},
    this.uid = '',
    this.createdAt,
  });

  factory SrModel.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    return SrModel(
      id: doc.id,
      name: d['name'] ?? '',
      phone: d['phone'] ?? '',
      email: d['email'] ?? '',
      monthlyFixedSalary: (d['monthlyFixedSalary'] as num?)?.toDouble() ?? 0,
      commissionPercent: (d['commissionPercent'] as num?)?.toDouble() ?? 6,
      dueLimit: (d['dueLimit'] as num?)?.toDouble() ?? 60000,
      isActive: d['isActive'] as bool? ?? true,
      assignedShopIds: List<String>.from(d['assignedShopIds'] ?? []),
      callContactIds: List<String>.from(d['callContactIds'] ?? []),
      shopDeliveryDays: Map<String, String>.from(d['shopDeliveryDays'] ?? {}),
      uid: d['uid'] as String? ?? '',
      createdAt: d['createdAt'] as Timestamp?,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'phone': phone,
        'email': email,
        'monthlyFixedSalary': monthlyFixedSalary,
        'commissionPercent': commissionPercent,
        'dueLimit': dueLimit,
        'isActive': isActive,
        'assignedShopIds': assignedShopIds,
        'callContactIds': callContactIds,
        'shopDeliveryDays': shopDeliveryDays,
        'uid': uid,
      };

  SrModel copyWith({
    String? name,
    String? phone,
    String? email,
    double? monthlyFixedSalary,
    double? commissionPercent,
    double? dueLimit,
    bool? isActive,
    List<String>? assignedShopIds,
    List<String>? callContactIds,
    Map<String, String>? shopDeliveryDays,
  }) {
    return SrModel(
      id: id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      monthlyFixedSalary: monthlyFixedSalary ?? this.monthlyFixedSalary,
      commissionPercent: commissionPercent ?? this.commissionPercent,
      dueLimit: dueLimit ?? this.dueLimit,
      isActive: isActive ?? this.isActive,
      assignedShopIds: assignedShopIds ?? this.assignedShopIds,
      callContactIds: callContactIds ?? this.callContactIds,
      shopDeliveryDays: shopDeliveryDays ?? this.shopDeliveryDays,
      createdAt: createdAt,
    );
  }
}
