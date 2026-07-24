import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/models/home_models.dart';
import 'home_dashboard_chrome.dart';

/// Refined Color System for High Contrast & Modern Feel
abstract final class _TimelineTheme {
  static const Color visitNew = Color(0xFFD97706); // Amber
  static const Color visitFollowUp = Color(0xFF8B5CF6); // Purple
  static const Color checkIn = Color(0xFF10B981); // Emerald
  static const Color checkOut = Color(0xFF64748B); // Slate
  static const Color defaultAccent = Color(0xFF06B6D4); // Cyan
}

class HomeTimelineSection extends StatelessWidget {
  const HomeTimelineSection({super.key, required this.events});

  final List<TimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: HomeDashboardChrome.panelDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeDashboardChrome.sectionHeader(
            context,
            eyebrow: 'LOG',
            title: 'Activity Stream',
            subtitle: events.isEmpty
                ? 'Check-ins, visits, and session summaries appear here.'
                : 'Latest check-ins, visits, and session activity.',
            icon: Icons.timeline_rounded,
          ),
          const SizedBox(height: 20),
          if (events.isEmpty)
            _EmptyStateView(scheme: scheme)
          else
            _TimelineListView(events: events, scheme: scheme),
        ],
      ),
    );
  }
}

class _TimelineListView extends StatelessWidget {
  const _TimelineListView({required this.events, required this.scheme});

  final List<TimelineEvent> events;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final shown =
        events.length > 12 ? events.sublist(events.length - 12) : events;
    final list = shown.reversed.take(8).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _TimelineTile(
          event: list[index],
          scheme: scheme,
          isFirst: index == 0,
          isLast: index == list.length - 1,
        );
      },
    );
  }
}

class _TimelineTile extends StatelessWidget {
  const _TimelineTile({
    required this.event,
    required this.scheme,
    required this.isFirst,
    required this.isLast,
  });

  final TimelineEvent event;
  final ColorScheme scheme;
  final bool isFirst;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final style = _getEventStyle(event);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Timeline Node & Line Segment
          SizedBox(
            width: 28,
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    width: 2,
                    color: isFirst
                        ? Colors.transparent
                        : scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: style.accent,
                    // Note: Glow here is minimal and part of the node design,
                    // not the card. Keeping it for visual clarity of the event type.
                    boxShadow: [
                      BoxShadow(
                        color: style.accent.withValues(alpha: 0.4),
                        blurRadius: 8,
                        spreadRadius: 2,
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast
                        ? Colors.transparent
                        : scheme.outlineVariant.withValues(alpha: 0.3),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Event Content Card
          Expanded(
            child: _ModernEventCard(
              event: event,
              scheme: scheme,
              style: style,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernEventCard extends StatelessWidget {
  const _ModernEventCard({
    required this.event,
    required this.scheme,
    required this.style,
  });

  final TimelineEvent event;
  final ColorScheme scheme;
  final _EventStyle style;

  @override
  Widget build(BuildContext context) {
    final timeStr = DateFormat('MMM d · h:mm a').format(event.at.toLocal());
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        // Simplified ambient shadow, no accent glow
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.1 : 0.04),
            blurRadius: isDark ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Container(
          decoration: BoxDecoration(
            // Soft Gradient Surface Background adapted for theme
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                scheme.surfaceContainerHigh
                    .withValues(alpha: isDark ? 0.9 : 0.7),
                scheme.surfaceContainerLow.withValues(alpha: isDark ? 0.6 : 0.4),
              ],
            ),
            border: Border.all(
              color: scheme.outlineVariant
                  .withValues(alpha: isDark ? 0.15 : 0.25),
            ),
          ),
          child: IntrinsicHeight(
            child: Row(
              children: [
                // Minimalist Left Accent Bar (Glow Removed)
                Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: style.accent,
                  ),
                ),
                // Main Content Body
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Icon Container (Adapted for theme, glow removed)
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: style.accent
                                .withValues(alpha: isDark ? 0.15 : 0.12),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: style.accent
                                  .withValues(alpha: isDark ? 0.3 : 0.2),
                            ),
                          ),
                          child: Icon(
                            style.icon,
                            color: style.accent,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Details Column
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      event.label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurface,
                                      ),
                                    ),
                                  ),
                                  _StatusBadge(
                                    label: style.badgeLabel,
                                    color: style.accent,
                                    isDark: isDark,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Row(
                                children: [
                                  Icon(
                                    Icons.access_time_rounded,
                                    size: 13,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    timeStr,
                                    style: GoogleFonts.inter(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w500,
                                      color: scheme.onSurfaceVariant,
                                    ),
                                  ),
                                ],
                              ),
                              if (event.isCheckOut &&
                                  event.meta['total_distance_km'] != null) ...[
                                const SizedBox(height: 10),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                 ),
                                  decoration: BoxDecoration(
                                    color: scheme.surfaceContainerHighest
                                        .withValues(alpha: 0.5),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: scheme.outlineVariant.withValues(
                                          alpha: isDark ? 0.1 : 0.2),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.directions_walk_rounded,
                                        size: 14,
                                        color: style.accent,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${event.meta['total_distance_km']} km covered',
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: scheme.onSurface,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ],
                    ),
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

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({
    required this.label,
    required this.color,
    required this.isDark,
  });

  final String label;
  final Color color;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: isDark ? 0.3 : 0.25)),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.inter(
          fontSize: 9.5,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.5,
          color: color,
        ),
      ),
    );
  }
}

class _EmptyStateView extends StatelessWidget {
  const _EmptyStateView({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: isDark ? 0.6 : 0.4),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.1 : 0.2),
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.history_toggle_off_rounded,
            size: 36,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(height: 10),
          Text(
            'No recent activity',
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventStyle {
  const _EventStyle({
    required this.icon,
    required this.accent,
    required this.badgeLabel,
  });

  final IconData icon;
  final Color accent;
  final String badgeLabel;
}

_EventStyle _getEventStyle(TimelineEvent event) {
  if (event.isVisit) {
    final isNew = event.meta['is_new_visit'] == true;
    return _EventStyle(
      icon: Icons.storefront_rounded,
      accent: isNew ? _TimelineTheme.visitNew : _TimelineTheme.visitFollowUp,
      badgeLabel: isNew ? 'New Visit' : 'Follow-up',
    );
  }
  if (event.isCheckIn) {
    return const _EventStyle(
      icon: Icons.login_rounded,
      accent: _TimelineTheme.checkIn,
      badgeLabel: 'Check-In',
    );
  }
  if (event.isCheckOut) {
    return const _EventStyle(
      icon: Icons.logout_rounded,
      accent: _TimelineTheme.checkOut,
      badgeLabel: 'Check-Out',
    );
  }
  return _EventStyle(
    icon: Icons.notifications_active_rounded,
    accent: _TimelineTheme.defaultAccent,
    badgeLabel: event.type,
  );
}