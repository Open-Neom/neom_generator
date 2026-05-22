import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;

import '../utils/constants/neom_generator_constants.dart';
import '../utils/enums/neom_spatial_mode.dart';
import 'neom_breath_engine.dart';
import 'neom_frequency_painter_engine.dart';
import 'neom_isochronic_engine.dart';
import 'neom_modulator_engine.dart';
import 'neom_neuro_state_engine.dart';

class NeomSineEngine {

  // ── Singleton ──
  static NeomSineEngine? _instance;

  /// Shared singleton instance. Use this to ensure onboarding and
  /// Cámara Neom share the same audio engine (like NeomAudioHandler).
  static NeomSineEngine get shared {
    _instance ??= NeomSineEngine._internal();
    return _instance!;
  }

  /// Named constructor for singleton.
  NeomSineEngine._internal();

  /// Public constructor — returns the singleton.
  factory NeomSineEngine() => shared;

  final FlutterSoundPlayer _player = FlutterSoundPlayer();
  final NeomBreathEngine breathEngine = NeomBreathEngine();
  final NeomNeuroStateEngine neuroStateEngine = NeomNeuroStateEngine();
  NeomFrequencyPainterEngine? painterEngine;

  bool _running = false;
  bool get isPlaying => _running;

  double _phaseL = 0.0;
  double _phaseR = 0.0;
  double _phaseSub = 0.0;

  /// Reset all phase accumulators to zero.
  ///
  /// Call when switching modes or setting new frequencies to avoid
  /// residual DC offset from frozen phases.
  void resetPhases() {
    _phaseL = 0.0;
    _phaseR = 0.0;
    _phaseSub = 0.0;
  }

  double posX = 0.0; // -1.0 izquierda | 0 centro | +1 derecha
  double posY = 0.0; // -1.0 cerca | +1 lejos
  double posZ = 0.0; // -1.0 abajo | +1 arriba

  double frequency = 432.0;
  double beat = 10.0;
  double volume = 0.5;

  /// Multi-frequency mode: 3 independent oscillators routed to L/R/Sub.
  ///
  /// When enabled, [frequency] is ignored and [frequencyL], [frequencyR],
  /// [frequencySub] drive independent oscillators:
  /// - Sub → mixed equally into both L and R channels
  /// - L → left channel only
  /// - R → right channel only
  bool multiFrequencyMode = false;
  double frequencyL = 0.0;
  double frequencyR = 0.0;
  double frequencySub = 0.0;
  double subMixLevel = 0.5; // 0.0–1.0 how loud the sub is relative to L/R

  NeomSpatialMode spatialMode = NeomSpatialMode.softPan;

// Para órbita
  double orbitPhase = 0.0;
  double orbitSpeed = 0.15; // Hz perceptual

  double spatialIntensity = 0.5;
  int orbitDirection = 1;

  Future<void> init() async {
    if (!_player.isOpen()) {
      await _player.openPlayer();
    }
  }

  Future<void> start() async {
    if (_running) return;

    // Ensure player is open (may have been closed by dispose or never opened)
    if (!_player.isOpen()) {
      await _player.openPlayer();
    }

    try { _player.setLogLevel(Level.off); } catch (_) {
      // setLogLevel not implemented on web — safe to ignore
    }
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: NeomGeneratorConstants.channels,
      sampleRate: NeomGeneratorConstants.sampleRate,
      interleaved: true,
      bufferSize: NeomGeneratorConstants.framesPerBuffer * 4,
    );

