import 'package:cloud_firestore/cloud_firestore.dart';

class StockSnapshotReplaceItem {
  final String productName;
  final int quantity;

  const StockSnapshotReplaceItem({
    required this.productName,
    required this.quantity,
  });

  factory StockSnapshotReplaceItem.fromMap(Map<String, dynamic> map) {
    return StockSnapshotReplaceItem(
      productName: map['productName'] ?? '',
      quantity: (map['quantity'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'productName': productName,
        'quantity': quantity,
      };
}

class StockSnapshotItem {
  final String productId;
  final String name;
  final String category;
  final int stock;
  final bool isInternal;

  const StockSnapshotItem({
    required this.productId,
    required this.name,
    required this.category,
    required this.stock,
    required this.isInternal,
  });

  factory StockSnapshotItem.fromMap(Map<String, dynamic> map) {
    return StockSnapshotItem(
      productId: map['productId'] ?? '',
      name: map['name'] ?? '',
      category: map['category'] ?? '',
      stock: (map['stock'] as num?)?.toInt() ?? 0,
      isInternal: map['isInternal'] ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'name': name,
        'category': category,
        'stock': stock,
        'isInternal': isInternal,
      };
}

class StockSnapshotModel {
  final String id;
  final String label;
  final DateTime savedAt;
  final List<StockSnapshotItem> items;
  final List<StockSnapshotReplaceItem> replaceItems;

  StockSnapshotModel({
    required this.id,
    required this.label,
    required this.savedAt,
    required this.items,
    this.replaceItems = const [],
  });

  int get totalProducts => items.length;
  int get totalStock => items.fold(0, (s, i) => s + i.stock);
  int get regularTotal =>
      items.where((i) => !i.isInternal).fold(0, (s, i) => s + i.stock);
  int get internalTotal =>
      items.where((i) => i.isInternal).fold(0, (s, i) => s + i.stock);
  int get replaceTotal =>
      replaceItems.fold(0, (s, i) => s + i.quantity);

  factory StockSnapshotModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;
    final ts = map['savedAt'];
    return StockSnapshotModel(
      id: doc.id,
      label: map['label'] ?? '',
      savedAt: ts is Timestamp ? ts.toDate() : DateTime.now(),
      items: (map['items'] as List?)
              ?.map((e) =>
                  StockSnapshotItem.fromMap(Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
      replaceItems: (map['replaceItems'] as List?)
              ?.map((e) => StockSnapshotReplaceItem.fromMap(
                  Map<String, dynamic>.from(e as Map)))
              .toList() ??
          [],
    );
  }
}
