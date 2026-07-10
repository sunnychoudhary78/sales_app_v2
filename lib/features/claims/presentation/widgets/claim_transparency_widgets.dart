import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/premium_shell.dart';

/// Formatting helpers for claim screens (no backend changes).
class ClaimFormatters {
  ClaimFormatters._();

  static final NumberFormat inr = NumberFormat.currency(
    locale: 'en_IN',
    symbol: '₹',
  );

  static String money(dynamic v) {
    if (v == null) return '—';
    final n = num.tryParse(v.toString());
    if (n == null) return v.toString();
    return inr.format(n);
  }

  static String formatMonthKey(String monthKey) {
    final s = monthKey.trim();
    final parts = s.split('-');
    if (parts.length != 2) return monthKey;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (y == null || m == null || m < 1 || m > 12) return monthKey;
    const names = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return '${names[m - 1]} $y';
  }

  static String formatYmdToDmy(String ymd) {
    final s = ymd.trim();
    final parts = s.split('-');
    if (parts.length != 3) return ymd;
    final y = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    final d = int.tryParse(parts[2]);
    if (y == null || m == null || d == null) return ymd;
    return '${d.toString().padLeft(2, '0')}/${m.toString().padLeft(2, '0')}/${y.toString().padLeft(4, '0')}';
  }

  static String formatTimestamp(dynamic v) {
    if (v == null) return '—';
    final dt = DateTime.tryParse(v.toString());
    if (dt == null) return v.toString();
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt.toLocal());
  }

  static String vehicleLabel(String? raw) {
    final v = (raw ?? 'two_wheeler').toString();
    return v == 'four_wheeler' ? 'Four wheeler' : 'Two wheeler';
  }

  static Color statusColor(ColorScheme scheme, String status) {
    final s = status.toLowerCase();
    if (s == 'approved') return scheme.primary;
    if (s == 'rejected') return scheme.error;
    if (s == 'disputed') return scheme.tertiary;
    if (s == 'pending' || s == 'submitted') return scheme.secondary;
    return scheme.outline;
  }

  static List<Map<String, dynamic>> extraExpenses(Map<String, dynamic>? claim) {
    if (claim == null) return [];
    final raw = claim['extraExpenses'] ?? claim['extra_expenses'];
    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
    }
    final total =
        num.tryParse((claim['extraExpenseAmount'] ?? claim['extra_expense_amount'] ?? '').toString()) ??
        0;
    return total > 0
        ? [
            {'type': 'Other', 'amount': total},
          ]
        : [];
  }

  static List<Map<String, dynamic>> claimChatEntries(Map<String, dynamic>? claim) {
    if (claim == null) return [];
    final raw = claim['claimChat'] ?? claim['claim_chat'];
    if (raw is! List) return [];
    return raw
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
  }
}

class ClaimAvailabilityBanner extends StatelessWidget {
  const ClaimAvailabilityBanner({
    super.key,
    required this.message,
    required this.canSubmitToday,
  });

  final String message;
  final bool canSubmitToday;

  @override
  Widget build(BuildContext context) {
    if (canSubmitToday) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.tertiary.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.tertiary, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Submission window closed today',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    color: scheme.onTertiaryContainer,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  message.trim(),
                  style: TextStyle(
                    fontSize: 12,
                    height: 1.35,
                    color: scheme.onTertiaryContainer.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ClaimInfoLine extends StatelessWidget {
  const ClaimInfoLine({
    super.key,
    required this.label,
    required this.value,
    this.emphasize = false,
    this.subtitle,
  });

  final String label;
  final String value;
  final bool emphasize;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: emphasize ? FontWeight.w800 : FontWeight.w600,
                    color: emphasize ? scheme.primary : scheme.onSurface,
                  ),
                ),
                if (subtitle != null && subtitle!.isNotEmpty)
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                      height: 1.25,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class ClaimFinancialBreakdownCard extends StatelessWidget {
  const ClaimFinancialBreakdownCard({
    super.key,
    required this.claim,
    this.previewCalculatedAmount,
    this.previewSystemKm,
    this.previewRate,
    this.embedded = false,
  });

  final Map<String, dynamic> claim;
  final dynamic previewCalculatedAmount;
  final dynamic previewSystemKm;
  final dynamic previewRate;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final baseAmount = claim['amount'];
    final advance = claim['advancePaymentAmount'] ?? claim['advance_payment_amount'];
    final extraTotal =
        claim['extraExpenseAmount'] ?? claim['extra_expense_amount'];
    final net = claim['netAmount'] ?? claim['net_amount'];
    final approvedAmount = claim['approvedAmount'] ?? claim['approved_amount'];
    final extras = ClaimFormatters.extraExpenses(claim);
    final status = (claim['status'] ?? '').toString().toLowerCase();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Financial breakdown',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Distance × rate + extra expenses − advance = net payable',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant, height: 1.3),
        ),
        const SizedBox(height: 12),
        ClaimInfoLine(
          label: 'Claim amount',
          value: ClaimFormatters.money(baseAmount ?? previewCalculatedAmount),
          subtitle: previewSystemKm != null && previewRate != null
              ? '$previewSystemKm km × ${ClaimFormatters.money(previewRate)}/km'
              : null,
        ),
        if (extras.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 150, bottom: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Extra expenses (+${ClaimFormatters.money(extraTotal)})',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.primary,
                  ),
                ),
                for (final e in extras)
                  Text(
                    '  ${e['type']}: ${ClaimFormatters.money(e['amount'])}',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
                  ),
              ],
            ),
          ),
        ] else if (extraTotal != null &&
            (num.tryParse(extraTotal.toString()) ?? 0) > 0)
          ClaimInfoLine(
            label: 'Extra expenses',
            value: ClaimFormatters.money(extraTotal),
          ),
        ClaimInfoLine(
          label: 'Advance deducted',
          value: '− ${ClaimFormatters.money(advance ?? 0)}',
        ),
        const Divider(height: 20),
        ClaimInfoLine(
          label: 'Net payable',
          value: ClaimFormatters.money(net),
          emphasize: true,
        ),
        if (status == 'approved' && approvedAmount != null)
          ClaimInfoLine(
            label: 'Approved amount',
            value: ClaimFormatters.money(approvedAmount),
            emphasize: true,
          ),
      ],
    );

    if (embedded) {
      return Padding(
        padding: const EdgeInsets.only(top: 8),
        child: content,
      );
    }
    return PremiumCard(padding: const EdgeInsets.all(16), child: content);
  }
}

