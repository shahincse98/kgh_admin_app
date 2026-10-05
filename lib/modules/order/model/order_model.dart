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
  final List<Map<String, dynamic>> replaceItems; // Replace products given during delivery
  final List<Map<String, dynamic>> returnItems;  // Products the customer returned (sales return)
  final bool isDueCollection;          // True if this is a due collection entry (no products)
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
    this.replaceItems = const [],
    this.returnItems = const [],
    this.isDueCollection = false,
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
      replaceItems: (data['replaceItems'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      returnItems: (data['returnItems'] as List?)
              ?.map((e) => Map<String, dynamic>.from(e as Map))
              .toList() ??
          [],
      isDueCollection: data['isDueCollection'] as bool? ?? false,
      previousDue: (data['previousDue'] as num?)?.toInt() ?? 0,
      userPhone: data['userPhone'] ?? data['orderedByPhone'] ?? '',
      items: (data['items'] as List? ?? [])
          .map((e) => OrderItem.fromMap(e))
          .toList(),
    );
  }

  /// Sale after discount, replace credit and returns. Negative when more
  /// was credited back than this order was worth (see [OrderProfit]).
  num get netSales =>
      totalAmount - discountAmount - deductionAmount - returnAmount;

  /// The money side of this order; [fallbackCost] gives a product's current
  /// purchase price when the order did not store one.
  OrderProfit profitOf(num Function(String productId) fallbackCost) =>
      computeOrderProfit(
        totalAmount: totalAmount,
        discountAmount: discountAmount,
        deductionAmount: deductionAmount,
        returnAmount: returnAmount,
        items: [for (final i in items) i.toMap()],
        returnItems: returnItems,
        replaceItems: replaceItems,
        currentCost: fallbackCost,
      );

  num purchaseCost(num Function(String productId) fallbackCost) =>
      profitOf(fallbackCost).purchaseCost;

  num recoveredGoodsValue(num Function(String productId) fallbackCost) =>
      profitOf(fallbackCost).recovered;

  num profit(num Function(String productId) fallbackCost) =>
      profitOf(fallbackCost).profit;
}

num _num(dynamic v) => v is num ? v : 0;

List<Map<String, dynamic>> _maps(dynamic v) => (v as List? ?? const [])
    .whereType<Map>()
    .map((e) => Map<String, dynamic>.from(e))
    .toList();

/// The money side of one order, worked out the same way on every page that
/// shows profit:
///
///   profit = net sale − purchase cost of what was sold
///            + purchase value of the goods that came back
///
/// Returned products go back to stock, and a defective unit taken against a
/// replace credit (টাকা কাটা) is exchanged by the supplier, so their purchase
/// value is not a loss — only the money given above it is.
class OrderProfit {
  /// Sale after discount, replace credit and returns. Never cut off at zero:
  /// when the credit is larger than the order (e.g. a replace for a unit
  /// bought earlier), the difference is money the shop gave away.
  final num netSales;
  final num purchaseCost;

  /// Purchase value of the goods that came back.
  final num recovered;

  const OrderProfit({
    required this.netSales,
    required this.purchaseCost,
    required this.recovered,
  });

  num get profit => netSales - purchaseCost + recovered;
}

OrderProfit computeOrderProfit({
  required num totalAmount,
  required num discountAmount,
  required num deductionAmount,
  required num returnAmount,
  required List<Map<String, dynamic>> items,
  required List<Map<String, dynamic>> returnItems,
  required List<Map<String, dynamic>> replaceItems,
  required num Function(String productId) currentCost,
}) {
  // A unit is valued at the purchase price saved on this order's line for
  // the same product, so a unit swapped within one order nets out exactly.
  final savedCost = <String, num>{};
  num purchaseCost = 0;
  for (final i in items) {
    final id = (i['productId'] ?? '').toString();
    final qty = i['quantity'] is num ? i['quantity'] as num : 1;
    final saved = _num(i['purchasePrice']);
    if (saved > 0) savedCost[id] = saved;
    purchaseCost += (saved > 0 ? saved : currentCost(id)) * qty;
  }
  num costOf(String id) => savedCost[id] ?? currentCost(id);

  // Each line recovers at most what was credited for it.
  num lineValue(Map<String, dynamic> m, num credited) {
    final value = costOf((m['productId'] ?? '').toString()) * _num(m['quantity']);
    return credited > 0 && value > credited ? credited : value;
  }

  num fromReturns = 0;
  for (final r in returnItems) {
    fromReturns += lineValue(r, _num(r['totalPrice']));
  }
  num fromReplaces = 0;
  for (final m in replaceItems) {
    if ((m['resolutionType'] ?? '') != 'money_deduct') continue;
    fromReplaces += lineValue(m, _num(m['deductionAmount']));
  }
  // And never more than the credit the order itself records: a line whose
  // money never reached the order (older entries) cannot bring value back.
  num capped(num v, num credit) => v > credit ? (credit > 0 ? credit : 0) : v;

  return OrderProfit(
    netSales: totalAmount - discountAmount - deductionAmount - returnAmount,
    purchaseCost: purchaseCost,
    recovered: capped(fromReturns, returnAmount) +
        capped(fromReplaces, deductionAmount),
  );
}

/// [computeOrderProfit] for a raw Firestore order map.
OrderProfit orderProfitOf(
        Map<String, dynamic> o, num Function(String productId) currentCost) =>
    computeOrderProfit(
      totalAmount: _num(o['totalAmount']),
      discountAmount: _num(o['discountAmount']),
      deductionAmount: _num(o['deductionAmount']),
      returnAmount: _num(o['returnAmount']),
      items: _maps(o['items']),
      returnItems: _maps(o['returnItems']),
      replaceItems: _maps(o['replaceItems']),
      currentCost: currentCost,
    );
