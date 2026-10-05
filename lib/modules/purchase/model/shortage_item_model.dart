/// One order line behind a shortage (which shop needs how many).
class ShortageOrderLine {
  final String orderId;
  final String shopName;
  final int quantity;
  final String status;

  const ShortageOrderLine({
    required this.orderId,
    required this.shopName,
    required this.quantity,
    required this.status,
  });
}

class ShortageItem {
  final String productId;
  final String productName;
  final String brandName;
  final String productCode;
  final String unit;
  final int orderedQty;
  final int stockQty;
  final int shortQty;
  final int orderCount;

  /// Current purchase price, for the estimated cost of buying the shortage.
  final num purchasePrice;

  /// The orders that need this product.
  final List<ShortageOrderLine> lines;

  /// True when the product is no longer in the product list (deleted), so
  /// its stock is unknown — it is still shown, since it was ordered.
  final bool missingProduct;

  ShortageItem({
    required this.productId,
    required this.productName,
    required this.brandName,
    required this.productCode,
    required this.unit,
    required this.orderedQty,
    required this.stockQty,
    required this.shortQty,
    required this.orderCount,
    this.purchasePrice = 0,
    this.lines = const [],
    this.missingProduct = false,
  });

  /// What it costs to buy the missing quantity (0 when no purchase price).
  num get estimatedCost => purchasePrice * shortQty;

  String get displayName {
    final parts = <String>[];
    if (brandName.isNotEmpty) parts.add(brandName);
    if (productCode.isNotEmpty) parts.add(productCode);
    final suffix = parts.isNotEmpty ? ' (${parts.join(' • ')})' : '';
    return '$productName$suffix';
  }
}