class ClaimDistanceComparisonCard extends StatelessWidget {
  const ClaimDistanceComparisonCard({
    super.key,
    required this.systemKm,
    this.userKm,
    this.approvedKm,
    this.ratePerKm,
    this.embedded = false,
  });

  final dynamic systemKm;
  final dynamic userKm;
  final dynamic approvedKm;
  final dynamic ratePerKm;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sys = num.tryParse(systemKm?.toString() ?? '');
    final user = userKm != null ? num.tryParse(userKm.toString()) : null;
    final approved =
        approvedKm != null ? num.tryParse(approvedKm.toString()) : null;
    final rate = ratePerKm != null ? num.tryParse(ratePerKm.toString()) : null;

    String? deltaLabel;
    if (sys != null && user != null) {
      final delta = user - sys;
      final sign = delta >= 0 ? '+' : '';
      deltaLabel = '$sign${delta.toStringAsFixed(2)} km vs system';
      if (rate != null) {
        final amountDelta = delta * rate;
        deltaLabel = '$deltaLabel ($sign${ClaimFormatters.money(amountDelta.abs())})';
      }
    }

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Distance comparison',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        ClaimInfoLine(
          label: 'System (GPS)',
          value: sys != null ? '${sys.toStringAsFixed(2)} km' : '—',
        ),
        if (user != null)
          ClaimInfoLine(
            label: 'Employee claimed',
            value: '${user.toStringAsFixed(2)} km',
            subtitle: deltaLabel,
          ),
        if (approved != null)
          ClaimInfoLine(
            label: 'Manager approved',
            value: '${approved.toStringAsFixed(2)} km',
            emphasize: true,
          ),
        if (user == null && approved == null)
          Text(
            'Employee agreed with system distance.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
      ],
    );

    if (embedded) return content;
    return PremiumCard(padding: const EdgeInsets.all(16), child: content);
  }
}

class ClaimSnapshotCard extends StatelessWidget {
  const ClaimSnapshotCard({
    super.key,
    required this.claim,
    this.embedded = false,
  });

  final Map<String, dynamic> claim;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final vehicle = claim['vehicleTypeSnapshot'] ?? claim['vehicle_type_snapshot'];
    final rate = claim['ratePerKmSnapshot'] ?? claim['rate_per_km_snapshot'];
    if (vehicle == null && rate == null) return const SizedBox.shrink();

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Locked at submission',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'Vehicle and rate frozen when this claim was submitted.',
          style: TextStyle(
            fontSize: 11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        if (vehicle != null)
          ClaimInfoLine(
            label: 'Vehicle',
            value: ClaimFormatters.vehicleLabel(vehicle.toString()),
          ),
        if (rate != null)
          ClaimInfoLine(label: 'Rate / km', value: ClaimFormatters.money(rate)),
      ],
    );

    if (embedded) {
      return Padding(padding: const EdgeInsets.only(top: 8), child: content);
    }
    return PremiumCard(padding: const EdgeInsets.all(16), child: content);
  }
}

class ClaimTimestampsCard extends StatelessWidget {
  const ClaimTimestampsCard({super.key, required this.claim});

