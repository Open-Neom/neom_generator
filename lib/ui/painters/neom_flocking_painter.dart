import 'dart:math';
import 'package:flutter/material.dart';

import '../../engine/neom_flocking_engine.dart';

/// Painter OPTIMIZADO para flocking con profundidad 3D
class NeomFlockingPainter extends CustomPainter {
  final NeomFlockingEngine engine;
  final bool showConnections;
  final bool showGlow;
  final double glowIntensity;

  NeomFlockingPainter({
    required this.engine,
    this.showConnections = true,
    this.showGlow = true,
    this.glowIntensity = 0.8,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    // Ordenar boids por profundidad (los más lejanos primero)
    final sortedBoids = List<Boid>.from(engine.boids)
      ..sort((a, b) => b.z.compareTo(a.z));

    if (showConnections) {
      _drawConnections(canvas);
    }

    // Dibujar boids ordenados por profundidad
    for (final boid in sortedBoids) {
      _drawBoid(canvas, boid);
    }

    _drawVignette(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 1.2,
        colors: [
          const Color(0xFF0A0A15),
          const Color(0xFF050510),
          Colors.black,
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawConnections(Canvas canvas) {
    final connections = engine.getConnections();
    final amp = engine.audioAmplitude.clamp(0.3, 1.0);

    for (final (boid1, boid2, opacity) in connections) {
      // Profundidad promedio para opacidad de la línea
      final avgDepth = (boid1.depthOpacity + boid2.depthOpacity) / 2;

      final color = Color.lerp(boid1.color, boid2.color, 0.5)!
          .withOpacity(opacity * 0.25 * amp * avgDepth);

      final paint = Paint()
        ..color = color
        ..strokeWidth = 0.4 + opacity * 0.6 * avgDepth
        ..style = PaintingStyle.stroke;

      canvas.drawLine(boid1.position, boid2.position, paint);
    }
  }

  void _drawBoid(Canvas canvas, Boid boid) {
    final baseColor = boid.color;
    final energy = boid.energy;
    final visualSize = boid.visualSize;
    final depthOpacity = boid.depthOpacity;

    // Glow effect (más tenue para boids lejanos)
    if (showGlow && visualSize > 1.5) {
      final glowPaint = Paint()
        ..color = baseColor.withOpacity(0.25 * energy * glowIntensity * depthOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, visualSize * 2);

      canvas.drawCircle(boid.position, visualSize * 1.8, glowPaint);
    }

    // Core del boid
    final corePaint = Paint()
      ..color = baseColor.withOpacity((0.7 + energy * 0.3) * depthOpacity)
      ..style = PaintingStyle.fill;

    canvas.drawCircle(boid.position, visualSize, corePaint);

    // Centro brillante (solo para boids cercanos)
    if (boid.z < 0.6) {
      final centerPaint = Paint()
        ..color = Colors.white.withOpacity(0.5 * energy * depthOpacity)
        ..style = PaintingStyle.fill;

      canvas.drawCircle(boid.position, visualSize * 0.3, centerPaint);
    }

    // Cola/trail direccional
    _drawTail(canvas, boid);
  }

  void _drawTail(Canvas canvas, Boid boid) {
    final speed = boid.velocity.distance;
    if (speed < 0.5) return;

    final visualSize = boid.visualSize;
    final depthOpacity = boid.depthOpacity;
    final normalized = boid.velocity / speed;
    final tailLength = visualSize * 2.5 + speed * 0.3;
    final tailEnd = boid.position - normalized * tailLength;

    final tailPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          boid.color.withOpacity(0.5 * depthOpacity),
          boid.color.withOpacity(0.0),
        ],
      ).createShader(Rect.fromPoints(boid.position, tailEnd))
      ..strokeWidth = visualSize * 0.6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    canvas.drawLine(boid.position, tailEnd, tailPaint);
  }

  void _drawVignette(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = max(size.width, size.height);

    final vignettePaint = Paint()
      ..shader = RadialGradient(
        center: Alignment.center,
        radius: 0.75,
        colors: [
          Colors.transparent,
          Colors.black.withOpacity(0.2),
          Colors.black.withOpacity(0.5),
        ],
        stops: const [0.5, 0.8, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius));

    canvas.drawRect(Offset.zero & size, vignettePaint);
  }

  @override
  bool shouldRepaint(covariant NeomFlockingPainter oldDelegate) => true;
}
