import 'package:flutter/material.dart';

class NeomOscilloscopeFullscreenPainter extends CustomPainter {
  final List<double> samples;
  final Color signalColor;
  final Color gridColor;
  final double thickness;
  final double waveScale;
  final double timeScale;
  final bool showGrid;
  final bool showGlow;
  final bool isPaused;

  NeomOscilloscopeFullscreenPainter({
    required this.samples,
    required this.signalColor,
    required this.gridColor,
    this.thickness = 1.8,
    this.waveScale = 0.4,
    this.timeScale = 1.0,
    this.showGrid = true,
    this.showGlow = true,
    this.isPaused = false,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);

    if (showGrid) {
      _drawGrid(canvas, size);
    }

    _drawCenterLine(canvas, size);
    _drawWave(canvas, size);

    if (isPaused) {
      _drawPauseOverlay(canvas, size);
    }

    _drawBorder(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF050510),
          const Color(0xFF0A0015),
          const Color(0xFF050510),
        ],
      ).createShader(Offset.zero & size);

    canvas.drawRect(Offset.zero & size, paint);
  }

  void _drawGrid(Canvas canvas, Size size) {
    final major = Paint()
      ..color = gridColor.withValues(alpha: 0.25)
      ..strokeWidth = 1;

    final minor = Paint()
      ..color = gridColor.withValues(alpha: 0.08)
      ..strokeWidth = 0.5;

    const divisionsH = 20;
    const divisionsV = 10;

    // Líneas verticales
    for (int i = 0; i <= divisionsH; i++) {
      final x = size.width * i / divisionsH;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x, size.height),
        i % 5 == 0 ? major : minor,
      );
    }

    // Líneas horizontales
    for (int i = 0; i <= divisionsV; i++) {
      final y = size.height * i / divisionsV;
      canvas.drawLine(
        Offset(0, y),
        Offset(size.width, y),
        i % 5 == 0 ? major : minor,
      );
    }
  }

  void _drawCenterLine(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = signalColor.withValues(alpha: 0.3)
      ..strokeWidth = 1;

    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);
  }

  void _drawWave(Canvas canvas, Size size) {
    if (samples.isEmpty) return;

    final path = Path();
    final midY = size.height / 2;
    final scaleY = size.height * waveScale;

    // Calcular cuántos samples mostrar según timeScale
    final visibleSamples = (samples.length / timeScale).round().clamp(10, samples.length);
    final startIndex = samples.length - visibleSamples;

    for (int i = 0; i < visibleSamples; i++) {
      final sampleIndex = (startIndex + i).clamp(0, samples.length - 1);
      final x = size.width * i / (visibleSamples - 1);
      final y = midY - samples[sampleIndex] * scaleY;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Glow effect
    if (showGlow) {
      final glow = Paint()
        ..color = signalColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness * 4
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12);

      canvas.drawPath(path, glow);

      // Segundo layer de glow más intenso
      final glowInner = Paint()
        ..color = signalColor.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = thickness * 2
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);

      canvas.drawPath(path, glowInner);
    }

    // Señal principal
    final signal = Paint()
      ..color = signalColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, signal);
  }

  void _drawPauseOverlay(Canvas canvas, Size size) {
    // Overlay semitransparente
    final overlay = Paint()..color = Colors.black.withValues(alpha: 0.2);
    canvas.drawRect(Offset.zero & size, overlay);

    // Marcadores de tiempo congelado
    final markerPaint = Paint()
      ..color = signalColor.withValues(alpha: 0.5)
      ..strokeWidth = 2;

    // Línea vertical pulsante en el centro
    final centerX = size.width / 2;
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, size.height),
      markerPaint,
    );
  }

  void _drawBorder(Canvas canvas, Size size) {
    final borderPaint = Paint()
      ..color = signalColor.withValues(alpha: 0.3)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(1, 1, size.width - 2, size.height - 2),
      const Radius.circular(4),
    );

    canvas.drawRRect(rrect, borderPaint);
  }

  @override
  bool shouldRepaint(covariant NeomOscilloscopeFullscreenPainter oldDelegate) {
    return samples != oldDelegate.samples ||
        thickness != oldDelegate.thickness ||
        waveScale != oldDelegate.waveScale ||
        timeScale != oldDelegate.timeScale ||
        showGrid != oldDelegate.showGrid ||
        showGlow != oldDelegate.showGlow ||
        isPaused != oldDelegate.isPaused;
  }
}
