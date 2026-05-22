import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/user_data_invalidation.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../shared/utils/avatar_url_utils.dart';
import '../../shared/widgets/profile_avatar_image.dart';
import '../utils/permission_utils.dart';

String _drawerFirstName(String full) {
  final t = full.trim();
  if (t.isEmpty) return 'there';
  return t.split(RegExp(r'\s+')).first;
}

class AppSideDrawer extends ConsumerWidget {
  const AppSideDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.rawUser;
    final roleObj = user == null ? null : user['role'];
    final roleName = ((roleObj is Map ? roleObj['name'] : user?['role_name'])
            ?.toString() ??
        '')
        .trim();
    final roleLower = roleName.toLowerCase();
    final isManager = roleLower.contains('manager');
    final route = ModalRoute.of(context);
    final currentRoute = route?.settings.name;

    bool entrySelected(_DrawerEntry entry) {
      if (entry.route == '/home') {
        return route?.isFirst == true && route?.isCurrent == true;
      }
      return currentRoute == entry.route;
    }

    final home = const _DrawerEntry(title: 'Home', route: '/home', icon: Icons.home_rounded);
    final profile =
        const _DrawerEntry(title: 'Profile', route: '/profile', icon: Icons.person_rounded);
    final visits = _DrawerEntry(
      title: 'Visits',
      route: '/visits',
      icon: Icons.place_rounded,
      visible: hasPermission(user, 'visit.read') ||
          hasPermission(user, 'visit.create') ||
          user == null,
    );
    final addVisit = _DrawerEntry(
      title: 'Add Visit',
      route: '/visits/add',
      icon: Icons.add_location_alt_rounded,
      visible: hasPermission(user, 'visit.create') || user == null,
    );
    final tracking = _DrawerEntry(
      title: 'Daily Tracking',
      route: '/tracking',
      icon: Icons.my_location_rounded,
      visible: hasAnyPermission(user, const [
            'tracking.read',
            'tracking.create',
            'tracking.view',
            'tracking.check_in',
            'tracking.check_out',
            'attendance.read',
            'attendance.create',
          ]) ||
          user == null,
    );
    final products = _DrawerEntry(
      title: 'Rate List',
      route: '/products',
      icon: Icons.sell_rounded,
      visible: hasPermission(user, 'product.read_trader_rate') ||
          hasPermission(user, 'product.read_industry_rate') ||
          user == null,
    );
    final myClaim = _DrawerEntry(
      title: 'My Claim',
      route: '/claims/my',
      icon: Icons.receipt_long_rounded,
      visible: user != null,
    );
    final claimRequests = _DrawerEntry(
      title: 'Claim Requests',
      route: '/claims/requests',
      icon: Icons.assignment_turned_in_rounded,
      visible: isManager ||
          hasPermission(user, 'claim.request.view') ||
          hasPermission(user, 'claim.view'),
    );
    final settings =
        const _DrawerEntry(title: 'Settings', route: '/settings', icon: Icons.settings_rounded);

    final groups = <_DrawerGroup>[
      _DrawerGroup('Overview', [home, profile]),
      _DrawerGroup('Field & GPS', [visits, addVisit, tracking]),
      _DrawerGroup('Rates & claims', [products, myClaim, claimRequests]),
      _DrawerGroup('Account', [settings]),
    ];

    final displayName = (user?['name'] ?? auth.profile?.name ?? 'User').toString();
    final employeeId = (user?['employee_id'] ?? user?['id'] ?? '-').toString();

    final scheme = Theme.of(context).colorScheme;
    final mq = MediaQuery.sizeOf(context);
    final drawerW = math.min(320.0, math.max(288.0, mq.width * 0.82));

