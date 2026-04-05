import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../engine/neom_frequency_painter_engine.dart';

/// Paints a sine wave flowing around the perimeter of a rectangle.
///
/// The wave travels: top → right → bottom → left (clockwise),
/// creating a living frame effect. Two waves are drawn:
/// - Left channel (primary color) — outward displacement
/// - Right channel (secondary color) — inward displacement
/// The beat between them creates visible interference patterns.
class PerimeterWavePainter extends CustomPainter {
  final NeomFrequencyPainterEngine engine;
  final double time;
  final Color primaryColor;
  final Color secondaryColor;
  final double strokeWidth;
  final double amplitude;
  final double inset;

  PerimeterWavePainter({
    required this.engine,
    required this.time,
    this.primaryColor = const Color(0xFF00BCD4),
    this.secondaryColor = const Color(0xFFAB47BC),
    this.strokeWidth = 2.0,
    this.amplitude = 12.0,
    this.inset = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final perimeter = 2 * (w + h);

    // Number of sample points around the perimeter — fewer on web
    final sampleCount = kIsWeb ? 150 : 400;

    final freq = engine.visualPhase * 20 + 3; // wave density
    final beat = engine.binauralPhase;
    final amp = amplitude * (0.5 + engine.glowIntensity * 0.5);

    // Build paths for L and R channels
    final pathL = Path();
    final pathR = Path();

    for (int i = 0; i <= sampleCount; i++) {
      final t = i / sampleCount; // 0..1 around perimeter
      final dist = t * perimeter;

      // Position on the rectangle perimeter
      final pos = _perimeterPoint(dist, w, h);
      // Normal direction (perpendicular to edge, pointing outward)
      final normal = _perimeterNormal(dist, w, h);

      // Left channel wave — flows with time
      final phaseL = t * freq * 2 * pi + time * 4;
      final displacementL = sin(phaseL) * amp;

      // Right channel wave — slightly different frequency (binaural)
      final phaseR = t * freq * 2 * pi + time * 4 + beat;
      final displacementR = sin(phaseR) * amp * 0.8;

      // Offset points along normal
      final pL = Offset(
        pos.dx + normal.dx * displacementL,
        pos.dy + normal.dy * displacementL,
      );
      final pR = Offset(
        pos.dx - normal.dx * displacementR, // inward
        pos.dy - normal.dy * displacementR,
      );

      if (i == 0) {
        pathL.moveTo(pL.dx, pL.dy);
        pathR.moveTo(pR.dx, pR.dy);
      } else {
        pathL.lineTo(pL.dx, pL.dy);
        pathR.lineTo(pR.dx, pR.dy);
      }
    }

    // Draw R channel (behind, slightly transparent)
    final paintR = Paint()
      ..color = secondaryColor.withAlpha(120)
      ..strokeWidth = strokeWidth * 0.8
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(pathR, paintR);

    // Draw L channel (front, brighter — thicker on web to compensate for missing glow)
    final paintL = Paint()
      ..color = primaryColor.withAlpha(kIsWeb ? 220 : 200)
      ..strokeWidth = kIsWeb ? strokeWidth * 1.5 : strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(pathL, paintL);

    // Subtle glow on L channel — skip blur on web
    if (!kIsWeb) {
      final glowPaint = Paint()
        ..color = primaryColor.withAlpha(30)
        ..strokeWidth = strokeWidth * 4
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
      canvas.drawPath(pathL, glowPaint);
    }
  }

  /// Get a point on the rectangle perimeter at distance [dist] from top-left.
  /// Travels: top edge → right edge → bottom edge → left edge (clockwise).
  Offset _perimeterPoint(double dist, double w, double h) {
    final d = dist + inset;
    if (d <= w) {
      // Top edge: left to right
      return Offset(d, 0);
    } else if (d <= w + h) {
      // Right edge: top to bottom
      return Offset(w, d - w);
    } else if (d <= 2 * w + h) {
      // Bottom edge: right to left
      return Offset(w - (d - w - h), h);
    } else {
      // Left edge: bottom to top
      return Offset(0, h - (d - 2 * w - h));
    }
  }

  /// Normal vector (pointing outward from the rectangle) at distance [dist].
  Offset _perimeterNormal(double dist, double w, double h) {
    final d = dist + inset;
    if (d <= w) {
      return const Offset(0, -1); // Top: up
    } else if (d <= w + h) {
      return const Offset(1, 0); // Right: right
    } else if (d <= 2 * w + h) {
      return const Offset(0, 1); // Bottom: down
    } else {
      return const Offset(-1, 0); // Left: left
    }
  }

  @override
  bool shouldRepaint(covariant PerimeterWavePainter old) => true;
}

/// Widget that wraps the perimeter wave painter with animation.
///
/// When [isActive] is false (engine not playing), shows a subtle static
/// border glow instead of the animated wave.
class PerimeterWaveWidget extends StatefulWidget {
  final NeomFrequencyPainterEngine engine;
  final Color? primaryColor;
  final Color? secondaryColor;
  final double amplitude;
  final double strokeWidth;
  final Widget? child;
  /// When false, shows a subtle static border instead of animated waves.
  final bool isActive;

  const PerimeterWaveWidget({
    super.key,
    required this.engine,
    this.primaryColor,
    this.secondaryColor,
    this.amplitude = 12.0,
    this.strokeWidth = 2.0,
    this.child,
    this.isActive = false,
  });

  @override
  State<PerimeterWaveWidget> createState() => _PerimeterWaveWidgetState();
}

class _PerimeterWaveWidgetState extends State<PerimeterWaveWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat();
    _anim.addListener(() => _frameCount++);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Inactive: show subtle static border, no animation
    if (!widget.isActive) {
      return Container(
        decoration: BoxDecoration(
          border: Border.all(
            color: (widget.primaryColor ?? const Color(0xFF00BCD4)).withAlpha(25),
            width: 0.5,
          ),
          borderRadius: BorderRadius.circular(4),
        ),
        child: widget.child,
      );
    }

    return AnimatedBuilder(
      animation: _anim,
      builder: (_, child) {
        // On web, skip every other frame to target ~30fps
        if (kIsWeb && _frameCount % 2 != 0) return child!;
        return CustomPaint(
          painter: PerimeterWavePainter(
            engine: widget.engine,
            time: _anim.value * 2 * pi,
            primaryColor: widget.primaryColor ?? const Color(0xFF00BCD4),
            secondaryColor: widget.secondaryColor ?? const Color(0xFFAB47BC),
            amplitude: widget.amplitude,
            strokeWidth: widget.strokeWidth,
          ),
          child: child,
        );
      },
      child: widget.child,
    );
  }
}
