import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/neom_frequency_painter_engine.dart';

/// 3D Lissajous figure with perspective projection.
///
/// X = sin(phaseL) — left ear frequency
/// Y = sin(phaseR) — right ear frequency
/// Z = breath phase — breathing cycle (0.0–1.0 mapped to sin)
///
/// The figure auto-rotates slowly around the Y axis, creating a
/// hypnotic 3D effect. Trail of previous points fades out.
class Lissajous3DPainter extends CustomPainter {
  final NeomFrequencyPainterEngine engine;
  final double rotationAngle;
  final Color baseColor;

  /// Trail buffer — stores recent (x, y, z) points for fade effect.
  // ignore: library_private_types_in_public_api
  final List<_Point3D> trail;

  static const int maxTrail = 300;
  static const double fov = 400.0; // perspective field of view

  Lissajous3DPainter({
    required this.engine,
    required this.rotationAngle,
    required this.trail,
    this.baseColor = const Color(0xFF00BCD4),
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (trail.isEmpty) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.shortestSide * 0.35;

    // Auto-rotation around Y axis
    final cosR = cos(rotationAngle);
    final sinR = sin(rotationAngle);

    // Draw trail with fade
    for (int i = 1; i < trail.length; i++) {
      final p0 = trail[i - 1];
      final p1 = trail[i];

      // Rotate around Y axis
      final rx0 = p0.x * cosR - p0.z * sinR;
      final rz0 = p0.x * sinR + p0.z * cosR;
      final rx1 = p1.x * cosR - p1.z * sinR;
      final rz1 = p1.x * sinR + p1.z * cosR;

      // Perspective projection
      final d0 = fov / (fov + rz0 * scale * 0.5);
      final d1 = fov / (fov + rz1 * scale * 0.5);

      final sx0 = cx + rx0 * scale * d0;
      final sy0 = cy + p0.y * scale * d0;
      final sx1 = cx + rx1 * scale * d1;
      final sy1 = cy + p1.y * scale * d1;

      // Fade: newer points are brighter
      final age = i / trail.length; // 0 = oldest, 1 = newest
      final alpha = (age * 220).round().clamp(10, 220);

      // Depth-based thickness and brightness
      final avgDepth = (d0 + d1) / 2;
      final thickness = (1.0 + avgDepth * 1.5).clamp(0.5, 3.0);

      // Color shifts with coherence
      final coherence = engine.hemisphericCoherence;
      final color = Color.lerp(
        baseColor.withAlpha(alpha),
        engine.eegColor.withAlpha(alpha),
        (1.0 - coherence).clamp(0.0, 0.6),
      )!;

      final paint = Paint()
        ..color = color
        ..strokeWidth = thickness
        ..strokeCap = StrokeCap.round
        ..style = PaintingStyle.stroke;

      canvas.drawLine(Offset(sx0, sy0), Offset(sx1, sy1), paint);
    }

    // Draw current point as a glowing dot
    if (trail.isNotEmpty) {
      final last = trail.last;
      final rx = last.x * cosR - last.z * sinR;
      final rz = last.x * sinR + last.z * cosR;
      final d = fov / (fov + rz * scale * 0.5);
      final sx = cx + rx * scale * d;
      final sy = cy + last.y * scale * d;

      // Glow
      final glowPaint = Paint()
        ..color = baseColor.withAlpha(60)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);
      canvas.drawCircle(Offset(sx, sy), 6 * d, glowPaint);

      // Core dot
      final dotPaint = Paint()..color = baseColor;
      canvas.drawCircle(Offset(sx, sy), 3 * d, dotPaint);
    }

    // Draw subtle axis guides
    _drawAxes(canvas, size, cx, cy, scale, cosR, sinR);
  }

  void _drawAxes(Canvas canvas, Size size, double cx, double cy,
      double scale, double cosR, double sinR) {
    final axisPaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.5
      ..style = PaintingStyle.stroke;

    // X axis (rotated)
    final axLen = 0.8;
    final x1r = axLen * cosR;
    final z1r = axLen * sinR;
    final d1 = fov / (fov + z1r * scale * 0.5);
    final d2 = fov / (fov - z1r * scale * 0.5);
    canvas.drawLine(
      Offset(cx - x1r * scale * d2, cy),
      Offset(cx + x1r * scale * d1, cy),
      axisPaint,
    );

    // Y axis (vertical, unaffected by Y rotation)
    canvas.drawLine(
      Offset(cx, cy - axLen * scale),
      Offset(cx, cy + axLen * scale),
      axisPaint,
    );
  }

  @override
  bool shouldRepaint(covariant Lissajous3DPainter old) => true;
}

/// Simple 3D point.
class _Point3D {
  final double x, y, z;
  const _Point3D(this.x, this.y, this.z);
}

/// Widget that wraps the 3D Lissajous painter with animation.
class Lissajous3DWidget extends StatefulWidget {
  final NeomFrequencyPainterEngine engine;
  final Color? baseColor;

  const Lissajous3DWidget({
    super.key,
    required this.engine,
    this.baseColor,
  });

  @override
  State<Lissajous3DWidget> createState() => _Lissajous3DWidgetState();
}

class _Lissajous3DWidgetState extends State<Lissajous3DWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _anim;
  final List<_Point3D> _trail = [];
  double _rotation = 0.0;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(hours: 1),
    )..repeat();
    _anim.addListener(_tick);
  }

  double _idlePhaseL = 0.0;
  double _idlePhaseR = 0.0;

  void _tick() {
    double x, y, z;

    // Check if engine has active audio (phases changing)
    final engineX = widget.engine.lissajousX;
    final engineY = widget.engine.lissajousY;
    final isIdle = (engineX == 0.0 && engineY == 0.0) ||
        (_trail.length > 5 &&
            _trail.last.x == engineX &&
            _trail.last.y == engineY);

    if (isIdle) {
      // Generate preview animation when engine is not playing
      // Uses the engine's current frequency/beat settings for the shape
      // Use binaural beat ratio for the idle animation shape
      // binauralPhase changes over time even when idle if tickBinaural was called
      final beatPhase = widget.engine.binauralPhase;
      final freqRatio = 1.0 + (beatPhase > 0 ? 0.02 : 0.015);

      _idlePhaseL += 0.03;
      _idlePhaseR += 0.03 * freqRatio;
      if (_idlePhaseL > 2 * pi) _idlePhaseL -= 2 * pi;
      if (_idlePhaseR > 2 * pi) _idlePhaseR -= 2 * pi;

      x = sin(_idlePhaseL);
      y = sin(_idlePhaseR);
      z = sin(_rotation * 0.5) * 0.3; // gentle Z oscillation
    } else {
      x = engineX;
      y = engineY;
      final breath = widget.engine.breathPulse;
      z = sin(breath * 2 * pi);
    }

    _trail.add(_Point3D(x, y, z));
    if (_trail.length > Lissajous3DPainter.maxTrail) {
      _trail.removeAt(0);
    }

    // Slow auto-rotation: ~6 seconds per full rotation
    _rotation += 0.008;
    if (_rotation > 2 * pi) _rotation -= 2 * pi;
  }

  @override
  void dispose() {
    _anim.removeListener(_tick);
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => CustomPaint(
        painter: Lissajous3DPainter(
          engine: widget.engine,
          rotationAngle: _rotation,
          trail: _trail,
          baseColor: widget.baseColor ?? const Color(0xFF00BCD4),
        ),
        size: Size.infinite,
      ),
    );
  }
}
