import 'package:cloud_firestore/cloud_firestore.dart';

class ProductModel {
  final String id;

  final String name;
  final String brandName;
  final String productCategory;
  final String productCode;
  final String productModel;
  final String productVideo;
  final String unit;
  final String warranty;

  final int purchasePrice;
  final int wholesalePrice;
  final int retailPrice;

  final int stock;
  final int pendingStock;
  final int totalSold;
  final int totalOrders;
  final int monthlySold;
  final int replaceCount;

  final bool isAvailable;
  final bool isHot;
  final bool isNew;

  final List<String> images;
  final List<String> productDetails;

  final Map<String, dynamic> quantityDiscount;

  final Timestamp? createdAt;

  ProductModel({
    required this.id,
    required this.name,
    required this.brandName,
    required this.productCategory,
    required this.productCode,
    required this.productModel,
    required this.productVideo,
    required this.unit,
    required this.warranty,
    required this.purchasePrice,
    required this.wholesalePrice,
    required this.retailPrice,
    required this.stock,
    required this.pendingStock,
    required this.totalSold,
    required this.totalOrders,
    required this.monthlySold,
    required this.replaceCount,
    required this.isAvailable,
    required this.isHot,
    required this.isNew,
    required this.images,
    required this.productDetails,
    required this.quantityDiscount,
    required this.createdAt,
  });

  /// 🔥 Firestore → ProductModel (100% safe)
  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data();
    if (data == null) {
      throw Exception('Product data is null');
    }

    final map = data as Map<String, dynamic>;

    return ProductModel(
      id: doc.id,

      name: map['name']?.toString() ?? '',
      brandName: map['brandName']?.toString() ?? '',
      productCategory: map['productCategory']?.toString() ?? '',
      productCode: map['productCode']?.toString() ?? '',
      productModel: map['productModel']?.toString() ?? '',
      productVideo: map['productVideo']?.toString() ?? '',
      unit: map['unit']?.toString() ?? '',
      warranty: map['warranty']?.toString() ?? '',

      purchasePrice: (map['purchasePrice'] as num?)?.toInt() ?? 0,
      wholesalePrice: (map['wholesalePrice'] as num?)?.toInt() ?? 0,
      retailPrice: (map['retailPrice'] as num?)?.toInt() ?? 0,

      stock: (map['stock'] as num?)?.toInt() ?? 0,
      pendingStock: (map['pendingStock'] as num?)?.toInt() ?? 0,
      totalSold: (map['totalSold'] as num?)?.toInt() ?? 0,
      totalOrders: (map['totalOrders'] as num?)?.toInt() ?? 0,
      monthlySold: (map['monthlySold'] as num?)?.toInt() ?? 0,
      replaceCount: (map['replaceCount'] as num?)?.toInt() ?? 0,

      isAvailable: map['isAvailable'] ?? false,
      isHot: map['isHot'] ?? false,
      isNew: map['isNew'] ?? false,

      images: (map['images'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],

      productDetails: (map['productDetails'] as List?)
              ?.map((e) => e.toString())
              .toList() ??
          [],

      quantityDiscount:
          (map['quantityDiscount'] as Map<String, dynamic>?) ?? {},

      createdAt: map['createdAt'] as Timestamp?,
    );
  }

  /// (Optional) Model → Firestore
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'brandName': brandName,
      'productCategory': productCategory,
      'productCode': productCode,
      'productModel': productModel,
      'productVideo': productVideo,
      'unit': unit,
      'warranty': warranty,
      'purchasePrice': purchasePrice,
      'wholesalePrice': wholesalePrice,
      'retailPrice': retailPrice,
      'stock': stock,
      'pendingStock': pendingStock,
      'totalSold': totalSold,
      'totalOrders': totalOrders,
      'monthlySold': monthlySold,
      'replaceCount': replaceCount,
      'isAvailable': isAvailable,
      'isHot': isHot,
      'isNew': isNew,
      'images': images,
      'productDetails': productDetails,
      'quantityDiscount': quantityDiscount,
      'createdAt': createdAt ?? FieldValue.serverTimestamp(),
    };
  }
}