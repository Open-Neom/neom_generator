import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../engine/neom_frequency_painter_engine.dart';
import '../widgets/visual_animation.dart';

/// Oscillator geometry in normalized coordinates. Hz determine the frequency
/// ratio; a wrapped phase is an angle and cannot be used as a frequency.
class LissajousGeometry {
  LissajousGeometry._(this.leftRatio, this.rightRatio, this.phaseDifference);

  static LissajousGeometry? fromFrequencies({
    required double leftHz,
    required double rightHz,
    required double phaseDifference,
  }) {
    if (!leftHz.isFinite ||
        !rightHz.isFinite ||
        !phaseDifference.isFinite ||
        leftHz < 0 ||
        rightHz < 0 ||
        (leftHz == 0 && rightHz == 0)) {
      return null;
    }
    final referenceHz = leftHz == 0 || rightHz == 0
        ? math.max(leftHz, rightHz)
        : math.min(leftHz, rightHz);
    final leftRatio = leftHz / referenceHz;
    final rightRatio = rightHz / referenceHz;
    if (!leftRatio.isFinite || !rightRatio.isFinite) return null;
    return LissajousGeometry._(leftRatio, rightRatio, phaseDifference);
  }

  final double leftRatio;
  final double rightRatio;
  final double phaseDifference;

  double get fastestRatio => math.max(leftRatio, rightRatio);

  /// Include complete simple ratios (3:2 needs two slow-channel periods).
  /// For an incommensurate or extreme ratio show a bounded, open observation
  /// window, preserving the exact frequencies rather than rounding the ratio.
  double get sweepRadians {
    for (var cycles = 1; cycles <= 8; cycles++) {
      final left = leftRatio * cycles;
      final right = rightRatio * cycles;
      if (math.max(left, right) > 16) break;
      if ((left - left.round()).abs() < 1e-8 &&
          (right - right.round()).abs() < 1e-8) {
        return cycles * 2 * math.pi;
      }
    }
    return math.min(1.0, 16 / fastestRatio) * 2 * math.pi;
  }

  Offset pointAt(double parameter) => Offset(
    math.sin(parameter * leftRatio),
    math.sin(parameter * rightRatio + phaseDifference),
  );

  /// The marker scans the displayed curve at a readable rate. This is a visual
  /// tracer, not reconstructed audio phase; both axes keep their actual ratio.
  double traceParameter(double visualSeconds) =>
      (visualSeconds * 1.8 / fastestRatio) % sweepRadians;
}

/// Lissajous figure: plots sin(phaseL) vs sin(phaseR).
///
/// When freqL == freqR (no binaural beat) → straight line or ellipse.
/// When freqL/freqR is a simple ratio (2:1, 3:2, etc.) → classic Lissajous
/// patterns (figure-8, trefoils, etc.). The beat frequency determines how
/// fast the pattern rotates.
class LissajousPainter extends CustomPainter {
  final NeomFrequencyPainterEngine engine;
  final Color color;
  final bool useEngineColor;
  final VisualAnimationClock? _clock;
  Duration? _previousElapsed;
  double _traceSeconds = 0;

  LissajousPainter({
    required this.engine,
    required this.color,
    this.useEngineColor = false,
    Listenable? repaint,
  }) : _clock = repaint is VisualAnimationClock ? repaint : null,
       super(repaint: repaint ?? engine);

  @override
  void paint(Canvas canvas, Size size) {
    final session = engine.audioSession;
    final geometry = LissajousGeometry.fromFrequencies(
      leftHz: session.leftHz,
      rightHz: session.rightHz,
      phaseDifference: session.beatPhase,
    );
    // No oscillator telemetry means no inferred 1:1 signal or fallback line.
    if (geometry == null || size.isEmpty) return;

    final elapsed = _clock?.elapsed;
    if (elapsed != null) {
      final previous = _previousElapsed ?? elapsed;
      _previousElapsed = elapsed;
      if (session.isPlaying) {
        _traceSeconds += math.max(
          0.0,
          (elapsed - previous).inMicroseconds / 1000000,
        );
      }
    } else {
      // Direct engine-listening callers still track output progress. This
      // scans the curve; it does not estimate oscillator phase as elapsed * Hz.
      _traceSeconds = session.elapsedSeconds;
    }

    final signalColor = useEngineColor ? engine.eegColor : color;
    final cx = size.width / 2;
    final cy = size.height / 2;
    final scale = math.min(cx, cy) * 0.85;

    final path = Path();

    final sweep = geometry.sweepRadians;
    final steps = math.max(
      400,
      (sweep / (2 * math.pi) * geometry.fastestRatio * 80).ceil(),
    );

    for (int i = 0; i <= steps; i++) {
      final point = geometry.pointAt(i / steps * sweep);
      final x = cx + point.dx * scale;
      final y = cy + point.dy * scale;

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
        ..color = signalColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10),
    );

    // Signal
    canvas.drawPath(
      path,
      Paint()
        ..color = signalColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // A mono 1:1 curve can correctly remain a line. Its moving marker makes
    // playback progress visible without deforming the selected relationship.
    final trace = geometry.pointAt(geometry.traceParameter(_traceSeconds));
    final position = Offset(cx + trace.dx * scale, cy + trace.dy * scale);
    canvas.drawCircle(
      position,
      6,
      Paint()
        ..color = signalColor.withValues(alpha: 0.45)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(position, 2.5, Paint()..color = signalColor);
  }

  @override
  bool shouldRepaint(_) => true;
}
