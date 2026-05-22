import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../data/models/home_models.dart';
import 'home_dashboard_chrome.dart';

/// Premium stream accents — stable across themes, matches field-tracking vibe.
abstract final class _StreamAccent {
  static const Color teal = Color(0xFF0D9488);
  static const Color cyan = Color(0xFF0891B2);
  static const Color live = Color(0xFF059669);
  static const Color violet = Color(0xFF7C3AED);
  static const Color amber = Color(0xFFD97706);
  static const Color slate = Color(0xFF64748B);
  static const Color ink = Color(0xFF0F172A);
  static const Color spine = Color(0xFF94A3B8);
}

class HomeTimelineSection extends StatelessWidget {
  const HomeTimelineSection({super.key, required this.events});

  final List<TimelineEvent> events;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    if (events.isEmpty) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
        decoration: HomeDashboardChrome.panelDecoration(scheme),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            HomeDashboardChrome.sectionHeader(
              context,
              eyebrow: 'Log',
              title: 'Activity stream',
              subtitle: 'Check-ins, visits, and session summaries appear here.',
              icon: Icons.timeline_rounded,
            ),
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.32),
                ),
              ),
              child: Column(
                children: [
                  Icon(
                    Icons.podcasts_rounded,
                    size: 36,
                    color: _StreamAccent.teal.withValues(alpha: 0.45),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No activity yet',
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.2,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Start a session or log a visit — your stream will show up here.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    final shown =
        events.length > 12 ? events.sublist(events.length - 12) : events;
    final list = shown.reversed.take(8).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
      decoration: HomeDashboardChrome.panelDecoration(scheme),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeDashboardChrome.sectionHeader(
            context,
            eyebrow: 'Log',
            title: 'Activity stream',
            subtitle: 'Latest check-ins, visits, and session ends from your account.',
            icon: Icons.timeline_rounded,
          ),
          const SizedBox(height: 4),
          ...list.asMap().entries.map((e) {
            final i = e.key;
            final ev = e.value;
            final isFirst = i == 0;
            final isLast = i == list.length - 1;
            return Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : 2),
              child: _TimelineRow(
                event: ev,
                scheme: scheme,
                isFirst: isFirst,
                isLast: isLast,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
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
    final style = _eventStyle(event);
    final spineColor = _StreamAccent.spine.withValues(alpha: 0.35);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 22,
            child: Column(
              children: [
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(bottom: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: isFirst
                            ? null
                            : LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  spineColor.withValues(alpha: 0.15),
                                  spineColor,
                                ],
                              ),
                        color: isFirst ? Colors.transparent : null,
                      ),
                    ),
                  ),
                ),
                Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.surface,
                    border: Border.all(
                      color: style.accent,
                      width: 2.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: style.accent.withValues(alpha: 0.35),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: Center(
                    child: Container(
                      width: 2,
                      margin: const EdgeInsets.only(top: 2),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(2),
                        gradient: isLast
                            ? null
                            : LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  spineColor,
                                  spineColor.withValues(alpha: 0.2),
                                ],
                              ),
                        color: isLast ? Colors.transparent : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _TimelineCard(event: event, scheme: scheme, style: style),
          ),
        ],
      ),
    );
  }
}

class _EventVisual {
  const _EventVisual({
    required this.icon,
    required this.accent,
    required this.iconBgTop,
    required this.iconBgBottom,
  });

  final IconData icon;
  final Color accent;
  final Color iconBgTop;
  final Color iconBgBottom;
}

_EventVisual _eventStyle(TimelineEvent event) {
  if (event.isVisit) {
    final isNew = event.meta['is_new_visit'] == true;
    return _EventVisual(
      icon: Icons.storefront_rounded,
      accent: isNew ? _StreamAccent.amber : _StreamAccent.violet,
      iconBgTop: (isNew ? _StreamAccent.amber : _StreamAccent.violet)
          .withValues(alpha: 0.22),
      iconBgBottom: (isNew ? _StreamAccent.amber : _StreamAccent.violet)
          .withValues(alpha: 0.08),
    );
  }
  if (event.isCheckIn) {
    return _EventVisual(
      icon: Icons.play_circle_filled_rounded,
      accent: _StreamAccent.live,
      iconBgTop: _StreamAccent.live.withValues(alpha: 0.2),
      iconBgBottom: _StreamAccent.teal.withValues(alpha: 0.08),
    );
  }
  if (event.isCheckOut) {
    return _EventVisual(
      icon: Icons.stop_circle_rounded,
      accent: _StreamAccent.slate,
      iconBgTop: _StreamAccent.slate.withValues(alpha: 0.18),
      iconBgBottom: _StreamAccent.cyan.withValues(alpha: 0.06),
    );
  }
  return _EventVisual(
    icon: Icons.circle_outlined,
    accent: _StreamAccent.cyan,
    iconBgTop: _StreamAccent.cyan.withValues(alpha: 0.18),
    iconBgBottom: _StreamAccent.teal.withValues(alpha: 0.06),
  );
}

class _TimelineCard extends StatelessWidget {
  const _TimelineCard({
    required this.event,
    required this.scheme,
    required this.style,
  });

  final TimelineEvent event;
  final ColorScheme scheme;
  final _EventVisual style;

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('MMM d · h:mm a').format(event.at.toLocal());
    final subtitle = event.isVisit && event.meta['is_new_visit'] == true
        ? 'New visit'
        : event.isVisit
            ? 'Follow-up'
            : (event.isCheckIn
                ? 'Start tracking'
                : (event.isCheckOut ? 'End tracking' : event.type));

    final chipBg = style.accent.withValues(alpha: 0.12);
    final chipBorder = style.accent.withValues(alpha: 0.28);

    return Container(
      decoration: BoxDecoration(
        color: scheme.surface.withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.34),
        ),
        boxShadow: [
          BoxShadow(
            color: scheme.shadow.withValues(alpha: 0.05),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: style.accent.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 4,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      style.accent,
                      Color.lerp(style.accent, _StreamAccent.teal, 0.35) ??
                          style.accent,
                    ],
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 13, 14, 13),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [style.iconBgTop, style.iconBgBottom],
                          ),
                          border: Border.all(
                            color: style.accent.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Icon(style.icon, color: style.accent, size: 24),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              event.label,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 15,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.28,
                                height: 1.25,
                                color: scheme.onSurface,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              runSpacing: 6,
                              crossAxisAlignment: WrapCrossAlignment.center,
                              children: [
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.schedule_rounded,
                                      size: 13,
                                      color: scheme.onSurfaceVariant
                                          .withValues(alpha: 0.85),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      time,
                                      style: GoogleFonts.inter(
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: chipBg,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(color: chipBorder),
                                  ),
                                  child: Text(
                                    subtitle,
                                    style: GoogleFonts.inter(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.2,
                                      color: style.accent,
                                    ),
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
                                  vertical: 7,
                                ),
                                decoration: BoxDecoration(
                                  color: _StreamAccent.teal.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: _StreamAccent.cyan
                                        .withValues(alpha: 0.28),
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.straighten_rounded,
                                      size: 15,
                                      color: _StreamAccent.teal,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Session · ${event.meta['total_distance_km']} km',
                                      style: GoogleFonts.inter(
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w800,
                                        color: _StreamAccent.ink
                                            .withValues(alpha: 0.88),
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
    );
  }
}
