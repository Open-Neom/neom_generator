import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:neom_core/app_config.dart';

import '../domain/models/neom_visual_state.dart';
import '../utils/constants/generator_translation_constants.dart';
import '../utils/enums/eeg_band.dart';

class NeomFrequencyPainterEngine extends ChangeNotifier {
  NeomVisualState _state = NeomVisualState.zero();

  double visualAmplitudeBase = 0.12;
  double visualAmplitudeMax = 0.45;

  double _smooth({
    required double current,
    required double target,
    required double factor,
    double snapThreshold = 0.02,
  }) {
    if ((target - current).abs() < snapThreshold) {
      return target;
    }
    return current + (target - current) * factor;
  }


  void updateFromAudio({
    required double phase,
    required double amplitude,
    required double pan,
    required double breath,
    required double modulation,
    required double neuro,
    required double frequency,
  }) {
    AppConfig.logger
        .t('NeomFrequencyPainterEngine.updateFromAudio: '
        'phase=$phase, amplitude=$amplitude, pan=$pan, '
        'breath=$breath, modulation=$modulation, neuro=$neuro');
    _state = NeomVisualState(
      frequency: _normalizeFrequency(frequency),
      phase: _smooth(current: _state.phase, target: phase, factor: 0.2),
      pan: _smooth(current: _state.pan, target: pan, factor: 0.25),
      modulation: _smooth(current: _state.modulation, target: modulation, factor: 0.2),
      amplitude: _smooth(
        current: _state.amplitude,
        target: amplitude,
        factor: smoothAmp,
      ),
      breath: _smooth(
        current: _state.breath,
        target: breath,
        factor: smoothBreath,
      ),
      neuro: _smooth(
        current: _state.neuro,
        target: neuro,
        factor: smoothNeuro,
      ),
    );

    notifyListeners();
  }

  /// -------- SALIDAS PARA EL PAINTER --------

  double get visualPhase =>
      _state.phase + _state.modulation * pi * 0.5;

  double get glowIntensity =>
      _clamp01((_state.modulation + _state.neuro) * 0.5);

  double get waveHeight {
    final amp =
        (_state.amplitude * 0.75) +
            (_state.breath * 0.2) +
            (_state.neuro * 0.15);

    return amp.clamp(0.0, 1.0) * visualAmplitudeMax;
  }



  double get waveStretch {
    // Grave → ondas largas | Agudo → ondas cortas
    return lerpDouble(0.5, 5, _state.frequency)! +
        (_state.neuro * 0.3) +
        (_state.modulation * 0.2);
  }


  double get horizontalDrift =>
      _clamp01(_state.pan * 0.5);

  double get breathPulse =>
      _clamp01(sin(_state.breath * pi).abs());


  double _clamp01(double v) {
    if (v.isNaN || v.isInfinite) return 0.0;
    return v.clamp(0.0, 1.0);
  }

  double _normalizeFrequency(double f) {
    const double minF = 40.0;
    const double maxF = 1500.0;

    final double norm =
        (log(f) - log(minF)) / (log(maxF) - log(minF));

    return norm.clamp(0.0, 1.0);
  }

  double smoothAmp = 0.35;
  double smoothBreath = 0.15;
  double smoothNeuro = 0.12;

  void setSmoothingProfile({
    required double amplitude,
    required double breath,
    required double neuro,
  }) {
    smoothAmp = amplitude;
    smoothBreath = breath;
    smoothNeuro = neuro;
  }

  double _binauralPhase = 0.0;
  double _binauralBeat = 0.0;

  void tickBinaural(double beatHz, double dt) {
    if (beatHz <= 0) return;

    _binauralBeat = beatHz;
    _binauralPhase += dt * beatHz * 2 * pi * 0.25; // lento, perceptual
    _binauralPhase %= (2 * pi);

    notifyListeners();
  }

  double get binauralPhase => _binauralPhase;

  // =========================
  // 🔬 OSCILLOSCOPE BUFFER
  // =========================
  static const int bufferSize = 512;
  final List<double> _samples =
  List.filled(bufferSize, 0.0, growable: false);
  int _writeIndex = 0;

  List<double> get samples => _samples;

  void pushSample(double value) {
    _samples[_writeIndex] = value.clamp(-1.0, 1.0);
    _writeIndex = (_writeIndex + 1) % bufferSize;
  }

  double _phaseL = 0.0;
  double _phaseR = 0.0;

  void updatePhases({
    required double phaseL,
    required double phaseR,
  }) {
    _phaseL = phaseL;
    _phaseR = phaseR;
  }

  double get lissajousX => sin(_phaseL);
  double get lissajousY => sin(_phaseR);

  EEGband get eegBand {
    final b = (_binauralBeat * 40).clamp(0.0, 40.0);

    if (b < 4) return EEGband.delta;
    if (b < 8) return EEGband.theta;
    if (b < 12) return EEGband.alpha;
    if (b < 30) return EEGband.beta;
    return EEGband.gamma;
  }

  Color get eegColor {
    switch (eegBand) {
      case EEGband.delta: return const Color(0xFF4B0082); // índigo
      case EEGband.theta: return const Color(0xFF6A5ACD); // violeta
      case EEGband.alpha: return const Color(0xFF00CED1); // cian
      case EEGband.beta:  return const Color(0xFFFFA500); // ámbar
      case EEGband.gamma: return const Color(0xFFFF4500); // rojo
    }
  }

  double get hemisphericCoherence {
    final diff = (_phaseL - _phaseR).abs();
    return cos(diff).abs().clamp(0.0, 1.0);
  }

}

Widget coherenceMeter(NeomFrequencyPainterEngine engine) {
  final c = engine.hemisphericCoherence;

  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(GeneratorTranslationConstants.hemisfericCoherence.tr.toUpperCase(),
        style: TextStyle(
          color: Colors.white54,
          fontSize: 10,
          letterSpacing: 1.5,
        ),
      ),
      const SizedBox(height: 6),
      ClipRRect(
        borderRadius: BorderRadius.circular(4),
        child: LinearProgressIndicator(
          value: c,
          minHeight: 6,
          backgroundColor: Colors.white10,
          valueColor: AlwaysStoppedAnimation<Color>(
            Color.lerp(
              Colors.redAccent,
              Colors.greenAccent,
              c,
            )!,
          ),
        ),
      ),
      const SizedBox(height: 4),
      Text(
        "${(c * 100).toStringAsFixed(1)} %",
        style: const TextStyle(
          fontFamily: 'Courier',
          fontSize: 12,
          color: Colors.white,
        ),
      )
    ],
  );
}
