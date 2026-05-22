import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/network/api_constants.dart';
import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../../shared/widgets/screen_accent_backdrop.dart';
import '../../data/models/visit_model.dart';
import '../providers/visits_providers.dart';

class VisitsListScreen extends ConsumerStatefulWidget {
  const VisitsListScreen({super.key});

  @override
  ConsumerState<VisitsListScreen> createState() => _VisitsListScreenState();
}

class _VisitsListScreenState extends ConsumerState<VisitsListScreen> {
  final _searchCtrl = TextEditingController();
  DateTime? _selectedDate;
  String _visitType = 'all';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  String _photoDisplayUrl(String photoUrl) {
    final u = photoUrl.trim();
    if (u.isEmpty) return '';
    if (u.startsWith('http://') || u.startsWith('https://')) return u;
    final base = ApiConstants.baseUrl.replaceAll(RegExp(r'/api/?$'), '');
    if (u.startsWith('/')) return '$base$u';
    return '$base/$u';
  }

  List<VisitModel> _applyFilters(List<VisitModel> visits) {
    var list = visits;
    final q = _searchCtrl.text.trim().toLowerCase();
    if (q.isNotEmpty) {
      list = list.where((v) {
        return v.clientName.toLowerCase().contains(q) ||
            v.contractorName.toLowerCase().contains(q) ||
            v.city.toLowerCase().contains(q) ||
            v.state.toLowerCase().contains(q) ||
            v.purpose.toLowerCase().contains(q) ||
            v.contactName.toLowerCase().contains(q);
      }).toList();
    }
    if (_selectedDate != null) {
      final d = _selectedDate!;
      list = list.where((v) {
        final dt = v.createdAt;
        return dt.year == d.year && dt.month == d.month && dt.day == d.day;
      }).toList();
    }
    if (_visitType == 'new') {
      list = list.where((v) => v.isNewVisit).toList();
    } else if (_visitType == 'followup') {
      list = list.where((v) => !v.isNewVisit).toList();
    }
    return list;
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
                  icon: Icons.schedule_rounded,
                  label: 'Logged',
                  value: DateFormat('dd MMM yyyy · hh:mm a').format(visit.createdAt),
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

  @override
  Widget build(BuildContext context) {
    final visitsAsync = ref.watch(visitsProvider);
    final scheme = Theme.of(context).colorScheme;

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
            subtitle:
                'Filter by type or day, search parties and locations, then open a card for the full story.',
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: PremiumCard(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: TextField(
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: _searchDecoration(context, scheme),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'All',
                    selected: _visitType == 'all',
                    onTap: () => setState(() => _visitType = 'all'),
                  ),
                  _FilterChip(
                    label: 'New',
                    selected: _visitType == 'new',
                    onTap: () => setState(() => _visitType = 'new'),
                  ),
                  _FilterChip(
                    label: 'Follow-up',
                    selected: _visitType == 'followup',
                    onTap: () => setState(() => _visitType = 'followup'),
                  ),
                  const SizedBox(width: 8),
                  ActionChip(
                    avatar: Icon(
                      Icons.calendar_month_rounded,
                      size: 18,
                      color: _selectedDate != null
                          ? scheme.onSecondaryContainer
                          : scheme.onSurfaceVariant,
                    ),
                    label: Text(
                      _selectedDate == null
                          ? 'Any day'
                          : DateFormat('d MMM').format(_selectedDate!),
                    ),
                    onPressed: () async {
                      final now = DateTime.now();
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _selectedDate ?? now,
                        firstDate: DateTime(now.year - 2),
                        lastDate: DateTime(now.year + 2),
                      );
                      if (picked != null) {
                        setState(() => _selectedDate = picked);
                      }
                    },
                  ),
                  if (_selectedDate != null ||
                      _visitType != 'all' ||
                      _searchCtrl.text.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ActionChip(
                        avatar: Icon(Icons.filter_alt_off_rounded,
                            size: 18, color: scheme.error),
                        label: const Text('Clear'),
                        onPressed: () {
                          setState(() {
                            _searchCtrl.clear();
                            _selectedDate = null;
                            _visitType = 'all';
                          });
                        },
                      ),
                    ),
                ],
              ),
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
                data: (visits) {
                  final filtered = _applyFilters(visits);
                  if (filtered.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 100),
                      children: [
                        PremiumEmptyState(
                          icon: Icons.travel_explore_rounded,
                          title: visits.isEmpty ? 'No visits yet' : 'No matches',
                          subtitle: visits.isEmpty
                              ? 'Log your first visit to see it here with photo, rating, and location.'
                              : 'Try widening search or clearing filters.',
                        ),
                      ],
                    );
                  }
                  return ListView.separated(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                    itemCount: filtered.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (_, index) => _VisitCard(
                      visit: filtered[index],
                      photoUrl: _photoDisplayUrl(filtered[index].photoUrl),
                      onTap: () => _openVisitSheet(filtered[index]),
                    ),
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
  });

  final VisitModel visit;
  final String photoUrl;
  final VoidCallback onTap;

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
                      DateFormat('dd MMM · h:mm a').format(visit.createdAt),
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