    return Drawer(
      width: drawerW,
      elevation: 0,
      backgroundColor: scheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(22)),
      ),
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SalesDrawerHeader(
              displayName: displayName,
              employeeId: employeeId,
              roleLabel: roleName.isEmpty ? 'Field user' : roleName,
              avatarUrls: resolveAvatarUrlCandidates(user),
              avatarVersion: resolveAvatarUrl(user) ?? '',
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                physics: const BouncingScrollPhysics(
                  parent: AlwaysScrollableScrollPhysics(),
                ),
                children: [
                  for (final g in groups) ..._buildGroupTiles(context, g, entrySelected),
                ],
              ),
            ),
            _DrawerSignOutBar(
              onLogout: () async {
                // Keep [AppRoot] as the only route under MaterialApp.home. Pushing the
                // named '/login' route removes AppRoot, so successful re-login would never
                // swap the shell to Home — only this orphan LoginScreen would update.
                final nav = Navigator.of(context);
                nav.pop();
                nav.popUntil((route) => route.isFirst);
                invalidateAllUserScopedData(ref);
                await ref.read(authProvider.notifier).logout();
              },
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildGroupTiles(
    BuildContext context,
    _DrawerGroup group,
    bool Function(_DrawerEntry) entrySelected,
  ) {
    final visible = group.entries.where((e) => e.visible).toList();
    if (visible.isEmpty) return const [];

    final scheme = Theme.of(context).colorScheme;
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(8, 14, 8, 6),
        child: Row(
          children: [
            Container(
              width: 3,
              height: 14,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              group.title.toUpperCase(),
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.1,
                color: scheme.onSurfaceVariant.withValues(alpha: 0.85),
              ),
            ),
          ],
        ),
      ),
      ...visible.map((entry) {
        final selected = entrySelected(entry);
        return Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: _DrawerNavTile(
            entry: entry,
            selected: selected,
            onTap: () {
              Navigator.of(context).pop();
              if (selected) return;
              if (entry.route == '/home') {
                Navigator.of(context).popUntil((r) => r.isFirst);
                return;
              }
              Navigator.of(context).pushNamedAndRemoveUntil(
                entry.route,
                (r) => r.isFirst,
              );
            },
          ),
        );
      }),
    ];
  }
}

class _DrawerGroup {
  const _DrawerGroup(this.title, this.entries);

  final String title;
  final List<_DrawerEntry> entries;
}

class _DrawerEntry {
  final String title;
  final String route;
  final IconData icon;
  final bool visible;

  const _DrawerEntry({
    required this.title,
    required this.route,
    required this.icon,
    this.visible = true,
  });
}

class _SalesDrawerHeader extends StatelessWidget {
  const _SalesDrawerHeader({
    required this.displayName,
    required this.employeeId,
    required this.roleLabel,
    required this.avatarUrls,
    this.avatarVersion = '',
  });

  final String displayName;
  final String employeeId;
  final String roleLabel;
  final List<String> avatarUrls;
  /// Bust image cache when [profile_picture] changes (may reuse same path).
  final String avatarVersion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final trimmed = displayName.trim();
    final initial = trimmed.isEmpty ? 'U' : trimmed.substring(0, 1).toUpperCase();
    final first = _drawerFirstName(displayName);
    final parts = trimmed.split(RegExp(r'\s+')).where((e) => e.isNotEmpty).toList();
    final showFullLine = parts.length > 1;

