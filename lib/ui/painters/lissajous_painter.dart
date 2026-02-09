import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../engine/neom_frequency_painter_engine.dart';

class LissajousPainter extends CustomPainter {
  final NeomFrequencyPainterEngine engine;
  final Color color;

  LissajousPainter({
    required this.engine,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = math.min(cx, cy) * 0.85;

    final path = Path();
    const int steps = 300;

    for (int i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;

      final x = cx +
          math.sin(t + engine.lissajousX) * scale;
      final y = cy +
          math.sin(t + engine.lissajousY) * scale;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Glow
    canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(
          BlurStyle.normal,
          10,
        ),
    );

    // Signal
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
  }

  @override
  bool shouldRepaint(_) => true;
}
