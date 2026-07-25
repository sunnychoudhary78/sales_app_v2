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
          SnackBar(
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            content: Text('Claim ${action.toLowerCase()}ed successfully'),
          ),
        );
      }
      ref.invalidate(managerClaimRequestsProvider);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: Theme.of(context).colorScheme.error,
            content: Text('Action failed: $e'),
          ),
        );
      }
    }
  }

  /// Modernized review dialog using BottomSheet for better mobile ergonomics
  Future<void> _openReviewSheet(
    BuildContext context, {
    required String claimId,
    required String action,
    double? suggestedDistance,
  }) async {
    final remarksCtrl = TextEditingController();
    final approvedKmCtrl = TextEditingController(
      text: suggestedDistance != null ? suggestedDistance.toStringAsFixed(1) : '',
    );
    final isReject = action == 'reject';

    final result = await showModalBottomSheet<(String, double?)>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final scheme = Theme.of(ctx).colorScheme;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            ),
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  isReject ? 'Reject Claim Request' : 'Approve Claim Request',
                  style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 16),
                if (!isReject) ...[
                  TextField(
                    controller: approvedKmCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: 'Approved Distance (km)',
                      hintText: 'Leave empty for original distance',
                      prefixIcon: const Icon(Icons.straighten_rounded, size: 20),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                    ),
                  ),
                  const SizedBox(height: 14),
                ],
                TextField(
                  controller: remarksCtrl,
                  maxLines: 3,
                  decoration: InputDecoration(
                    labelText: isReject ? 'Reason for Rejection *' : 'Manager Remarks (Optional)',
                    hintText: isReject ? 'Provide details for the employee...' : 'Add any notes...',
                    alignLabelWithHint: true,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.all(16),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(ctx).pop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: isReject ? scheme.error : scheme.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
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
                        child: Text(isReject ? 'Confirm Rejection' : 'Confirm Approval'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );

    remarksCtrl.dispose();
    approvedKmCtrl.dispose();

    if (result == null || !context.mounted) return;

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
    final roleName = ((roleObj is Map ? roleObj['name'] : user?['role_name'])?.toString() ?? '').toLowerCase();
    final canAccess = roleName.contains('manager') ||
        hasPermission(user, 'claim.request.view') ||
        hasPermission(user, 'claim.view');

    final scheme = Theme.of(context).colorScheme;

    if (!canAccess) {
      return Scaffold(
        backgroundColor: scheme.surfaceContainerLowest,
        drawer: const AppSideDrawer(),
        appBar: const SalesGlassAppBar(title: 'Claim Requests', showDrawer: true),
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
        title: 'Claim Requests',
        showDrawer: true,
      ),
      body: ScreenAccentBackdrop(
        // spot: DrawerRouteAccents.claimRequests,
        // spot2: DrawerRouteAccents.claimRequestsAmber,
        child: RefreshIndicator(
          color: scheme.primary,
          onRefresh: () async => ref.refresh(managerClaimRequestsProvider.future),
          child: requestsAsync.when(
            loading: () => Center(
              child: CircularProgressIndicator(strokeWidth: 2, color: scheme.primary),
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
                      title: 'No pending requests',
                      subtitle: 'When your team submits or disputes a claim, it will show up here for review.',
                    ),
                  ],
                );
              }

              return CustomScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                slivers: [
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    sliver: SliverList.separated(
                      itemCount: rows.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (_, i) {
                        final r = _asClaimMap(rows[i]);
                        return _ModernClaimCard(
                          claim: r,
                          onApprove: (id, km) => _openReviewSheet(
                            context,
                            claimId: id,
                            action: 'approve',
                            suggestedDistance: km,
                          ),
                          onReject: (id) => _openReviewSheet(
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

class _ModernClaimCard extends StatefulWidget {
  const _ModernClaimCard({
    required this.claim,
    required this.onApprove,
    required this.onReject,
  });

  final Map<String, dynamic> claim;
  final void Function(String claimId, double? userKm) onApprove;
  final void Function(String claimId) onReject;

  @override
  State<_ModernClaimCard> createState() => _ModernClaimCardState();
}

class _ModernClaimCardState extends State<_ModernClaimCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final claim = widget.claim;
    final id = (claim['id'] ?? '').toString();
    final u = claim['user'] is Map ? Map<String, dynamic>.from(claim['user'] as Map) : <String, dynamic>{};
    final name = (u['name'] ?? u['email'] ?? 'Unknown User').toString();
    final employeeId = (u['employeeId'] ?? u['employee_id'] ?? '').toString();
    final monthKey = (claim['monthKey'] ?? claim['month_key'] ?? '-').toString();
    final status = (claim['status'] ?? 'pending').toString();
    final st = status.toLowerCase();

    final systemKm = _ClaimRequestsScreenState._numField(claim, ['systemDistanceKm', 'system_distance_km']);
    final userKm = _ClaimRequestsScreenState._numField(claim, ['userDistanceKm', 'user_distance_km', 'correctedDistanceKm']);
    final approvedKm = _ClaimRequestsScreenState._numField(claim, ['approvedDistanceKm', 'approved_distance_km']);
    final rateSnapshot = claim['ratePerKmSnapshot'] ?? claim['rate_per_km_snapshot'];

    final employeeRemarks = (claim['remarks'] ?? '').toString();
    final managerRemarks = (claim['managerRemarks'] ?? claim['manager_remarks'] ?? '').toString();

    final isDisputed = st == 'disputed' || st == 'pending';

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outlineVariant.withOpacity(0.5)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Card Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 20,
                      backgroundColor: scheme.primaryContainer,
                      child: Text(
                        name.isNotEmpty ? name[0].toUpperCase() : 'U',
                        style: TextStyle(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                          if (employeeId.isNotEmpty)
                            Text(
                              'ID: $employeeId • ${ClaimFormatters.formatMonthKey(monthKey)}',
                              style: TextStyle(fontSize: 16, color: scheme.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    _StatusBadge(status: status),
                  ],
                ),
                const SizedBox(height: 16),

                // High-level Metrics Row
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MetricItem(
                        label: 'System Distance',
                        value: systemKm != null ? '${systemKm.toStringAsFixed(1)} km' : '--',
                      ),
                      Container(height: 24, width: 1, color: scheme.outlineVariant),
                      _MetricItem(
                        label: 'Claimed Distance',
                        value: userKm != null ? '${userKm.toStringAsFixed(1)} km' : '--',
                        highlight: userKm != null && systemKm != null && (userKm - systemKm).abs() > 1.0,
                      ),
                      if (approvedKm != null) ...[
                        Container(height: 24, width: 1, color: scheme.outlineVariant),
                        _MetricItem(
                          label: 'Approved',
                          value: '${approvedKm.toStringAsFixed(1)} km',
                          color: scheme.primary,
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),

          // Collapsible Detailed Audit View
          AnimatedCrossFade(
            firstChild: const SizedBox.shrink(),
            secondChild: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Divider(height: 1),
                  const SizedBox(height: 12),
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
                ],
              ),
            ),
            crossFadeState: _isExpanded ? CrossFadeState.showSecond : CrossFadeState.showFirst,
            duration: const Duration(milliseconds: 250),
          ),

          // Card Actions Bar
          InkWell(
            onTap: () => setState(() => _isExpanded = !_isExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    _isExpanded ? 'Hide Details' : 'View Full Details',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: scheme.primary,
                    ),
                  ),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                    size: 18,
                    color: scheme.primary,
                  ),
                ],
              ),
            ),
          ),

          if (isDisputed) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: scheme.error,
                        side: BorderSide(color: scheme.error.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: id.isEmpty ? null : () => widget.onReject(id),
                      child: const Text('Reject'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: id.isEmpty ? null : () => widget.onApprove(id, userKm),
                      child: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final st = status.toLowerCase();

    Color bgColor = scheme.surfaceContainerHigh;
    Color fgColor = scheme.onSurfaceVariant;

    if (st == 'approved') {
      bgColor = Colors.green.shade50;
      fgColor = Colors.green.shade700;
    } else if (st == 'rejected') {
      bgColor = scheme.errorContainer.withOpacity(0.4);
      fgColor = scheme.error;
    } else if (st == 'disputed' || st == 'pending') {
      bgColor = Colors.amber.shade50;
      fgColor = Colors.amber.shade900;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: fgColor,
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}

class _MetricItem extends StatelessWidget {
  const _MetricItem({
    required this.label,
    required this.value,
    this.highlight = false,
    this.color,
  });

  final String label;
  final String value;
  final bool highlight;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 15, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            color: highlight
                ? scheme.error
                : color ?? scheme.onSurface,
          ),
        ),
      ],
    );
  }
}