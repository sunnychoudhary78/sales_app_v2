import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Map pin widgets matching admin panel semantics (S / E / visit / replay).
class TrackingStartPin extends StatelessWidget {
  const TrackingStartPin({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TeardropPin(
      fill: Color(0xFF22C55E),
      label: 'S',
      labelColor: Color(0xFF16A34A),
    );
  }
}

class TrackingEndPin extends StatelessWidget {
  const TrackingEndPin({super.key});

  @override
  Widget build(BuildContext context) {
    return const _TeardropPin(
      fill: Color(0xFFEF4444),
      label: 'E',
      labelColor: Color(0xFFB91C1C),
    );
  }
}

class TrackingVisitPin extends StatelessWidget {
  const TrackingVisitPin({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        color: const Color(0xFF3B82F6),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: const Icon(Icons.person_rounded, color: Colors.white, size: 16),
    );
  }
}

class TrackingReplayLivePin extends StatelessWidget {
  const TrackingReplayLivePin({super.key, this.bearingDegrees});

  final double? bearingDegrees;

  @override
  Widget build(BuildContext context) {
    final arrow = Transform.rotate(
      angle: ((bearingDegrees ?? 0) - 90) * math.pi / 180,
      child: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFF97316).withValues(alpha: 0.45),
              blurRadius: 12,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFFED7AA).withValues(alpha: 0.9),
              ),
            ),
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFEA580C),
                border: Border.all(color: Colors.white, width: 2.5),
              ),
              child: const Icon(
                Icons.navigation_rounded,
                color: Colors.white,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
    return arrow;
  }
}

class _TeardropPin extends StatelessWidget {
  const _TeardropPin({
    required this.fill,
    required this.label,
    required this.labelColor,
  });

  final Color fill;
  final String label;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      height: 42,
      child: CustomPaint(
        painter: _TeardropPainter(fill: fill),
        child: Align(
          alignment: const Alignment(0, -0.35),
          child: Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ),
      ),
    );
  }
}

class _TeardropPainter extends CustomPainter {
  _TeardropPainter({required this.fill});

  final Color fill;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path()
      ..moveTo(w / 2, h)
      ..cubicTo(w * 0.1, h * 0.55, 0, h * 0.35, w / 2, h * 0.08)
      ..cubicTo(w, h * 0.35, w * 0.9, h * 0.55, w / 2, h)
      ..close();
    canvas.drawShadow(path, Colors.black.withValues(alpha: 0.25), 3, false);
    canvas.drawPath(path, Paint()..color = fill);
    canvas.drawCircle(
      Offset(w / 2, h * 0.28),
      w * 0.22,
      Paint()..color = Colors.white,
    );
  }

  @override
  bool shouldRepaint(covariant _TeardropPainter oldDelegate) =>
      oldDelegate.fill != fill;
}
