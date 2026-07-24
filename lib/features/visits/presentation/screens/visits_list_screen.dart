import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_constants.dart';
import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../../shared/widgets/screen_accent_backdrop.dart';
import '../../../auth/presentation/providers/auth_provider.dart';
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
  bool _isFabExtended = true;

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
    _searchDebounce = Timer(const Duration(milliseconds: 300), () {
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            dialogTheme: DialogThemeData(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
          child: child!,
        );
      },
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
      isScrollControlled: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.55,
          maxChildSize: 0.85,
          minChildSize: 0.35,
          builder: (_, controller) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  child: Row(
                    children: [
                      Text(
                        'Select Team Member',
                        style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.all(16),
                    children: [
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        leading: CircleAvatar(
                          backgroundColor: scheme.primaryContainer,
                          child: Icon(Icons.groups_rounded, color: scheme.onPrimaryContainer, size: 20),
                        ),
                        title: const Text('All Employees', style: TextStyle(fontWeight: FontWeight.w600)),
                        selected: _filters.employeeId == null,
                        selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.2),
                        onTap: () => Navigator.pop(ctx, null),
                      ),
                      const SizedBox(height: 8),
                      ...members.map(
                        (m) {
                          final isSelected = _filters.employeeId == m.id;
                          return ListTile(
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            leading: CircleAvatar(
                              backgroundColor: isSelected ? scheme.primary : scheme.surfaceContainerHighest,
                              child: Icon(
                                Icons.person_outline_rounded,
                                color: isSelected ? scheme.onPrimary : scheme.onSurfaceVariant,
                                size: 20,
                              ),
                            ),
                            title: Text(
                              m.displayLabel(showCompany: showCompany),
                              style: TextStyle(fontWeight: isSelected ? FontWeight.bold : FontWeight.w500),
                            ),
                            subtitle: m.departmentName != null && m.departmentName!.isNotEmpty
                                ? Text(m.departmentName!)
                                : null,
                            selected: isSelected,
                            selectedTileColor: scheme.primaryContainer.withValues(alpha: 0.2),
                            onTap: () => Navigator.pop(ctx, m.id),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
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
    final title = visit.clientName.isNotEmpty ? visit.clientName : visit.contractorName;
    final photo = _photoDisplayUrl(visit.photoUrl);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (_, scrollCtrl) {
            return ListView(
              controller: scrollCtrl,
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
              children: [
                if (photo.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(20),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
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
                  const SizedBox(height: 20),
                ],
                Text(
                  title.isNotEmpty ? title : 'Visit Details',
                  style: Theme.of(ctx).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: scheme.onSurface,
                      ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: visit.isNewVisit
                            ? scheme.primaryContainer
                            : scheme.tertiaryContainer,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            visit.isNewVisit ? Icons.fiber_new_rounded : Icons.replay_rounded,
                            size: 16,
                            color: visit.isNewVisit
                                ? scheme.onPrimaryContainer
                                : scheme.onTertiaryContainer,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            visit.isNewVisit ? 'New Visit' : 'Follow-up',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: visit.isNewVisit
                                  ? scheme.onPrimaryContainer
                                  : scheme.onTertiaryContainer,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amber.shade100,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.star_rounded, size: 16, color: Colors.amber.shade900),
                          const SizedBox(width: 6),
                          Text(
                            '${visit.rating} / 10 Rating',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _SheetRow(
                          icon: Icons.place_outlined,
                          label: 'Location',
                          value: '${visit.city}, ${visit.state}',
                        ),
                        if (visit.address.trim().isNotEmpty) ...[
                          const Divider(height: 24),
                          _SheetRow(
                            icon: Icons.home_work_outlined,
                            label: 'Address',
                            value: visit.address,
                          ),
                        ],
                        const Divider(height: 24),
                        _SheetRow(
                          icon: Icons.flag_outlined,
                          label: 'Purpose',
                          value: visit.purpose,
                        ),
                        if (visit.contactName.isNotEmpty) ...[
                          const Divider(height: 24),
                          _SheetRow(
                            icon: Icons.person_outline,
                            label: 'Contact Person',
                            value: visit.contactName,
                          ),
                        ],
                        if (visit.contactPhone.isNotEmpty) ...[
                          const Divider(height: 24),
                          _SheetRow(
                            icon: Icons.phone_outlined,
                            label: 'Phone Number',
                            value: visit.contactPhone,
                          ),
                        ],
                        if (visit.contactEmail.isNotEmpty) ...[
                          const Divider(height: 24),
                          _SheetRow(
                            icon: Icons.email_outlined,
                            label: 'Email',
                            value: visit.contactEmail,
                          ),
                        ],
                        if ((visit.notes ?? '').trim().isNotEmpty) ...[
                          const Divider(height: 24),
                          _SheetRow(
                            icon: Icons.notes_rounded,
                            label: 'Notes',
                            value: visit.notes!.trim(),
                          ),
                        ],
                        if (visit.followUpDate != null) ...[
                          const Divider(height: 24),
                          _SheetRow(
                            icon: Icons.event_available_outlined,
                            label: 'Follow-Up Date',
                            value: DateFormat('dd MMM yyyy').format(visit.followUpDate!),
                          ),
                        ],
                        const Divider(height: 24),
                        _SheetRow(
                          icon: Icons.event_rounded,
                          label: 'Visited On',
                          value: DateFormat('dd MMM yyyy · hh:mm a').format(visit.visitDate),
                        ),
                        if (visit.createdByName.isNotEmpty) ...[
                          const Divider(height: 24),
                          _SheetRow(
                            icon: Icons.badge_outlined,
                            label: 'Recorded By',
                            value: visit.createdByName,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildSearchBar(ColorScheme scheme) {
    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: TextField(
        controller: _searchCtrl,
        onChanged: _onSearchChanged,
        onSubmitted: (_) => _applyFilters(),
        style: TextStyle(color: scheme.onSurface, fontSize: 14, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: 'Search client, city, purpose…',
          hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.6), fontSize: 14),
          prefixIcon: Icon(Icons.search_rounded, color: scheme.primary, size: 22),
          suffixIcon: _searchCtrl.text.isNotEmpty
              ? IconButton(
                  icon: Icon(Icons.cancel_rounded, color: scheme.onSurfaceVariant, size: 18),
                  onPressed: _clearFilters,
                )
              : null,
          filled: true,
          fillColor: Colors.transparent,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: InputBorder.none,
          enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none,
        ),
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
      clipBehavior: Clip.none,
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
                child: FilterChip(
                  avatar: Icon(
                    Icons.person_search_rounded,
                    size: 16,
                    color: employeeLabel != null
                        ? scheme.onPrimaryContainer
                        : scheme.onSurfaceVariant,
                  ),
                  label: Text(employeeLabel ?? 'Employee'),
                  selected: employeeLabel != null,
                  onSelected: (_) => _showEmployeePicker(
                    teamMembers,
                    showCompany: showCompany,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  backgroundColor: scheme.surface,
                  selectedColor: scheme.primaryContainer,
                  side: BorderSide(
                    color: employeeLabel != null ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
            const SizedBox(width: 4),
          ],
          _FilterChip(
            label: 'New',
            selected: _filters.visitType == VisitTypeFilter.newVisit,
            onTap: () => _applyFilters(
              _filters.copyWith(
                visitType: _filters.visitType == VisitTypeFilter.newVisit
                    ? VisitTypeFilter.all
                    : VisitTypeFilter.newVisit,
              ),
            ),
          ),
          _FilterChip(
            label: 'Follow-up',
            selected: _filters.visitType == VisitTypeFilter.followup,
            onTap: () => _applyFilters(
              _filters.copyWith(
                visitType: _filters.visitType == VisitTypeFilter.followup
                    ? VisitTypeFilter.all
                    : VisitTypeFilter.followup,
              ),
            ),
          ),
          const SizedBox(width: 4),
          ActionChip(
            avatar: Icon(
              Icons.date_range_rounded,
              size: 16,
              color: _filters.startDate != null || _filters.endDate != null
                  ? scheme.primary
                  : scheme.onSurfaceVariant,
            ),
            label: Text(_dateRangeLabel()),
            onPressed: _pickDateRange,
            backgroundColor: scheme.surface,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            side: BorderSide(
              color: _filters.startDate != null || _filters.endDate != null
                  ? scheme.primary
                  : scheme.outlineVariant.withValues(alpha: 0.4),
            ),
          ),
          if (_filters.hasActiveFilters) ...[
            const SizedBox(width: 8),
            ActionChip(
              avatar: Icon(Icons.filter_alt_off_rounded, size: 16, color: scheme.error),
              label: Text('Clear', style: TextStyle(color: scheme.error, fontWeight: FontWeight.bold)),
              onPressed: _clearFilters,
              backgroundColor: scheme.errorContainer.withValues(alpha: 0.2),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide(color: scheme.error.withValues(alpha: 0.2)),
            ),
          ],
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
        child: NotificationListener<UserScrollNotification>(
          onNotification: (notification) {
            if (notification.direction == ScrollDirection.reverse && _isFabExtended) {
              setState(() => _isFabExtended = false);
            } else if (notification.direction == ScrollDirection.forward && !_isFabExtended) {
              setState(() => _isFabExtended = true);
            }
            return true;
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 12),
              // Filter & Search Section
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _buildSearchBar(scheme),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _filterChipRow(
                  scheme: scheme,
                  canFilterTeam: canFilterTeam,
                  teamMembers: teamMembers,
                  showCompany: showCompany,
                ),
              ),
              const SizedBox(height: 12),
              
              // Visits Count Indicator / Header
              if (listState != null)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Total Visits (${listState.visits.length})',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: scheme.onSurfaceVariant,
                              letterSpacing: 0.5,
                            ),
                      ),
                      if (_filters.hasActiveFilters)
                        Text(
                          'Filtered View',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: scheme.primary,
                          ),
                        ),
                    ],
                  ),
                ),
              const SizedBox(height: 6),

              Expanded(
                child: RefreshIndicator(
                  color: scheme.primary,
                  onRefresh: () => ref.read(visitsProvider.notifier).refresh(),
                  child: visitsAsync.when(
                    loading: () => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(vertical: 100),
                      children: [
                        Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: scheme.primary,
                          ),
                        ),
                      ],
                    ),
                    error: (error, _) => ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.all(24),
                      children: [
                        _ModernEmptyState(
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
                          (_filters.employeeId == null || _filters.employeeId!.isEmpty);

                      final companyByUserId = showCompany
                          ? <String, String>{
                              for (final m in teamMembers)
                                if (m.companyName != null && m.companyName!.trim().isNotEmpty)
                                  m.id: m.companyName!.trim(),
                            }
                          : const <String, String>{};

                      if (visits.isEmpty) {
                        return ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(24, 60, 24, 100),
                          children: [
                            _ModernEmptyState(
                              icon: Icons.explore_outlined,
                              title: _filters.hasActiveFilters
                                  ? 'No matching visits'
                                  : 'No visits recorded yet',
                              subtitle: _filters.hasActiveFilters
                                  ? 'Try adjusting your filters or search terms.'
                                  : 'Start logging your client meetings and field activities.',
                            ),
                          ],
                        );
                      }

                      return ListView.separated(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        itemCount: visits.length,
                        separatorBuilder: (context, index) => const SizedBox(height: 12),
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
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.of(context).pushNamed('/visits/add');
          if (context.mounted) {
            await ref.read(visitsProvider.notifier).refresh();
          }
        },
        elevation: 3,
        highlightElevation: 6,
        isExtended: _isFabExtended,
        backgroundColor: scheme.primary,
        foregroundColor: scheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        icon: const Icon(Icons.add_rounded, size: 22),
        label: const Text(
          'Add Visit',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 14,
            letterSpacing: 0.2,
          ),
        ),
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
      child: FilterChip(
        label: Text(
          label,
          style: TextStyle(
            fontWeight: selected ? FontWeight.bold : FontWeight.w500,
            fontSize: 13,
            color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
          ),
        ),
        selected: selected,
        onSelected: (_) => onTap(),
        backgroundColor: scheme.surface,
        selectedColor: scheme.primaryContainer,
        side: BorderSide(
          color: selected ? scheme.primary : scheme.outlineVariant.withValues(alpha: 0.4),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        showCheckmark: false,
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
    final title = visit.clientName.isNotEmpty ? visit.clientName : visit.contractorName;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.3)),
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Modern Image / Thumbnail Frame
                Stack(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: SizedBox(
                        width: 82,
                        height: 82,
                        child: photoUrl.isEmpty
                            ? Container(
                                color: scheme.surfaceContainerHighest,
                                child: Icon(
                                  Icons.image_not_supported_outlined,
                                  color: scheme.onSurfaceVariant.withValues(alpha: 0.6),
                                  size: 26,
                                ),
                              )
                            : Image.network(
                                photoUrl,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) => Container(
                                  color: scheme.surfaceContainerHighest,
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: scheme.onSurfaceVariant,
                                    size: 26,
                                  ),
                                ),
                                loadingBuilder: (c, w, p) {
                                  if (p == null) return w;
                                  return Center(
                                    child: SizedBox(
                                      width: 20,
                                      height: 20,
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
                    Positioned(
                      top: 6,
                      left: 6,
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: (visit.isNewVisit ? scheme.primary : scheme.tertiary),
                          borderRadius: BorderRadius.circular(6),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.1),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                        child: Text(
                          visit.isNewVisit ? 'NEW' : 'F/U',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.bold,
                            color: visit.isNewVisit ? scheme.onPrimary : scheme.onTertiary,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(width: 14),

                // Main Details Section
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title.isNotEmpty ? title : 'Unnamed visit',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 15,
                                    color: scheme.onSurface,
                                  ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          // Star Rating Chip
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                            decoration: BoxDecoration(
                              color: Colors.amber.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.amber.shade200),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.star_rounded, size: 13, color: Colors.amber.shade800),
                                const SizedBox(width: 2),
                                Text(
                                  '${visit.rating}',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 11,
                                    color: Colors.amber.shade900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(Icons.location_on_outlined, size: 14, color: scheme.primary),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${visit.city}, ${visit.state}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: scheme.onSurfaceVariant,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        visit.purpose,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                              fontSize: 12,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          if (showRecordedBy && visit.createdByName.isNotEmpty) ...[
                            Icon(Icons.badge_outlined, size: 13, color: scheme.secondary),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _recordedByLabel(),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.secondary,
                                ),
                              ),
                            ),
                          ] else const Spacer(),
                          Icon(Icons.schedule_rounded, size: 13, color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                          const SizedBox(width: 4),
                          Text(
                            DateFormat('dd MMM · h:mm a').format(visit.visitDate),
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ModernEmptyState extends StatelessWidget {
  const _ModernEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: scheme.primaryContainer.withValues(alpha: 0.3),
            shape: BoxShape.circle,
          ),
          child: Icon(
            icon,
            size: 48,
            color: scheme.primary,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
                color: scheme.onSurface,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
        ),
      ],
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: scheme.primaryContainer.withValues(alpha: 0.4),
          child: Icon(icon, size: 18, color: scheme.primary),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurface,
                      fontWeight: FontWeight.w500,
                      height: 1.3,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}