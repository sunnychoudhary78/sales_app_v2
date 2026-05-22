import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Shared visual language for dashboard surfaces.
class HomeDashboardChrome {
  HomeDashboardChrome._();

  static BoxDecoration panelDecoration(ColorScheme scheme, {bool lift = true}) {
    return BoxDecoration(
      color: scheme.surface.withValues(alpha: 0.94),
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.38)),
      boxShadow: lift
          ? [
              BoxShadow(
                color: scheme.shadow.withValues(alpha: 0.07),
                blurRadius: 28,
                offset: const Offset(0, 14),
              ),
              BoxShadow(
                color: scheme.primary.withValues(alpha: 0.04),
                blurRadius: 40,
                offset: const Offset(0, 20),
              ),
            ]
          : null,
    );
  }

  static Widget sectionHeader(
    BuildContext context, {
    required String eyebrow,
    required String title,
    String? subtitle,
    IconData icon = Icons.insights_rounded,
  }) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(left: 2, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  scheme.primary.withValues(alpha: 0.18),
                  scheme.tertiary.withValues(alpha: 0.12),
                ],
              ),
              border: Border.all(color: scheme.primary.withValues(alpha: 0.22)),
            ),
            child: Icon(icon, color: scheme.primary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  eyebrow.toUpperCase(),
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.25,
                    color: scheme.primary.withValues(alpha: 0.85),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                    letterSpacing: -0.45,
                    height: 1.15,
                    color: scheme.onSurface,
                  ),
                ),
                if (subtitle != null && subtitle.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 12.5,
                      height: 1.35,
                      fontWeight: FontWeight.w500,
                      color: scheme.onSurfaceVariant,
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