    final deep = Color.lerp(scheme.primary, const Color(0xFF0A0A0A), 0.14) ?? scheme.primary;
    final lift = Color.lerp(scheme.primary, scheme.tertiary, 0.22) ?? scheme.primary;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(bottom: Radius.circular(26)),
      child: ColoredBox(
        color: scheme.primary,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      deep,
                      scheme.primary,
                      lift,
                    ],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(
                painter: _TelemetryGridPainter(
                  lineColor: scheme.onPrimary.withValues(alpha: 0.075),
                  diagonalColor: scheme.onPrimary.withValues(alpha: 0.045),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 18, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: scheme.tertiary,
                                    boxShadow: [
                                      BoxShadow(
                                        color: scheme.tertiary.withValues(alpha: 0.5),
                                        blurRadius: 10,
                                        spreadRadius: 0.5,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  'LIVE OPS',
                                  style: GoogleFonts.inter(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.35,
                                    color: scheme.onPrimary.withValues(alpha: 0.82),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'Hi, $first',
                              style: GoogleFonts.inter(
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                letterSpacing: -0.85,
                                height: 1.05,
                                color: scheme.onPrimary,
                              ),
                            ),
                            if (showFullLine) ...[
                              const SizedBox(height: 5),
                              Text(
                                trimmed,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.onPrimary.withValues(alpha: 0.78),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: scheme.onPrimary.withValues(alpha: 0.42),
                            width: 2.5,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.18),
                              blurRadius: 12,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child: ProfileAvatarImage(
                            urls: avatarUrls,
                            size: 56,
                            version: avatarVersion,
                            fallback: _AvatarInitialsFallback(
                              scheme: scheme,
                              initial: initial,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _OpsStripTag(
                          icon: Icons.work_outline_rounded,
                          text: roleLabel,
                          scheme: scheme,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _OpsStripTag(
                          icon: Icons.tag_rounded,
                          text: 'ID $employeeId',
                          scheme: scheme,
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
    );
  }
}

class _AvatarInitialsFallback extends StatelessWidget {
  const _AvatarInitialsFallback({
    required this.scheme,
    required this.initial,
  });

  final ColorScheme scheme;
  final String initial;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.onPrimary,
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: 21,
            fontWeight: FontWeight.w800,
            color: scheme.primary,
          ),
        ),
      ),
    );
  }
}

class _TelemetryGridPainter extends CustomPainter {
  _TelemetryGridPainter({
    required this.lineColor,
    required this.diagonalColor,
  });

  final Color lineColor;
  final Color diagonalColor;

  @override
  void paint(Canvas canvas, Size size) {
    const step = 20.0;
    final grid = Paint()
      ..color = lineColor
      ..strokeWidth = 0.65;
    for (var x = 0.0; x <= size.width; x += step) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (var y = 0.0; y <= size.height; y += step) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final diag = Paint()
      ..color = diagonalColor
      ..strokeWidth = 0.55;
    for (var i = -size.height; i < size.width + size.height; i += 40) {
      canvas.drawLine(Offset(i, 0), Offset(i + size.height * 1.15, size.height), diag);
    }
  }

  @override
  bool shouldRepaint(covariant _TelemetryGridPainter oldDelegate) =>
      oldDelegate.lineColor != lineColor || oldDelegate.diagonalColor != diagonalColor;
}

class _OpsStripTag extends StatelessWidget {
  const _OpsStripTag({
    required this.icon,
    required this.text,
    required this.scheme,
  });

  final IconData icon;
  final String text;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.onPrimary.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.onPrimary.withValues(alpha: 0.24)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Icon(icon, size: 17, color: scheme.onPrimary.withValues(alpha: 0.92)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: scheme.onPrimary.withValues(alpha: 0.96),
                  height: 1.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DrawerNavTile extends StatelessWidget {
  const _DrawerNavTile({
    required this.entry,
    required this.selected,
    required this.onTap,
  });

  final _DrawerEntry entry;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: selected
                ? scheme.primaryContainer.withValues(alpha: 0.55)
                : scheme.surfaceContainerHighest.withValues(alpha: 0.35),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.45)
                  : scheme.outlineVariant.withValues(alpha: 0.35),
            ),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: scheme.primary.withValues(alpha: 0.12),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: selected
                      ? scheme.primary.withValues(alpha: 0.2)
                      : scheme.surface.withValues(alpha: 0.9),
                ),
                child: Icon(
                  entry.icon,
                  color: selected ? scheme.primary : scheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.title,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: -0.2,
                    color: selected ? scheme.onPrimaryContainer : scheme.onSurface,
                  ),
                ),
              ),
              if (selected)
                Icon(
                  Icons.chevron_right_rounded,
                  color: scheme.primary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DrawerSignOutBar extends StatelessWidget {
  const _DrawerSignOutBar({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
        child: FilledButton.tonalIcon(
          onPressed: onLogout,
          icon: Icon(Icons.logout_rounded, color: scheme.error),
          label: Text(
            'Sign out',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700, letterSpacing: -0.2),
          ),
          style: FilledButton.styleFrom(
            foregroundColor: scheme.error,
            backgroundColor: scheme.errorContainer.withValues(alpha: 0.38),
            elevation: 0,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: scheme.error.withValues(alpha: 0.22)),
            ),
          ),
        ),
      ),
    );
  }
}