    _running = true;
    _audioLoop();
  }

  Future<void> stop() async {
    _running = false;
    if (_player.isPlaying) {
      await _player.stopPlayer();
    }
  }

  Future<void> dispose() async {
    _running = false;
    // Don't close the player on singleton — it will be reused.
    // Only stop the audio loop. Player stays open for next start().
    if (_player.isPlaying) {
      await _player.stopPlayer();
    }
  }

  Future<void> _audioLoop() async {
    while (_running) {
      final buffer = _generateBuffer();
      await _player.feedUint8FromStream(buffer);
      // Yield to event loop so parameter changes (frequency, volume, beat)
      // are picked up in real-time without needing stop/start.
      await Future.delayed(Duration.zero);
    }
  }

  final NeomModulatorEngine modulator = NeomModulatorEngine();
  final NeomIsochronicEngine isochronic = NeomIsochronicEngine();

  /// Exposed for unit testing only. Do not call directly in production.
  @visibleForTesting
  Uint8List generateBufferForTesting() => _generateBuffer();

  Uint8List _generateBuffer() {
    final Int16List pcm = Int16List(NeomGeneratorConstants.framesPerBuffer * NeomGeneratorConstants.channels);
    const double twoPi = 2 * pi;

    for (int i = 0; i < NeomGeneratorConstants.framesPerBuffer; i++) {

      if (multiFrequencyMode) {
        // ═══════════════════════════════════════════════════
        // MULTI-FREQUENCY MODE: 3 independent oscillators
        // Sub → both channels, L → left only, R → right only
        // ═══════════════════════════════════════════════════
        final double incL = twoPi * frequencyL / NeomGeneratorConstants.sampleRate;
        final double incR = twoPi * frequencyR / NeomGeneratorConstants.sampleRate;
        final double incSub = twoPi * frequencySub / NeomGeneratorConstants.sampleRate;

        double amp = isochronic.apply(
          amplitude: volume,
          sampleRate: NeomGeneratorConstants.sampleRate,
        );
        amp = breathEngine.apply(
          baseAmplitude: amp,
          sampleRate: NeomGeneratorConstants.sampleRate,
        );

        final double scaledAmp = 32767 * amp.clamp(0.0, 1.0);
        // Gain staging: total must not exceed 1.0 to prevent clipping.
        // subGain + channelGain = subMix/(1+subMix) + 1/(1+subMix) = 1.0
        final double clampedSub = subMixLevel.clamp(0.0, 1.0);
        final double subGain = clampedSub / (1.0 + clampedSub);
        final double channelGain = 1.0 / (1.0 + clampedSub);
        final double subSample = sin(_phaseSub) * scaledAmp * subGain;
        final double lSample = sin(_phaseL) * scaledAmp * channelGain;
        final double rSample = sin(_phaseR) * scaledAmp * channelGain;

        // Mix: L gets its own freq + sub, R gets its own freq + sub
        final int outL = (lSample + subSample).toInt();
        final int outR = (rSample + subSample).toInt();

        pcm[i * 2] = outL.clamp(-32768, 32767);
        pcm[i * 2 + 1] = outR.clamp(-32768, 32767);

        // Visual feedback uses sub as dominant
        final double visualSample = sin((_phaseL + _phaseR + _phaseSub) / 3.0);
        painterEngine?.pushSample(visualSample);
        painterEngine?.updatePhases(phaseL: _phaseL, phaseR: _phaseR);
        painterEngine?.tickBinaural(
          (frequencyR - frequencyL).abs(),
          1 / NeomGeneratorConstants.sampleRate,
        );

        _phaseL += incL;
        _phaseR += incR;
        _phaseSub += incSub;

        if (_phaseL >= twoPi) _phaseL -= twoPi;
        if (_phaseR >= twoPi) _phaseR -= twoPi;
        if (_phaseSub >= twoPi) _phaseSub -= twoPi;

      } else {
        // ═══════════════════════════════════════════════════
        // STANDARD MODE: carrier + binaural beat (existing behavior)
        // ═══════════════════════════════════════════════════

        // 1️⃣ MODULACIÓN (FM / phase)
        final double modulatedFreqL = modulator.apply(
          carrierFreq: frequency,
          sampleRate: NeomGeneratorConstants.sampleRate,
        );

        final double modulatedFreqR = modulator.apply(
          carrierFreq: frequency + beat,
          sampleRate: NeomGeneratorConstants.sampleRate,
        );

        final double incL = twoPi * modulatedFreqL / NeomGeneratorConstants.sampleRate;
        final double incR = twoPi * modulatedFreqR / NeomGeneratorConstants.sampleRate;

        posX.clamp(-1.0, 1.0);

        double panL = 1.0;
        double panR = 1.0;

        computePan(
          posX: posX,
          outL: panL,
          outR: panR,
          apply: (l, r) {
            panL = l;
            panR = r;
          },
        );

        double distanceAttenuation = (1.0 - (posY.abs() * 0.5)).clamp(0.2, 1.0);

        // 2️⃣ ISOCRÓNICO / AMPLITUD
        double amp = isochronic.apply(
          amplitude: volume,
          sampleRate: NeomGeneratorConstants.sampleRate,
        );

        amp = breathEngine.apply(
          baseAmplitude: amp,
          sampleRate: NeomGeneratorConstants.sampleRate,
        );

        final double scaledAmp = 32767 * amp.clamp(0.0, 1.0);
        final double ampL = scaledAmp * panL * distanceAttenuation;
        final double ampR = scaledAmp * panR * distanceAttenuation;

        // 3️⃣ GENERACIÓN DE LA ONDA
        final int sampleL = (sin(_phaseL) * ampL).toInt();
        final int sampleR = (sin(_phaseR) * ampR).toInt();

        final double visualSample = sin((_phaseL + _phaseR) * 0.5);

        painterEngine?.pushSample(visualSample);
        painterEngine?.updatePhases(
          phaseL: _phaseL,
          phaseR: _phaseR,
        );

        painterEngine?.tickBinaural(
          beat,
          1 / NeomGeneratorConstants.sampleRate,
        );

        pcm[i * 2] = sampleL.clamp(-32768, 32767);
        pcm[i * 2 + 1] = sampleR.clamp(-32768, 32767);

        // 4️⃣ AVANCE DE FASE
        _phaseL += incL * (1.0 + posZ * 0.02);
        _phaseR += incR * (1.0 - posZ * 0.02);

        if (_phaseL >= twoPi) _phaseL -= twoPi;
        if (_phaseR >= twoPi) _phaseR -= twoPi;
      }
    }

    painterEngine?.updateFromAudio(
      phase: (_phaseL + _phaseR) * 0.5,
      amplitude: volume,
      pan: posX,
      breath: breathEngine.currentValue,
      modulation: modulator.intensity,
      neuro: neuroStateEngine.intensity,
      frequency: (frequency - 20) / (20000 - 20)
    );

    return pcm.buffer.asUint8List();
  }

  void computePan({
    required double posX,
    required double outL,
    required double outR,
    required void Function(double l, double r) apply,
  }) {
    final double pan = posX.clamp(-1.0, 1.0);

    switch (spatialMode) {

    /// 🔹 1. SOFT PAN (equal-power, default)
      case NeomSpatialMode.softPan:
        final l = cos((pan + 1) * pi / 4);
        final r = sin((pan + 1) * pi / 4);
        apply(l, r);
        break;

    /// 🔹 2. HARD PAN
      case NeomSpatialMode.hardPan:
        apply(
          pan <= 0 ? 1.0 : 0.0,
          pan >= 0 ? 1.0 : 0.0,
        );
        break;

    /// 🔹 3. CROSSFade PROGRESIVO
      case NeomSpatialMode.crossfade:
        final l = ((1 - pan) / 2).clamp(0.0, 1.0);
        final r = ((1 + pan) / 2).clamp(0.0, 1.0);
        apply(l, r);
        break;

    /// 🔹 4. ORBITA AUTOMÁTICA
      case NeomSpatialMode.orbit:
        orbitPhase += orbitSpeed / NeomGeneratorConstants.sampleRate;
        if (orbitPhase > 1) orbitPhase -= 1;

        final angle = orbitPhase * 2 * pi;
        final l = cos(angle).abs();
        final r = sin(angle).abs();
        apply(l, r);
        break;
      case NeomSpatialMode.centered:
        break;
    }
  }


}
