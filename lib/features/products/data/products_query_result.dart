import 'models/product_model.dart';

class ProductsQueryResult {
  final List<ProductModel> products;
  final int total;
  final int totalPages;

  const ProductsQueryResult({
    required this.products,
    required this.total,
    required this.totalPages,
  });
}
