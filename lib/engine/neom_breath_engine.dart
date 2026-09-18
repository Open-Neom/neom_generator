import 'dart:math';

enum NeomBreathMode {
  off,
  box,
  fourSevenEight,
  free;

  /// Translation key for humanized label.
  String get translationKey => switch (this) {
    off => 'breathOff',
    box => 'breathBox',
    fourSevenEight => 'breathFourSevenEight',
    free => 'breathFree',
  };
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
  double get phase => _phase;
  double get cyclePosition => _phase / (2 * pi);
  int completedCycles = 0;
  void restorePhase(double value) {
    _phase = value.isFinite ? value % (2 * pi) : 0;
    completedCycles = 0;
    currentValue = mode == NeomBreathMode.off ? 1 : _envelope();
  }

  double apply({required double baseAmplitude, required int sampleRate}) {
    if (mode == NeomBreathMode.off) {
      currentValue = 1;
      return baseAmplitude;
    }

    final breathHz = breathsPerMinute / 60.0;
    _phase += 2 * pi * breathHz / sampleRate;

    if (_phase >= 2 * pi) {
      _phase -= 2 * pi;
      completedCycles++;
    }
    currentValue = _envelope();
    final mod = 1.0 - depth + depth * currentValue;
    return baseAmplitude * mod;
  }

  double _envelope() => switch (mode) {
    NeomBreathMode.box => _boxEnvelope(),
    NeomBreathMode.fourSevenEight => _fourSevenEightEnvelope(),
    NeomBreathMode.free => (sin(_phase) + 1) / 2,
    NeomBreathMode.off => 1,
  };

  double _boxEnvelope() {
    final t = (_phase / (2 * pi));
    if (t < 0.25) return t * 4;
    if (t < 0.5) return 1.0;
    if (t < 0.75) return 1.0 - (t - 0.5) * 4;
    return 0.0;
  }

  double _fourSevenEightEnvelope() {
    final t = (_phase / (2 * pi));
    if (t < 0.25) return t * 4; // inhale
    if (t < 0.6) return 1.0; // hold
    if (t < 0.85) return 1.0 - (t - 0.6) * 4;
    return 0.0;
  }
}
