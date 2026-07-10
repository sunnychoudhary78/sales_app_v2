import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/utils/permission_utils.dart';
import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../../shared/widgets/screen_accent_backdrop.dart';
import '../../data/claims_repository.dart';
import '../providers/claims_provider.dart';
import '../widgets/claim_transparency_widgets.dart';

class ClaimRequestsScreen extends ConsumerStatefulWidget {
  const ClaimRequestsScreen({super.key});

  @override
  ConsumerState<ClaimRequestsScreen> createState() => _ClaimRequestsScreenState();
}

class _ClaimRequestsScreenState extends ConsumerState<ClaimRequestsScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() => ref.invalidate(managerClaimRequestsProvider));
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

  static Map<String, dynamic> _asClaimMap(Map<String, dynamic> r) {
    return Map<String, dynamic>.from(r);
  }

  Future<void> _review(
    BuildContext context, {
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
    BuildContext context, {
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
      claimId: claimId,
      action: action,
      managerRemarks: result.$1,
      approvedDistanceKm: result.$2,
    );
  }

  @override
  Widget build(BuildContext context) {
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
                        'Full distance, financial, and activity details for each claim. Expand a card for the audit trail. Pull down to refresh.',
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.separated(
                    itemCount: rows.length,
                    separatorBuilder: (context, index) => const SizedBox(height: 12),
                    itemBuilder: (_, i) {
                      final r = _asClaimMap(rows[i]);
                      return _ManagerClaimCard(
                        claim: r,
                        onApprove: (id) => _openReviewDialog(
                          context,
                          claimId: id,
                          action: 'approve',
                        ),
                        onReject: (id) => _openReviewDialog(
                          context,
                          claimId: id,
                          action: 'reject',
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

class _ManagerClaimCard extends StatelessWidget {
  const _ManagerClaimCard({
    required this.claim,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> claim;
  final void Function(String claimId) onApprove;
  final void Function(String claimId) onReject;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final id = (claim['id'] ?? '').toString();
    final u = claim['user'] is Map
        ? Map<String, dynamic>.from(claim['user'] as Map)
        : <String, dynamic>{};
    final name = (u['name'] ?? u['email'] ?? '-').toString();
    final employeeId = (u['employeeId'] ?? u['employee_id'] ?? '').toString();
    final company = (u['companyName'] ?? u['company_name'] ?? '').toString();
    final mobile = (u['mobile'] ?? '').toString();
    final monthKey = (claim['monthKey'] ?? claim['month_key'] ?? '-').toString();
    final monthStart = (claim['monthStart'] ?? claim['month_start'] ?? '').toString();
    final monthEnd = (claim['monthEnd'] ?? claim['month_end'] ?? '').toString();
    final status = (claim['status'] ?? '-').toString();
    final st = status.toLowerCase();
    final systemKm = _ClaimRequestsScreenState._numField(claim, [
      'systemDistanceKm',
      'system_distance_km',
    ]);
    final userKm = _ClaimRequestsScreenState._numField(claim, [
      'userDistanceKm',
      'user_distance_km',
      'correctedDistanceKm',
    ]);
    final approvedKm = _ClaimRequestsScreenState._numField(claim, [
      'approvedDistanceKm',
      'approved_distance_km',
    ]);
    final rateSnapshot =
        claim['ratePerKmSnapshot'] ?? claim['rate_per_km_snapshot'];
    final employeeRemarks = (claim['remarks'] ?? '').toString();
    final managerRemarks =
        (claim['managerRemarks'] ?? claim['manager_remarks'] ?? '').toString();
    final submittedAt = claim['submittedAt'] ?? claim['submitted_at'];
    final reviewedAt = claim['reviewedAt'] ?? claim['reviewed_at'];

    final periodLabel = monthStart.isNotEmpty && monthEnd.isNotEmpty
        ? '${ClaimFormatters.formatYmdToDmy(monthStart)} – ${ClaimFormatters.formatYmdToDmy(monthEnd)}'
        : null;

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    if (employeeId.isNotEmpty)
                      Text(
                        'ID $employeeId',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (company.isNotEmpty)
                      Text(
                        company,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    if (mobile.isNotEmpty)
                      Text(
                        mobile,
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              PremiumStatusPill(
                label: status,
                color: ClaimFormatters.statusColor(scheme, status),
                icon: st == 'disputed'
                    ? Icons.warning_amber_rounded
                    : Icons.check_circle_outline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 10),
          _InfoRow(
            icon: Icons.calendar_month_outlined,
            text: ClaimFormatters.formatMonthKey(monthKey),
          ),
          if (periodLabel != null)
            _InfoRow(icon: Icons.date_range_outlined, text: periodLabel),
          if (id.isNotEmpty)
            _InfoRow(icon: Icons.tag_outlined, text: 'Ref $id'),
          if (submittedAt != null)
            _InfoRow(
              icon: Icons.schedule_outlined,
              text: 'Submitted ${ClaimFormatters.formatTimestamp(submittedAt)}',
            ),
          if (reviewedAt != null)
            _InfoRow(
              icon: Icons.fact_check_outlined,
              text: 'Reviewed ${ClaimFormatters.formatTimestamp(reviewedAt)}',
            ),
          const Divider(height: 24),
          ClaimDistanceComparisonCard(
            systemKm: systemKm,
            userKm: userKm,
            approvedKm: approvedKm,
            ratePerKm: rateSnapshot,
            embedded: true,
          ),
          ClaimFinancialBreakdownCard(claim: claim, embedded: true),
          ClaimSnapshotCard(claim: claim, embedded: true),
          ClaimRemarksCard(
            employeeRemarks: employeeRemarks,
            managerRemarks: managerRemarks,
            embedded: true,
          ),
          ClaimActivityTimeline(claim: claim, embedded: true),
          if (st == 'disputed') ...[
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: id.isEmpty ? null : () => onApprove(id),
                    child: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton(
                    onPressed: id.isEmpty ? null : () => onReject(id),
                    child: const Text('Reject'),
                  ),
                ),
              ],
            ),
          ],
        ],
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
