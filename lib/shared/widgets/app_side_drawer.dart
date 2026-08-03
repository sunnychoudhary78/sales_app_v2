import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/user_data_invalidation.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import 'organization_line.dart';
import '../../shared/utils/avatar_url_utils.dart';
import '../../shared/widgets/profile_avatar_image.dart';
import '../utils/permission_utils.dart';

class AppSideDrawer extends ConsumerWidget {
  const AppSideDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final user = auth.rawUser;
    final companyCtx = ref.watch(companyContextProvider);
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

    final home = const _DrawerEntry(
      title: 'Home',
      route: '/home',
      icon: Icons.grid_view_rounded,
    );
    final profile = const _DrawerEntry(
      title: 'Profile',
      route: '/profile',
      icon: Icons.person_outline_rounded,
    );
    final visits = _DrawerEntry(
      title: 'Visits',
      route: '/visits',
      icon: Icons.location_on_outlined,
      visible: hasPermission(user, 'visit.read') ||
          hasPermission(user, 'visit.create') ||
          user == null,
    );
    final addVisit = _DrawerEntry(
      title: 'Add Visit',
      route: '/visits/add',
      icon: Icons.add_location_alt_outlined,
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
      icon: Icons.sell_outlined,
      visible: hasPermission(user, 'product.read_trader_rate') ||
          hasPermission(user, 'product.read_industry_rate') ||
          user == null,
    );
    final myClaim = _DrawerEntry(
      title: 'My Claim',
      route: '/claims/my',
      icon: Icons.receipt_long_outlined,
      visible: user != null,
    );
    final claimRequests = _DrawerEntry(
      title: 'Claim Requests',
      route: '/claims/requests',
      icon: Icons.assignment_turned_in_outlined,
      visible: isManager ||
          hasPermission(user, 'claim.request.view') ||
          hasPermission(user, 'claim.view'),
    );
    final settings = const _DrawerEntry(
      title: 'Settings',
      route: '/settings',
      icon: Icons.settings_outlined,
    );

    final groups = <_DrawerGroup>[
      _DrawerGroup('Overview', [home, profile]),
      _DrawerGroup('Field & GPS', [visits, addVisit, tracking]),
      _DrawerGroup('Rates & claims', [products, myClaim, claimRequests]),
      _DrawerGroup('Account', [settings]),
    ];

    final displayName =
        (user?['name'] ?? auth.profile?.name ?? 'User').toString();
    final designation = (user?['designation_name'] ?? '').toString().trim();
    final employeeCode = (user?['employee_id'] ?? '').toString().trim();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final mq = MediaQuery.sizeOf(context);
    final drawerW = math.min(320.0, math.max(288.0, mq.width * 0.82));

    return Drawer(
      width: drawerW,
      elevation: 0,
      backgroundColor: isDark
          ? scheme.surface
          : Color.alphaBlend(scheme.primary.withValues(alpha: 0.02), scheme.surface),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(24)),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14.0, vertical: 12.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // User Profile Header Card
              _SalesDrawerHeader(
                displayName: displayName,
                designation: designation.isEmpty ? null : designation,
                companyLine: companyCtx.displayCompanyName.isNotEmpty
                    ? companyCtx.displayCompanyName
                    : null,
                isSubCompany: companyCtx.isSubCompany,
                employeeCode: employeeCode.isEmpty ? null : employeeCode,
                avatarUrls: resolveAvatarUrlCandidates(user),
                avatarVersion: resolveAvatarUrl(user) ?? '',
              ),
              const SizedBox(height: 8),

              // Navigation Links List
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  physics: const BouncingScrollPhysics(
                    parent: AlwaysScrollableScrollPhysics(),
                  ),
                  children: [
                    for (final g in groups)
                      ..._buildGroupTiles(context, g, entrySelected),
                  ],
                ),
              ),

              // Sign Out Footer
              _DrawerSignOutBar(
                onLogout: () async {
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
        padding: const EdgeInsets.fromLTRB(10, 14, 10, 6),
        child: Text(
          group.title.toUpperCase(),
          style: GoogleFonts.inter(
            fontSize: 11, // Original font size restored
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
          ),
        ),
      ),
      ...visible.map((entry) {
        final selected = entrySelected(entry);
        return Padding(
          padding: const EdgeInsets.only(bottom: 3),
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
    required this.avatarUrls,
    this.designation,
    this.companyLine,
    this.isSubCompany = false,
    this.employeeCode,
    this.avatarVersion = '',
  });

  final String displayName;
  final String? designation;
  final String? companyLine;
  final bool isSubCompany;
  final String? employeeCode;
  final List<String> avatarUrls;
  final String avatarVersion;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final trimmed = displayName.trim();
    final name = trimmed.isEmpty ? 'User' : trimmed;
    final initial = name.substring(0, 1).toUpperCase();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? scheme.surfaceContainerHigh.withValues(alpha: 0.5)
            : scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: isDark ? 0.25 : 0.45),
        ),
      ),
      child: Row(
        children: [
          ClipOval(
            child: ProfileAvatarImage(
              urls: avatarUrls,
              size: 50,
              version: avatarVersion,
              fallback: _AvatarInitialsFallback(
                scheme: scheme,
                initial: initial,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 22, // Original font size restored
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.65,
                    height: 1.15,
                    color: scheme.onSurface,
                  ),
                ),
                if (designation != null && designation!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    designation!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 13, // Original font size restored
                      fontWeight: FontWeight.w500,
                      height: 1.35,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
                if (companyLine != null && companyLine!.isNotEmpty) ...[
                  const SizedBox(height: 3),
                  OrganizationLine(
                    companyName: companyLine!,
                    isSubCompany: isSubCompany,
                    textColor: scheme.primary,
                    fontSize: 12, // Original font size restored
                  ),
                ],
                if (employeeCode != null && employeeCode!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    'Code: $employeeCode',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      fontSize: 12, // Original font size restored
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.65),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
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
    return Container(
      width: 50,
      height: 50,
      color: scheme.primaryContainer,
      child: Center(
        child: Text(
          initial,
          style: GoogleFonts.inter(
            fontSize: 21, // Original font size restored
            fontWeight: FontWeight.w800,
            color: scheme.onPrimaryContainer,
          ),
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
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;

    final activeBg = isDark
        ? scheme.primary.withValues(alpha: 0.18)
        : scheme.primary.withValues(alpha: 0.08);

    final activeFg = scheme.primary;
    final inactiveFg = scheme.onSurfaceVariant.withValues(alpha: 0.8);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: selected ? activeBg : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Icon(
                entry.icon,
                color: selected ? activeFg : inactiveFg,
                size: 24,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  entry.title,
                  style: GoogleFonts.inter(
                    fontSize: 20, // Original font size restored
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    letterSpacing: -0.2,
                    color: selected ? activeFg : scheme.onSurface,
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

class _DrawerSignOutBar extends StatelessWidget {
  const _DrawerSignOutBar({required this.onLogout});

  final Future<void> Function() onLogout;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onLogout,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          child: Row(
            children: [
              Icon(
                Icons.logout_rounded,
                color: scheme.error,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                'Sign out',
                style: GoogleFonts.inter(
                  fontSize: 18, // Original font size restored
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: scheme.error,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}