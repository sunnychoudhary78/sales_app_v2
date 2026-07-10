import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_constants.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../../shared/widgets/screen_accent_backdrop.dart';
import '../../data/models/visit_filter_state.dart';
import '../../data/models/visit_model.dart';
import '../providers/visits_providers.dart';

class VisitsListScreen extends ConsumerStatefulWidget {
  const VisitsListScreen({super.key});

  @override
  ConsumerState<VisitsListScreen> createState() => _VisitsListScreenState();
}

class _VisitsListScreenState extends ConsumerState<VisitsListScreen> {
  final _searchCtrl = TextEditingController();
  VisitListFilters _filters = const VisitListFilters();
  Timer? _searchDebounce;

  @override
  void dispose() {
    _searchDebounce?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _applyFilters([VisitListFilters? next]) {
    final merged = (next ?? _filters).copyWith(search: _searchCtrl.text.trim());
    setState(() => _filters = merged);
    ref.read(visitsProvider.notifier).applyFilters(merged);
  }

  void _clearFilters() {
    _searchDebounce?.cancel();
    _searchCtrl.clear();
    setState(() => _filters = const VisitListFilters());
    ref.read(visitsProvider.notifier).applyFilters(const VisitListFilters());
  }

  void _onSearchChanged(String value) {
    _searchDebounce?.cancel();
    _searchDebounce = Timer(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      _applyFilters(_filters.copyWith(search: value.trim()));
    });
  }

  String _photoDisplayUrl(String photoUrl) {
    final u = photoUrl.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    if (u.startsWith('/')) return '$base$u';
    return '$base/$u';
  }

  String _dateRangeLabel() {
    if (_filters.startDate == null && _filters.endDate == null) return 'Date range';
    final fmt = DateFormat('d MMM');
    if (_filters.startDate != null && _filters.endDate != null) {
      return '${fmt.format(_filters.startDate!)} – ${fmt.format(_filters.endDate!)}';
    }
    if (_filters.startDate != null) {
      return 'From ${fmt.format(_filters.startDate!)}';
    }
    return 'Until ${fmt.format(_filters.endDate!)}';
  }

