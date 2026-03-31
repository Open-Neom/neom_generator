import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../engine/neom_frequency_painter_engine.dart';

/// Lissajous figure: plots sin(phaseL) vs sin(phaseR).
///
/// When freqL == freqR (no binaural beat) → straight line or ellipse.
/// When freqL/freqR is a simple ratio (2:1, 3:2, etc.) → classic Lissajous
/// patterns (figure-8, trefoils, etc.). The beat frequency determines how
/// fast the pattern rotates.
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

    // Trace the parametric curve using the actual L/R phase relationship.
    // phaseL and phaseR advance at different rates (freqL vs freqR),
    // so sweeping t and adding the current phases produces a real Lissajous.
    const int steps = 400;
    final pL = engine.phaseL;
    final pR = engine.phaseR;

    // The ratio between phases determines the pattern complexity.
    // We sweep one full cycle of the LEFT channel and let the RIGHT
    // channel advance proportionally based on the phase relationship.
    final ratio = pR == 0 ? 1.0 : (pL / pR).abs();
    final safeRatio = ratio.isFinite ? ratio.clamp(0.1, 10.0) : 1.0;

    for (int i = 0; i <= steps; i++) {
      final t = i / steps * 2 * math.pi;

      final x = cx + math.sin(t + pL) * scale;
      final y = cy + math.sin(t * safeRatio + pR) * scale;

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
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
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