  final Map<String, dynamic> claim;

  @override
  Widget build(BuildContext context) {
    final submitted = claim['submittedAt'] ?? claim['submitted_at'];
    final reviewed = claim['reviewedAt'] ?? claim['reviewed_at'];
    final resolved = claim['resolvedAt'] ?? claim['resolved_at'];
    if (submitted == null && reviewed == null && resolved == null) {
      return const SizedBox.shrink();
    }

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Timeline',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 12),
          if (submitted != null)
            ClaimInfoLine(
              label: 'Submitted',
              value: ClaimFormatters.formatTimestamp(submitted),
            ),
          if (reviewed != null)
            ClaimInfoLine(
              label: 'Reviewed',
              value: ClaimFormatters.formatTimestamp(reviewed),
            ),
          if (resolved != null)
            ClaimInfoLine(
              label: 'Resolved',
              value: ClaimFormatters.formatTimestamp(resolved),
            ),
        ],
      ),
    );
  }
}

class ClaimActivityTimeline extends StatelessWidget {
  const ClaimActivityTimeline({
    super.key,
    required this.claim,
    this.embedded = false,
  });

  final Map<String, dynamic> claim;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final entries = ClaimFormatters.claimChatEntries(claim);
    if (entries.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    final tile = ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 8),
      childrenPadding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
      leading: Icon(Icons.history_rounded, color: scheme.primary, size: 22),
      title: Text(
        'Activity history (${entries.length})',
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
      ),
      subtitle: Text(
        'Every submission, dispute, and manager action',
        style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
      ),
      children: [
        for (var i = 0; i < entries.length; i++) ...[
          if (i > 0) Divider(color: scheme.outlineVariant.withValues(alpha: 0.5)),
          _ClaimChatEntryTile(entry: entries[i]),
        ],
      ],
    );

    if (embedded) {
      return Padding(
        padding: const EdgeInsets.only(top: 4),
        child: tile,
      );
    }
    return PremiumCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      child: tile,
    );
  }
}

class _ClaimChatEntryTile extends StatelessWidget {
  const _ClaimChatEntryTile({required this.entry});

  final Map<String, dynamic> entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final role = (entry['role'] ?? entry['by'] ?? 'User').toString();
    final action = (entry['action'] ?? '—').toString();
    final at = ClaimFormatters.formatTimestamp(entry['at']);
    final distance = entry['distance_km'] ?? entry['distanceKm'];
    final amount = entry['amount'];
    final net = entry['net_amount'] ?? entry['netAmount'];
    final remarks = (entry['remarks'] ?? '').toString();
    final status = (entry['status'] ?? '').toString();

    final isManager = role.toLowerCase().contains('manager') ||
        entry['by']?.toString().toLowerCase() == 'manager';

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isManager
                      ? scheme.secondaryContainer
                      : scheme.primaryContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  role,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    color: isManager
                        ? scheme.onSecondaryContainer
                        : scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  action.toUpperCase(),
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Text(
                at,
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          if (status.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Status → $status',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
          if (distance != null)
            Text(
              'Distance: ${num.tryParse(distance.toString())?.toStringAsFixed(2) ?? distance} km',
              style: TextStyle(fontSize: 12, color: scheme.onSurface),
            ),
          if (amount != null)
            Text(
              'Amount: ${ClaimFormatters.money(amount)}',
              style: TextStyle(fontSize: 12, color: scheme.onSurface),
            ),
          if (net != null)
            Text(
              'Net: ${ClaimFormatters.money(net)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          if (remarks.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                remarks.trim(),
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: scheme.onSurfaceVariant,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class ClaimRemarksCard extends StatelessWidget {
  const ClaimRemarksCard({
    super.key,
    this.employeeRemarks,
    this.managerRemarks,
    this.embedded = false,
  });

  final String? employeeRemarks;
  final String? managerRemarks;
  final bool embedded;

  @override
  Widget build(BuildContext context) {
    final emp = employeeRemarks?.trim() ?? '';
    final mgr = managerRemarks?.trim() ?? '';
    if (emp.isEmpty && mgr.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;

    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Remarks',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 12),
        if (emp.isNotEmpty) ...[
          Text(
            'Employee',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            emp,
            style: TextStyle(fontSize: 13, color: scheme.onSurface, height: 1.35),
          ),
        ],
        if (emp.isNotEmpty && mgr.isNotEmpty) const SizedBox(height: 12),
        if (mgr.isNotEmpty) ...[
          Text(
            'Manager',
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: scheme.tertiary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            mgr,
            style: TextStyle(fontSize: 13, color: scheme.onSurface, height: 1.35),
          ),
        ],
      ],
    );

    if (embedded) {
      return Padding(padding: const EdgeInsets.only(top: 8), child: content);
    }
    return PremiumCard(padding: const EdgeInsets.all(16), child: content);
  }
}
