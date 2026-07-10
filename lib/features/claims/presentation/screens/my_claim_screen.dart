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

/// Monthly distance claim — parity with legacy Sales App + [salesvisitpro_api] `claimController`.
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
        title: const Text('Claims not available today'),
        content: Text(
          '${availabilityMessage.trim()}\n\n'
          'Distance for this claim covers: $periodLabel.',
          style: TextStyle(color: scheme.onSurfaceVariant, height: 1.35),
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
        () => _advanceError =
            'Enter a valid advance payment (or leave blank for 0)',
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
          () => _extraExpenseError = 'Enter a type for each extra expense',
        );
        return null;
      }
      final amount = double.tryParse(amountText);
      if (amount == null || amount <= 0) {
        setState(
          () => _extraExpenseError =
              'Enter a valid amount for each extra expense',
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
        return 'Submitted — awaiting manager review (advance or extra expenses).';
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
      ).showSnackBar(const SnackBar(content: Text('Claim submitted')));
      ref.invalidate(myClaimPreviewProvider);
    } on DioException catch (e) {
      if (!mounted) return;
      final msg = _dioMessage(e);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
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
      remarkErr = 'Remarks are required when you disagree';
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
      appBar: const SalesGlassAppBar(title: 'My claim', showDrawer: true),
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
                ? '${ClaimFormatters.formatYmdToDmy(monthStart)} to ${ClaimFormatters.formatYmdToDmy(monthEnd)}'
                : '—';
            final canSubmitToday = d['canSubmitToday'] == true;
            final availabilityMsg =
                (d['claimAvailabilityMessage'] ??
                        'Claim submission is not available today.')
                    .toString();

            final vehicleRaw = (d['vehicleType'] ?? 'two_wheeler').toString();
            final vehicleLabel = vehicleRaw == 'four_wheeler'
                ? 'Four wheeler'
                : 'Two wheeler';
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
                : (claim == null ? 'Not submitted' : '—');
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
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  PremiumFeatureHeader(
                    icon: Icons.receipt_long_rounded,
                    title: 'Monthly distance claim',
                    subtitle:
                        'Same window as the classic app: submit or dispute during allowed calendar days; amounts use your tracking sessions in the period below.',
                  ),
                  ClaimAvailabilityBanner(
                    message: availabilityMsg,
                    canSubmitToday: canSubmitToday,
                  ),
                  PremiumCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(
                                ClaimFormatters.formatMonthKey(monthKey),
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w800),
                              ),
                            ),
                            PremiumStatusPill(
                              label: headerStatus,
                              color: ClaimFormatters.statusColor(
                                scheme,
                                headerStatus,
                              ),
                              icon: Icons.flag_outlined,
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Period: $periodLabel',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
                        ),
                        if (claimId != null && claimId.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              'Reference: $claimId',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant.withValues(
                                  alpha: 0.85,
                                ),
                              ),
                            ),
                          ),
                        if (statusGuidance.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              statusGuidance,
                              style: TextStyle(
                                fontSize: 12,
                                color: scheme.onSurfaceVariant,
                                height: 1.35,
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        ClaimInfoLine(label: 'Vehicle (current)', value: vehicleLabel),
                        ClaimInfoLine(
                          label: 'System distance (km)',
                          value: systemKm?.toString() ?? '0',
                        ),
                        ClaimInfoLine(
                          label: 'Rate / km (current)',
                          value: ClaimFormatters.money(rate),
                        ),
                        ClaimInfoLine(
                          label: 'Calculated amount',
                          value: ClaimFormatters.money(calculated),
                          emphasize: claim == null,
                        ),
                      ],
                    ),
                  ),
                  if (claim != null) ...[
                    const SizedBox(height: 14),
                    ClaimDistanceComparisonCard(
                      systemKm: claim['systemDistanceKm'] ?? systemKm,
                      userKm: userKm,
                      approvedKm: approvedKm,
                      ratePerKm: rateSnapshot,
                    ),
                    const SizedBox(height: 14),
                    ClaimFinancialBreakdownCard(
                      claim: claim,
                      previewCalculatedAmount: calculated,
                      previewSystemKm: systemKm,
                      previewRate: rate,
                    ),
                    const SizedBox(height: 14),
                    ClaimSnapshotCard(claim: claim),
                    const SizedBox(height: 14),
                    ClaimTimestampsCard(claim: claim),
                    const SizedBox(height: 14),
                    ClaimRemarksCard(
                      employeeRemarks: remarks,
                      managerRemarks: managerRemarks,
                    ),
                    const SizedBox(height: 14),
                    ClaimActivityTimeline(claim: claim),
                  ],
                  const SizedBox(height: 14),
                  _PastClaimPeriodsCard(highlightMonthKey: monthKey),
                  if (canShowSubmitActions) ...[
                    const SizedBox(height: 14),
                    PremiumCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            'Submit',
                            style: Theme.of(context).textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            statusLower == 'rejected'
                                ? 'Your manager rejected this claim. Update and resubmit; the review loop stays open until approval.'
                                : 'Advance or extra expenses send the claim to your manager first (same as classic app).',
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                              height: 1.3,
                            ),
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: _advanceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            onChanged: (_) {
                              if (_advanceError != null) {
                                setState(() => _advanceError = null);
                              }
                            },
                            decoration: InputDecoration(
                              labelText: 'Advance payment (optional)',
                              errorText: _advanceError,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Extra expenses (optional)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: scheme.onSurface,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...List.generate(_extraDrafts.length, (index) {
                            final draft = _extraDrafts[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: draft.typeCtrl,
                                      decoration: InputDecoration(
                                        labelText: 'Type',
                                        hintText: 'Food, hotel…',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: TextField(
                                      controller: draft.amountCtrl,
                                      keyboardType:
                                          const TextInputType.numberWithOptions(
                                            decimal: true,
                                          ),
                                      decoration: InputDecoration(
                                        labelText: 'Amount',
                                        border: OutlineInputBorder(
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    tooltip: 'Remove',
                                    onPressed: _extraDrafts.length == 1
                                        ? null
                                        : () => setState(() {
                                            final r = _extraDrafts.removeAt(
                                              index,
                                            );
                                            r.dispose();
                                          }),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
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
                                style: TextStyle(
                                  color: scheme.error,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          Align(
                            alignment: Alignment.centerLeft,
                            child: TextButton.icon(
                              onPressed: () => setState(
                                () => _extraDrafts.add(_ExtraExpenseDraft()),
                              ),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add extra expense'),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed:
                                      (_agreeSubmitting || _disagreeSubmitting)
                                      ? null
                                      : () => _submitAgree(
                                          canSubmitThisClaim,
                                          availabilityMsg,
                                          periodLabel,
                                        ),
                                  child: Text(
                                    _agreeSubmitting ? 'Submitting…' : 'Agree',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton(
                                  onPressed:
                                      (_agreeSubmitting || _disagreeSubmitting)
                                      ? null
                                      : () async {
                                          if (!canSubmitThisClaim) {
                                            await _showClaimUnavailableDialog(
                                              availabilityMessage:
                                                  availabilityMsg,
                                              periodLabel: periodLabel,
                                            );
                                            return;
                                          }
                                          setState(() {
                                            _showDisputeForm =
                                                !_showDisputeForm;
                                          });
                                        },
                                  child: const Text('Disagree'),
                                ),
                              ),
                            ],
                          ),
                          if (_showDisputeForm) ...[
                            const SizedBox(height: 14),
                            TextField(
                              controller: _correctedKmCtrl,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                              onChanged: (_) {
                                if (_correctedKmError != null) {
                                  setState(() => _correctedKmError = null);
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Corrected distance (km)',
                                errorText: _correctedKmError,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 10),
                            TextField(
                              controller: _remarksCtrl,
                              minLines: 2,
                              maxLines: 4,
                              onChanged: (_) {
                                if (_remarksError != null) {
                                  setState(() => _remarksError = null);
                                }
                              },
                              decoration: InputDecoration(
                                labelText: 'Remarks',
                                errorText: _remarksError,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                              ),
                            ),
                            const SizedBox(height: 12),
                            FilledButton.tonal(
                              onPressed:
                                  (_agreeSubmitting || _disagreeSubmitting)
                                  ? null
                                  : () => _submitDisagree(
                                      canSubmitThisClaim,
                                      availabilityMsg,
                                      periodLabel,
                                    ),
                              child: Text(
                                _disagreeSubmitting
                                    ? 'Submitting…'
                                    : 'Submit dispute',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ] else ...[
                    const SizedBox(height: 12),
                    Text(
                      'This claim period is already in progress or completed. '
                      'If it was rejected, you can submit again after the server updates the status.',
                      style: TextStyle(
                        fontSize: 13,
                        color: scheme.onSurfaceVariant,
                        height: 1.35,
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        ),
      ),
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

    return PremiumCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Past claim periods',
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tracked km per claim period — use this when preparing your monthly claim.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant, height: 1.35),
          ),
          const SizedBox(height: 12),
          historyAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
            ),
            error: (e, _) => Text(
              'Could not load distance history.',
              style: TextStyle(color: scheme.error, fontSize: 13),
            ),
            data: (rows) {
              if (rows.isEmpty) {
                return Text(
                  'No distance history yet.',
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13),
                );
              }
              return Column(
                children: [
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Month',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 3,
                        child: Text(
                          'Period',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(
                          'Km',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      Expanded(
                        flex: 2,
                        child: Text(
                          'Claim',
                          textAlign: TextAlign.right,
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                  ...rows.map((row) {
                    final mk = (row['monthKey'] ?? '').toString();
                    final start = (row['monthStart'] ?? '').toString();
                    final end = (row['monthEnd'] ?? '').toString();
                    final km = row['systemDistanceKm'];
                    final status = (row['claimStatus'] ?? '—').toString();
                    final highlight = mk == highlightMonthKey;
                    final statusColor = status == '—'
                        ? scheme.onSurfaceVariant
                        : ClaimFormatters.statusColor(scheme, status);
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      decoration: BoxDecoration(
                        color: highlight
                            ? scheme.primaryContainer.withValues(alpha: 0.45)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 2,
                            child: Text(
                              ClaimFormatters.formatMonthKey(mk),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: highlight ? FontWeight.w800 : FontWeight.w600,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 3,
                            child: Text(
                              start.isNotEmpty && end.isNotEmpty
                                  ? '${ClaimFormatters.formatYmdToDmy(start)} → ${ClaimFormatters.formatYmdToDmy(end)}'
                                  : '—',
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                          Expanded(
                            child: Text(
                              km != null ? '${num.tryParse(km.toString())?.toStringAsFixed(2) ?? km}' : '0',
                              textAlign: TextAlign.right,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Expanded(
                            flex: 2,
                            child: Text(
                              status,
                              textAlign: TextAlign.right,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: statusColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

