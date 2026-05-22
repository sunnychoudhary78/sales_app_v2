import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/permission_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/product_model.dart';
import '../../data/products_repository.dart';

class ProductsState {
  final bool isLoading;
  final List<ProductModel> products;
  final List<String> categories;
  final int page;
  final int limit;
  final String search;
  final String category;
  final String rateType;
  final int total;
  final int totalPages;
  final String? loadError;
  final List<String>? productNames;

  const ProductsState({
    required this.isLoading,
    required this.products,
    required this.categories,
    required this.page,
    required this.limit,
    required this.search,
    required this.category,
    required this.rateType,
    required this.total,
    required this.totalPages,
    this.loadError,
    this.productNames,
  });

  const ProductsState.initial()
      : this(
          isLoading: false,
          products: const [],
          categories: const [],
          page: 1,
          limit: 50,
          search: '',
          category: '',
          rateType: 'industry',
          total: 0,
          totalPages: 1,
          loadError: null,
          productNames: null,
        );

  ProductsState copyWith({
    bool? isLoading,
    List<ProductModel>? products,
    List<String>? categories,
    int? page,
    int? limit,
    String? search,
    String? category,
    String? rateType,
    int? total,
    int? totalPages,
    String? loadError,
    List<String>? productNames,
    bool clearLoadError = false,
    bool clearProductNames = false,
  }) {
    return ProductsState(
      isLoading: isLoading ?? this.isLoading,
      products: products ?? this.products,
      categories: categories ?? this.categories,
      page: page ?? this.page,
      limit: limit ?? this.limit,
      search: search ?? this.search,
      category: category ?? this.category,
      rateType: rateType ?? this.rateType,
      total: total ?? this.total,
      totalPages: totalPages ?? this.totalPages,
      loadError: clearLoadError ? null : (loadError ?? this.loadError),
      productNames:
          clearProductNames ? null : (productNames ?? this.productNames),
    );
  }
}

class ProductsNotifier extends Notifier<ProductsState> {
  @override
  ProductsState build() {
    _init();
    return const ProductsState.initial();
  }

  Future<void> _init() async {
    final repo = ref.read(productsRepositoryProvider);
    final cats = await repo.fetchCategories();
    state = state.copyWith(categories: cats);
    _applyDefaultRateType();
    await fetchProducts(resetPage: true);
  }

  void _applyDefaultRateType() {
    final raw = ref.read(authProvider).rawUser;
    final trader = hasPermission(raw, 'product.read_trader_rate');
    final industry = hasPermission(raw, 'product.read_industry_rate');
    String next = state.rateType;
    if (trader && !industry) {
      next = 'trader';
    } else if (industry && !trader) {
      next = 'industry';
    } else if (industry && trader) {
      if (next != 'trader' && next != 'industry') next = 'industry';
    }
    if (next != state.rateType) {
      state = state.copyWith(rateType: next);
    }
  }

  Future<void> fetchProducts({bool resetPage = false}) async {
    final repo = ref.read(productsRepositoryProvider);
    final page = resetPage ? 1 : state.page;
    state = state.copyWith(
      isLoading: true,
      page: page,
      clearLoadError: true,
    );
    try {
      final result = await repo.fetchProducts(
        page: page,
        limit: state.limit,
        search: state.search,
        category: state.category.isEmpty ? null : state.category,
      );
      state = state.copyWith(
        isLoading: false,
        products: result.products,
        total: result.total,
        totalPages: result.totalPages,
        page: page,
        clearLoadError: true,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        loadError: e.toString(),
      );
    }
  }

  Future<void> loadProductNames() async {
    if (state.productNames != null) return;
    try {
      final repo = ref.read(productsRepositoryProvider);
      final names = await repo.fetchProductNames();
      state = state.copyWith(productNames: names);
    } catch (_) {
      state = state.copyWith(productNames: const []);
    }
  }

  void setSearch(String value) {
    state = state.copyWith(search: value);
  }

  void setCategory(String value) {
    state = state.copyWith(category: value);
  }

  Future<void> setRateType(String value) async {
    state = state.copyWith(rateType: value);
    await fetchProducts(resetPage: true);
  }

  Future<void> setLimit(int value) async {
    if (value == state.limit) return;
    state = state.copyWith(limit: value);
    await fetchProducts(resetPage: true);
  }

  Future<void> nextPage() async {
    if (state.page >= state.totalPages) return;
    state = state.copyWith(page: state.page + 1);
    await fetchProducts(resetPage: false);
  }

  Future<void> prevPage() async {
    if (state.page <= 1) return;
    state = state.copyWith(page: state.page - 1);
    await fetchProducts(resetPage: false);
  }

  Future<void> replaceProduct(ProductModel updated) async {
    final list = state.products.map((p) => p.id == updated.id ? updated : p).toList();
    state = state.copyWith(products: list);
  }
}

final productsProvider = NotifierProvider<ProductsNotifier, ProductsState>(
  ProductsNotifier.new,
);
