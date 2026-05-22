import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../shared/widgets/app_side_drawer.dart';
import '../../../../shared/widgets/premium_shell.dart';
import '../../../../shared/widgets/screen_accent_backdrop.dart';
import '../../../../core/theme/app_theme_provider.dart';
import '../../../../core/theme/theme_mode_provider.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final primary = ref.watch(appThemeProvider);
    final scheme = Theme.of(context).colorScheme;

    final presets = <Color>[
      const Color(0xFF0284C7),
      const Color(0xFF16A34A),
      const Color(0xFFDC2626),
      const Color(0xFF9333EA),
      const Color(0xFF4F46E5),
      const Color(0xFFD97706),
    ];

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      drawer: const AppSideDrawer(),
      appBar: const SalesGlassAppBar(
        title: 'Settings',
        showDrawer: true,
      ),
      body: ScreenAccentBackdrop(
        spot: DrawerRouteAccents.settings,
        spot2: DrawerRouteAccents.settingsSlate,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 28),
          children: [
            PremiumFeatureHeader(
              icon: Icons.palette_outlined,
              title: 'Look & feel',
              subtitle:
                  'Theme mode and primary seed stay dynamic; accents below add character per screen.',
            ),
            const SizedBox(height: 12),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Theme mode',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('System')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Light')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Dark')),
                    ],
                    selected: {themeMode},
                    onSelectionChanged: (s) {
                      ref.read(themeModeProvider.notifier).setThemeMode(s.first);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PremiumCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Primary color',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: presets.map((c) {
                      final selected = c.toARGB32() == primary.toARGB32();
                      return GestureDetector(
                        onTap: () => ref.read(appThemeProvider.notifier).setPrimaryColor(c),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: c,
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: selected
                                  ? scheme.onSurface
                                  : scheme.outlineVariant,
                              width: selected ? 2.5 : 1,
                            ),
                            boxShadow: selected
                                ? [
                                    BoxShadow(
                                      color: c.withValues(alpha: 0.45),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ]
                                : null,
                          ),
                          child: selected
                              ? Icon(Icons.check_rounded, size: 20, color: _onColor(c))
                              : null,
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Readable check icon on saturated swatches.
  static Color _onColor(Color background) {
    final luminance = background.computeLuminance();
    return luminance > 0.55 ? const Color(0xFF0F172A) : Colors.white;
  }
}
