import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../shared/utils/permission_utils.dart';
import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../../shared/widgets/screen_accent_backdrop.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../application/location_disclosure_coordinator.dart';
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
  DateTime? _filterDate;
  String? _expandedSessionId;

  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.trim().toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
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
    return DateFormat('d MMM, yyyy').format(dt);
  }

  String _fmtDay(String? value) {
    if (value == null) return 'Day —';
    final dt = DateTime.tryParse(value)?.toLocal();
    if (dt == null) return 'Day —';
    return DateFormat('EEEE').format(dt);
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
    return '${two(d.inHours)}h ${two(d.inMinutes.remainder(60))}m';
  }

  List<TrackingSessionModel> _filtered(List<TrackingSessionModel> history) {
    var list = history;

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

    if (_searchQuery.isNotEmpty) {
      list = list.where((item) {
        final userName = (item.userDisplayName ?? '').toLowerCase();
        final status = item.status.toLowerCase();
        final date = (item.checkInAt ?? '').toLowerCase();
        return userName.contains(_searchQuery) ||
            status.contains(_searchQuery) ||
            date.contains(_searchQuery);
      }).toList();
    }

    return list;
  }

  Future<void> _refresh() async {
    await ref.read(trackingProvider.notifier).refreshStatus();
    await ref.read(trackingProvider.notifier).fetchHistory();
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(trackingProvider);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final rawUser = ref.watch(authProvider).rawUser;

    final canMapPreview = hasPermission(rawUser, 'visit.map.preview');
    final filtered = _filtered(s.history);

    final activeSession = s.history.firstWhere(
      (item) => item.isActive,
      orElse: () => s.history.isNotEmpty
          ? s.history.first
          : TrackingSessionModel(
              id: '',
              checkInAt: null,
              checkOutAt: null,
              status: '',
              totalDistanceKm: 0.0,
            ),
    );

    return Scaffold(
      drawer: const AppSideDrawer(),
      appBar: SalesGlassAppBar(
        title: 'Tracking',
        showDrawer: true,
        actions: [
          IconButton(
            tooltip: 'Filter by date',
            icon: Icon(
              _filterDate == null
                  ? Icons.calendar_month_outlined
                  : Icons.event_available_rounded,
              color: _filterDate == null ? scheme.onSurface : scheme.primary,
            ),
            onPressed: () async {
              if (_filterDate != null) {
                setState(() => _filterDate = null);
                return;
              }
              final now = DateTime.now();
              final picked = await showDatePicker(
                context: context,
                initialDate: now,
                firstDate: DateTime(now.year - 2),
                lastDate: DateTime(now.year + 2),
              );
              if (picked != null) {
                setState(() => _filterDate = picked);
              }
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
              // 1. SEARCH BAR
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 22, 16, 12),
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by date or status...',
                      hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant.withOpacity(0.7),
                      ),
                      prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
                      suffixIcon: _searchQuery.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () => _searchController.clear(),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark 
                          ? scheme.surfaceContainerHigh 
                          : scheme.surfaceContainerHighest.withOpacity(0.5),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: isDark 
                            ? BorderSide(color: scheme.outlineVariant.withOpacity(0.3)) 
                            : BorderSide.none,
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: isDark 
                            ? BorderSide(color: scheme.outlineVariant.withOpacity(0.3)) 
                            : BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),

              // 2. HERO METRICS DASHBOARD
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? scheme.surfaceContainer : scheme.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: s.isTracking
                            ? scheme.primary
                            : (isDark 
                                ? scheme.outlineVariant.withOpacity(0.4) 
                                : scheme.outlineVariant.withOpacity(0.4)),
                        width: s.isTracking ? 1.5 : 1.0,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: isDark 
                              ? Colors.black.withOpacity(0.3) 
                              : Colors.black.withOpacity(0.04),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 10,
                                  height: 10,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: s.isTracking 
                                        ? const Color(0xFF00E676) // Vibrant green accent for dark
                                        : scheme.outline,
                                    boxShadow: s.isTracking ? [
                                      BoxShadow(
                                        color: const Color(0xFF00E676).withOpacity(0.5),
                                        blurRadius: 6,
                                      )
                                    ] : null,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  s.isTracking ? 'Active Session' : 'Shift Inactive',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: scheme.onSurface,
                                  ),
                                ),
                              ],
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: s.isTracking
                                    ? scheme.primaryContainer
                                    : (isDark ? scheme.surfaceContainerHighest : scheme.surfaceContainerHighest),
                                borderRadius: BorderRadius.circular(10),
                                border: isDark
                                    ? Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3))
                                    : null,
                              ),
                              child: Text(
                                s.isTracking ? 'LIVE' : 'CHECKED OUT',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.5,
                                  color: s.isTracking
                                      ? scheme.onPrimaryContainer
                                      : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        Row(
                          children: [
                            Expanded(
                              child: _HeroStatTile(
                                icon: Icons.timer_outlined,
                                label: 'Time Elapsed',
                                value: s.isTracking ? s.durationText : '00:00:00',
                                valueColor: s.isTracking 
                                    ? (isDark ? scheme.primaryContainer : scheme.primary) 
                                    : scheme.onSurface,
                              ),
                            ),
                            Container(
                              width: 1, 
                              height: 40, 
                              color: isDark 
                                  ? scheme.outlineVariant.withOpacity(0.4) 
                                  : scheme.outlineVariant.withOpacity(0.5)
                            ),
                            Expanded(
                              child: _HeroStatTile(
                                icon: Icons.straighten_rounded,
                                label: 'Distance',
                                value: '${activeSession.totalDistanceKm.toStringAsFixed(1)} Km',
                                valueColor: scheme.onSurface,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 3. ACTION BUTTONS
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                  child: Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: (s.isLoading || s.isTracking)
                              ? null
                              : () async {
                                  final ok = await LocationDisclosureCoordinator.ensureAccepted(
                                    context,
                                    ref,
                                  );
                                  if (!ok || !context.mounted) return;
                                  ref.read(trackingProvider.notifier).checkIn();
                                },
                          icon: s.isLoading && !s.isTracking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.play_arrow_rounded),
                          label: const Text('Check In'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: scheme.primary,
                            foregroundColor: scheme.onPrimary,
                            elevation: isDark ? 2 : 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: (s.isLoading || !s.isTracking)
                              ? null
                              : () => ref.read(trackingProvider.notifier).checkOut(),
                          icon: s.isLoading && s.isTracking
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.stop_rounded),
                          label: const Text('Check Out'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: scheme.onSurface,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            side: BorderSide(
                              color: isDark ? scheme.outline : scheme.outlineVariant,
                            ),
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

              // 4. SECTION HEADER
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Session History',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: scheme.onSurface,
                        ),
                      ),
                      Text(
                        '${filtered.length} total',
                        style: TextStyle(
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 5. TIMELINE LIST
              if (filtered.isEmpty)
                SliverFillRemaining(
                  hasScrollBody: false,
                  child: PremiumEmptyState(
                    icon: Icons.history_rounded,
                    title: s.history.isEmpty ? 'No tracking history' : 'No records found',
                    subtitle: s.history.isEmpty
                        ? 'Your check-in and check-out timeline will appear here.'
                        : 'Try changing your search query or date filter.',
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  sliver: SliverList.builder(
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];
                      final isLast = index == filtered.length - 1;
                      final closed = !item.isActive;
                      final workDur = closed
                          ? _workingDuration(item.checkInAt, item.checkOutAt)
                          : null;
                      final expanded = _expandedSessionId == item.id;

                      return _TimelineSessionNode(
                        item: item,
                        isLast: isLast,
                        dayTitle: _fmtDay(item.checkInAt),
                        dateStr: _fmtDate(item.checkInAt),
                        checkInTime: _fmtTime(item.checkInAt),
                        checkOutTime: closed ? _fmtTime(item.checkOutAt) : 'Active',
                        workDuration: workDur,
                        expanded: expanded,
                        canMapPreview: canMapPreview,
                        onToggleExpand: () {
                          setState(() {
                            _expandedSessionId = expanded ? null : item.id;
                          });
                        },
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

class _HeroStatTile extends StatelessWidget {
  const _HeroStatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.valueColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final Color valueColor;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: scheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w500,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}

class _TimelineSessionNode extends StatelessWidget {
  const _TimelineSessionNode({
    required this.item,
    required this.isLast,
    required this.dayTitle,
    required this.dateStr,
    required this.checkInTime,
    required this.checkOutTime,
    required this.workDuration,
    required this.expanded,
    required this.canMapPreview,
    required this.onToggleExpand,
  });

  final TrackingSessionModel item;
  final bool isLast;
  final String dayTitle;
  final String dateStr;
  final String checkInTime;
  final String checkOutTime;
  final String? workDuration;
  final bool expanded;
  final bool canMapPreview;
  final VoidCallback onToggleExpand;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 36,
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: item.isActive
                        ? scheme.primary
                        : (isDark ? scheme.surfaceContainerHigh : scheme.primaryContainer),
                    shape: BoxShape.circle,
                    border: isDark
                        ? Border.all(color: scheme.outlineVariant.withOpacity(0.5))
                        : null,
                  ),
                  child: Icon(
                    item.isActive
                        ? Icons.navigation_rounded
                        : Icons.check_circle_rounded,
                    size: 16,
                    color: item.isActive
                        ? scheme.onPrimary
                        : (isDark ? scheme.primary : scheme.onPrimaryContainer),
                  ),
                ),
                if (!isLast)
                  Expanded(
                    child: Container(
                      width: 2,
                      color: isDark 
                          ? scheme.outlineVariant.withOpacity(0.3) 
                          : scheme.outlineVariant.withOpacity(0.5),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isDark ? scheme.surfaceContainer : scheme.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: item.isActive
                        ? scheme.primary
                        : (isDark 
                            ? scheme.outlineVariant.withOpacity(0.3) 
                            : scheme.outlineVariant.withOpacity(0.4)),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$dayTitle Session',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color: scheme.onSurface,
                              ),
                            ),
                            Text(
                              dateStr,
                              style: TextStyle(
                                fontSize: 11,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark 
                                ? scheme.surfaceContainerHigh 
                                : scheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(10),
                            border: isDark ? Border.all(color: scheme.outlineVariant.withOpacity(0.2)) : null,
                          ),
                          child: Text(
                            '${item.totalDistanceKm.toStringAsFixed(1)} Km',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark 
                            ? scheme.surfaceContainerLow 
                            : scheme.surfaceContainerHighest.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'IN: $checkInTime',
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface.withOpacity(0.9),
                            ),
                          ),
                          if (workDuration != null)
                            Text(
                              workDuration!,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                          Text(
                            'OUT: $checkOutTime',
                            style: TextStyle(
                              fontSize: 11, 
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurface.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (canMapPreview && item.id.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: onToggleExpand,
                        child: Row(
                          children: [
                            Icon(
                              expanded ? Icons.map_rounded : Icons.unfold_more_rounded,
                              size: 14,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              expanded ? 'Hide Map' : 'Preview Route',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: scheme.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (expanded) ...[
                        const SizedBox(height: 8),
                        SessionRouteMapPreview(
                          sessionId: item.id,
                          height: 160,
                          checkInAt: item.checkInAt,
                          checkOutAt: item.checkOutAt,
                          totalDistanceKm: item.totalDistanceKm,
                          sessionStatus: item.status,
                        ),
                      ],
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}