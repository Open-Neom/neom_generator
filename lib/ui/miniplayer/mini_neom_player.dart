import 'dart:math';

import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:sint/sint.dart';

import '../../utils/constants/generator_translation_constants.dart';
import '../neom_generator_controller.dart';

/// A compact bar that shows when the Neom Chamber (frequency generator)
/// is playing. Sits at the same level as the mini audio player so the
/// user can navigate the app while still hearing the frequency.
///
/// Uses a StatefulWidget that polls controller registration instead of
/// SintBuilder, because the controller may not exist yet at mount time
/// (it's registered with lazyPut/fenix).
class MiniNeomPlayer extends StatefulWidget {
  const MiniNeomPlayer({super.key});

  @override
  State<MiniNeomPlayer> createState() => _MiniNeomPlayerState();
}

class _MiniNeomPlayerState extends State<MiniNeomPlayer> {

  NeomGeneratorController? _controller;

  NeomGeneratorController? get _ctrl {
    _controller ??= Sint.isRegistered<NeomGeneratorController>()
        ? Sint.find<NeomGeneratorController>()
        : null;
    return _controller;
  }

  @override
  Widget build(BuildContext context) {
    final c = _ctrl;
    if (c == null) return const SizedBox.shrink();

    return Obx(() {
      final isPlaying = c.isPlaying.value;
      // Show bar if currently playing OR if frequency was ever set (not default 432)
      final hasBeenUsed = c.currentFreq.value != 432.0 || isPlaying;
      if (!hasBeenUsed) return const SizedBox.shrink();
      return _buildBar(
        freq: c.currentFreq.value.toStringAsFixed(0),
        beat: c.currentBeat.value.toStringAsFixed(1),
        vol: (c.currentVol.value * 100).round(),
        isPlaying: isPlaying,
        onPlayStop: () => c.playStopPreview(stop: isPlaying),
        onTap: () => Sint.toNamed('/generator'),
      );
    });
  }

  Widget _buildBar({
    required String freq,
    required String beat,
    required int vol,
    required bool isPlaying,
    required VoidCallback onPlayStop,
    required VoidCallback onTap,
  }) {
    final accentColor = isPlaying ? AppColor.bondiBlue : Colors.white38;

    return GestureDetector(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black87,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: accentColor.withAlpha(80)),
            boxShadow: [
              BoxShadow(
                color: accentColor.withAlpha(20),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // ── Left: info ──
              if (isPlaying)
                _PulsingDot(color: AppColor.bondiBlue)
              else
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white24,
                  ),
                ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    GeneratorTranslationConstants.neomChamber.tr,
                    style: TextStyle(
                      color: isPlaying ? Colors.white70 : Colors.white38,
                      fontSize: 9,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$freq Hz · $beat Hz beat',
                    style: TextStyle(
                      color: isPlaying ? Colors.white : Colors.white54,
                      fontFamily: 'Courier',
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 12),

              // ── Center: waveform (50% of available width) ──
              Expanded(
                child: SizedBox(
                  height: 28,
                  child: isPlaying
                      ? _MiniWaveform(color: AppColor.bondiBlue)
                      : CustomPaint(
                          painter: _FlatLinePainter(color: Colors.white12),
                        ),
                ),
              ),
              const SizedBox(width: 12),

              // ── Right: volume + play/stop ──
              Text(
                '$vol%',
                style: TextStyle(
                  color: Colors.white.withAlpha(isPlaying ? 120 : 60),
                  fontFamily: 'Courier',
                  fontSize: 11,
                ),
              ),
              const SizedBox(width: 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: onPlayStop,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isPlaying
                            ? AppColor.bondiBlue.withAlpha(100)
                            : Colors.white24,
                      ),
                    ),
                    child: Icon(
                      isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded,
                      color: isPlaying ? AppColor.bondiBlue : Colors.white54,
                      size: 18,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
}


class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withAlpha((120 + (_ctrl.value * 135)).round()),
          boxShadow: [
            BoxShadow(
              color: widget.color.withAlpha((_ctrl.value * 80).round()),
              blurRadius: 6,
            ),
          ],
        ),
      ),
    );
  }
}

/// Animated mini sine wave for the mini player bar.
class _MiniWaveform extends StatefulWidget {
  final Color color;
  const _MiniWaveform({required this.color});

  @override
  State<_MiniWaveform> createState() => _MiniWaveformState();
}

class _MiniWaveformState extends State<_MiniWaveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, _) => CustomPaint(
        painter: _SineWavePainter(
          phase: _ctrl.value * 2 * 3.14159,
          color: widget.color,
        ),
      ),
    );
  }
}

/// Flat horizontal line when paused.
class _FlatLinePainter extends CustomPainter {
  final Color color;
  _FlatLinePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    final midY = size.height / 2;
    canvas.drawLine(Offset(0, midY), Offset(size.width, midY), paint);
  }

  @override
  bool shouldRepaint(covariant _FlatLinePainter old) => false;
}

class _SineWavePainter extends CustomPainter {
  final double phase;
  final Color color;
  _SineWavePainter({required this.phase, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withAlpha(180)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    final midY = size.height / 2;
    final amplitude = size.height * 0.35;

    for (double x = 0; x <= size.width; x += 1) {
      final normalized = x / size.width;
      final y = midY + sin(normalized * 4 * 3.14159 + phase) * amplitude;
      if (x == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);

    // Second wave (binaural visual hint) — slightly offset
    final paint2 = Paint()
      ..color = color.withAlpha(60)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final path2 = Path();
    for (double x = 0; x <= size.width; x += 1) {
      final normalized = x / size.width;
      final y = midY + sin(normalized * 4 * 3.14159 + phase + 0.8) * amplitude * 0.7;
      if (x == 0) {
        path2.moveTo(x, y);
      } else {
        path2.lineTo(x, y);
      }
    }
    canvas.drawPath(path2, paint2);
  }

  @override
  bool shouldRepaint(covariant _SineWavePainter old) => true;
}
