import 'dart:math';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../engine/neom_frequency_painter_engine.dart';
import '../widgets/visual_animation.dart';

/// Paints a sine wave flowing around the perimeter of a rectangle.
///
/// The wave travels: top → right → bottom → left (clockwise),
/// creating a living frame effect. Two waves are drawn:
/// - Left channel (primary color) — brighter trace
/// - Right channel (secondary color) — quieter trace with the binaural phase
/// The beat between them creates visible interference patterns.
/// Both traces stay within a narrow border band, clear of the controls.
class PerimeterWavePainter extends CustomPainter {
  final NeomFrequencyPainterEngine engine;
  final double _time;
  final VisualAnimationClock? clock;
  double get time => clock == null ? _time : clock!.value * 2 * pi;
  final Color primaryColor;
  final Color secondaryColor;
  final double strokeWidth;
  final double amplitude;
  final double inset;

  PerimeterWavePainter({
    required this.engine,
    double time = 0,
    this.clock,
    this.primaryColor = const Color(0xFF00BCD4),
    this.secondaryColor = const Color(0xFFAB47BC),
    this.strokeWidth = 2.0,
    this.amplitude = 12.0,
    this.inset = 0.0,
  }) : _time = time,
       super(repaint: clock);

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || !size.isFinite) return;
    if (!inset.isFinite || !amplitude.isFinite || !strokeWidth.isFinite) return;
    final rect = (Offset.zero & size).deflate(max(0.0, inset));
    if (rect.isEmpty) return;
    final perimeter = 2 * (rect.width + rect.height);

    // Number of sample points around the perimeter — fewer on web
    final sampleCount = (perimeter / 8).ceil().clamp(64, 240);

    final freq = (3.0 + engine.waveStretch * 2.0).clamp(1.0, sampleCount / 8);
    final beat = engine.binauralPhase;
    final amp = amplitude.clamp(0.0, 5.0) * (0.5 + engine.glowIntensity * 0.5);

    // Build paths for L and R channels
    final pathL = Path();
    final pathR = Path();

    final corners = [
      rect.topLeft,
      rect.topRight,
      rect.bottomRight,
      rect.bottomLeft,
      rect.topLeft,
    ];
    double accumulated = 0;
    for (var edge = 0; edge < 4; edge++) {
      final from = corners[edge];
      final to = corners[edge + 1];
      final delta = to - from;
      final length = delta.distance;
      final normal = Offset(-delta.dy, delta.dx) / length;
      final steps = max(1, (length / perimeter * sampleCount).ceil());
      for (var i = 0; i <= steps; i++) {
        final localT = i / steps;
        final t = (accumulated + localT * length) / perimeter;
        final pos = Offset.lerp(from, to, localT)!;
        // Sampling each edge includes every corner exactly. Tapering there
        // avoids diagonal cuts and a phase discontinuity at the loop seam.
        final taper = min(1.0, min(localT, 1 - localT) * length / 12);
        final phase = t * freq * 2 * pi + time * 4;
        final pL = pos + normal * ((sin(phase) + 1) * 0.5 * amp * taper);
        final pR =
            pos + normal * ((sin(phase + beat) + 1) * 0.5 * amp * 0.8 * taper);
        if (edge == 0 && i == 0) {
          pathL.moveTo(pL.dx, pL.dy);
          pathR.moveTo(pR.dx, pR.dy);
        } else {
          pathL.lineTo(pL.dx, pL.dy);
          pathR.lineTo(pR.dx, pR.dy);
        }
      }
      accumulated += length;
    }
    pathL.close();
    pathR.close();

    final borderRegion = Path()..addRect(Offset.zero & size);
    final interior = rect.deflate(6);
    if (!interior.isEmpty) {
      borderRegion
        ..fillType = PathFillType.evenOdd
        ..addRect(interior);
    }
    canvas.save();
    canvas.clipPath(borderRegion);

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
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant PerimeterWavePainter old) =>
      clock == null ||
      engine != old.engine ||
      clock != old.clock ||
      _time != old._time ||
      primaryColor != old.primaryColor ||
      secondaryColor != old.secondaryColor ||
      amplitude != old.amplitude ||
      strokeWidth != old.strokeWidth ||
      inset != old.inset;
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

class _PerimeterWaveWidgetState extends State<PerimeterWaveWidget> {
  @override
  Widget build(BuildContext context) {
    return VisualAnimation(
      active: widget.isActive,
      builder: (_, clock, child) => Stack(
        fit: StackFit.passthrough,
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: widget.isActive
                      ? PerimeterWavePainter(
                          engine: widget.engine,
                          clock: clock,
                          primaryColor:
                              widget.primaryColor ?? const Color(0xFF00BCD4),
                          secondaryColor:
                              widget.secondaryColor ?? const Color(0xFFAB47BC),
                          amplitude: widget.amplitude,
                          strokeWidth: widget.strokeWidth,
                        )
                      : null,
                ),
              ),
            ),
          ),
          // The child keeps the same ancestors when playing/stopping. Paints
          // cannot interrupt an in-progress tap, slider drag, or text focus.
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(
                color: widget.isActive
                    ? Colors.transparent
                    : (widget.primaryColor ?? const Color(0xFF00BCD4))
                          .withAlpha(25),
                width: 0.5,
              ),
              borderRadius: BorderRadius.circular(4),
            ),
            child: child,
          ),
        ],
      ),
      child: RepaintBoundary(child: widget.child ?? const SizedBox.shrink()),
    );
  }
}
