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

  factory ProductModel.fromFirestore(DocumentSnapshot doc) {
    final map = doc.data() as Map<String, dynamic>;

    return ProductModel(
      id: doc.id,
      name: map['name'] ?? '',
      brandName: map['brandName'] ?? '',
      productCategory: map['productCategory'] ?? '',
      productCode: map['productCode'] ?? '',
      productModel: map['productModel'] ?? '',
      productVideo: map['productVideo'] ?? '',
      unit: map['unit'] ?? '',
      warranty: map['warranty'] ?? '',
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
      images: (map['images'] as List?)?.map((e) => e.toString()).toList() ?? [],
      productDetails:
          (map['productDetails'] as List?)?.map((e) => e.toString()).toList() ??
              [],
      quantityDiscount:
          (map['quantityDiscount'] as Map<String, dynamic>?) ?? {},
      createdAt: map['createdAt'] as Timestamp?,
    );
  }

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

  // 🔥 IMPORTANT: Local update support
  ProductModel copyWithMap(Map<String, dynamic> map) {
    return ProductModel(
      id: id,
      name: map['name'] ?? name,
      brandName: map['brandName'] ?? brandName,
      productCategory: map['productCategory'] ?? productCategory,
      productCode: map['productCode'] ?? productCode,
      productModel: map['productModel'] ?? productModel,
      productVideo: map['productVideo'] ?? productVideo,
      unit: map['unit'] ?? unit,
      warranty: map['warranty'] ?? warranty,
      purchasePrice: (map['purchasePrice'] as num?)?.toInt() ?? purchasePrice,
      wholesalePrice:
          (map['wholesalePrice'] as num?)?.toInt() ?? wholesalePrice,
      retailPrice: (map['retailPrice'] as num?)?.toInt() ?? retailPrice,
      stock: (map['stock'] as num?)?.toInt() ?? stock,
      pendingStock: (map['pendingStock'] as num?)?.toInt() ?? pendingStock,
      totalSold: (map['totalSold'] as num?)?.toInt() ?? totalSold,
      totalOrders: (map['totalOrders'] as num?)?.toInt() ?? totalOrders,
      monthlySold: (map['monthlySold'] as num?)?.toInt() ?? monthlySold,
      replaceCount: (map['replaceCount'] as num?)?.toInt() ?? replaceCount,
      isAvailable: map['isAvailable'] ?? isAvailable,
      isHot: map['isHot'] ?? isHot,
      isNew: map['isNew'] ?? isNew,
      images: map['images'] != null
          ? List<String>.from(map['images'])
          : images,
      productDetails: map['productDetails'] != null
          ? List<String>.from(map['productDetails'])
          : productDetails,
      quantityDiscount: map['quantityDiscount'] ?? quantityDiscount,
      createdAt: createdAt,
    );
  }
}