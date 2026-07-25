import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../../shared/widgets/screen_accent_backdrop.dart';
import '../../data/claims_repository.dart';
import '../providers/claims_provider.dart';
import '../widgets/claim_transparency_widgets.dart';

class _ExtraExpenseDraft {
  _ExtraExpenseDraft({String type = '', String amount = ''})
    : typeCtrl = TextEditingController(text: type),
      amountCtrl = TextEditingController(text: amount);

  final TextEditingController typeCtrl;
  final TextEditingController amountCtrl;

  void dispose() {
    typeCtrl.dispose();
    amountCtrl.dispose();
  }
}

/// Modern UI: Monthly distance claim screen
class MyClaimScreen extends ConsumerStatefulWidget {
  const MyClaimScreen({super.key});

  @override
  ConsumerState<MyClaimScreen> createState() => _MyClaimScreenState();
}

class _MyClaimScreenState extends ConsumerState<MyClaimScreen> {
  bool _agreeSubmitting = false;
  bool _disagreeSubmitting = false;
  final _advanceCtrl = TextEditingController();
  final _correctedKmCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();
  final List<_ExtraExpenseDraft> _extraDrafts = [_ExtraExpenseDraft()];
  bool _showDisputeForm = false;

  String? _advanceError;
  String? _extraExpenseError;
  String? _correctedKmError;
  String? _remarksError;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.invalidate(myClaimPreviewProvider);
      ref.invalidate(myClaimDistanceHistoryProvider);
    });
  }

  @override
  void dispose() {
    _advanceCtrl.dispose();
    _correctedKmCtrl.dispose();
    _remarksCtrl.dispose();
    for (final d in _extraDrafts) {
      d.dispose();
    }
    super.dispose();
  }

  Future<void> _showClaimUnavailableDialog({
    required String availabilityMessage,
    required String periodLabel,
  }) async {
    if (!mounted) return;
    final scheme = Theme.of(context).colorScheme;
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Claims Not Available Today'),
        content: Text(
          '${availabilityMessage.trim()}\n\n'
          'Distance for this claim covers: $periodLabel.',
          style: TextStyle(color: scheme.onSurfaceVariant, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  double? _validatedAdvancePayment() {
    final text = _advanceCtrl.text.trim();
    if (text.isEmpty) return 0;
    final value = double.tryParse(text);
    if (value == null || value < 0) {
      setState(
        () => _advanceError = 'Enter a valid advance payment amount (or leave blank)',
      );
      return null;
    }
    setState(() => _advanceError = null);
    return value;
  }

  List<Map<String, dynamic>>? _validatedExtraExpenses() {
    final items = <Map<String, dynamic>>[];
    for (final draft in _extraDrafts) {
      final type = draft.typeCtrl.text.trim();
      final amountText = draft.amountCtrl.text.trim();
      if (type.isEmpty && amountText.isEmpty) continue;
      if (type.isEmpty) {
        setState(
          () => _extraExpenseError = 'Enter a type for each expense line',
        );
        return null;
      }
      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        setState(
          () => _extraExpenseError = 'Enter a valid amount for each expense line',
        );
        return null;
      }
      items.add({'type': type, 'amount': amount});
    }
    setState(() => _extraExpenseError = null);
    return items;
  }

  void _replaceExtraDrafts(List<Map<String, dynamic>> items) {
    for (final d in _extraDrafts) {
      d.dispose();
    }
    _extraDrafts
      ..clear()
      ..addAll(
        items.isEmpty
            ? [_ExtraExpenseDraft()]
            : items
                  .map(
                    (e) => _ExtraExpenseDraft(
                      type: e['type']?.toString() ?? '',
                      amount: e['amount']?.toString() ?? '',
                    ),
                  )
                  .toList(),
      );
  }

  void _syncDraftsFromClaim(Map<String, dynamic>? claim) {
    if (claim is! Map<String, dynamic>) return;
    if (_advanceCtrl.text.trim().isEmpty &&
        claim['advancePaymentAmount'] != null) {
      _advanceCtrl.text = claim['advancePaymentAmount'].toString();
    }
    final existing = ClaimFormatters.extraExpenses(claim);
    final hasTyped = _extraDrafts.any(
      (d) =>
          d.typeCtrl.text.trim().isNotEmpty ||
          d.amountCtrl.text.trim().isNotEmpty,
    );
    if (!hasTyped && existing.isNotEmpty) {
      _replaceExtraDrafts(existing);
    }
    final st = (claim['status'] ?? '').toString().toLowerCase();
    if (st == 'rejected') {
      if (_correctedKmCtrl.text.trim().isEmpty &&
          claim['userDistanceKm'] != null) {
        _correctedKmCtrl.text = claim['userDistanceKm'].toString();
      }
      if (_remarksCtrl.text.trim().isEmpty && claim['remarks'] != null) {
        _remarksCtrl.text = claim['remarks'].toString();
      }
    }
  }

  String _statusGuidance(String statusLower) {
    switch (statusLower) {
      case 'disputed':
        return 'Your manager is reviewing your disputed distance.';
      case 'pending':
        return 'Submitted — awaiting manager review.';
      case 'approved':
        return 'Approved. Net payable reflects manager-approved figures.';
      case 'rejected':
        return 'Rejected — update and resubmit during the allowed window.';
      default:
        return '';
    }
  }

  Future<void> _submitAgree(
    bool canSubmitToday,
    String availabilityMsg,
    String periodLabel,
  ) async {
    if (!canSubmitToday) {
      await _showClaimUnavailableDialog(
        availabilityMessage: availabilityMsg,
        periodLabel: periodLabel,
      );
      return;
    }
    final advance = _validatedAdvancePayment();
    if (advance == null) return;
    final extras = _validatedExtraExpenses();
    if (extras == null) return;
    if (_agreeSubmitting || _disagreeSubmitting) return;
    setState(() => _agreeSubmitting = true);
    try {
      await ref
          .read(claimsRepositoryProvider)
          .submitMyClaim(
            action: 'agree',
            advancePaymentAmount: advance,
            extraExpenses: extras,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Claim submitted successfully')));
      ref.invalidate(myClaimPreviewProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_dioMessage(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _agreeSubmitting = false);
    }
  }

  Future<void> _submitDisagree(
    bool canSubmitToday,
    String availabilityMsg,
    String periodLabel,
  ) async {
    if (!canSubmitToday) {
      await _showClaimUnavailableDialog(
        availabilityMessage: availabilityMsg,
        periodLabel: periodLabel,
      );
      return;
    }
    final advance = _validatedAdvancePayment();
    if (advance == null) return;
    final extras = _validatedExtraExpenses();
    if (extras == null) return;

    final corrected = double.tryParse(_correctedKmCtrl.text.trim());
    final remarks = _remarksCtrl.text.trim();
    String? kmErr;
    String? remarkErr;
    if (_correctedKmCtrl.text.trim().isEmpty) {
      kmErr = 'Corrected distance is required';
    } else if (corrected == null || corrected < 0) {
      kmErr = 'Enter a valid distance';
    }
    if (remarks.isEmpty) {
      remarkErr = 'Remarks are required when disputing';
    }
    if (kmErr != null || remarkErr != null) {
      setState(() {
        _correctedKmError = kmErr;
        _remarksError = remarkErr;
      });
      return;
    }
    setState(() {
      _correctedKmError = null;
      _remarksError = null;
    });

    if (_agreeSubmitting || _disagreeSubmitting) return;
    setState(() => _disagreeSubmitting = true);
    try {
      await ref
          .read(claimsRepositoryProvider)
          .submitMyClaim(
            action: 'disagree',
            correctedDistanceKm: corrected,
            remarks: remarks,
            advancePaymentAmount: advance,
            extraExpenses: extras,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Dispute submitted')));
      setState(() => _showDisputeForm = false);
      ref.invalidate(myClaimPreviewProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_dioMessage(e))));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _disagreeSubmitting = false);
    }
  }

  String _dioMessage(DioException e) {
    final data = e.response?.data;
    if (data is Map && data['message'] != null) {
      return data['message'].toString();
    }
    return e.message ?? 'Request failed';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    ref.listen(myClaimPreviewProvider, (prev, next) {
      next.whenData((d) {
        final claim = d['claim'] is Map<String, dynamic>
            ? d['claim'] as Map<String, dynamic>
            : null;
        if (!mounted || claim == null) return;
        _syncDraftsFromClaim(claim);
      });
    });

    final previewAsync = ref.watch(myClaimPreviewProvider);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppSideDrawer(),
      appBar: const SalesGlassAppBar(title: 'My Claim', showDrawer: true),
      body: ScreenAccentBackdrop(
        spot: DrawerRouteAccents.myClaim,
        spot2: DrawerRouteAccents.myClaimSky,
        child: previewAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text('Failed to load claim preview.\n$e'),
            ),
          ),
          data: (d) {
            final monthKey = (d['monthKey'] ?? '-').toString();
            final monthStart = (d['monthStart'] ?? '').toString();
            final monthEnd = (d['monthEnd'] ?? '').toString();
            final periodLabel = monthStart.isNotEmpty && monthEnd.isNotEmpty
                ? '${ClaimFormatters.formatYmdToDmy(monthStart)} - ${ClaimFormatters.formatYmdToDmy(monthEnd)}'
                : '—';
            final canSubmitToday = d['canSubmitToday'] == true;
            final availabilityMsg =
                (d['claimAvailabilityMessage'] ??
                        'Claim submission is not available today.')
                    .toString();

            final vehicleRaw = (d['vehicleType'] ?? 'two_wheeler').toString();
            final vehicleLabel = vehicleRaw == 'four_wheeler'
                ? 'Four Wheeler'
                : 'Two Wheeler';
            final systemKm = d['systemDistanceKm'];
            final rate = d['ratePerKm'];
            final calculated = d['calculatedAmount'];

            final claim = d['claim'] is Map<String, dynamic>
                ? d['claim'] as Map<String, dynamic>
                : null;

            final claimStatus = claim?['status']?.toString();
            final headerStatus =
                (claimStatus != null && claimStatus.trim().isNotEmpty)
                ? claimStatus.trim()
                : (claim == null ? 'Not Submitted' : '—');
            final statusLower = headerStatus.toLowerCase();
            final canShowSubmitActions =
                claim == null || statusLower == 'rejected';
            final canSubmitThisClaim =
                canSubmitToday || statusLower == 'rejected';

            final userKm = claim?['userDistanceKm'];
            final approvedKm = claim?['approvedDistanceKm'];
            final managerRemarks = claim?['managerRemarks']?.toString();
            final remarks = claim?['remarks']?.toString() ?? '';
            final claimId = claim?['id']?.toString();
            final rateSnapshot =
                claim?['ratePerKmSnapshot'] ?? claim?['rate_per_km_snapshot'] ?? rate;
            final statusGuidance = _statusGuidance(statusLower);

            return RefreshIndicator(
              color: scheme.primary,
              onRefresh: () async {
                ref.invalidate(myClaimPreviewProvider);
                ref.invalidate(myClaimDistanceHistoryProvider);
              },
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  ClaimAvailabilityBanner(
                    message: availabilityMsg,
                    canSubmitToday: canSubmitToday,
                  ),
                  const SizedBox(height: 12),

                  // Hero Modern Overview Card
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          scheme.primaryContainer,
                          scheme.surfaceContainerHigh,
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              ClaimFormatters.formatMonthKey(monthKey),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            PremiumStatusPill(
                              label: headerStatus,
                              color: ClaimFormatters.statusColor(scheme, headerStatus),
                              icon: Icons.info_outline,
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Period: $periodLabel',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        if (claimId != null && claimId.isNotEmpty)
                          Text(
                            'Ref: $claimId',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                            ),
                          ),
                        const Divider(height: 24),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricTile(
                                label: 'Calculated Amount',
                                value: ClaimFormatters.money(calculated),
                                isHighlight: true,
                              ),
                            ),
                            Container(height: 36, width: 1, color: scheme.outlineVariant),
                            Expanded(
                              child: _MetricTile(
                                label: 'System Distance',
                                value: '${systemKm?.toString() ?? "0"} km',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _MetricTile(
                                label: 'Vehicle Type',
                                value: vehicleLabel,
                              ),
                            ),
                            Container(height: 36, width: 1, color: scheme.outlineVariant),
                            Expanded(
                              child: _MetricTile(
                                label: 'Rate / km',
                                value: ClaimFormatters.money(rate),
                              ),
                            ),
                          ],
                        ),
                        if (statusGuidance.isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: scheme.surface.withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info_outline, size: 16, color: scheme.primary),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    statusGuidance,
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  if (claim != null) ...[
                    const SizedBox(height: 16),
                    ClaimDistanceComparisonCard(
                      systemKm: claim['systemDistanceKm'] ?? systemKm,
                      userKm: userKm,
                      approvedKm: approvedKm,
                      ratePerKm: rateSnapshot,
                    ),
                    const SizedBox(height: 12),
                    ClaimFinancialBreakdownCard(
                      claim: claim,
                      previewCalculatedAmount: calculated,
                      previewSystemKm: systemKm,
                      previewRate: rate,
                    ),
                    const SizedBox(height: 12),
                    ClaimSnapshotCard(claim: claim),
                    const SizedBox(height: 12),
                    ClaimTimestampsCard(claim: claim),
                    const SizedBox(height: 12),
                    ClaimRemarksCard(
                      employeeRemarks: remarks,
                      managerRemarks: managerRemarks,
                    ),
                    const SizedBox(height: 12),
                    ClaimActivityTimeline(claim: claim),
                  ],

                  const SizedBox(height: 16),

                  if (canShowSubmitActions) ...[
                    Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(color: scheme.outlineVariant),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Submit Monthly Claim',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              statusLower == 'rejected'
                                  ? 'Your claim was rejected. Please edit details below and resubmit.'
                                  : 'Enter additional details if applicable before submitting for review.',
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                            const SizedBox(height: 16),
                            TextField(
                              controller: _advanceCtrl,
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              onChanged: (_) {
                                if (_advanceError != null) {
                                  setState(() => _advanceError = null);
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Advance Payment Received (Optional)',
                                prefixText: '\$ ',
                                errorText: _advanceError,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(14),
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Extra Expenses',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: scheme.onSurface,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () => setState(
                                    () => _extraDrafts.add(_ExtraExpenseDraft()),
                                  ),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add Line'),
                                ),
                              ],
                            ),
                            ...List.generate(_extraDrafts.length, (index) {
                              final draft = _extraDrafts[index];
                              return Container(
                                margin: const EdgeInsets.only(bottom: 8),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: scheme.surfaceContainerLow,
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: TextField(
                                        controller: draft.typeCtrl,
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          labelText: 'Type (e.g. Food)',
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: TextField(
                                        controller: draft.amountCtrl,
                                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                        decoration: const InputDecoration(
                                          isDense: true,
                                          labelText: 'Amount',
                                          prefixText: '\₹',
                                          border: InputBorder.none,
                                        ),
                                      ),
                                    ),
                                    if (_extraDrafts.length > 1)
                                      IconButton(
                                        icon: Icon(Icons.cancel, color: scheme.error, size: 20),
                                        onPressed: () => setState(() {
                                          final r = _extraDrafts.removeAt(index);
                                          r.dispose();
                                        }),
                                      ),
                                  ],
                                ),
                              );
                            }),
                            if (_extraExpenseError != null)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Text(
                                  _extraExpenseError!,
                                  style: TextStyle(color: scheme.error, fontSize: 12),
                                ),
                              ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: FilledButton(
                                    style: FilledButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: (_agreeSubmitting || _disagreeSubmitting)
                                        ? null
                                        : () => _submitAgree(
                                              canSubmitThisClaim,
                                              availabilityMsg,
                                              periodLabel,
                                            ),
                                    child: Text(_agreeSubmitting ? 'Submitting…' : 'Agree & Submit'),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: OutlinedButton(
                                    style: OutlinedButton.styleFrom(
                                      padding: const EdgeInsets.symmetric(vertical: 14),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(14),
                                      ),
                                    ),
                                    onPressed: (_agreeSubmitting || _disagreeSubmitting)
                                        ? null
                                        : () async {
                                            if (!canSubmitThisClaim) {
                                              await _showClaimUnavailableDialog(
                                                availabilityMessage: availabilityMsg,
                                                periodLabel: periodLabel,
                                              );
                                              return;
                                            }
                                            setState(() {
                                              _showDisputeForm = !_showDisputeForm;
                                            });
                                          },
                                    child: const Text('Dispute Distance'),
                                  ),
                                ),
                              ],
                            ),
                            if (_showDisputeForm) ...[
                              const SizedBox(height: 16),
                              const Divider(),
                              const SizedBox(height: 8),
                              TextField(
                                controller: _correctedKmCtrl,
                                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                decoration: InputDecoration(
                                  labelText: 'Corrected Distance (km)',
                                  errorText: _correctedKmError,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _remarksCtrl,
                                minLines: 2,
                                maxLines: 4,
                                decoration: InputDecoration(
                                  labelText: 'Reason / Remarks',
                                  errorText: _remarksError,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: double.infinity,
                                child: FilledButton.tonal(
                                  style: FilledButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(vertical: 14),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(14),
                                    ),
                                  ),
                                  onPressed: (_agreeSubmitting || _disagreeSubmitting)
                                      ? null
                                      : () => _submitDisagree(
                                            canSubmitThisClaim,
                                            availabilityMsg,
                                            periodLabel,
                                          ),
                                  child: Text(_disagreeSubmitting ? 'Submitting…' : 'Submit Dispute'),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],

                  const SizedBox(height: 16),
                  _PastClaimPeriodsCard(highlightMonthKey: monthKey),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
    this.isHighlight = false,
  });

  final String label;
  final String value;
  final bool isHighlight;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: isHighlight ? 18 : 15,
            fontWeight: isHighlight ? FontWeight.w800 : FontWeight.w600,
            color: isHighlight ? scheme.primary : scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

