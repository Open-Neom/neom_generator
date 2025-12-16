import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../engine/neom_frequency_painter_engine.dart';

class FrequencyPainter extends CustomPainter {
  final NeomFrequencyPainterEngine engine;
  final Color color;
  final double strokeWidth;

  FrequencyPainter({
    required this.engine,
    required this.color,
    this.strokeWidth = 2.0
  }) : super(repaint: engine); // 🔥 clave

  @override
  void paint(Canvas canvas, Size size) {
    final glow = engine.glowIntensity.clamp(0.0, 1.0);
    final stroke = 1.0 + engine.waveHeight * 2.5 + engine.glowIntensity * strokeWidth;
    final paint = Paint()
      ..color = color.withOpacity(glow)
      ..strokeWidth = stroke
      ..style = PaintingStyle.stroke;

    final path = Path();

    for (double x = 0; x < size.width; x++) {
      final t = x / size.width;
      final amplitudePx = size.height * 0.50; // 🔥 no más de 30%


      final y = math.sin(
        t * 2 * math.pi * engine.waveStretch +
            engine.visualPhase,
      ) *
          amplitudePx *
          engine.waveHeight *
          (1.0 + engine.breathPulse * 0.35);

      final dx = x + engine.horizontalDrift * 20;
      final dy = amplitudePx + y;

      if (x == 0) {
        path.moveTo(dx, dy);
      } else {
        path.lineTo(dx, dy);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
