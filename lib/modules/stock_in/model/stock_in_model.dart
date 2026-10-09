import 'package:cloud_firestore/cloud_firestore.dart';

class StockInModel {
  final String id;
  final String productId;
  final String productName;
  final String image;
  final int quantity;
  final num unitPrice;
  final num totalPrice;
  final String source;
  final String note;
  final DateTime date;
  final DateTime createdAt;
  final String createdBy;

  /// An active entry's pieces are in the product's main stock; an inactive
  /// one stays on the list but is not counted. Entries saved before this
  /// field existed have no value and count as active.
  final bool active;

  StockInModel({
    required this.id,
    required this.productId,
    required this.productName,
    this.image = '',
    required this.quantity,
    this.unitPrice = 0,
    this.totalPrice = 0,
    this.source = '',
    this.note = '',
    required this.date,
    required this.createdAt,
    this.createdBy = '',
    this.active = true,
  });

  factory StockInModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return StockInModel(
      id: doc.id,
      productId: data['productId'] ?? '',
      productName: data['productName'] ?? '',
      image: data['image'] ?? '',
      quantity: (data['quantity'] ?? 0).toInt(),
      unitPrice: (data['unitPrice'] as num?) ?? 0,
      totalPrice: (data['totalPrice'] as num?) ?? 0,
      source: data['source'] ?? '',
      note: data['note'] ?? '',
      date: (data['date'] as Timestamp).toDate(),
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      createdBy: data['createdBy'] ?? '',
      active: data['active'] != false,
    );
  }

  StockInModel copyWith({DateTime? date, bool? active}) => StockInModel(
        id: id,
        productId: productId,
        productName: productName,
        image: image,
        quantity: quantity,
        unitPrice: unitPrice,
        totalPrice: totalPrice,
        source: source,
        note: note,
        date: date ?? this.date,
        createdAt: createdAt,
        createdBy: createdBy,
        active: active ?? this.active,
      );
}
