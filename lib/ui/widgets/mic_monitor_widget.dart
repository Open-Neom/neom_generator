import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sint/sint.dart';

import '../neom_generator_controller.dart';

/// Real-time microphone waveform monitor for meditation sessions.
///
/// Displays amplitude bars from the mic input, similar to a DAW recording view.
/// Used during meditation to:
/// - Show the user that mic is active (biofeedback)
/// - Detect attention breaks (noise spikes)
/// - Provide visual feedback of breathing patterns
///
/// Reads from [NeomGeneratorController.micWaveform] (RxList<double>).
class MicMonitorWidget extends StatelessWidget {
  final double height;
  final Color barColor;
  final Color alertColor;
  final double alertThreshold;
  final bool showAlerts;
  final bool compact;

  const MicMonitorWidget({
    super.key,
    this.height = 80,
    this.barColor = const Color(0xFF00BCD4),
    this.alertColor = const Color(0xFFFF5252),
    this.alertThreshold = 0.6,
    this.showAlerts = true,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return SintBuilder<NeomGeneratorController>(
      builder: (controller) {
        return Obx(() {
          final waveform = controller.micWaveform.toList();
          final isRecording = controller.isRecording.value;

          if (waveform.isEmpty || !isRecording) {
            return SizedBox(
              height: height,
              child: Center(
                child: Text(
                  isRecording ? 'Esperando señal...' : 'Micrófono inactivo',
                  style: TextStyle(
                    color: Colors.white24,
                    fontSize: compact ? 10 : 12,
                  ),
                ),
              ),
            );
          }

          // Detect attention breaks (high amplitude = noise/talking)
          final hasAlert = showAlerts &&
              waveform.length > 5 &&
              waveform.sublist(waveform.length - 5).any((v) => v > alertThreshold);

          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!compact) ...[
                Row(
                  children: [
                    Icon(
                      Icons.mic,
                      size: 14,
                      color: hasAlert ? alertColor : Colors.white38,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'MONITOR DE AUDIO',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: Colors.white38,
                        letterSpacing: 2,
                      ),
                    ),
                    const Spacer(),
                    if (hasAlert)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: alertColor.withAlpha(40),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: alertColor.withAlpha(100)),
                        ),
                        child: Text(
                          'Sonido detectado',
                          style: TextStyle(
                            fontSize: 9,
                            color: alertColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 6),
              ],
              ClipRRect(
                borderRadius: BorderRadius.circular(compact ? 4 : 8),
                child: Container(
                  height: height,
                  decoration: BoxDecoration(
                    color: Colors.black26,
                    border: Border.all(
                      color: hasAlert
                          ? alertColor.withAlpha(80)
                          : Colors.white10,
                    ),
                    borderRadius: BorderRadius.circular(compact ? 4 : 8),
                  ),
                  child: CustomPaint(
                    size: Size.infinite,
                    painter: _MicWaveformPainter(
                      waveform: waveform,
                      barColor: hasAlert ? alertColor : barColor,
                      alertThreshold: alertThreshold,
                      showThresholdLine: showAlerts && !compact,
                    ),
                  ),
                ),
              ),
            ],
          );
        });
      },
    );
  }
}

class _MicWaveformPainter extends CustomPainter {
  final List<double> waveform;
  final Color barColor;
  final double alertThreshold;
  final bool showThresholdLine;

  _MicWaveformPainter({
    required this.waveform,
    required this.barColor,
    this.alertThreshold = 0.6,
    this.showThresholdLine = true,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (waveform.isEmpty) return;

    final barCount = waveform.length;
    final barWidth = (size.width / barCount).clamp(1.0, 6.0);
    final gap = barWidth * 0.2;
    final effectiveWidth = barWidth - gap;
    final centerY = size.height / 2;

    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < barCount; i++) {
      final amp = waveform[i].clamp(0.0, 1.0);
      final barHeight = amp * size.height * 0.9;
      final x = i * barWidth;

      // Color gradient: low amplitude = dim, high = bright, over threshold = alert
      final isAlert = amp > alertThreshold;
      final opacity = (0.3 + amp * 0.7).clamp(0.0, 1.0);
      paint.color = isAlert
          ? const Color(0xFFFF5252).withAlpha((opacity * 255).toInt())
          : barColor.withAlpha((opacity * 255).toInt());

      // Draw mirrored bar (centered)
      final rect = Rect.fromCenter(
        center: Offset(x + effectiveWidth / 2, centerY),
        width: effectiveWidth,
        height: math.max(barHeight, 1.0),
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, Radius.circular(effectiveWidth / 2)),
        paint,
      );
    }

    // Threshold line
    if (showThresholdLine) {
      final thresholdY = centerY - (alertThreshold * size.height * 0.45);
      final thresholdYBottom = centerY + (alertThreshold * size.height * 0.45);
      final linePaint = Paint()
        ..color = Colors.white12
        ..strokeWidth = 0.5
        ..style = PaintingStyle.stroke;
      canvas.drawLine(
        Offset(0, thresholdY),
        Offset(size.width, thresholdY),
        linePaint,
      );
      canvas.drawLine(
        Offset(0, thresholdYBottom),
        Offset(size.width, thresholdYBottom),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MicWaveformPainter old) => true;
}

/// Attention state derived from mic monitoring.
enum MeditationAttentionState {
  /// Calm — low ambient noise, focused
  focused,
  /// Mild distraction — brief noise spike
  distracted,
  /// Break — sustained noise (talking, moving)
  interrupted,
}

/// Analyzes mic waveform to determine meditation attention state.
class MeditationAttentionAnalyzer {
  final double _alertThreshold;
  final List<double> _recentAlerts = [];
  static const _windowSize = 30; // ~3 seconds of data at 10 samples/sec

  MeditationAttentionAnalyzer({double alertThreshold = 0.6})
      : _alertThreshold = alertThreshold;

  /// Push a new amplitude sample and return the current attention state.
  MeditationAttentionState pushSample(double amplitude) {
    _recentAlerts.add(amplitude > _alertThreshold ? 1.0 : 0.0);
    if (_recentAlerts.length > _windowSize) {
      _recentAlerts.removeAt(0);
    }

    final alertRatio = _recentAlerts.isEmpty
        ? 0.0
        : _recentAlerts.reduce((a, b) => a + b) / _recentAlerts.length;

    if (alertRatio > 0.5) return MeditationAttentionState.interrupted;
    if (alertRatio > 0.15) return MeditationAttentionState.distracted;
    return MeditationAttentionState.focused;
  }

  /// Reset for new session.
  void reset() => _recentAlerts.clear();

  /// Get focus percentage (0-100) over the analyzed window.
  double get focusPercentage {
    if (_recentAlerts.isEmpty) return 100.0;
    final focused = _recentAlerts.where((v) => v == 0.0).length;
    return (focused / _recentAlerts.length * 100).clamp(0.0, 100.0);
  }
}
