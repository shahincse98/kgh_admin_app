import 'package:cloud_firestore/cloud_firestore.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Customer-based monthly sales plan.
// Firestore collection: customer_sales_plans
// One document per month key, e.g. '2026-06'
// ─────────────────────────────────────────────────────────────────────────────

class CustomerPlanItem {
  final String userId;
  final String shopName;
  final String phone;
  final String address;
  final double targetAmount; // planned revenue in BDT

  const CustomerPlanItem({
    required this.userId,
    required this.shopName,
    required this.phone,
    this.address = '',
    required this.targetAmount,
  });

  Map<String, dynamic> toMap() => {
        'userId': userId,
        'shopName': shopName,
        'phone': phone,
        'address': address,
        'targetAmount': targetAmount,
      };

  factory CustomerPlanItem.fromMap(Map<String, dynamic> m) =>
      CustomerPlanItem(
        userId: m['userId'] ?? '',
        shopName: m['shopName'] ?? '',
        phone: m['phone'] ?? '',
        address: m['address'] ?? '',
        targetAmount:
            (m['targetAmount'] as num?)?.toDouble() ?? 0,
      );

  CustomerPlanItem copyWith({double? targetAmount}) =>
      CustomerPlanItem(
        userId: userId,
        shopName: shopName,
        phone: phone,
        address: address,
        targetAmount: targetAmount ?? this.targetAmount,
      );
}

class CustomerSalesPlan {
  final String month; // document ID, e.g. '2026-06'
  final DateTime? createdAt;
  final List<CustomerPlanItem> items;

  const CustomerSalesPlan({
    required this.month,
    this.createdAt,
    required this.items,
  });

  double get totalTarget =>
      items.fold(0, (s, i) => s + i.targetAmount);

  /// Display label: "জুন ২০২৬"
  String get displayMonth {
    final parts = month.split('-');
    if (parts.length != 2) return month;
    final y = int.tryParse(parts[0]) ?? 0;
    final m = int.tryParse(parts[1]) ?? 0;
    const names = [
      'জানুয়ারি', 'ফেব্রুয়ারি', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
      'জুলাই', 'আগস্ট', 'সেপ্টেম্বর', 'অক্টোবর', 'নভেম্বর',
      'ডিসেম্বর'
    ];
    if (m < 1 || m > 12) return month;
    return '${names[m - 1]} $y';
  }

  factory CustomerSalesPlan.fromFirestore(DocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final ca = d['createdAt'];
    return CustomerSalesPlan(
      month: doc.id,
      createdAt: ca is Timestamp ? ca.toDate() : null,
      items: (d['items'] as List?)
              ?.map((e) => CustomerPlanItem.fromMap(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'month': month,
        'createdAt': FieldValue.serverTimestamp(),
        'items': items.map((i) => i.toMap()).toList(),
      };
}

// ─── Legacy types kept so existing references don't break until removed ──────

class SalesPlanItem {
  final String productId;
  final String productName;
  final int targetQty;

  const SalesPlanItem({
    required this.productId,
    required this.productName,
    required this.targetQty,
  });

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'targetQty': targetQty,
      };

  factory SalesPlanItem.fromMap(Map<String, dynamic> m) => SalesPlanItem(
        productId: m['productId'] ?? '',
        productName: m['productName'] ?? '',
        targetQty: (m['targetQty'] as num?)?.toInt() ?? 0,
      );

  SalesPlanItem copyWith({int? targetQty}) => SalesPlanItem(
        productId: productId,
        productName: productName,
        targetQty: targetQty ?? this.targetQty,
      );
}

class SalesPlanModel {
  final String id;
  final String title;
  final String type; // 'monthly' | 'weekly'
  final String period; // '2026-05' or '2026-W22'
  final DateTime periodStart;
  final DateTime periodEnd;
  final String assignedTo; // 'all' or srId
  final String srName; // '' when assignedTo == 'all'
  final DateTime? createdAt;
  final List<SalesPlanItem> items;

  const SalesPlanModel({
    required this.id,
    required this.title,
    required this.type,
    required this.period,
    required this.periodStart,
    required this.periodEnd,
    required this.assignedTo,
    required this.srName,
    this.createdAt,
    required this.items,
  });

  int get totalTarget => items.fold(0, (s, i) => s + i.targetQty);

  String get displayPeriod {
    if (type == 'weekly') {
      final end = periodEnd.subtract(const Duration(days: 1));
      return '${_d(periodStart)} – ${_d(end)}';
    }
    const months = [
      'জানু', 'ফেব্রু', 'মার্চ', 'এপ্রিল', 'মে', 'জুন',
      'জুলাই', 'আগস্ট', 'সেপ্ট', 'অক্টো', 'নভে', 'ডিসে'
    ];
    return '${months[periodStart.month - 1]} ${periodStart.year}';
  }

  static String _d(DateTime d) =>
      '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';

  factory SalesPlanModel.fromFirestore(DocumentSnapshot doc) {
    final m = doc.data() as Map<String, dynamic>;
    final ps = m['periodStart'];
    final pe = m['periodEnd'];
    final ca = m['createdAt'];
    return SalesPlanModel(
      id: doc.id,
      title: m['title'] ?? '',
      type: m['type'] ?? 'monthly',
      period: m['period'] ?? '',
      periodStart: ps is Timestamp ? ps.toDate() : DateTime.now(),
      periodEnd: pe is Timestamp ? pe.toDate() : DateTime.now(),
      assignedTo: m['assignedTo'] ?? 'all',
      srName: m['srName'] ?? '',
      createdAt: ca is Timestamp ? ca.toDate() : null,
      items: (m['items'] as List?)
              ?.map((e) =>
                  SalesPlanItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toFirestore() => {
        'title': title,
        'type': type,
        'period': period,
        'periodStart': Timestamp.fromDate(periodStart),
        'periodEnd': Timestamp.fromDate(periodEnd),
        'assignedTo': assignedTo,
        'srName': srName,
        'createdAt': FieldValue.serverTimestamp(),
        'items': items.map((i) => i.toMap()).toList(),
      };
}
