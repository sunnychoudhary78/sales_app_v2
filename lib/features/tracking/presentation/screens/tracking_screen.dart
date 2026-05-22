import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/utils/permission_utils.dart';
import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../../shared/widgets/screen_accent_backdrop.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../data/models/tracking_session_model.dart';
import '../providers/tracking_provider.dart';
import 'tracking_session_map_full_screen.dart';
import '../widgets/session_route_map_preview.dart';

class TrackingScreen extends ConsumerStatefulWidget {
  const TrackingScreen({super.key});

  @override
  ConsumerState<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends ConsumerState<TrackingScreen>
    with WidgetsBindingObserver {
  final _searchCtrl = TextEditingController();
  final _searchFocus = FocusNode();
  bool _searching = false;
  DateTime? _filterDate;
  String? _expandedSessionId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(trackingProvider.notifier).refreshStatus();
      ref.read(trackingProvider.notifier).fetchHistory();
    }
  }

  String _fmtDate(String? value) {
    if (value == null) return '—';
    final dt = DateTime.tryParse(value)?.toLocal();
    if (dt == null) return '—';
    return DateFormat('EEE, d MMM yyyy').format(dt);
  }

  String _fmtTime(String? value) {
    if (value == null) return '—';
    final dt = DateTime.tryParse(value)?.toLocal();
    if (dt == null) return '—';
    return DateFormat('h:mm a').format(dt);
  }

  String _workingDuration(String? inAt, String? outAt) {
    final inDt = inAt == null ? null : DateTime.tryParse(inAt)?.toLocal();
    final outDt = outAt == null ? null : DateTime.tryParse(outAt)?.toLocal();
    if (inDt == null || outDt == null || outDt.isBefore(inDt)) return '—';
    final d = outDt.difference(inDt);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.inHours)}:${two(d.inMinutes.remainder(60))}:${two(d.inSeconds.remainder(60))}';
  }

  List<TrackingSessionModel> _filtered(List<TrackingSessionModel> history) {
    var list = history;
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((item) {
        final name = (item.userDisplayName ?? '').toLowerCase();
        return name.contains(q);
      }).toList();
    }
    if (_filterDate != null) {
      final s = DateTime(_filterDate!.year, _filterDate!.month, _filterDate!.day);
      list = list.where((item) {
        final checkInStr = item.checkInAt;
        if (checkInStr == null) return false;
        final dDate = DateTime.tryParse(checkInStr)?.toLocal();
        if (dDate == null) return false;
        final d = DateTime(dDate.year, dDate.month, dDate.day);
        return d == s;
      }).toList();
    }
    return list;
  }

  InputDecoration _searchDecoration(ColorScheme scheme) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
      hintText: 'Filter by teammate name…',
      prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: .45)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: .65)),
      ),
    );
  }

  Future<void> _refresh() async {
    await ref.read(trackingProvider.notifier).refreshStatus();
    await ref.read(trackingProvider.notifier).fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(trackingProvider);
    final scheme = Theme.of(context).colorScheme;
    final rawUser = ref.watch(authProvider).rawUser;
    final canMapPreview = hasPermission(rawUser, 'visit.map.preview');

    final filtered = _filtered(s.history);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppSideDrawer(),
      appBar: SalesGlassAppBar(
        title: 'Daily tracking',
        showDrawer: true,
        actions: [
          IconButton(
            tooltip: _searching ? 'Close search' : 'Search & filter',
            icon: Icon(_searching ? Icons.search_off_rounded : Icons.search_rounded),
            onPressed: () {
              setState(() {
                _searching = !_searching;
                if (!_searching) {
                  _searchCtrl.clear();
                  _filterDate = null;
                  _searchFocus.unfocus();
                }
              });
            },
          ),
        ],
      ),
      body: ScreenAccentBackdrop(
        spot: DrawerRouteAccents.trackingTeal,
        spot2: DrawerRouteAccents.trackingCyan,
        child: RefreshIndicator(
        color: scheme.primary,
        onRefresh: _refresh,
        child: CustomScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(
              child: PremiumFeatureHeader(
                icon: Icons.route_rounded,
                title: 'Field day control',
                subtitle:
                    'Check in to record your route for visits and mileage. History shows each session with distance and duration.',
              ),
            ),
            if (_searching)
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: PremiumCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _searchCtrl,
                          focusNode: _searchFocus,
                          decoration: _searchDecoration(scheme),
                          onChanged: (_) => setState(() {}),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            ActionChip(
                              avatar: Icon(
                                Icons.calendar_month_rounded,
                                size: 18,
                                color: _filterDate != null
                                    ? scheme.onSecondaryContainer
                                    : scheme.onSurfaceVariant,
                              ),
                              label: Text(
                                _filterDate == null
                                    ? 'Pick day'
                                    : DateFormat('d MMM yyyy').format(_filterDate!),
                              ),
                              onPressed: () async {
                                final now = DateTime.now();
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _filterDate ?? now,
                                  firstDate: DateTime(now.year - 2),
                                  lastDate: DateTime(now.year + 2),
                                );
                                if (picked != null) {
                                  setState(() => _filterDate = picked);
                                }
                              },
                            ),
                            if (_filterDate != null || _searchCtrl.text.isNotEmpty)
                              ActionChip(
                                avatar: Icon(Icons.close_rounded,
                                    size: 18, color: scheme.error),
                                label: const Text('Clear'),
                                onPressed: () {
                                  setState(() {
                                    _searchCtrl.clear();
                                    _filterDate = null;
                                  });
                                },
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: PremiumCard(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: s.isTracking
                                  ? scheme.primary.withValues(alpha: 0.12)
                                  : scheme.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              s.isTracking
                                  ? Icons.play_circle_filled_rounded
                                  : Icons.pause_circle_outline_rounded,
                              size: 32,
                              color: s.isTracking ? scheme.primary : scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                PremiumStatusPill(
                                  label: s.isTracking ? 'Live session' : 'Checked out',
                                  color: s.isTracking ? scheme.tertiary : scheme.outline,
                                  icon: s.isTracking
                                      ? Icons.sensors_rounded
                                      : Icons.stop_circle_outlined,
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  s.isTracking
                                      ? 'You are checked in'
                                      : 'Start when you begin your route',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (s.isTracking) ...[
                        const SizedBox(height: 16),
                        Text(
                          s.durationText,
                          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.2,
                                color: scheme.primary,
                              ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Running time · stays in sync when you return to this screen',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.3,
                          ),
                        ),
                      ] else ...[
                        const SizedBox(height: 12),
                        Text(
                          'Check in sends your GPS with the session (same as classic Sales App).',
                          style: TextStyle(
                            color: scheme.onSurfaceVariant,
                            fontSize: 13,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: (s.isLoading || s.isTracking)
                            ? null
                            : () => ref.read(trackingProvider.notifier).checkIn(),
                        icon: s.isLoading && !s.isTracking
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onPrimary,
                                ),
                              )
                            : const Icon(Icons.login_rounded),
                        label: const Text('Check in'),
                        style: FilledButton.styleFrom(
                          backgroundColor: scheme.primary,
                          foregroundColor: scheme.onPrimary,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: (s.isLoading || !s.isTracking)
                            ? null
                            : () => ref.read(trackingProvider.notifier).checkOut(),
                        icon: s.isLoading && s.isTracking
                            ? SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: scheme.onSecondaryContainer,
                                ),
                              )
                            : const Icon(Icons.logout_rounded),
                        label: const Text('Check out'),
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: PremiumSectionTitle(
                  title: 'Recent history',
                  subtitle: '${filtered.length} session${filtered.length == 1 ? '' : 's'}',
                ),
              ),
            ),
            if (filtered.isEmpty)
              SliverFillRemaining(
                hasScrollBody: false,
                child: PremiumEmptyState(
                  icon: Icons.history_rounded,
                  title: s.history.isEmpty ? 'No sessions yet' : 'No matches',
                  subtitle: s.history.isEmpty
                      ? 'After your first check-in and check-out, your route summary appears here.'
                      : 'Try clearing search or the date filter.',
                ),
              )
            else
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                sliver: SliverList.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (context, index) =>
                      const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final closed = !item.isActive;
                    final workDur = closed
                        ? _workingDuration(item.checkInAt, item.checkOutAt)
                        : null;
                    final expanded = _expandedSessionId == item.id;

                    return PremiumCard(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if ((item.userDisplayName ?? '').trim().isNotEmpty) ...[
                            Row(
                              children: [
                                Icon(Icons.person_outline_rounded,
                                    size: 18, color: scheme.primary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    item.userDisplayName!.trim(),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      color: scheme.primary,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Divider(height: 1, color: scheme.outlineVariant),
                            const SizedBox(height: 10),
                          ],
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  _fmtDate(item.checkInAt),
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ),
                              PremiumStatusPill(
                                label: item.status.toUpperCase(),
                                color: closed ? scheme.outline : scheme.tertiary,
                                icon: closed
                                    ? Icons.flag_rounded
                                    : Icons.directions_run_rounded,
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          PremiumStatusPill(
                            label: '${item.totalDistanceKm.toStringAsFixed(2)} km',
                            color: scheme.secondary,
                            icon: Icons.straighten_rounded,
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: _TimeBlock(
                                  label: 'Check in',
                                  time: _fmtTime(item.checkInAt),
                                  icon: Icons.login_rounded,
                                  iconColor: scheme.tertiary,
                                ),
                              ),
                              Container(
                                width: 1,
                                height: 40,
                                color: scheme.outlineVariant,
                              ),
                              Expanded(
                                child: _TimeBlock(
                                  label: 'Check out',
                                  time: closed
                                      ? _fmtTime(item.checkOutAt)
                                      : 'Active',
                                  icon: Icons.logout_rounded,
                                  iconColor:
                                      closed ? scheme.error : scheme.tertiary,
                                ),
                              ),
                            ],
                          ),
                          if (closed &&
                              workDur != null &&
                              workDur != '—') ...[
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Icon(Icons.timer_outlined,
                                    size: 18, color: scheme.onSurfaceVariant),
                                const SizedBox(width: 8),
                                Text(
                                  'Working duration · $workDur',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (canMapPreview && item.id.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Wrap(
                              alignment: WrapAlignment.end,
                              spacing: 4,
                              runSpacing: 4,
                              children: [
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() {
                                      _expandedSessionId =
                                          expanded ? null : item.id;
                                    });
                                  },
                                  icon: Icon(
                                    expanded
                                        ? Icons.expand_less_rounded
                                        : Icons.map_rounded,
                                  ),
                                  label: Text(expanded ? 'Hide map' : 'Show map'),
                                ),
                                if (expanded)
                                  TextButton.icon(
                                    onPressed: () {
                                      Navigator.of(context).push(
                                        MaterialPageRoute<void>(
                                          builder: (_) =>
                                              TrackingSessionMapFullScreen(
                                            sessionId: item.id,
                                          ),
                                        ),
                                      );
                                    },
                                    icon: const Icon(Icons.open_in_full_rounded),
                                    label: const Text('Full screen'),
                                  ),
                              ],
                            ),
                            if (expanded) ...[
                              const SizedBox(height: 4),
                              SessionRouteMapPreview(sessionId: item.id),
                            ],
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      ),
    );
  }
}

class _TimeBlock extends StatelessWidget {
  const _TimeBlock({
    required this.label,
    required this.time,
    required this.icon,
    required this.iconColor,
  });

  final String label;
  final String time;
  final IconData icon;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  time,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
