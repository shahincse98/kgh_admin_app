import 'package:cloud_firestore/cloud_firestore.dart';

/// Tracks every replace item at the admin level:
///   - Received from customer
///   - Sent to supplier (for repair / exchange)
///   - Received back from supplier
///   - Repaired in-house
///   - Added back to stock (regular or replace)
class AdminReplaceModel {
  final String id;
  final String productId;
  final String productName;
  final int quantity;

  /// 'customer_in' | 'supplier_out' | 'supplier_in' | 'shop_repair'
  final String entryType;

  // Customer info (entryType == 'customer_in')
  final String customerId;      // UserModel.id from Firestore users collection
  final String customerName;    // shop name
  final String customerPhone;
  final String customerAddress;

  /// What the customer will receive back as replacement
  final String replaceProductId;
  final String replaceProductName;

  /// Has the replacement been handed back to the customer?
  final bool deliveredToCustomer;
  final DateTime? deliveredToCustomerAt;

  /// Customer resolution type: '' | 'product_replace' | 'money_deduct'
  final String customerResolutionType;

  /// Amount deducted from bill if customerResolutionType == 'money_deduct'
  final int deductionAmount;

  /// Price/value of the defective product the customer returned
  final int defectiveProductPrice;

  /// Price/value of the replacement product the customer receives
  final int replaceProductPrice;

  // Supplier info
  final String supplierId;
  final String supplierName;

  /// 'at_shop' | 'with_supplier' | 'resolved'
  final String status;

  /// 'at_shop' | 'supplier'  — current physical location
  final String currentLocation;

  /// '' | 'added_to_regular_stock' | 'added_to_replace_stock' | 'scrapped'
  final String resolution;

  final int resolvedQty;
  final DateTime? resolvedAt;
  final DateTime? sentToSupplierDate;

  final String note;
  final DateTime date;
  final DateTime createdAt;

