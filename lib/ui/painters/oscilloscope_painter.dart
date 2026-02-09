import 'package:flutter/material.dart';

import '../../engine/neom_frequency_painter_engine.dart';

class OscilloscopePainter extends CustomPainter {
  final NeomFrequencyPainterEngine engine;
  final Color signalColor;
  final Color gridColor;

  OscilloscopePainter({
    required this.engine,
    required this.signalColor,
    required this.gridColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    _drawBackground(canvas, size);
    _drawGrid(canvas, size);
    _drawWave(canvas, size);
  }

  void _drawBackground(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.black,
          const Color(0xFF12001A),
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

    const divisions = 10;

    for (int i = 0; i <= divisions; i++) {
      final x = size.width * i / divisions;
      final y = size.height * i / divisions;

      canvas.drawLine(Offset(x, 0), Offset(x, size.height),
          i % 5 == 0 ? major : minor);
      canvas.drawLine(Offset(0, y), Offset(size.width, y),
          i % 5 == 0 ? major : minor);
    }
  }

  void _drawWave(Canvas canvas, Size size) {
    final samples = engine.samples; // Float32List o List<double>
    if (samples.isEmpty) return;

    final path = Path();
    final midY = size.height / 2;
    final scaleY = size.height * 0.4;

    for (int i = 0; i < samples.length; i++) {
      final x = size.width * i / (samples.length - 1);
      final y = midY - samples[i] * scaleY;

      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    // Glow
    final glow = Paint()
      ..color = signalColor.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);

    // Signal
    final signal = Paint()
      ..color = signalColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(path, glow);
    canvas.drawPath(path, signal);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
