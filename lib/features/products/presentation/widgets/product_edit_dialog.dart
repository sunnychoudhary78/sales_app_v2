import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/utils/permission_utils.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/product_model.dart';
import '../../data/products_repository.dart';
import '../providers/products_provider.dart';

String _sanitizeUnit(String? unit) {
  if (unit == null) return '';
  return unit.trim().replaceAll(RegExp(r'^/+'), '');
}

Future<void> showProductEditDialog(
  BuildContext context,
  WidgetRef ref,
  ProductModel product,
) async {
  final raw = ref.read(authProvider).rawUser;
  final canUpdate = hasPermission(raw, 'product.update');
  final canTrader = hasPermission(raw, 'product.read_trader_rate');
  final canIndustry = hasPermission(raw, 'product.read_industry_rate');
  if (!canUpdate || (!canTrader && !canIndustry)) return;

  final nameCtrl = TextEditingController(text: product.productName.trim());
  final traderCtrl = TextEditingController(
    text: product.traderRate?.toString() ?? '',
  );
  final industryCtrl = TextEditingController(
    text: product.industryRate?.toString() ?? '',
  );

  final scheme = Theme.of(context).colorScheme;

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Text(
        product.productName.trim().isEmpty ? 'Product' : product.productName.trim(),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              product.productId.isNotEmpty ? product.productId : '—',
              style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: 'Product name',
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            if (canTrader) ...[
              const SizedBox(height: 12),
              TextField(
                controller: traderCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText:
                      'Trader rate${_sanitizeUnit(product.unit).isEmpty ? '' : ' (${_sanitizeUnit(product.unit)})'}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
            if (canIndustry) ...[
              const SizedBox(height: 12),
              TextField(
                controller: industryCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText:
                      'Industry rate${_sanitizeUnit(product.unit).isEmpty ? '' : ' (${_sanitizeUnit(product.unit)})'}',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
        FilledButton(
          onPressed: () async {
            final payload = <String, dynamic>{};
            final newName = nameCtrl.text.trim();
            if (newName.isNotEmpty && newName != product.productName.trim()) {
              payload['product_name'] = newName;
            }
            if (canTrader) {
              final t = traderCtrl.text.trim();
              payload['trader_rate'] = t.isEmpty ? null : num.tryParse(t);
            }
            if (canIndustry) {
              final t = industryCtrl.text.trim();
              payload['industry_rate'] = t.isEmpty ? null : num.tryParse(t);
            }
            try {
              final updated = await ref
                  .read(productsRepositoryProvider)
                  .updateProduct(product.id, payload);
              await ref.read(productsProvider.notifier).replaceProduct(updated);
              if (ctx.mounted) Navigator.pop(ctx);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Product updated')),
                );
              }
            } on DioException catch (e) {
              final data = e.response?.data;
              final msg = data is Map && data['message'] != null
                  ? data['message'].toString()
                  : 'Update failed';
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text(msg)));
              }
            } catch (_) {
              if (ctx.mounted) {
                ScaffoldMessenger.of(ctx).showSnackBar(
                  const SnackBar(content: Text('Update failed')),
                );
              }
            }
          },
          child: const Text('Save'),
        ),
      ],
    ),
  );

  nameCtrl.dispose();
  traderCtrl.dispose();
  industryCtrl.dispose();
}
