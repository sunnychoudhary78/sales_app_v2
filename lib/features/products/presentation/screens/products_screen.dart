import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/utils/permission_utils.dart';
import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../../shared/widgets/screen_accent_backdrop.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../providers/products_provider.dart';
import '../widgets/product_edit_dialog.dart';

class ProductsScreen extends ConsumerStatefulWidget {
  const ProductsScreen({super.key});

  @override
  ConsumerState<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends ConsumerState<ProductsScreen> {
  final _searchCtrl = TextEditingController();
  bool _filtersExpanded = true;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  static final NumberFormat _rateFmt = NumberFormat('#,##0.##');

  String _sanitizeUnit(String? unit) {
    if (unit == null) return '';
    return unit.trim().replaceAll(RegExp(r'^/+'), '');
  }

  String _formatRate(num? rate, String? unit) {
    if (rate == null) return 'â€”';
    final u = _sanitizeUnit(unit);
    return '${_rateFmt.format(rate)}${u.isEmpty ? '' : '/$u'}';
  }

  InputDecoration _fieldDec(ColorScheme scheme, {String? hint, IconData? icon}) {
    return InputDecoration(
      hintText: hint,
      prefixIcon: icon == null ? null : Icon(icon, size: 22),
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: .5)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: .75)),
      ),
    );
  }

  Future<void> _openProductPicker() async {
    final n = ref.read(productsProvider.notifier);
    await n.loadProductNames();
    if (!mounted) return;
    final names = ref.read(productsProvider).productNames ?? const <String>[];
    final scheme = Theme.of(context).colorScheme;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (ctx) {
        var query = '';
        return StatefulBuilder(
          builder: (ctx, setSt) {
            final filtered = query.isEmpty
                ? names
                : names
                    .where((e) => e.toLowerCase().contains(query.toLowerCase()))
                    .toList();
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 16,
                top: 8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Jump to product',
                    style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    decoration: _fieldDec(scheme, hint: 'Type to filterâ€¦', icon: Icons.search_rounded),
                    onChanged: (v) => setSt(() => query = v),
                    autofocus: true,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: MediaQuery.of(ctx).size.height * 0.45,
                    child: ListView.separated(
                      itemCount: filtered.length + 1,
                      separatorBuilder: (context, index) =>
                          Divider(height: 1, color: scheme.outlineVariant),
                      itemBuilder: (_, i) {
                        if (i == 0) {
                          return ListTile(
                            title: const Text('Any product'),
                            leading: Icon(Icons.clear_all_rounded, color: scheme.primary),
                            onTap: () {
                              _searchCtrl.clear();
                              n.setSearch('');
                              Navigator.pop(ctx);
                              n.fetchProducts(resetPage: true);
                            },
                          );
                        }
                        final name = filtered[i - 1];
                        return ListTile(
                          title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () {
                            _searchCtrl.text = name;
                            n.setSearch(name);
                            Navigator.pop(ctx);
                            n.fetchProducts(resetPage: true);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(productsProvider);
    final n = ref.read(productsProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final raw = ref.watch(authProvider).rawUser;
    final showTrader = hasPermission(raw, 'product.read_trader_rate');
    final showIndustry = hasPermission(raw, 'product.read_industry_rate');
    final canEdit = hasPermission(raw, 'product.update') &&
        (showTrader || showIndustry);

    if (_searchCtrl.text != s.search) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchCtrl.text = s.search;
      });
    }

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppSideDrawer(),
      appBar: SalesGlassAppBar(
        title: 'Rate list',
        showDrawer: true,
        actions: [
          IconButton(
            tooltip: 'Pick product name',
            onPressed: _openProductPicker,
            icon: const Icon(Icons.playlist_add_check_rounded),
          ),
          IconButton(
            tooltip: 'Filters',
            onPressed: () => setState(() => _filtersExpanded = !_filtersExpanded),
            icon: Icon(
              _filtersExpanded ? Icons.filter_alt_off_rounded : Icons.filter_alt_rounded,
            ),
          ),
        ],
      ),
      body: ScreenAccentBackdrop(
        spot: DrawerRouteAccents.products,
        spot2: DrawerRouteAccents.productsSky,
        child: Column(
        children: [
          if (s.loadError != null)
            Material(
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                child: Row(
                  children: [
                    Icon(Icons.error_outline_rounded, color: scheme.onErrorContainer),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        s.loadError!,
                        style: TextStyle(color: scheme.onErrorContainer, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      onPressed: () => n.fetchProducts(resetPage: true),
                      icon: Icon(Icons.refresh_rounded, color: scheme.onErrorContainer),
                    ),
                  ],
                ),
              ),
            ),
          Expanded(
            child: RefreshIndicator(
              color: scheme.primary,
              onRefresh: () => n.fetchProducts(resetPage: true),
              child: CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(
                    child: PremiumFeatureHeader(
                      icon: Icons.payments_rounded,
                      title: 'Trader & industry rates',
                      subtitle:
                          'Search, filter by category, compare columns, and page through results â€” same data as the classic app.',
                    ),
                  ),
                  if (_filtersExpanded)
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                        child: PremiumCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              const PremiumSectionTitle(
                                title: 'Find products',
                                subtitle: 'Search applies on the server when you run search.',
                              ),
                              const SizedBox(height: 12),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _searchCtrl,
                                      decoration: _fieldDec(
                                        scheme,
                                        hint: 'Name containsâ€¦',
                                        icon: Icons.search_rounded,
                                      ),
                                      textInputAction: TextInputAction.search,
                                      onSubmitted: (_) {
                                        n.setSearch(_searchCtrl.text);
                                        n.fetchProducts(resetPage: true);
                                      },
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  FilledButton.tonal(
                                    onPressed: () {
                                      n.setSearch(_searchCtrl.text);
                                      n.fetchProducts(resetPage: true);
                                    },
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.all(16),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    child: const Icon(Icons.search_rounded),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Category',
                                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  ChoiceChip(
                                    label: const Text('Any'),
                                    selected: s.category.isEmpty,
                                    onSelected: (_) {
                                      n.setCategory('');
                                      n.fetchProducts(resetPage: true);
                                    },
                                  ),
                                  ...s.categories.map(
                                    (c) => ChoiceChip(
                                      label: Text(c, maxLines: 1, overflow: TextOverflow.ellipsis),
                                      selected: s.category == c,
                                      onSelected: (_) {
                                        n.setCategory(c);
                                        n.fetchProducts(resetPage: true);
                                      },
                                    ),
                                  ),
                                ],
                              ),
                              if (showTrader && showIndustry) ...[
                                const SizedBox(height: 16),
                                Text(
                                  'Rate column',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                SegmentedButton<String>(
                                  segments: const [
                                    ButtonSegment(
                                      value: 'industry',
                                      label: Text('Industry'),
                                      icon: Icon(Icons.factory_outlined, size: 18),
                                    ),
                                    ButtonSegment(
                                      value: 'trader',
                                      label: Text('Trader'),
                                      icon: Icon(Icons.storefront_outlined, size: 18),
                                    ),
                                  ],
                                  selected: {s.rateType},
                                  onSelectionChanged: (v) {
                                    n.setRateType(v.first);
                                  },
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),
                    ),
                  if (s.isLoading && s.products.isEmpty)
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (s.products.isEmpty)
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: PremiumEmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No products',
                        subtitle:
                            'Try another search, category, or pull to refresh.',
                      ),
                    )
                  else ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: _TableHeader(
                          scheme: scheme,
                          rateType: s.rateType,
                          canEdit: canEdit,
                        ),
                      ),
                    ),
                    SliverPadding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
                      sliver: SliverList.separated(
                        itemCount: s.products.length,
                        separatorBuilder: (context, index) =>
                            Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: 0.5)),
                        itemBuilder: (context, index) {
                          final p = s.products[index];
                          final rate = s.rateType == 'trader'
                              ? _formatRate(p.traderRate, p.unit)
                              : _formatRate(p.industryRate, p.unit);
                          final rateColor =
                              s.rateType == 'trader' ? scheme.tertiary : scheme.primary;

                          return Material(
                            color: index.isEven
                                ? scheme.surface
                                : scheme.surfaceContainerLow.withValues(alpha: 0.65),
                            child: InkWell(
                              onLongPress: canEdit
                                  ? () => showProductEditDialog(context, ref, p)
                                  : null,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 12,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 3,
                                      child: Text(
                                        p.productId.isEmpty ? 'â€”' : p.productId,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(
                                      flex: 5,
                                      child: Text(
                                        p.productName.trim().isEmpty
                                            ? 'â€”'
                                            : p.productName.trim(),
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12,
                                        ),
                                        maxLines: 3,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Expanded(
                                      flex: 3,
                                      child: Align(
                                        alignment: Alignment.centerRight,
                                        child: Text(
                                          rate,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 12,
                                            color: rateColor,
                                          ),
                                        ),
                                      ),
                                    ),
                                    if (canEdit)
                                      IconButton(
                                        tooltip: 'Edit',
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                          minWidth: 32,
                                          minHeight: 32,
                                        ),
                                        icon: Icon(Icons.edit_outlined, size: 20, color: scheme.primary),
                                        onPressed: () =>
                                            showProductEditDialog(context, ref, p),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          Material(
            elevation: 10,
            shadowColor: Colors.black26,
            color: scheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                child: Row(
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Rows',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 8),
                        DropdownButton<int>(
                          value: s.limit,
                          underline: const SizedBox.shrink(),
                          items: const [
                            DropdownMenuItem(value: 10, child: Text('10')),
                            DropdownMenuItem(value: 20, child: Text('20')),
                            DropdownMenuItem(value: 50, child: Text('50')),
                            DropdownMenuItem(value: 100, child: Text('100')),
                          ],
                          onChanged: s.isLoading
                              ? null
                              : (v) {
                                  if (v != null) n.setLimit(v);
                                },
                        ),
                      ],
                    ),
                    const Spacer(),
                    OutlinedButton(
                      onPressed: s.isLoading || s.page <= 1
                          ? null
                          : () => n.prevPage(),
                      child: const Text('Prev'),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '${s.page} / ${s.totalPages}',
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    ),
                    OutlinedButton(
                      onPressed: s.isLoading || s.page >= s.totalPages
                          ? null
                          : () => n.nextPage(),
                      child: const Text('Next'),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Total ${s.total}',
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  const _TableHeader({
    required this.scheme,
    required this.rateType,
    required this.canEdit,
  });

  final ColorScheme scheme;
  final String rateType;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final rateLabel = rateType == 'trader' ? 'Trader rate' : 'Industry rate';
    return Container(
      decoration: BoxDecoration(
        color: scheme.primary,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: Text(
              'Product ID',
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              'Product name',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              rateLabel,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: scheme.onPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          if (canEdit) const SizedBox(width: 36),
        ],
      ),
    );
  }
}
