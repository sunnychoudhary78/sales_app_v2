import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_constants.dart';
import '../../../core/providers/network_providers.dart';
import 'models/product_model.dart';
import 'products_query_result.dart';

class ProductsRepository {
  final Dio _dio;
  ProductsRepository(this._dio);

  Future<List<String>> fetchCategories() async {
    final res = await _dio.get(ApiConstants.productCategories);
    final data = res.data;
    if (data is Map && data['data'] is List) {
      return (data['data'] as List)
          .whereType<Map>()
          .map((e) => (e['name'] ?? '').toString())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }

  /// Names for picker (legacy app loads up to 500 for autocomplete).
  Future<List<String>> fetchProductNames({int limit = 500}) async {
    final payload = {
      'page': 1,
      'limit': limit,
      'search': null,
      'columnFilters': null,
      'sort': {'key': 'product_name', 'dir': 'asc'},
    };
    final res = await _dio.post(ApiConstants.productsQuery, data: payload);
    final data = res.data;
    List rows = const [];
    if (data is Map && data['rows'] is List) {
      rows = data['rows'] as List;
    } else if (data is Map && data['data'] is List) {
      rows = data['data'] as List;
    } else if (data is Map &&
        data['data'] is Map &&
        (data['data'] as Map)['products'] is List) {
      rows = (data['data'] as Map)['products'] as List;
    }
    return rows
        .whereType<Map>()
        .map((e) => (e['product_name'] ?? e['productName'])?.toString().trim())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList();
  }

  Future<ProductsQueryResult> fetchProducts({
    required int page,
    required int limit,
    String? search,
    String? category,
  }) async {
    final payload = {
      'page': page,
      'limit': limit,
      'search': (search == null || search.trim().isEmpty) ? null : search.trim(),
      'columnFilters': (category == null || category.isEmpty)
          ? null
          : {
              'category': {'op': 'eq', 'value': category}
            },
      'sort': {'key': 'product_name', 'dir': 'asc'},
    };
    final res = await _dio.post(ApiConstants.productsQuery, data: payload);
    final data = res.data;
    List rows = const [];
    if (data is Map && data['rows'] is List) {
      rows = data['rows'] as List;
    } else if (data is Map && data['data'] is List) {
      rows = data['data'] as List;
    } else if (data is Map &&
        data['data'] is Map &&
        (data['data'] as Map)['products'] is List) {
      rows = (data['data'] as Map)['products'] as List;
    }
    var total = 0;
    var totalPages = 1;
    if (data is Map && data['meta'] is Map) {
      final meta = Map<String, dynamic>.from(data['meta'] as Map);
      total = int.tryParse('${meta['total']}') ?? 0;
      totalPages = int.tryParse(
            '${meta['totalPages'] ?? meta['total_pages'] ?? 1}',
          ) ??
          1;
    }
    final products = rows
        .whereType<Map>()
        .map((e) => ProductModel.fromJson(Map<String, dynamic>.from(e)))
        .toList();
    return ProductsQueryResult(
      products: products,
      total: total,
      totalPages: totalPages < 1 ? 1 : totalPages,
    );
  }

  Future<ProductModel> updateProduct(
    String id,
    Map<String, dynamic> payload,
  ) async {
    final res = await _dio.put(ApiConstants.productById(id), data: payload);
    final body = res.data;
    Map<String, dynamic>? prodJson;
    if (body is Map) {
      final d = body['data'];
      if (d is Map && d['product'] is Map) {
        prodJson = Map<String, dynamic>.from(d['product'] as Map);
      } else if (body['product'] is Map) {
        prodJson = Map<String, dynamic>.from(body['product'] as Map);
      }
    }
    if (prodJson != null) {
      return ProductModel.fromJson(prodJson);
    }
    throw Exception('Unexpected update response');
  }
}

final productsRepositoryProvider = Provider<ProductsRepository>((ref) {
  return ProductsRepository(ref.read(dioProvider));
});
