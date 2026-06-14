import 'package:cloud_firestore/cloud_firestore.dart';

class ManualStockOutItem {
  final String productId;
  final String productName;
  final String image;
  final int quantity;

  ManualStockOutItem({
    required this.productId,
    required this.productName,
    this.image = '',
    required this.quantity,
  });

  factory ManualStockOutItem.fromMap(Map<String, dynamic> map) {
    return ManualStockOutItem(
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      image: map['image'] ?? '',
      quantity: (map['quantity'] ?? 0).toInt(),
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'image': image,
        'quantity': quantity,
      };
}

class ManualStockOutReplaceAction {
  final String replaceEntryId;      // admin_replace_entries doc ID
  final String defectiveProductId;   // defective product's productId (to decrement replaceCount)
  final String defectiveProductName;
  final int defectiveQty;
  final String resolutionType;       // 'product_replace' or 'money_deduct'
  final String replaceProductId;     // if product_replace
  final String replaceProductName;   // if product_replace
  final int replaceQty;              // if product_replace
  final num deductionAmount;         // if money_deduct

  ManualStockOutReplaceAction({
    required this.replaceEntryId,
    this.defectiveProductId = '',
    required this.defectiveProductName,
    required this.defectiveQty,
    required this.resolutionType,
    this.replaceProductId = '',
    this.replaceProductName = '',
    this.replaceQty = 0,
    this.deductionAmount = 0,
  });

  factory ManualStockOutReplaceAction.fromMap(Map<String, dynamic> map) {
    return ManualStockOutReplaceAction(
      replaceEntryId: map['replaceEntryId'] ?? '',
      defectiveProductId: map['defectiveProductId'] ?? '',
      defectiveProductName: map['defectiveProductName'] ?? '',
      defectiveQty: (map['defectiveQty'] ?? 0).toInt(),
      resolutionType: map['resolutionType'] ?? '',
      replaceProductId: map['replaceProductId'] ?? '',
      replaceProductName: map['replaceProductName'] ?? '',
      replaceQty: (map['replaceQty'] ?? 0).toInt(),
      deductionAmount: map['deductionAmount'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() => {
        'replaceEntryId': replaceEntryId,
        'defectiveProductId': defectiveProductId,
        'defectiveProductName': defectiveProductName,
        'defectiveQty': defectiveQty,
        'resolutionType': resolutionType,
        'replaceProductId': replaceProductId,
        'replaceProductName': replaceProductName,
        'replaceQty': replaceQty,
        'deductionAmount': deductionAmount,
      };
}

class ManualStockOutModel {
  final String id;
  final DateTime createdAt;
  final DateTime stockOutDate;
  final String customerName;
  final String customerPhone;
  final String customerAddress;
  final String memoNumber;
  final String customerId;
  final List<ManualStockOutItem> items;
  final List<ManualStockOutReplaceAction> replaceActions;
  final String createdBy;

  ManualStockOutModel({
    required this.id,
    required this.createdAt,
    required this.stockOutDate,
    required this.customerName,
    this.customerPhone = '',
    this.customerAddress = '',
    this.memoNumber = '',
    this.customerId = '',
    required this.items,
    this.replaceActions = const [],
    this.createdBy = '',
  });

  bool get hasReplaces => replaceActions.isNotEmpty;

  factory ManualStockOutModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return ManualStockOutModel(
      id: doc.id,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      stockOutDate: data['stockOutDate'] is Timestamp
          ? (data['stockOutDate'] as Timestamp).toDate()
          : (data['createdAt'] as Timestamp).toDate(),
      customerName: data['customerName'] ?? '',
      customerPhone: data['customerPhone'] ?? '',
      customerAddress: data['customerAddress'] ?? '',
      memoNumber: data['memoNumber'] ?? '',
      customerId: data['customerId'] ?? '',
      items: (data['items'] as List? ?? [])
          .map((e) => ManualStockOutItem.fromMap(e))
          .toList(),
      replaceActions: (data['replaceActions'] as List? ?? [])
          .map((e) => ManualStockOutReplaceAction.fromMap(e))
          .toList(),
      createdBy: data['createdBy'] ?? '',
    );
  }
}
