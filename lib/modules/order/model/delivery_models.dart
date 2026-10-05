/// Value types used by the order money/stock operations in OrderController.

/// Thrown when an order operation is refused (stale screen, missing order,
/// already processed, …). [message] is user-facing.
class OrderOpException implements Exception {
  final String message;
  OrderOpException(this.message);
  @override
  String toString() => message;
}

/// One replace line on an order.
///   money_deduct    — customer returns a defective unit, its value is
///                     credited to the customer (goes to the replace section)
///   product_replace — customer returns a defective unit and gets a new one
///                     right now (goes to the replace section, stock −qty)
///   replace_given   — a replacement unit is handed over (stock −qty)
class ReplaceLine {
  final String productId;
  final String productName;
  final int quantity;
  final String resolutionType;

  /// Total credit for the whole line (money_deduct only).
  final int deductionAmount;

  const ReplaceLine({
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.resolutionType,
    this.deductionAmount = 0,
  });

  bool get isMoneyDeduct => resolutionType == 'money_deduct';
  bool get createsReplaceEntry => resolutionType != 'replace_given';
  bool get takesStockOut =>
      resolutionType == 'product_replace' || resolutionType == 'replace_given';
}

/// One sales-return line (goes back to regular stock via a stock-in entry).
class ReturnLine {
  final String productId;
  final String productName;
  final String image;
  final int quantity;
  final num unitPrice;

  const ReturnLine({
    required this.productId,
    required this.productName,
    this.image = '',
    required this.quantity,
    required this.unitPrice,
  });

  num get total => unitPrice * quantity;
}

/// Order money fields after an operation, as written to Firestore.
class OrderMoneyState {
  final num paidAmount;
  final num discountAmount;
  final num deductionAmount;
  final num returnAmount;
  final int previousDue;
  final List<Map<String, dynamic>> payments;
  final List<Map<String, dynamic>> replaceItems;
  final List<Map<String, dynamic>> returnItems;
  final String paymentMethod;
  final String localMemo;

  /// Customer's totalDue after the operation; null when it was not touched.
  final int? newUserDue;

  /// Pending replace hand-overs that were skipped because another screen
  /// had already delivered them.
  final int skippedPendingReplaces;

  const OrderMoneyState({
    required this.paidAmount,
    required this.discountAmount,
    required this.deductionAmount,
    required this.returnAmount,
    required this.previousDue,
    required this.payments,
    required this.replaceItems,
    this.returnItems = const [],
    required this.paymentMethod,
    required this.localMemo,
    this.newUserDue,
    this.skippedPendingReplaces = 0,
  });
}
