import 'dart:math';
import 'package:flutter/material.dart';

import '../../engine/neom_breathing_engine.dart';

/// Painter para la visualización del ejercicio de respiración
class NeomBreathingPainter extends CustomPainter {
  final NeomBreathingEngine engine;
  final bool showGuide;
  final bool showParticles;

  // Partículas decorativas
  final List<_BreathParticle> _particles = [];
  static const int _maxParticles = 40;

  NeomBreathingPainter({
    required this.engine,
    this.showGuide = true,
    this.showParticles = true,
  }) {
    // Inicializar partículas si es necesario
    if (_particles.isEmpty && showParticles) {
      final random = Random();
      for (int i = 0; i < _maxParticles; i++) {
        _particles.add(_BreathParticle(
          x: random.nextDouble(),
          y: random.nextDouble(),
          size: 1.0 + random.nextDouble() * 2.0,
          speed: 0.1 + random.nextDouble() * 0.3,
          opacity: 0.2 + random.nextDouble() * 0.4,
        ));
      }
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    // Fondo con gradiente
    _drawBackground(canvas, size);

    // Partículas flotantes
    if (showParticles) {
      _drawParticles(canvas, size);
    }

    // Guía de zona táctil
    if (showGuide) {
      _drawTouchGuide(canvas, size);
    }

    // Indicador de progreso lateral
    _drawProgressBar(canvas, size);

    // Esfera principal con glow
    _drawSphere(canvas, size);

    // Texto de fase
    _drawPhaseText(canvas, size);

    // Indicador de atención
    _drawAttentionIndicator(canvas, size);

    // Indicador de dedo del usuario
    if (engine.isUserTouching) {
      _drawUserTouch(canvas, size);
    }
  }

  void _drawBackground(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);

    // Gradiente basado en fase
    final topColor = engine.sphereColor.withValues(alpha: 0.15);
    final bottomColor = Colors.black;

    final gradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [topColor, bottomColor, bottomColor],
      stops: const [0.0, 0.5, 1.0],
    );

    final paint = Paint()
      ..shader = gradient.createShader(rect);

    canvas.drawRect(rect, paint);

