import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class HomeWelcomeHeader extends StatelessWidget {
  const HomeWelcomeHeader({
    super.key,
    required this.name,
    required this.subtitle,
  });

  final String name;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            scheme.primary,
            Color.lerp(scheme.primary, scheme.tertiary, 0.35)!,
            scheme.primaryContainer.withValues(alpha: 0.9),
          ],
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: scheme.primary.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Hello${name.isEmpty ? '' : ','}',
            style: GoogleFonts.inter(
              fontSize: 15,
              fontWeight: FontWeight.w500,
              color: scheme.onPrimary.withValues(alpha: 0.88),
            ),
          ),
          if (name.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              name,
              style: GoogleFonts.inter(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
                color: scheme.onPrimary,
              ),
            ),
          ],
          const SizedBox(height: 10),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              height: 1.35,
              color: scheme.onPrimary.withValues(alpha: 0.85),
            ),
          ),
        ],
      ),
    );
  }
}
