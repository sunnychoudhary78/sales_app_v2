import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/utils/permission_utils.dart';
import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../../shared/widgets/screen_accent_backdrop.dart';
import '../../data/claims_repository.dart';
import '../providers/claims_provider.dart';

class ClaimRequestsScreen extends ConsumerWidget {
  const ClaimRequestsScreen({super.key});

  static final NumberFormat _inr = NumberFormat.currency(locale: 'en_IN', symbol: '₹');

  static String _money(dynamic v) {
    if (v == null) return '—';
    final n = num.tryParse(v.toString());
    if (n == null) return v.toString();
    return _inr.format(n);
  }

  /// API returns camelCase (`systemDistanceKm`, `userDistanceKm`); tolerate legacy keys.
  static double? _numField(Map<String, dynamic> r, List<String> keys) {
    for (final k in keys) {
      if (r[k] == null) continue;
      final n = num.tryParse(r[k].toString());
      if (n != null) return n.toDouble();
    }
    return null;
  }

  Future<void> _review(
    BuildContext context,
    WidgetRef ref, {
    required String claimId,
    required String action,
    String? managerRemarks,
    double? approvedDistanceKm,
  }) async {
    try {
      await ref.read(claimsRepositoryProvider).reviewRequest(
            claimId: claimId,
            action: action,
            managerRemarks: managerRemarks,
            approvedDistanceKm: approvedDistanceKm,
          );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Claim $action successfully')),
        );
      }
      ref.invalidate(managerClaimRequestsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Action failed: $e')),
        );
      }
    }
  }

  Future<void> _openReviewDialog(
    BuildContext context,
    WidgetRef ref, {
    required String claimId,
    required String action,
  }) async {
    final remarksCtrl = TextEditingController();
    final approvedKmCtrl = TextEditingController();
    final isReject = action == 'reject';

    final result = await showDialog<(String, double?)>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Text(isReject ? 'Reject claim' : 'Approve claim'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!isReject) ...[
                  TextField(
                    controller: approvedKmCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Approved distance (km), optional',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                ],
                TextField(
                  controller: remarksCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText:
                        isReject ? 'Rejection remarks (required)' : 'Manager remarks (optional)',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Cancel')),
            FilledButton(
              onPressed: () {
                final remarks = remarksCtrl.text.trim();
                if (isReject && remarks.isEmpty) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    const SnackBar(content: Text('Remarks are required for rejection')),
                  );
                  return;
                }
                final approvedKm = double.tryParse(approvedKmCtrl.text.trim());
                Navigator.of(ctx).pop((remarks, approvedKm));
              },
              child: Text(isReject ? 'Reject' : 'Approve'),
            ),
          ],
        );
      },
    );

    remarksCtrl.dispose();
    approvedKmCtrl.dispose();
    if (result == null) return;
    if (!context.mounted) return;
    await _review(
      context,
      ref,
      claimId: claimId,
      action: action,
      managerRemarks: result.$1,
      approvedDistanceKm: result.$2,
    );
  }

  Color _statusColor(ColorScheme scheme, String status) {
    final s = status.toLowerCase();
    if (s == 'disputed') return scheme.tertiary;
    if (s == 'approved') return scheme.primary;
    if (s == 'rejected') return scheme.error;
    return scheme.outline;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authProvider).rawUser;
    final roleObj = user == null ? null : user['role'];
    final roleName = ((roleObj is Map ? roleObj['name'] : user?['role_name'])
            ?.toString() ??
        '')
        .toLowerCase();
    final canAccess = roleName.contains('manager') ||
        hasPermission(user, 'claim.request.view') ||
        hasPermission(user, 'claim.view');

    final scheme = Theme.of(context).colorScheme;

    if (!canAccess) {
      return Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        drawer: const AppSideDrawer(),
        appBar: const SalesGlassAppBar(title: 'Claim requests', showDrawer: true),
        body: ScreenAccentBackdrop(
          spot: DrawerRouteAccents.claimRequests,
          spot2: DrawerRouteAccents.claimRequestsAmber,
          child: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: PremiumCard(
                child: Text(
                  'You do not have permission to view claim requests.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: scheme.onSurfaceVariant),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final requestsAsync = ref.watch(managerClaimRequestsProvider);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppSideDrawer(),
      appBar: const SalesGlassAppBar(
        title: 'Claim requests',
        showDrawer: true,
      ),
      body: ScreenAccentBackdrop(
        spot: DrawerRouteAccents.claimRequests,
        spot2: DrawerRouteAccents.claimRequestsAmber,
        child: RefreshIndicator(
        color: scheme.primary,
        onRefresh: () async => ref.refresh(managerClaimRequestsProvider.future),
        child: requestsAsync.when(
          loading: () => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: EdgeInsets.symmetric(
              vertical: MediaQuery.sizeOf(context).height * 0.3,
            ),
            children: [
              Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: scheme.primary,
                ),
              ),
            ],
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(24),
            children: [
              PremiumEmptyState(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load requests',
                subtitle: e.toString(),
              ),
            ],
          ),
          data: (rows) {
            if (rows.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  PremiumEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No claim requests',
                    subtitle:
                        'When your team submits or disputes a claim, it will show here for review.',
                  ),
                ],
              );
            }
            return CustomScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: PremiumFeatureHeader(
                    icon: Icons.approval_rounded,
                    title: 'Manager queue',
                    subtitle:
                        'Review disputed distance claims: system vs employee distance, amounts, and remarks. Pull down to refresh.',
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: rows.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final r = rows[i];
                      final id = (r['id'] ?? '').toString();
                      final u = r['user'] is Map ? (r['user'] as Map) : const {};
                      final name = (u['name'] ?? u['email'] ?? '-').toString();
                      final month = (r['monthKey'] ?? r['month_key'] ?? '-').toString();
                      final status = (r['status'] ?? '-').toString();
                      final amount = _money(r['amount'] ?? r['approvedAmount']);
                      final net = r['netAmount'] ?? r['net_amount'];
                      final systemKm = _numField(r, ['systemDistanceKm', 'system_distance_km']);
                      final userKm = _numField(r, [
                        'userDistanceKm',
                        'user_distance_km',
                        'correctedDistanceKm',
                      ]);
                      final employeeRemarks = (r['remarks'] ?? '').toString();
                      final st = status.toLowerCase();

                      return PremiumCard(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Expanded(
                                  child: Text(
                                    name,
                                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ),
                                PremiumStatusPill(
                                  label: status,
                                  color: _statusColor(scheme, status),
                                  icon: st == 'disputed'
                                      ? Icons.warning_amber_rounded
                                      : Icons.check_circle_outline_rounded,
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            _InfoRow(icon: Icons.calendar_month_outlined, text: 'Month · $month'),
                            _InfoRow(icon: Icons.payments_outlined, text: 'Amount · $amount'),
                            if (net != null)
                              _InfoRow(
                                icon: Icons.account_balance_wallet_outlined,
                                text: 'Net · ${_money(net)}',
                              ),
                            _InfoRow(
                              icon: Icons.route_outlined,
                              text: 'System distance · ${systemKm != null ? '${systemKm.toStringAsFixed(2)} km' : '—'}',
                            ),
                            if (userKm != null)
                              _InfoRow(
                                icon: Icons.edit_location_alt_outlined,
                                text: 'Employee distance · ${userKm.toStringAsFixed(2)} km',
                              ),
                            if (employeeRemarks.trim().isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Text(
                                  employeeRemarks.trim(),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant,
                                    height: 1.35,
                                  ),
                                ),
                              ),
                            if (st == 'disputed') ...[
                              const SizedBox(height: 14),
                              Row(
                                children: [
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: id.isEmpty
                                          ? null
                                          : () => _openReviewDialog(
                                                context,
                                                ref,
                                                claimId: id,
                                                action: 'approve',
                                              ),
                                      child: const Text('Approve'),
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: id.isEmpty
                                          ? null
                                          : () => _openReviewDialog(
                                                context,
                                                ref,
                                                claimId: id,
                                                action: 'reject',
                                              ),
                                      child: const Text('Reject'),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
      ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 13, color: scheme.onSurface, height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}
