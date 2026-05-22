import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../domain/models/harmonic/harmonic_footprint.dart';

/// CustomPainter that renders a unique visual shape from a [HarmonicFootprint].
///
/// The visualization is a "sonic mandala" / radar chart:
/// - 8 axes radiating from center (one per harmonic)
/// - Axis length = harmonic strength (normalized 0-1)
/// - Tips connected with smooth Bezier curves forming an organic shape
/// - Fill gradient: warm (low centroid) to cool (high centroid)
/// - Outer arc = vocal range (pitchRangeMin to pitchRangeMax)
/// - Glow opacity = averageVolume
/// - Dots = individual capture timestamps
class HarmonicFootprintPainter extends CustomPainter {
  final HarmonicFootprint footprint;

  HarmonicFootprintPainter({required this.footprint});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final maxRadius = math.min(size.width, size.height) / 2 * 0.85;

    if (footprint.captures.isEmpty) {
      _paintEmptyState(canvas, center, maxRadius);
      return;
    }

    final signature = footprint.harmonicSignature;
    final centroidAvg = footprint.spectralCentroidAvg;
    final volume = footprint.averageVolume;

    // 1. Draw outer ring (vocal range arc)
    _paintVocalRangeArc(canvas, center, maxRadius);

    // 2. Draw glow behind the shape
    _paintGlow(canvas, center, maxRadius * 0.7, volume);

    // 3. Draw axis guidelines
    _paintAxisGuides(canvas, center, maxRadius * 0.8);

    // 4. Draw the harmonic shape (the fingerprint)
    _paintHarmonicShape(canvas, center, maxRadius * 0.75, signature,
        centroidAvg);

    // 5. Draw capture dots
    _paintCaptureDots(canvas, center, maxRadius * 0.75, signature);