  String? _employeeLabel(
    List<VisitTeamMember> members, {
    required bool showCompany,
  }) {
    if (_filters.employeeId == null || _filters.employeeId!.isEmpty) return null;
    for (final m in members) {
      if (m.id == _filters.employeeId) {
        return m.displayLabel(showCompany: showCompany);
      }
    }
    return 'Employee';
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 2),
      initialDateRange: _filters.startDate != null && _filters.endDate != null
          ? DateTimeRange(start: _filters.startDate!, end: _filters.endDate!)
          : DateTimeRange(
              start: now.subtract(const Duration(days: 7)),
              end: now,
            ),
    );
    if (picked == null || !mounted) return;
    _applyFilters(
      _filters.copyWith(
        startDate: picked.start,
        endDate: picked.end,
      ),
    );
  }

  Future<void> _showEmployeePicker(
    List<VisitTeamMember> members, {
    required bool showCompany,
  }) async {
    if (members.isEmpty) return;
    final scheme = Theme.of(context).colorScheme;
    final selected = await showModalBottomSheet<String?>(
      context: context,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
            children: [
              ListTile(
                leading: const Icon(Icons.groups_rounded),
                title: const Text('All employees'),
                selected: _filters.employeeId == null,
                onTap: () => Navigator.pop(ctx, null),
              ),
              const Divider(height: 1),
              ...members.map(
                (m) => ListTile(
                  leading: const Icon(Icons.person_outline_rounded),
                  title: Text(m.displayLabel(showCompany: showCompany)),
                  subtitle: m.departmentName != null && m.departmentName!.isNotEmpty
                      ? Text(m.departmentName!)
                      : null,
                  selected: _filters.employeeId == m.id,
                  onTap: () => Navigator.pop(ctx, m.id),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted) return;
    _applyFilters(
      _filters.copyWith(
        employeeId: selected,
        clearEmployeeId: selected == null,
        scope: VisitScope.all,
      ),
    );
  }

  void _openVisitSheet(VisitModel visit) {
    final scheme = Theme.of(context).colorScheme;
    final title =
        visit.clientName.isNotEmpty ? visit.clientName : visit.contractorName;
    final photo = _photoDisplayUrl(visit.photoUrl);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.72,
          minChildSize: 0.45,
          maxChildSize: 0.94,
          builder: (_, scrollCtrl) {
            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
              children: [
                Text(
                  title.isNotEmpty ? title : 'Visit',
                  style: Theme.of(ctx).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    PremiumStatusPill(
                      label: visit.isNewVisit ? 'New visit' : 'Follow-up',
                      color: visit.isNewVisit
                          ? scheme.primary
                          : scheme.tertiary,
                      icon: visit.isNewVisit
                          ? Icons.fiber_new_rounded
                          : Icons.reply_rounded,
                    ),
                    PremiumStatusPill(
                      label: '${visit.rating}/10',
                      color: scheme.secondary,
                      icon: Icons.star_rounded,
                    ),
                  ],
                ),
                if (photo.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 10,
                      child: Image.network(
                        photo,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: scheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.broken_image_outlined,
                            size: 48,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        loadingBuilder: (c, w, p) {
                          if (p == null) return w;
                          return Center(
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                _SheetRow(
                  icon: Icons.place_outlined,
                  label: 'Location',
                  value: '${visit.city}, ${visit.state}',
                ),
                if (visit.address.trim().isNotEmpty)
                  _SheetRow(
                    icon: Icons.home_work_outlined,
                    label: 'Address',
                    value: visit.address,
                  ),
                _SheetRow(
                  icon: Icons.flag_outlined,
                  label: 'Purpose',
                  value: visit.purpose,
                ),
                if (visit.contactName.isNotEmpty)
                  _SheetRow(
                    icon: Icons.person_outline,
                    label: 'Contact',
                    value: visit.contactName,
                  ),
                if (visit.contactPhone.isNotEmpty)
                  _SheetRow(
                    icon: Icons.phone_outlined,
                    label: 'Phone',
                    value: visit.contactPhone,
                  ),
                if (visit.contactEmail.isNotEmpty)
                  _SheetRow(
                    icon: Icons.email_outlined,
                    label: 'Email',
                    value: visit.contactEmail,
                  ),
                if ((visit.notes ?? '').trim().isNotEmpty)
                  _SheetRow(
                    icon: Icons.notes_rounded,
                    label: 'Notes',
                    value: visit.notes!.trim(),
                  ),
                if (visit.followUpDate != null)
                  _SheetRow(
                    icon: Icons.event_available_outlined,
                    label: 'Follow-up',
                    value: DateFormat('dd MMM yyyy').format(visit.followUpDate!),
                  ),
                _SheetRow(
                  icon: Icons.event_rounded,
                  label: 'Visit date',
                  value: DateFormat('dd MMM yyyy · hh:mm a').format(visit.visitDate),
                ),
                if (visit.createdByName.isNotEmpty)
                  _SheetRow(
                    icon: Icons.badge_outlined,
                    label: 'Recorded by',
                    value: visit.createdByName,
                  ),
              ],
            );
          },
        );
      },
    );
  }

  InputDecoration _searchDecoration(BuildContext context, ColorScheme scheme) {
    return InputDecoration(
      isDense: true,
      filled: true,
      fillColor: scheme.surfaceContainerHighest.withValues(alpha: 0.65),
      hintText: 'Search client, city, purpose…',
      prefixIcon: Icon(Icons.search_rounded, color: scheme.primary),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.outlineVariant.withValues(alpha: .4)),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: scheme.primary.withValues(alpha: .65)),
      ),
    );
  }

  Widget _filterChipRow({
    required ColorScheme scheme,
    required bool canFilterTeam,
    required List<VisitTeamMember> teamMembers,
    required bool showCompany,
  }) {
    final employeeLabel = _employeeLabel(teamMembers, showCompany: showCompany);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (canFilterTeam) ...[
            _FilterChip(
              label: 'All',
              selected: _filters.scope == VisitScope.all &&
                  (_filters.employeeId == null || _filters.employeeId!.isEmpty),
              onTap: () => _applyFilters(
                _filters.copyWith(scope: VisitScope.all, clearEmployeeId: true),
              ),
            ),
            _FilterChip(
              label: 'My visits',
              selected: _filters.scope == VisitScope.mine &&
                  (_filters.employeeId == null || _filters.employeeId!.isEmpty),
              onTap: () => _applyFilters(
                _filters.copyWith(scope: VisitScope.mine, clearEmployeeId: true),
              ),
            ),
            _FilterChip(
              label: 'Team',
              selected: _filters.scope == VisitScope.team &&
                  (_filters.employeeId == null || _filters.employeeId!.isEmpty),
              onTap: () => _applyFilters(
                _filters.copyWith(scope: VisitScope.team, clearEmployeeId: true),
              ),
            ),
            if (teamMembers.length > 1)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ActionChip(
                  avatar: Icon(
                    Icons.person_search_rounded,
                    size: 18,
                    color: employeeLabel != null
                        ? scheme.onSecondaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  label: Text(
                    employeeLabel ?? 'Employee',
                    overflow: TextOverflow.ellipsis,
                  ),
                  onPressed: () => _showEmployeePicker(
                    teamMembers,
                    showCompany: showCompany,
                  ),
                ),
              ),
            const SizedBox(width: 4),
          ],
          _FilterChip(
            label: 'New',
            selected: _filters.visitType == VisitTypeFilter.newVisit,
            onTap: () => _applyFilters(
              _filters.copyWith(visitType: VisitTypeFilter.newVisit),
            ),
          ),
          _FilterChip(
            label: 'Follow-up',
            selected: _filters.visitType == VisitTypeFilter.followup,
            onTap: () => _applyFilters(
              _filters.copyWith(visitType: VisitTypeFilter.followup),
            ),
          ),
          if (_filters.visitType != VisitTypeFilter.all)
            _FilterChip(
              label: 'All types',
              selected: false,
              onTap: () => _applyFilters(
                _filters.copyWith(visitType: VisitTypeFilter.all),
              ),
            ),
          const SizedBox(width: 8),
          ActionChip(
            avatar: Icon(
              Icons.date_range_rounded,
              size: 18,
              color: _filters.startDate != null || _filters.endDate != null
                  ? scheme.onSecondaryContainer
                  : scheme.onSurfaceVariant,
            ),
            label: Text(_dateRangeLabel()),
            onPressed: _pickDateRange,
          ),
          if (_filters.hasActiveFilters)
            Padding(
              padding: const EdgeInsets.only(left: 6),
              child: ActionChip(
                avatar: Icon(Icons.filter_alt_off_rounded,
                    size: 18, color: scheme.error),
                label: const Text('Clear'),
                onPressed: _clearFilters,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(visitsProvider);
    final scheme = Theme.of(context).colorScheme;
    final listState = visitsAsync.asData?.value;
    final canFilterTeam = listState?.meta.canFilterTeam ?? false;
    final teamMembers = listState?.teamMembers ?? const [];
    final showCompany = ref.watch(companyContextProvider).spansMultipleCompanies;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppSideDrawer(),
      appBar: const SalesGlassAppBar(
        title: 'Visits',
        showDrawer: true,
      ),
      body: ScreenAccentBackdrop(
        spot: DrawerRouteAccents.visits,
        spot2: DrawerRouteAccents.visitsMagenta,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            PremiumFeatureHeader(
              icon: Icons.route_rounded,
              title: 'Field visit log',
              subtitle: canFilterTeam
                  ? 'Filter your visits, your team, or by employee, date range, and type.'
                  : 'Search parties and locations, filter by date or type, then open a card for details.',
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: PremiumCard(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  onSubmitted: (_) => _applyFilters(),
                  decoration: _searchDecoration(context, scheme),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _filterChipRow(
                scheme: scheme,
                canFilterTeam: canFilterTeam,
                teamMembers: teamMembers,
                showCompany: showCompany,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                color: scheme.primary,
                onRefresh: () => ref.read(visitsProvider.notifier).refresh(),
                child: visitsAsync.when(
                  loading: () => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.symmetric(vertical: 120),
                    children: [
                      Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: scheme.primary,
                        ),
                      ),
                    ],
                  ),
                  error: (error, _) => ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(24),
                    children: [
                      PremiumEmptyState(
                        icon: Icons.cloud_off_rounded,
                        title: 'Could not load visits',
                        subtitle: error.toString(),
                      ),
                    ],
                  ),
                  data: (state) {
                    final visits = state.visits;
                    final showRecordedBy = canFilterTeam &&
                        _filters.scope != VisitScope.mine &&
                        (_filters.employeeId == null ||
                            _filters.employeeId!.isEmpty);
                    final companyByUserId = showCompany
                        ? <String, String>{
                            for (final m in teamMembers)
                              if (m.companyName != null &&
                                  m.companyName!.trim().isNotEmpty)
                                m.id: m.companyName!.trim(),
                          }
                        : const <String, String>{};
                    if (visits.isEmpty) {
                      return ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
                        children: [
                          PremiumEmptyState(
                            icon: Icons.travel_explore_rounded,
                            title: _filters.hasActiveFilters
                                ? 'No matches'
                                : 'No visits yet',
                            subtitle: _filters.hasActiveFilters
                                ? 'Try widening search or clearing filters.'
                                : 'Log your first visit to see it here with photo, rating, and location.',
                          ),
                        ],
                      );
                    }
                    return ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                      itemCount: visits.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 12),
                      itemBuilder: (_, index) {
                        final visit = visits[index];
                        return _VisitCard(
                          visit: visit,
                          photoUrl: _photoDisplayUrl(visit.photoUrl),
                          showRecordedBy: showRecordedBy,
                          recordedByCompanyName: showCompany && showRecordedBy
                              ? companyByUserId[visit.createdById]
                              : null,
                          onTap: () => _openVisitSheet(visit),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).pushNamed('/visits/add');
          if (context.mounted) {
            await ref.read(visitsProvider.notifier).refresh();
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add visit'),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => onTap(),
        selectedColor: scheme.primaryContainer,
        labelStyle: TextStyle(
          fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
        ),
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _VisitCard extends StatelessWidget {
  const _VisitCard({
    required this.visit,
    required this.photoUrl,
    required this.onTap,
    this.showRecordedBy = false,
    this.recordedByCompanyName,
  });

  final VisitModel visit;
  final String photoUrl;
  final VoidCallback onTap;
  final bool showRecordedBy;
  final String? recordedByCompanyName;

  String _recordedByLabel() {
    final name = visit.createdByName.trim();
    final company = recordedByCompanyName?.trim();
    if (company != null && company.isNotEmpty) {
      return '$name · $company';
    }
    return name;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title =
        visit.clientName.isNotEmpty ? visit.clientName : visit.contractorName;
    final typeColor = visit.isNewVisit ? scheme.primary : scheme.tertiary;

    return PremiumCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 76,
              height: 76,
              child: photoUrl.isEmpty
                  ? ColoredBox(
                      color: scheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.image_not_supported_outlined,
                        color: scheme.onSurfaceVariant,
                      ),
                    )
                  : Image.network(
                      photoUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => ColoredBox(
                        color: scheme.surfaceContainerHighest,
                        child: Icon(
                          Icons.broken_image_outlined,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      loadingBuilder: (c, w, p) {
                        if (p == null) return w;
                        return Center(
                          child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: scheme.primary,
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title.isNotEmpty ? title : 'Unnamed visit',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                    ),
                    PremiumStatusPill(
                      label: visit.isNewVisit ? 'New' : 'F/U',
                      color: typeColor,
                      icon: visit.isNewVisit
                          ? Icons.fiber_new_rounded
                          : Icons.reply_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.place_outlined,
                        size: 15, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        '${visit.city}, ${visit.state}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: scheme.onSurfaceVariant,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  visit.purpose,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (showRecordedBy && visit.createdByName.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Icon(Icons.badge_outlined,
                          size: 14, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          _recordedByLabel(),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(Icons.star_rounded,
                        size: 16, color: scheme.secondary),
                    const SizedBox(width: 2),
                    Text(
                      '${visit.rating}/10',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Icon(Icons.schedule_rounded,
                        size: 15, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 4),
                    Text(
                      DateFormat('dd MMM · h:mm a').format(visit.visitDate),
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: scheme.outline),
        ],
      ),
    );
  }
}

class _SheetRow extends StatelessWidget {
  const _SheetRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: scheme.primary),
          const SizedBox(width: 12),
          Expanded(
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
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
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
