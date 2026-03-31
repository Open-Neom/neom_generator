import 'dart:math';

enum NeomModulationType {
  none,
  am,
  fm,
  phase,
  pm;

  /// Translation key for humanized label.
  String get translationKey => switch (this) {
    none => 'modNone',
    am => 'modAm',
    fm => 'modFm',
    phase => 'modPhase',
    pm => 'modPm',
  };
}

class NeomModulatorEngine {
  NeomModulationType type = NeomModulationType.none;

  double modFrequency = 0.5; // Hz
  double depth = 0.5;        // 0.0 – 1.0
  double intensity = 0.5;        // 0.0 – 1.0
  double _phase = 0.0;
  bool enabled = false;

  double apply({
    required double carrierFreq,
    required int sampleRate,
  }) {
    if (!enabled || type == NeomModulationType.none) return carrierFreq;

    final double twoPi = 2 * pi;
    _phase += twoPi * modFrequency / sampleRate;
    if (_phase > twoPi) _phase -= twoPi;

    switch (type) {
      case NeomModulationType.am:
      // AM afecta amplitud (se maneja fuera)
        return carrierFreq;

      case NeomModulationType.fm:
      // FM altera la frecuencia portadora
        return carrierFreq + (sin(_phase) * carrierFreq * depth);

      case NeomModulationType.phase:
      // Phase se aplica directamente en el oscilador
        return carrierFreq;

      default:
        return carrierFreq;
    }
  }

  double applyAmplitude(double baseAmp) {
    if (type != NeomModulationType.am) return baseAmp;
    return baseAmp * (1.0 - depth + depth * sin(_phase).abs());
  }
}
