import 'package:flutter/material.dart';

class LoginTrackingBackground extends StatelessWidget {
  final Animation<double> animation;

  const LoginTrackingBackground({
    super.key,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final top = Color.lerp(scheme.primary, const Color(0xFF02030A), 0.93) ?? const Color(0xFF02030A);
    final bottom =
        Color.lerp(scheme.secondary, const Color(0xFF000106), 0.95) ?? const Color(0xFF000106);

    return Stack(
      children: [
        Positioned.fill(
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [top, bottom],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return CustomPaint(
                painter: _TrackingGridPainter(
                  progress: animation.value,
                  color: scheme.primary,
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrackingGridPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _TrackingGridPainter({
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = color.withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    const xSpace = 44.0;
    const ySpace = 40.0;
    for (double x = 0; x <= size.width; x += xSpace) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), grid);
    }
    for (double y = 0; y <= size.height; y += ySpace) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final trackerRoute = _buildGridAlignedRoute(size, xSpace, ySpace);
    _drawRedTracker(canvas, trackerRoute);
  }

  Path _buildGridAlignedRoute(Size size, double xSpace, double ySpace) {
    double snapX(double ratio) => (size.width * ratio / xSpace).round() * xSpace;
    double snapY(double ratio) => (size.height * ratio / ySpace).round() * ySpace;

    final start = Offset(snapX(0.58), size.height + ySpace); // starts below screen
    final mid1 = Offset(start.dx, snapY(0.84));
    final mid2 = Offset(snapX(0.50), mid1.dy);
    final mid3 = Offset(mid2.dx, snapY(0.60));
    final mid4 = Offset(snapX(0.62), mid3.dy);
    final mid5 = Offset(mid4.dx, snapY(0.48));
    final mid6 = Offset(snapX(0.42), mid5.dy);
    final mid7 = Offset(mid6.dx, snapY(0.34));
    final mid8 = Offset(snapX(0.30), mid7.dy);
    final mid9 = Offset(mid8.dx, snapY(0.14));
    final mid10 = Offset(snapX(0.20), mid9.dy);
    final end = Offset(mid10.dx, -ySpace); // exits from top edge

    return Path()
      ..moveTo(start.dx, start.dy)
      ..lineTo(mid1.dx, mid1.dy)
      ..lineTo(mid2.dx, mid2.dy)
      ..lineTo(mid3.dx, mid3.dy)
      ..lineTo(mid4.dx, mid4.dy)
      ..lineTo(mid5.dx, mid5.dy)
      ..lineTo(mid6.dx, mid6.dy)
      ..lineTo(mid7.dx, mid7.dy)
      ..lineTo(mid8.dx, mid8.dy)
      ..lineTo(mid9.dx, mid9.dy)
      ..lineTo(mid10.dx, mid10.dy)
      ..lineTo(end.dx, end.dy);
  }

  void _drawRedTracker(Canvas canvas, Path path) {
    final metric = path.computeMetrics().isNotEmpty ? path.computeMetrics().first : null;
    if (metric == null) return;

    final t = (progress * 2.7) % 1.0;
    final len = metric.length;
    final head = len * t;
    final trail = len * 0.12;
    final start = (head - trail).clamp(0.0, len);

    final segment = metric.extractPath(start, head);
    final flowPaint = Paint()
      ..color = const Color(0xFFF43F5E).withValues(alpha: 0.90)
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 1.8;
    canvas.drawPath(segment, flowPaint);

    final pos = metric.getTangentForOffset(head);
    if (pos == null) return;
    final point = pos.position;

    final pulse = 0.65 + ((progress * 2.0) % 1.0) * 0.35;
    final pulsePaint = Paint()
      ..color = const Color(0xFFF43F5E).withValues(alpha: 0.16)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;
    canvas.drawCircle(point, 10.0 * pulse, pulsePaint);

    final dotOuter = Paint()..color = const Color(0xFFF43F5E).withValues(alpha: 0.32);
    final dotInner = Paint()..color = const Color(0xFFF43F5E);
    canvas.drawCircle(point, 6, dotOuter);
    canvas.drawCircle(point, 2.4, dotInner);
  }

  @override
  bool shouldRepaint(covariant _TrackingGridPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.color != color;
  }
}

