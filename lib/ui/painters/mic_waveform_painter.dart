import 'package:flutter/material.dart';

/// Paints a real-time bar waveform from microphone amplitude samples.
///
/// Each bar represents one RMS amplitude reading (0.0–1.0).
/// Bars scroll left as new samples arrive (latest on the right).
class MicWaveformPainter extends CustomPainter {
  final List<double> bars;
  final Color color;

  MicWaveformPainter({required this.bars, required this.color});

  static const double _barWidth = 2.5;
  static const double _barSpacing = 1.0;
  static const double _step = _barWidth + _barSpacing;

  @override
  void paint(Canvas canvas, Size size) {
    if (bars.isEmpty) return;

    final paint = Paint()
      ..color = color
      ..strokeCap = StrokeCap.round
      ..strokeWidth = _barWidth;

    final midY = size.height / 2;
    final maxBars = (size.width / _step).floor();
    final visibleBars = bars.length > maxBars
        ? bars.sublist(bars.length - maxBars)
        : bars;

    final startX = size.width - (visibleBars.length * _step);

    for (int i = 0; i < visibleBars.length; i++) {
      final x = startX + (i * _step) + _barWidth / 2;
      final amplitude = visibleBars[i].clamp(0.02, 1.0);
      final halfHeight = amplitude * midY * 0.9;

      canvas.drawLine(
        Offset(x, midY - halfHeight),
        Offset(x, midY + halfHeight),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(MicWaveformPainter oldDelegate) => true;
}
