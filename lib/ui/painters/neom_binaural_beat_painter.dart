import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../engine/neom_frequency_painter_engine.dart';

class NeomBinauralBeatPainter extends CustomPainter {
  final NeomFrequencyPainterEngine engine;
  final double beatHz;
  final double intensity;
  final Color color;

  NeomBinauralBeatPainter({
    required this.engine,
    required this.beatHz,
    required this.intensity,
    required this.color,
  }) : super(repaint: engine);

  @override
  void paint(Canvas canvas, Size size) {

    if(beatHz == 0) return;

    final centerY = size.height / 2;

    final paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5 + intensity * 2;

    final path = Path();

    final pulses = beatHz.abs().clamp(0.5, 40);
    final wavelength = size.width / pulses;

    for (double x = 0; x <= size.width; x++) {
      final phase =
          (x / wavelength) * 2 * math.pi + engine.binauralPhase;

      final y = math.sin(phase) *
          size.height *
          0.35 *
          intensity;

      if (x == 0) {
        path.moveTo(x, centerY + y);
      } else {
        path.lineTo(x, centerY + y);
      }
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant NeomBinauralBeatPainter oldDelegate) {
    return true;
  }
}
