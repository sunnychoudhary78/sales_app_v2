import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DashboardAppBarTitle extends StatelessWidget {
  const DashboardAppBarTitle({
    super.key,
    required this.displayName,
    required this.periodLabel,
    this.showLiveBadge = false,
  });

  final String displayName;
  final String periodLabel;
  final bool showLiveBadge;

  String get _firstName {
    final name = displayName.trim();
    if (name.isEmpty) return "User";
    return name.split(" ").first;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return "Good Morning";
    if (hour < 17) return "Good Afternoon";
    return "Good Evening";
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Row(
      children: [
        Expanded(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting Tagline
              Text(
                _getGreeting().toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(height: 2),
              // User First Name Greeting
              Text(
                "Hi, $_firstName 👋",
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 1),
              // Subtitle Date/Period
              Text(
                periodLabel,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w500,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),

        // Live / Past Month Status Badge
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 6,
          ),
          decoration: BoxDecoration(
            color: showLiveBadge
                ? const Color(0xFF10B981).withValues(alpha: .12)
                : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: showLiveBadge
                  ? const Color(0xFF10B981).withValues(alpha: .35)
                  : scheme.outlineVariant.withValues(alpha: .5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (showLiveBadge) ...[
                const Icon(
                  Icons.verified_rounded,
                  size: 13,
                  color: Color(0xFF10B981),
                ),
                const SizedBox(width: 4),
              ],
              Text(
                showLiveBadge ? "Live" : "Past Month",
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: showLiveBadge
                      ? const Color(0xFF10B981)
                      : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}