    // 6. Draw center resonance point
    _paintResonanceCenter(canvas, center);
  }

  void _paintEmptyState(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = Colors.white24
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, radius * 0.5, paint);

    // Draw 8 faint axis lines
    for (int i = 0; i < 8; i++) {
      final angle = (2 * math.pi * i / 8) - math.pi / 2;
      final end = Offset(
        center.dx + math.cos(angle) * radius * 0.5,
        center.dy + math.sin(angle) * radius * 0.5,
      );
      canvas.drawLine(center, end, paint);
    }
  }

  void _paintVocalRangeArc(Canvas canvas, Offset center, double radius) {
    final rangeMin = footprint.pitchRangeMin;
    final rangeMax = footprint.pitchRangeMax;
    if (rangeMin <= 0 || rangeMax <= 0) return;

    // Map pitch range to angle (80Hz=0, 1050Hz=2*pi)
    const minFreq = 80.0;
    const maxFreq = 1050.0;
    final startAngle = ((rangeMin - minFreq) / (maxFreq - minFreq)) *
            2 *
            math.pi -
        math.pi / 2;
    final sweepAngle =
        ((rangeMax - rangeMin) / (maxFreq - minFreq)) * 2 * math.pi;

    final arcPaint = Paint()
      ..color = Colors.amberAccent.withValues(alpha: 0.4)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawArc(rect, startAngle, sweepAngle, false, arcPaint);
  }

  void _paintGlow(
      Canvas canvas, Offset center, double radius, double volume) {
    final glowPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        radius,
        [
          Colors.cyanAccent.withValues(alpha: 0.15 * volume),
          Colors.transparent,
        ],
      );
    canvas.drawCircle(center, radius, glowPaint);
  }

  void _paintAxisGuides(Canvas canvas, Offset center, double radius) {
    final guidePaint = Paint()
      ..color = Colors.white10
      ..strokeWidth = 0.5;

    for (int i = 0; i < 8; i++) {
      final angle = (2 * math.pi * i / 8) - math.pi / 2;
      final end = Offset(
        center.dx + math.cos(angle) * radius,
        center.dy + math.sin(angle) * radius,
      );
      canvas.drawLine(center, end, guidePaint);
    }
  }

  void _paintHarmonicShape(
    Canvas canvas,
    Offset center,
    double maxRadius,
    List<double> signature,
    double centroid,
  ) {
    if (signature.length < 8) return;

    // Compute points on each axis
    final points = <Offset>[];
    for (int i = 0; i < 8; i++) {
      final angle = (2 * math.pi * i / 8) - math.pi / 2;
      final r = maxRadius * (0.15 + signature[i] * 0.85); // Min 15% radius
      points.add(Offset(
        center.dx + math.cos(angle) * r,
        center.dy + math.sin(angle) * r,
      ));
    }

    // Create smooth Bezier path through points
    final path = Path();
    path.moveTo(points[0].dx, points[0].dy);

    for (int i = 0; i < points.length; i++) {
      final current = points[i];
      final next = points[(i + 1) % points.length];
      final afterNext = points[(i + 2) % points.length];

      final cp1 = Offset(
        current.dx + (next.dx - points[(i - 1 + points.length) % points.length].dx) * 0.25,
        current.dy + (next.dy - points[(i - 1 + points.length) % points.length].dy) * 0.25,
      );
      final cp2 = Offset(
        next.dx - (afterNext.dx - current.dx) * 0.25,
        next.dy - (afterNext.dy - current.dy) * 0.25,
      );

      path.cubicTo(cp1.dx, cp1.dy, cp2.dx, cp2.dy, next.dx, next.dy);
    }

    path.close();

    // Gradient fill: warm (low centroid) to cool (high centroid)
    // Centroid typically 200-4000 Hz
    final warmth = ((centroid - 200) / 3800).clamp(0.0, 1.0);
    final warmColor = Color.lerp(
      const Color(0xFFFF6B35), // warm orange
      const Color(0xFF4FC3F7), // cool blue
      warmth,
    )!;
    final coolColor = Color.lerp(
      const Color(0xFFE91E63), // warm pink
      const Color(0xFF7C4DFF), // cool purple
      warmth,
    )!;

    final fillPaint = Paint()
      ..shader = ui.Gradient.radial(
        center,
        maxRadius,
        [
          warmColor.withValues(alpha: 0.6),
          coolColor.withValues(alpha: 0.2),
        ],
      );

    canvas.drawPath(path, fillPaint);

    // Stroke
    final strokePaint = Paint()
      ..color = warmColor.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;

    canvas.drawPath(path, strokePaint);
  }

  void _paintCaptureDots(
    Canvas canvas,
    Offset center,
    double maxRadius,
    List<double> signature,
  ) {
    if (footprint.captures.isEmpty) return;

    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.fill;

    final random = math.Random(footprint.userId.hashCode);

    // Place dots on the shape surface, distributed by capture index
    final maxDots = math.min(footprint.captures.length, 50);
    for (int i = 0; i < maxDots; i++) {
      final captureIndex =
          (i * footprint.captures.length / maxDots).floor();
      final capture = footprint.captures[captureIndex];

      // Map this capture to a position on the shape
      final harmonicIndex = (capture.fundamentalHz.hashCode % 8).abs();
      final angle = (2 * math.pi * harmonicIndex / 8) - math.pi / 2;
      final jitter = (random.nextDouble() - 0.5) * 0.3;
      final r = maxRadius *
          (0.15 + signature[harmonicIndex] * 0.85) *
          (0.5 + random.nextDouble() * 0.5);

      final pos = Offset(
        center.dx + math.cos(angle + jitter) * r,
        center.dy + math.sin(angle + jitter) * r,
      );

      canvas.drawCircle(pos, 1.5, dotPaint);
    }
  }

  void _paintResonanceCenter(Canvas canvas, Offset center) {
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    canvas.drawCircle(center, 3.0, centerPaint);

    final ringPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    canvas.drawCircle(center, 6.0, ringPaint);
  }

  @override
  bool shouldRepaint(covariant HarmonicFootprintPainter oldDelegate) {
    return oldDelegate.footprint.totalCaptures != footprint.totalCaptures ||
        oldDelegate.footprint.updatedAt != footprint.updatedAt;
  }
}
