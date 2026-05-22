import 'package:flutter/material.dart';

class LoginBrandPanel extends StatelessWidget {
  const LoginBrandPanel({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.black.withValues(alpha: 0.24),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.16),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: scheme.primary.withValues(alpha: 0.22),
              border: Border.all(
                color: scheme.primary.withValues(alpha: 0.75),
              ),
            ),
            child: Icon(
              Icons.gps_fixed_rounded,
              color: scheme.primary,
              size: 30,
            ),
          ),
          const SizedBox(height: 18),
          Text(
            'Sales Tracking v2',
            style: theme.textTheme.headlineMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Enterprise location intelligence for field teams.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.90),
            ),
          ),
          const SizedBox(height: 18),
          _PointRow(
            icon: Icons.route_rounded,
            text: 'Live route-aware check-in and check-out',
          ),
          const SizedBox(height: 10),
          _PointRow(
            icon: Icons.track_changes_rounded,
            text: 'Continuous movement visibility across regions',
          ),
          const SizedBox(height: 10),
          _PointRow(
            icon: Icons.hub_rounded,
            text: 'Role-based dashboard and operational control',
          ),
        ],
      ),
    );
  }
}

class _PointRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PointRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.white.withValues(alpha: 0.78), size: 18),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Colors.white.withValues(alpha: 0.85),
                ),
          ),
        ),
      ],
    );
  }
}