    // Líneas sutiles de guía
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.03)
      ..strokeWidth = 1;

    for (int i = 1; i < 10; i++) {
      final y = size.height * i / 10;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        linePaint,
      );
    }
  }

  void _drawParticles(Canvas canvas, Size size) {
    final random = Random();
    final paint = Paint();

    for (var particle in _particles) {
      // Mover partículas hacia arriba o abajo según la fase
      final direction = engine.phase == BreathingPhase.inhale ||
          engine.phase == BreathingPhase.holdIn
          ? -1.0
          : 1.0;

      particle.y += particle.speed * 0.01 * direction;

      // Wrap around
      if (particle.y < 0) particle.y = 1.0;
      if (particle.y > 1) particle.y = 0.0;

      // Añadir movimiento horizontal sutil
      particle.x += (random.nextDouble() - 0.5) * 0.002;
      particle.x = particle.x.clamp(0.0, 1.0);

      // Dibujar partícula
      final px = particle.x * size.width;
      final py = particle.y * size.height;

      // Opacidad varía con la distancia a la esfera
      final sphereY = engine.getSphereY();
      final distToSphere = (py - sphereY).abs() / size.height;
      final opacity = particle.opacity * (0.3 + (1 - distToSphere) * 0.7);

      paint.color = engine.sphereColor.withValues(alpha: opacity * 0.5);

      canvas.drawCircle(
        Offset(px, py),
        particle.size * (1 + engine.audioAmplitude * 0.5),
        paint,
      );
    }
  }

  void _drawTouchGuide(Canvas canvas, Size size) {
    // Zona central donde el usuario debe tocar
    final centerX = size.width / 2;
    final guideWidth = size.width * 0.4;

    final guidePaint = Paint()
      ..color = engine.sphereColor.withValues(alpha: 0.08)
      ..style = PaintingStyle.fill;

    final guideRect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset(centerX, size.height / 2),
        width: guideWidth,
        height: size.height * 0.85,
      ),
      const Radius.circular(30),
    );

    canvas.drawRRect(guideRect, guidePaint);

    // Borde de la guía
    final borderPaint = Paint()
      ..color = engine.sphereColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;

    canvas.drawRRect(guideRect, borderPaint);

    // Flechas de dirección
    _drawDirectionArrows(canvas, size, centerX, guideWidth);
  }

  void _drawDirectionArrows(Canvas canvas, Size size, double centerX, double guideWidth) {
    final arrowPaint = Paint()
      ..color = engine.sphereColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final isGoingUp = engine.phase == BreathingPhase.inhale;
    final arrowSize = 15.0;

    // Dibujar múltiples flechas
    for (int i = 0; i < 3; i++) {
      final yOffset = size.height * 0.3 + i * 80;
      final opacity = 0.1 + (engine.getPhaseProgress() * 0.2);

      arrowPaint.color = engine.sphereColor.withValues(alpha: opacity);

      final arrowY = isGoingUp ? yOffset : size.height - yOffset;

      final path = Path();
      if (isGoingUp) {
        path.moveTo(centerX - arrowSize, arrowY + arrowSize);
        path.lineTo(centerX, arrowY);
        path.lineTo(centerX + arrowSize, arrowY + arrowSize);
      } else {
        path.moveTo(centerX - arrowSize, arrowY - arrowSize);
        path.lineTo(centerX, arrowY);
        path.lineTo(centerX + arrowSize, arrowY - arrowSize);
      }

      canvas.drawPath(path, arrowPaint);
    }
  }

  void _drawProgressBar(Canvas canvas, Size size) {
    final barWidth = 6.0;
    final barX = size.width - 25;
    final barTop = size.height * 0.1;
    final barBottom = size.height * 0.9;
    final barHeight = barBottom - barTop;

    // Fondo del bar
    final bgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.1)
      ..style = PaintingStyle.fill;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barTop, barWidth, barHeight),
        const Radius.circular(3),
      ),
      bgPaint,
    );

    // Progreso (posición de la esfera)
    final progress = 1.0 - engine.spherePosition;
    final fillHeight = barHeight * progress;

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          engine.sphereColor.withValues(alpha: 0.8),
          engine.sphereColor.withValues(alpha: 0.3),
        ],
      ).createShader(Rect.fromLTWH(barX, barTop, barWidth, barHeight));

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(barX, barTop + (barHeight - fillHeight), barWidth, fillHeight),
        const Radius.circular(3),
      ),
      fillPaint,
    );

    // Marcador de posición actual
    final markerY = barTop + barHeight * progress;
    final markerPaint = Paint()
      ..color = engine.sphereColor
      ..style = PaintingStyle.fill;

    canvas.drawCircle(
      Offset(barX + barWidth / 2, markerY),
      5,
      markerPaint,
    );
  }

  void _drawSphere(Canvas canvas, Size size) {
    final centerX = size.width / 2;
    final centerY = engine.getSphereY();
    final radius = engine.sphereRadius;

    // Glow exterior múltiple
    for (int i = 4; i >= 0; i--) {
      final glowRadius = radius + (i * 20 * engine.glowIntensity);
      final glowOpacity = 0.05 * (5 - i) * engine.glowIntensity;

      final glowPaint = Paint()
        ..color = engine.sphereColor.withValues(alpha: glowOpacity)
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, glowRadius * 0.5);

      canvas.drawCircle(
        Offset(centerX, centerY),
        glowRadius,
        glowPaint,
      );
    }

    // Esfera principal con gradiente
    final sphereGradient = RadialGradient(
      center: const Alignment(-0.3, -0.3),
      radius: 1.0,
      colors: [
        Colors.white.withValues(alpha: 0.9),
        engine.sphereColor,
        engine.sphereColor.withValues(alpha: 0.7),
      ],
      stops: const [0.0, 0.4, 1.0],
    );

    final spherePaint = Paint()
      ..shader = sphereGradient.createShader(
        Rect.fromCircle(center: Offset(centerX, centerY), radius: radius),
      );

    canvas.drawCircle(
      Offset(centerX, centerY),
      radius,
      spherePaint,
    );

    // Highlight brillante
    final highlightPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.6)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);

    canvas.drawCircle(
      Offset(centerX - radius * 0.3, centerY - radius * 0.3),
      radius * 0.25,
      highlightPaint,
    );

    // Anillo pulsante alrededor
    final ringPaint = Paint()
      ..color = engine.sphereColor.withValues(alpha: 0.3 + engine.audioAmplitude * 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final ringRadius = radius * (1.3 + sin(engine.audioPhase * 2) * 0.1);
    canvas.drawCircle(
      Offset(centerX, centerY),
      ringRadius,
      ringPaint,
    );
  }

  void _drawPhaseText(Canvas canvas, Size size) {
    final text = engine.getPhaseText();
    final centerX = size.width / 2;

    // Posición del texto (arriba o abajo de la esfera según la fase)
    final sphereY = engine.getSphereY();
    final textY = engine.spherePosition > 0.5
        ? sphereY + engine.sphereRadius + 50
        : sphereY - engine.sphereRadius - 50;

    // Texto principal
    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: engine.sphereColor,
          fontSize: 28,
          fontWeight: FontWeight.bold,
          letterSpacing: 8,
          shadows: [
            Shadow(
              color: engine.sphereColor.withValues(alpha: 0.5),
              blurRadius: 10,
            ),
          ],
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(centerX - textPainter.width / 2, textY - textPainter.height / 2),
    );

    // Texto secundario con tiempos
    final timeText = _getTimeText();
    final timePainter = TextPainter(
      text: TextSpan(
        text: timeText,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.5),
          fontSize: 12,
          fontFamily: 'Courier',
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    timePainter.layout();
    timePainter.paint(
      canvas,
      Offset(
        centerX - timePainter.width / 2,
        textY + (engine.spherePosition > 0.5 ? 25 : -25) - timePainter.height / 2,
      ),
    );
  }

  String _getTimeText() {
    final progress = engine.getPhaseProgress();
    double duration;

    switch (engine.phase) {
      case BreathingPhase.inhale:
        duration = engine.inhaleTime;
        break;
      case BreathingPhase.holdIn:
        duration = engine.holdInTime;
        break;
      case BreathingPhase.exhale:
        duration = engine.exhaleTime;
        break;
      case BreathingPhase.holdOut:
        duration = engine.holdOutTime;
        break;
    }

    final remaining = (duration * (1 - progress)).ceil();
    return '${remaining}s';
  }

  void _drawAttentionIndicator(Canvas canvas, Size size) {
    final score = engine.attentionScore;
    final avgScore = engine.sessionAttentionAvg;

    // Indicador en la esquina superior izquierda
    final indicatorX = 20.0;
    final indicatorY = 50.0;

    // Fondo
    final bgPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.5);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(indicatorX, indicatorY, 80, 50),
        const Radius.circular(10),
      ),
      bgPaint,
    );

    // Barra de atención actual
    final barWidth = 60.0;
    final barHeight = 6.0;
    final barY = indicatorY + 20;

    final barBgPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.2);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(indicatorX + 10, barY, barWidth, barHeight),
        const Radius.circular(3),
      ),
      barBgPaint,
    );

    // Barra de progreso
    final attentionColor = Color.lerp(
      Colors.red,
      Colors.green,
      score,
    )!;

    final barFillPaint = Paint()
      ..color = attentionColor;

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(indicatorX + 10, barY, barWidth * score, barHeight),
        const Radius.circular(3),
      ),
      barFillPaint,
    );

    // Texto "FOCUS"
    final textPainter = TextPainter(
      text: TextSpan(
        text: 'FOCUS',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.6),
          fontSize: 9,
          letterSpacing: 2,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(indicatorX + 10, indicatorY + 5),
    );

    // Porcentaje promedio
    final avgPainter = TextPainter(
      text: TextSpan(
        text: '${(avgScore * 100).toInt()}%',
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.8),
          fontSize: 10,
          fontFamily: 'Courier',
          fontWeight: FontWeight.bold,
        ),
      ),
      textDirection: TextDirection.ltr,
    );

    avgPainter.layout();
    avgPainter.paint(
      canvas,
      Offset(indicatorX + 10, barY + 12),
    );
  }

  void _drawUserTouch(Canvas canvas, Size size) {
    final touchY = size.height * 0.1 +
        (1.0 - engine.userTouchY) * size.height * 0.8;
    final centerX = size.width / 2;

    // Línea horizontal donde está el dedo
    final linePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    canvas.drawLine(
      Offset(centerX - 50, touchY),
      Offset(centerX + 50, touchY),
      linePaint,
    );

    // Círculo indicador del dedo
    final touchPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.5)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    canvas.drawCircle(
      Offset(centerX, touchY),
      20,
      touchPaint,
    );

    // Punto central
    final dotPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.8);

    canvas.drawCircle(
      Offset(centerX, touchY),
      4,
      dotPaint,
    );
  }

  @override
  bool shouldRepaint(covariant NeomBreathingPainter oldDelegate) => true;
}

/// Partícula decorativa para el fondo
class _BreathParticle {
  double x;
  double y;
  double size;
  double speed;
  double opacity;

  _BreathParticle({
    required this.x,
    required this.y,
    required this.size,
    required this.speed,
    required this.opacity,
  });
}