  const AdminReplaceModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.entryType,
    this.customerId = '',
    required this.customerName,
    required this.customerPhone,
    this.customerAddress = '',
    this.replaceProductId = '',
    this.replaceProductName = '',
    this.deliveredToCustomer = false,
    this.deliveredToCustomerAt,
    this.customerResolutionType = '',
    this.deductionAmount = 0,
    this.defectiveProductPrice = 0,
    this.replaceProductPrice = 0,
    required this.supplierId,
    required this.supplierName,
    required this.status,
    required this.currentLocation,
    required this.resolution,
    required this.resolvedQty,
    this.resolvedAt,
    this.sentToSupplierDate,
    required this.note,
    required this.date,
    required this.createdAt,
  });

  factory AdminReplaceModel.fromDoc(
      QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final d = doc.data();
    return AdminReplaceModel(
      id: doc.id,
      productId: (d['productId'] as String?) ?? '',
      productName: (d['productName'] as String?) ?? '',
      quantity: (d['quantity'] as num?)?.toInt() ?? 1,
      entryType: (d['entryType'] as String?) ?? 'customer_in',
      customerId: (d['customerId'] as String?) ?? '',
      customerName: (d['customerName'] as String?) ?? '',
      customerPhone: (d['customerPhone'] as String?) ?? '',
      customerAddress: (d['customerAddress'] as String?) ?? '',
      replaceProductId: (d['replaceProductId'] as String?) ?? '',
      replaceProductName: (d['replaceProductName'] as String?) ?? '',
      deliveredToCustomer: (d['deliveredToCustomer'] as bool?) ?? false,
      deliveredToCustomerAt:
          (d['deliveredToCustomerAt'] as Timestamp?)?.toDate(),
      customerResolutionType:
          (d['customerResolutionType'] as String?) ?? '',
      deductionAmount: (d['deductionAmount'] as num?)?.toInt() ?? 0,
      defectiveProductPrice: (d['defectiveProductPrice'] as num?)?.toInt() ?? 0,
      replaceProductPrice: (d['replaceProductPrice'] as num?)?.toInt() ?? 0,
      supplierId: (d['supplierId'] as String?) ?? '',
      supplierName: (d['supplierName'] as String?) ?? '',
      status: (d['status'] as String?) ?? 'at_shop',
      currentLocation: (d['currentLocation'] as String?) ?? 'shop',
      resolution: (d['resolution'] as String?) ?? '',
      resolvedQty: (d['resolvedQty'] as num?)?.toInt() ?? 0,
      resolvedAt: (d['resolvedAt'] as Timestamp?)?.toDate(),
      sentToSupplierDate: (d['sentToSupplierDate'] as Timestamp?)?.toDate(),
      note: (d['note'] as String?) ?? '',
      date: (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
        'productId': productId,
        'productName': productName,
        'quantity': quantity,
        'entryType': entryType,
        'customerId': customerId,
        'customerName': customerName,
        'customerPhone': customerPhone,
        'customerAddress': customerAddress,
        'replaceProductId': replaceProductId,
        'replaceProductName': replaceProductName,
        'deliveredToCustomer': deliveredToCustomer,
        'deliveredToCustomerAt': deliveredToCustomerAt != null
            ? Timestamp.fromDate(deliveredToCustomerAt!)
            : null,
        'customerResolutionType': customerResolutionType,
        'deductionAmount': deductionAmount,
        'defectiveProductPrice': defectiveProductPrice,
        'replaceProductPrice': replaceProductPrice,
        'supplierId': supplierId,
        'supplierName': supplierName,
        'status': status,
        'currentLocation': currentLocation,
        'resolution': resolution,
        'resolvedQty': resolvedQty,
        'resolvedAt': resolvedAt != null ? Timestamp.fromDate(resolvedAt!) : null,
        'sentToSupplierDate': sentToSupplierDate != null
            ? Timestamp.fromDate(sentToSupplierDate!)
            : null,
        'note': note,
        'date': Timestamp.fromDate(DateTime(date.year, date.month, date.day)),
        'createdAt': FieldValue.serverTimestamp(),
      };

  bool get isAtShop => status == 'at_shop';
  bool get isWithSupplier => status == 'with_supplier';
  bool get isResolved => status == 'resolved';

  bool get hasCustomer =>
      customerId.isNotEmpty || customerName.isNotEmpty || customerPhone.isNotEmpty;
  bool get hasReplaceProduct => replaceProductName.isNotEmpty;

  /// Entry is waiting to be handed back to the customer
  bool get pendingCustomerDelivery =>
      hasCustomer && hasReplaceProduct && !deliveredToCustomer;

  String get customerResolutionLabel {
    switch (customerResolutionType) {
      case 'product_replace':
        return replaceProductName.isNotEmpty
            ? 'Replace: $replaceProductName'
            : 'Product Replace';
      case 'money_deduct':
        return deductionAmount > 0
            ? 'Money Deduct: ৳$deductionAmount'
            : 'Money Deduct';
      default:
        return 'Resolution Pending';
    }
  }

  bool get isCustomerResolved =>
      customerResolutionType == 'product_replace' ||
      customerResolutionType == 'money_deduct';

  String get entryTypeLabel {
    switch (entryType) {
      case 'customer_in':
        return 'কাস্টমার থেকে';
      case 'supplier_out':
        return 'সাপ্লাইয়ারে পাঠানো';
      case 'supplier_in':
        return 'সাপ্লাইয়ার ফেরত';
      case 'shop_repair':
        return 'দোকানে মেরামত';
      default:
        return entryType;
    }
  }

  String get statusLabel {
    switch (status) {
      case 'at_shop':
        return 'দোকানে আছে';
      case 'with_supplier':
        return 'সাপ্লাইয়ারে আছে';
      case 'resolved':
        return _resolutionLabel;
      default:
        return status;
    }
  }

  String get _resolutionLabel {
    switch (resolution) {
      case 'added_to_regular_stock':
        return 'রেগুলার স্টকে যোগ হয়েছে';
      case 'added_to_replace_stock':
        return 'রিপ্লেস স্টকে যোগ হয়েছে';
      case 'scrapped':
        return 'বাতিল করা হয়েছে';
      default:
        return 'সম্পন্ন';
    }
  }
}
