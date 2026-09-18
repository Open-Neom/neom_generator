import 'dart:math';

import 'package:flutter/material.dart';

import '../../engine/neom_frequency_painter_engine.dart';
import '../widgets/visual_animation.dart';
import 'lissajous_painter.dart';

/// 3D Lissajous figure with perspective projection.
///
/// X/Y trace the actual left/right oscillator frequency ratio and relative
/// phase at a readable visual speed. Z is the actual breathing envelope.
///
/// The figure auto-rotates slowly around the Y axis, creating a
/// hypnotic 3D effect. Trail of previous points fades out.
class Lissajous3DPainter extends CustomPainter {
  final NeomFrequencyPainterEngine engine;
  final double rotationAngle;
  final Color baseColor;
  final VisualAnimationClock? _clock;
  final _LissajousVisualState? _visualState;

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
  }) : _clock = null,
       _visualState = null;

  Lissajous3DPainter._animated({
    required this.engine,
    required VisualAnimationClock clock,
    required _LissajousVisualState visualState,
    required this.baseColor,
  }) : rotationAngle = 0,
       trail = visualState.trail,
       _clock = clock,
       _visualState = visualState,
       super(repaint: clock);

  @override
  void paint(Canvas canvas, Size size) {
    // Advance only visual state, once per clock notification. The engine/audio
    // remains independent, and extra paints do not add duplicate trail points.
    final clock = _clock;
    final visualState = _visualState;
    if (clock != null && visualState != null) {
      visualState.advance(engine, clock.elapsed);
    }
    if (trail.isEmpty) return;

    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = size.shortestSide * 0.35;

    // Auto-rotation around Y axis
    final rotation = visualState?.rotation ?? rotationAngle;
    final cosR = cos(rotation);
    final sinR = sin(rotation);

    // Draw trail with fade
    for (int i = 1; i < trail.length; i++) {
      final p0 = trail[i - 1];
      final p1 = trail[i];
      // An open sweep restarts at its beginning; connecting its endpoints
      // would introduce a straight segment unrelated to either oscillator.
      if (p1.breakBefore) continue;

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

  void _drawAxes(
    Canvas canvas,
    Size size,
    double cx,
    double cy,
    double scale,
    double cosR,
    double sinR,
  ) {
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
  bool shouldRepaint(covariant Lissajous3DPainter old) =>
      _clock == null ||
      old._clock != _clock ||
      old.engine != engine ||
      old.baseColor != baseColor ||
      old._visualState != _visualState ||
      old.rotationAngle != rotationAngle;
}

/// Simple 3D point.
class _Point3D {
  final double x, y, z;
  final Duration elapsed;
  final bool breakBefore;

  /// Position in the observation window, independent of its current Hz/phase.
  /// Null denotes a legacy point supplied directly by an oscillator producer.
  final double? sweepFraction;
  const _Point3D(
    this.x,
    this.y,
    this.z, [
    this.elapsed = Duration.zero,
    this.breakBefore = false,
    this.sweepFraction,
  ]);
}

/// Mutable drawing cache shared across painter replacements, never audio state.
class _LissajousVisualState {
  final List<_Point3D> trail = [];
  Duration? _lastElapsed;
  double _traceSeconds = 0;
  double? _lastSweepFraction;
  double rotation = 0;

  void advance(NeomFrequencyPainterEngine engine, Duration elapsed) {
    if (_lastElapsed == elapsed) return;
    final previous = _lastElapsed ?? elapsed;
    final dt = max(0.0, (elapsed - previous).inMicroseconds / 1000000.0);
    _lastElapsed = elapsed;

    final session = engine.audioSession;
    final geometry = LissajousGeometry.fromFrequencies(
      leftHz: session.leftHz,
      rightHz: session.rightHz,
      phaseDifference: session.beatPhase,
    );

    double x, y, z;
    var breakBefore = false;
    double? sweepFraction;
    if (geometry != null) {
      if (!session.isPlaying && trail.isNotEmpty) return;
      if (session.isPlaying) {
        _traceSeconds += dt;
        // Camera rotation is visual presentation, never audio/EEG telemetry.
        rotation = (rotation + 0.48 * dt) % (2 * pi);
      }
      final parameter = geometry.traceParameter(_traceSeconds);
      sweepFraction = parameter / geometry.sweepRadians;
      breakBefore =
          _lastSweepFraction != null && sweepFraction < _lastSweepFraction!;
      _lastSweepFraction = sweepFraction;
      // Legacy oscillator points do not identify a location on this curve.
      trail.removeWhere((point) => point.sweepFraction == null);
      final point = geometry.pointAt(parameter);
      x = point.dx;
      y = point.dy;
      z = session.breathingEnabled && session.breathValue.isFinite
          ? session.breathValue.clamp(0.0, 1.0) * 2 - 1
          : 0;
    } else {
      // Legacy producers can supply phases without session telemetry. Repeated
      // samples stay repeated: silence or equal phases never create fake beats.
      x = engine.lissajousX;
      y = engine.lissajousY;
      z = 0;
      if (!x.isFinite || !y.isFinite) return;
    }

    trail.add(_Point3D(x, y, z, elapsed, breakBefore, sweepFraction));
    // 300 points at the old nominal 60 Hz were about five seconds. Keep the
    // same duration when the visual scheduler uses a lower frame rate.
    final cutoff = elapsed - const Duration(seconds: 5);
    trail.removeWhere((point) => point.elapsed < cutoff);
    if (trail.length > Lissajous3DPainter.maxTrail) {
      trail.removeRange(0, trail.length - Lissajous3DPainter.maxTrail);
    }
    if (geometry != null) {
      // All points belong to ONE instantaneous L/R geometry. Retaining each
      // point's old beat phase connects different curves into vertical bars.
      // Reproject the stored sweep positions, retaining real breath history,
      // timestamps and sweep breaks. This also handles changing frequency sets.
      final sweep = geometry.sweepRadians;
      for (var i = 0; i < trail.length; i++) {
        final previousPoint = trail[i];
        final point = geometry.pointAt(previousPoint.sweepFraction! * sweep);
        trail[i] = _Point3D(
          point.dx,
          point.dy,
          previousPoint.z,
          previousPoint.elapsed,
          previousPoint.breakBefore,
          previousPoint.sweepFraction,
        );
      }
    }
  }
}

/// Widget that wraps the 3D Lissajous painter with animation.
class Lissajous3DWidget extends StatefulWidget {
  final NeomFrequencyPainterEngine engine;
  final Color? baseColor;

  const Lissajous3DWidget({super.key, required this.engine, this.baseColor});

  @override
  State<Lissajous3DWidget> createState() => _Lissajous3DWidgetState();
}

class _Lissajous3DWidgetState extends State<Lissajous3DWidget> {
  _LissajousVisualState _visualState = _LissajousVisualState();

  @override
  void didUpdateWidget(covariant Lissajous3DWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.engine != widget.engine) {
      _visualState = _LissajousVisualState();
    }
  }

  @override
  Widget build(BuildContext context) {
    return VisualAnimation(
      builder: (context, clock, child) => RepaintBoundary(
        child: CustomPaint(
          painter: Lissajous3DPainter._animated(
            engine: widget.engine,
            clock: clock,
            visualState: _visualState,
            baseColor: widget.baseColor ?? const Color(0xFF00BCD4),
          ),
          size: Size.infinite,
        ),
      ),
    );
  }
}
