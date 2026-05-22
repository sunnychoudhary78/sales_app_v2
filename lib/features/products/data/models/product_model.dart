class ProductModel {
  final String id;
  final String productId;
  final String productName;
  final String category;
  final String? unit;
  final num? traderRate;
  final num? industryRate;
  final bool isActive;

  const ProductModel({
    required this.id,
    required this.productId,
    required this.productName,
    required this.category,
    this.unit,
    this.traderRate,
    this.industryRate,
    required this.isActive,
  });

  factory ProductModel.fromJson(Map<String, dynamic> json) {
    return ProductModel(
      id: (json['id'] ?? '').toString(),
      productId: (json['product_id'] ?? '').toString(),
      productName: (json['product_name'] ?? '').toString(),
      category: (json['category'] ?? '').toString(),
      unit: json['unit']?.toString(),
      traderRate: json['trader_rate'] is num
          ? json['trader_rate'] as num
          : num.tryParse((json['trader_rate'] ?? '').toString()),
      industryRate: json['industry_rate'] is num
          ? json['industry_rate'] as num
          : num.tryParse((json['industry_rate'] ?? '').toString()),
      isActive: json['is_active'] == true || json['is_active']?.toString() == 'true',
    );
  }
}

