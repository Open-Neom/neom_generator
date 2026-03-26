import 'dart:math';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../../engine/neom_fractal_engine.dart';

/// GPU-accelerated fractal painter using Flutter fragment shaders.
///
/// Works on mobile (Impeller) and web (CanvasKit).
/// Falls back to [NeomFractalFallbackPainter] on unsupported renderers.
class NeomFractalPainter extends CustomPainter {
  final NeomFractalEngine engine;

  NeomFractalPainter({required this.engine}) : super(repaint: engine);

  @override
  void paint(Canvas canvas, Size size) {
    if (engine.useFallback || engine.currentShader == null) {
      _paintFallback(canvas, size);
      return;
    }

    engine.configureShader(size);
    final paint = Paint()..shader = engine.currentShader;
    canvas.drawRect(Offset.zero & size, paint);
  }

  /// CPU fallback: renders a low-res Mandelbrot and scales up.
  /// Used when fragment shaders aren't available (web HTML renderer).
  void _paintFallback(Canvas canvas, Size size) {
    if (!engine.shadersLoaded && !engine.useFallback) {
      // Still loading — show gradient placeholder
      _paintLoadingGradient(canvas, size);
      return;
    }

    // CPU Mandelbrot at reduced resolution for performance.
    // Web uses 1/8 resolution (each pixel = 8x8 block) since CPU iteration
    // per-pixel is expensive. Mobile uses 1/4 for better quality.
    final scale = kIsWeb ? 8 : 4;
    final w = (size.width / scale).ceil();
    final h = (size.height / scale).ceil();
    final minDim = min(size.width, size.height);
    final maxIter = engine.config.platformIterations;

    final recorder = ui.PictureRecorder();
    final offCanvas = Canvas(recorder);

    for (int py = 0; py < h; py++) {
      for (int px = 0; px < w; px++) {
        final sx = px * scale.toDouble();
        final sy = py * scale.toDouble();

        final uvx = (sx - size.width * 0.5) / minDim;
        final uvy = (sy - size.height * 0.5) / minDim;

        final cx = uvx / engine.zoom + engine.centerX;
        final cy = uvy / engine.zoom + engine.centerY;

        final iter = engine.computeMandelbrotAt(cx, cy);

        Color color;
        if (iter < 0) {
          color = Colors.black;
        } else {
          final t = (iter / maxIter) + engine.time * 0.02;
          color = engine.paletteAt(t);
        }

        offCanvas.drawRect(
          Rect.fromLTWH(
            px.toDouble() * scale,
            py.toDouble() * scale,
            scale.toDouble(),
            scale.toDouble(),
          ),
          Paint()..color = color,
        );
      }
    }

    final picture = recorder.endRecording();
    canvas.drawPicture(picture);
    picture.dispose();
  }

  void _paintLoadingGradient(Canvas canvas, Size size) {
    final palette = engine.config.palette;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [palette.color1, palette.color2, palette.color3],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, paint);

    final textPainter = TextPainter(
      text: const TextSpan(
        text: 'Cargando fractal...',
        style: TextStyle(
          color: Colors.white54,
          fontSize: 14,
          fontFamily: 'Courier',
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();

    textPainter.paint(
      canvas,
      Offset(
        (size.width - textPainter.width) / 2,
        (size.height - textPainter.height) / 2,
      ),
    );
  }

  @override
  bool shouldRepaint(covariant NeomFractalPainter oldDelegate) => true;
}
