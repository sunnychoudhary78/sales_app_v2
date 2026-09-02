import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:sales_tracking_v2/core/theme/app_theme_provider.dart';
import 'package:sales_tracking_v2/core/theme/theme_mode_provider.dart';

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
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
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

  Color _shade(Color color, double lightnessDelta) {
    final hsl = HSLColor.fromColor(color);
    final l = (hsl.lightness + lightnessDelta).clamp(0.0, 1.0);
    return hsl.withLightness(l).toColor();
  }

  Color _onColor(Color background) {
    return ThemeData.estimateBrightnessForColor(background) == Brightness.dark
        ? Colors.white
        : Colors.black;
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

    // Accent color comes straight from the user's chosen theme seed, and
    // light/dark from the theme mode provider — so this screen re-tints
    // itself immediately when either changes, regardless of how (or
    // whether) MaterialApp's own ColorScheme is wired to them.
    final accent = ref.watch(appThemeProvider);
    final mode = ref.watch(themeModeProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = mode == ThemeMode.dark ||
        (mode == ThemeMode.system && platformBrightness == Brightness.dark);
    final onAccent = _onColor(accent);
    final heroGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [
        _shade(accent, isDark ? -0.06 : 0.08),
        _shade(accent, isDark ? -0.18 : -0.06),
      ],
    );

    if (_searchCtrl.text != s.search) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _searchCtrl.text = s.search;
      });
    }

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppSideDrawer(),
      appBar: SalesGlassAppBar(
        title: 'Rate List',
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
                color: accent,
                onRefresh: () => n.fetchProducts(resetPage: true),
                child: CustomScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  slivers: [
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                        child: Container(
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            gradient: heroGradient,
                            borderRadius: BorderRadius.circular(24),
                            // boxShadow: [
                            //   BoxShadow(
                            //     color: accent.withValues(alpha: 0.35),
                            //     blurRadius: 20,
                            //     offset: const Offset(0, 10),
                            //   ),
                            // ],
                          ),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              Positioned(
                                right: -10,
                                top: -10,
                                child: Icon(
                                  Icons.description_rounded,
                                  size: 90,
                                  color: onAccent.withValues(alpha: 0.14),
                                ),
                              ),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: onAccent.withValues(alpha: 0.18),
                                      borderRadius: BorderRadius.circular(16),
                                    ),
                                    child: Icon(Icons.insert_chart_rounded, color: onAccent, size: 26),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Trader & Industry Rates',
                                          style: TextStyle(
                                            color: onAccent,
                                            fontSize: 19,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          'Search, filter by category, compare columns, and page through results.',
                                          style: TextStyle(
                                            color: onAccent.withValues(alpha: 0.9),
                                            fontSize: 13,
                                            height: 1.35,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    if (_filtersExpanded)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: isDark ? 0.2 : 0.05),
                                  blurRadius: 14,
                                  offset: const Offset(0, 6),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Find products',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Search applies on the server when you run search.',
                                  style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
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
                                          hint: 'Search by name, product, code…',
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
                                    Material(
                                      color: accent,
                                      borderRadius: BorderRadius.circular(14),
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(14),
                                        onTap: () {
                                          n.setSearch(_searchCtrl.text);
                                          n.fetchProducts(resetPage: true);
                                        },
                                        child: Padding(
                                          padding: const EdgeInsets.all(15),
                                          child: Icon(Icons.search_rounded, color: onAccent),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  children: [
                                    Expanded(
                                      child: _FilterLabelled(
                                        label: 'Category',
                                        scheme: scheme,
                                        child: DropdownButtonFormField<String>(
                                          initialValue: s.category.isEmpty ? null : s.category,
                                          isExpanded: true,
                                          icon: const Icon(Icons.keyboard_arrow_down_rounded),
                                          decoration: _fieldDec(scheme, icon: Icons.grid_view_rounded),
                                          hint: const Text('Any Category'),
                                          items: [
                                            const DropdownMenuItem(value: '', child: Text('Any Category')),
                                            ...s.categories.map(
                                              (c) => DropdownMenuItem(
                                                value: c,
                                                child: Text(c, overflow: TextOverflow.ellipsis),
                                              ),
                                            ),
                                          ],
                                          onChanged: (v) {
                                            n.setCategory(v ?? '');
                                            n.fetchProducts(resetPage: true);
                                          },
                                        ),
                                      ),
                                    ),
                                    if (showTrader && showIndustry) ...[
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: _FilterLabelled(
                                          label: 'Rate column',
                                          scheme: scheme,
                                          child: _RateTypePill(
                                            scheme: scheme,
                                            accent: accent,
                                            onAccent: onAccent,
                                            value: s.rateType,
                                            onChanged: n.setRateType,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
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
                        child: _EmptyProductsState(
                          scheme: scheme,
                          accent: accent,
                          onRefresh: () => n.fetchProducts(resetPage: true),
                        ),
                      )
                    else ...[
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _TableHeader(
                            scheme: scheme,
                            accent: accent,
                            onAccent: onAccent,
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
                            final rateColor = s.rateType == 'trader'
                                ? _shade(accent, isDark ? 0.1 : -0.05)
                                : accent;

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
                                          p.productId.isEmpty ? '—' : p.productId,
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
                                              ? '—'
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
                                          icon: Icon(Icons.edit_outlined, size: 20, color: accent),
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
                            'Rows per page',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10),
                            decoration: BoxDecoration(
                              border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.6)),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: DropdownButton<int>(
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
                          ),
                        ],
                      ),
                      const Spacer(),
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(foregroundColor: accent),
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
                        style: OutlinedButton.styleFrom(foregroundColor: accent),
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

class _FilterLabelled extends StatelessWidget {
  const _FilterLabelled({
    required this.label,
    required this.scheme,
    required this.child,
  });

  final String label;
  final ColorScheme scheme;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _RateTypePill extends StatelessWidget {
  const _RateTypePill({
    required this.scheme,
    required this.accent,
    required this.onAccent,
    required this.value,
    required this.onChanged,
  });

  final ColorScheme scheme;
  final Color accent;
  final Color onAccent;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: _pillSegment(
              context,
              label: 'Industry',
              icon: Icons.factory_outlined,
              selected: value == 'industry',
              onTap: () => onChanged('industry'),
            ),
          ),
          Expanded(
            child: _pillSegment(
              context,
              label: 'Trader',
              icon: Icons.storefront_outlined,
              selected: value == 'trader',
              onTap: () => onChanged('trader'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _pillSegment(
    BuildContext context, {
    required String label,
    required IconData icon,
    required bool selected,
    required VoidCallback onTap,
  }) {
    return Material(
      color: selected ? accent : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 16,
                color: selected ? onAccent : scheme.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: selected ? onAccent : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyProductsState extends StatelessWidget {
  const _EmptyProductsState({
    required this.scheme,
    required this.accent,
    required this.onRefresh,
  });

  final ColorScheme scheme;
  final Color accent;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 120,
              height: 120,
              // decoration: BoxDecoration(
              //   color: accent.withValues(alpha: 0.10),
              //   shape: BoxShape.circle,
              // ),
              child: Image.asset(
                'assets/empty_box.png',
                width: 55,
                height: 55,
                color: accent.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No products found',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              'Try another search, category, or pull to refresh.',
              textAlign: TextAlign.center,
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 18),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: accent,
                side: BorderSide(color: accent.withValues(alpha: 0.6)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              label: const Text('Refresh'),
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
    required this.accent,
    required this.onAccent,
    required this.rateType,
    required this.canEdit,
  });

  final ColorScheme scheme;
  final Color accent;
  final Color onAccent;
  final String rateType;
  final bool canEdit;

  @override
  Widget build(BuildContext context) {
    final rateLabel = rateType == 'trader' ? 'Trader rate' : 'Industry rate';
    return Container(
      decoration: BoxDecoration(
        color: accent,
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
                color: onAccent,
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
                color: onAccent,
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
                color: onAccent,
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