class _PastClaimPeriodsCard extends ConsumerWidget {
  const _PastClaimPeriodsCard({required this.highlightMonthKey});

  final String highlightMonthKey;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final historyAsync = ref.watch(myClaimDistanceHistoryProvider);

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Past Claim Periods',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Historical distance logs for previous claim periods',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            historyAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
              error: (e, _) => Text(
                'Could not load distance history.',
                style: TextStyle(color: scheme.error, fontSize: 13),
              ),
              data: (rows) {
                if (rows.isEmpty) {
                  return Text(
                    'No past claims recorded.',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                  );
                }
                return ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) => const Divider(height: 12),
                  itemBuilder: (context, index) {
                    final row = rows[index];
                    final mk = (row['monthKey'] ?? '').toString();
                    final km = row['systemDistanceKm'];
                    final status = (row['claimStatus'] ?? '—').toString();
                    final highlight = mk == highlightMonthKey;

                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: highlight
                            ? scheme.primaryContainer.withValues(alpha: 0.3)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                ClaimFormatters.formatMonthKey(mk),
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                  color: scheme.onSurface,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${km ?? 0} km logged',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                          PremiumStatusPill(
                            label: status,
                            color: ClaimFormatters.statusColor(scheme, status),
                            icon: Icons.flag_outlined,
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}