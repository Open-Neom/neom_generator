import 'dart:math';

enum NeomBreathMode {
  off,
  box,
  fourSevenEight,
  free,
}

class NeomBreathEngine {
  NeomBreathMode mode = NeomBreathMode.off;

  double currentValue = 0.5;
  /// Respiraciones por minuto
  double breathsPerMinute = 6.0;

  /// Intensidad de influencia (0–1)
  double depth = 0.5;
  double intensity = 0.5;

  double _phase = 0.0;

  double apply({
    required double baseAmplitude,
    required int sampleRate,
  }) {
    if (mode == NeomBreathMode.off) return baseAmplitude;

    final breathHz = breathsPerMinute / 60.0;
    _phase += 2 * pi * breathHz / sampleRate;

    if (_phase > 2 * pi) _phase -= 2 * pi;

    double envelope;

    switch (mode) {
      case NeomBreathMode.box:
        envelope = _boxEnvelope();
        break;
      case NeomBreathMode.fourSevenEight:
        envelope = _fourSevenEightEnvelope();
        break;
      case NeomBreathMode.free:
        envelope = (sin(_phase) + 1) / 2;
        break;
      default:
        envelope = 1.0;
    }

    final mod = 1.0 - depth + depth * envelope;
    return baseAmplitude * mod;
  }

  double _boxEnvelope() {
    final t = (_phase / (2 * pi));
    if (t < 0.25) return t * 4;
    if (t < 0.5) return 1.0;
    if (t < 0.75) return 1.0 - (t - 0.5) * 4;
    return 0.0;
  }

  double _fourSevenEightEnvelope() {
    final t = (_phase / (2 * pi));
    if (t < 0.25) return t * 4;          // inhale
    if (t < 0.6) return 1.0;             // hold
    if (t < 0.85) return 1.0 - (t - 0.6) * 4;
    return 0.0;
  }
}
