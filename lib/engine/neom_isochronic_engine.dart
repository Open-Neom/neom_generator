import 'dart:math';

class NeomIsochronicEngine {
  bool enabled = false;

  double pulseFrequency = 4.0; // Hz (delta, theta, etc)
  double dutyCycle = 0.5;      // 0.1 – 0.9

  double _phase = 0.0;

  double apply({
    required double amplitude,
    required int sampleRate,
  }) {
    if (!enabled) return amplitude;

    final double twoPi = 2 * pi;
    _phase += twoPi * pulseFrequency / sampleRate;
    if (_phase > twoPi) _phase -= twoPi;

    final double cycle = _phase / twoPi;

    return cycle < dutyCycle ? amplitude : 0.0;
  }
}
