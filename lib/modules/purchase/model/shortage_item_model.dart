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
  });

  String get displayName {
    final parts = <String>[];
    if (brandName.isNotEmpty) parts.add(brandName);
    if (productCode.isNotEmpty) parts.add(productCode);
    final suffix = parts.isNotEmpty ? ' (${parts.join(' • ')})' : '';
    return '$productName$suffix';
  }
}
