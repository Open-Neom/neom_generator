import 'dart:async';
import 'dart:collection';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:neom_core/domain/use_cases/neom_audio_visual_signal.dart';

import '../utils/constants/neom_generator_constants.dart';
import '../utils/enums/neom_spatial_mode.dart';
import 'audio/neom_pcm_backend.dart';
import 'audio/neom_pcm_backend_factory.dart';
import 'neom_breath_engine.dart';
import 'neom_frequency_painter_engine.dart';
import 'neom_isochronic_engine.dart';
import 'neom_modulator_engine.dart';
import 'neom_neuro_state_engine.dart';
import 'neom_session_envelope.dart';

class NeomSineEngine {
  // ── Singleton ──
  static NeomSineEngine? _instance;

  /// Shared singleton instance. Use this to ensure onboarding and
  /// Cámara Neom share the same audio engine (like NeomAudioHandler).
  static NeomSineEngine get shared {
    _instance ??= NeomSineEngine._internal();
    return _instance!;
  }

  /// Public constructor — returns the singleton.
  factory NeomSineEngine() => shared;

  /// Named constructor for singleton.
  NeomSineEngine._internal() : _backend = createNeomPcmBackend();

  /// Independent output for short helpers such as a stereo channel check.
  /// Construction alone never opens or activates platform audio.
  NeomSineEngine.isolated() : _backend = createNeomPcmBackend();

  /// Isolated engine for deterministic, output-free lifecycle tests.
  @visibleForTesting
  NeomSineEngine.withBackend(NeomPcmBackend backend) : _backend = backend;

  final NeomPcmBackend _backend;
  final NeomBreathEngine breathEngine = NeomBreathEngine();
  final NeomNeuroStateEngine neuroStateEngine = NeomNeuroStateEngine();
  NeomFrequencyPainterEngine? _painterEngine;
  NeomFrequencyPainterEngine? get painterEngine => _painterEngine;
  set painterEngine(NeomFrequencyPainterEngine? value) {
    final previous = _painterEngine;
    previous?.audioSessionReader = null;
    _painterEngine = value;
    value?.audioSessionReader = () => audioSession;
    if (!identical(previous, value)) previous?.notifySessionChange();
  }

  final _visualBlocks = ListQueue<NeomAudioSessionSnapshot>();
  int _stoppedFrame = 0;

  /// Select the block being heard, not the most recently generated/queued
  /// block. No UI clock drives synthesis or advances session recordings.
  NeomAudioSessionSnapshot get audioSession {
    final frame = _running ? playedFrames : _stoppedFrame;
    if (_visualBlocks.isEmpty) {
      return NeomAudioSessionSnapshot(isPlaying: _running);
    }
    _pruneVisualBlocks(frame);
    final block = _visualBlocks.first;
    final phase =
        (block.beatPhase +
            (frame - block.playedFrames).clamp(
                  0,
                  NeomGeneratorConstants.framesPerBuffer,
                ) /
                block.sampleRate *
                (block.rightHz - block.leftHz) *
                2 *
                pi) %
        (2 * pi);
    return NeomAudioSessionSnapshot(
      isPlaying: _running,
      multiFrequency: block.multiFrequency,
      breathingEnabled: block.breathingEnabled,
      playedFrames: frame,
      sampleRate: block.sampleRate,
      leftHz: block.leftHz,
      rightHz: block.rightHz,
      subHz: block.subHz,
      subGain: block.subGain,
      level: _running ? block.level : 0,
      breathValue: block.breathValue,
      breathRateHz: block.breathRateHz,
      beatPhase: phase,
      phaseRelationship: cos(phase).abs(),
    );
  }

  void _pruneVisualBlocks(int frame) {
    while (_visualBlocks.length > 1 &&
        _visualBlocks.elementAt(1).playedFrames <= frame) {
      _visualBlocks.removeFirst();
    }
  }

  bool _running = false;
  bool get isPlaying => _running;
  bool _desiredPlaying = false;
  int _request = 0;
  int _pendingOperations = 0;
  Future<void> _operations = Future<void>.value();
  Future<void>? _producer;
  bool get isTransitioning => _pendingOperations > 0;

  Object? lastError;
  void Function(Object error, StackTrace stack)? onError;
  void Function(bool playing)? onPlayingChanged;
  void Function()? onPlaybackComplete;

  /// Synthesis clock, independent of animation frames and wall-clock changes.
  int generatedFrames = 0;
  int get playedFrames => _backend.playedFrames.clamp(0, generatedFrames);

  /// Null for a free session. A finite replay drains its final partial buffer.
  int? frameLimit;

  /// Optional raised-cosine ramps, evaluated on the absolute synthesis clock.
  /// Defaults keep existing recordings and callers byte-for-byte unchanged.
  double fadeInSeconds = 0;
  double fadeOutSeconds = 0;

  /// Exclusive original scheduled ending; null means no automatic fade-out.
  /// Keep this separate from [frameLimit]: replaying a manually stopped session
  /// must not add a new ending or compress the original scheduled fade.
  int? fadeOutEndFrame;
  void Function(int generatedFrames)? beforeBuffer;
  void Function(int generatedFrames)? afterBuffer;

  double _phaseL = 0.0;
  double _phaseR = 0.0;
  double _phaseSub = 0.0;

  ({double left, double right, double sub, double orbit}) get phaseState =>
      (left: _phaseL, right: _phaseR, sub: _phaseSub, orbit: orbitPhase);

  void restorePhaseState(
    ({double left, double right, double sub, double orbit}) state,
  ) {
    _phaseL = state.left;
    _phaseR = state.right;
    _phaseSub = state.sub;
    orbitPhase = state.orbit;
  }

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

  Future<void> _enqueue(Future<void> Function() operation) {
    _pendingOperations++;
    final result = _operations.then((_) => operation()).whenComplete(() {
      _pendingOperations--;
    });
    // A failed output must not poison subsequent stop/start requests.
    _operations = result.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return result;
  }

  void _setPlaying(bool value) {
    if (_running == value) return;
    if (!value) _stoppedFrame = playedFrames;
    _running = value;
    painterEngine?.notifySessionChange();
    onPlayingChanged?.call(value);
  }

  void _reportError(Object error, StackTrace stack) {
    lastError = error;
    onError?.call(error, stack);
  }

  Future<void> init() => _enqueue(_backend.init);

  /// Unlock output from an explicit gesture without starting synthesis or
  /// emitting PCM. Voice measurement can then start playback after releasing
  /// its microphone, even when the browser's transient activation has expired.
  Future<void> preparePlayback() => _backend.activate();

  Future<void> start() {
    if (_desiredPlaying) return _operations;
    _desiredPlaying = true;
    final request = ++_request;
    lastError = null;

    // Activate web audio within the gesture, not after a pending stop/open.
    // Handle rejection immediately even if a previous operation is pending.
    Future<({Object? error, StackTrace? stack})> activation;
    try {
      activation = _backend.activate().then(
        (_) => (error: null, stack: null),
        onError: (Object error, StackTrace stack) =>
            (error: error, stack: stack),
      );
    } catch (error, stack) {
      activation = Future.value((error: error, stack: stack));
    }

    return _enqueue(() async {
      final result = await activation;
      if (request != _request || !_desiredPlaying) return;
      try {
        if (result.error != null) {
          Error.throwWithStackTrace(result.error!, result.stack!);
        }
        await _backend.start(
          channels: NeomGeneratorConstants.channels,
          sampleRate: NeomGeneratorConstants.sampleRate,
          framesPerBuffer: NeomGeneratorConstants.framesPerBuffer,
        );
        if (request != _request || !_desiredPlaying) {
          await _backend.stop();
          return;
        }
        generatedFrames = 0;
        _stoppedFrame = 0;
        _visualBlocks.clear();
        _setPlaying(true);
        _producer = _audioLoop(request);
      } catch (error, stack) {
        try {
          await _backend.stop();
        } catch (_) {
          /* Keep original error. */
        }
        if (request == _request) {
          _desiredPlaying = false;
          _setPlaying(false);
          _reportError(error, stack);
          Error.throwWithStackTrace(error, stack);
        }
      }
    });
  }

  Future<void> stop() {
    _desiredPlaying = false;
    ++_request;
    _backend.interrupt();
    final producer = _producer;
    final stopped = _enqueue(() async {
      await _backend.stop();
      await producer;
      if (identical(_producer, producer)) _producer = null;
    });
    _setPlaying(false);
    return stopped;
  }

  Future<void> dispose() {
    stop();
    final request = _request;
    // The singleton is reusable: each backend reopens lazily on the next start.
    // A new Play may already have resumed the context from a browser gesture;
    // an older queued Dispose must not close that newly requested session.
    return _enqueue(() async {
      if (request == _request && !_desiredPlaying) await _backend.dispose();
    });
  }

  bool _isCurrent(int request) =>
      request == _request && _desiredPlaying && _running;

  Future<void> _audioLoop(int request) async {
    try {
      while (_isCurrent(request)) {
        var frames = NeomGeneratorConstants.framesPerBuffer;
        if (frameLimit != null) {
          frames = min(frames, frameLimit! - generatedFrames);
        }
        if (frames <= 0) {
          await _backend.drain();
          if (!_isCurrent(request)) return;
          // Serialize shutdown with a Play pressed at this same boundary.
          _desiredPlaying = false;
          final stopped = _enqueue(() async {
            await _backend.stop();
            if (request == _request) onPlaybackComplete?.call();
          });
          _setPlaying(false);
          // Never await the operation queue from inside the producer: a Stop
          // on that queue may itself be waiting for this producer to finish.
          unawaited(
            stopped.catchError((Object error, StackTrace stack) {
              if (request == _request) _reportError(error, stack);
            }),
          );
          return;
        }
        await _backend.waitForCapacity(frames);
        if (!_isCurrent(request)) return;
        beforeBuffer?.call(generatedFrames);
        if (!_isCurrent(request)) return;
        final buffer = _generateBuffer(frames: frames);
        generatedFrames += frames;
        afterBuffer?.call(generatedFrames);
        if (!_isCurrent(request)) return;
        await _backend.write(buffer);
        // Even fake/immediate backends must leave room for the stop gesture.
        await Future<void>.delayed(Duration.zero);
      }
    } catch (error, stack) {
      if (!_isCurrent(request)) return; // Expected cancellation by Stop.
      _desiredPlaying = false;
      _backend.interrupt();
      // Errors from the unawaited producer are observed, never zone leaks.
      final stopped = _enqueue(() async {
        try {
          await _backend.stop();
        } catch (_) {
          /* Original error reported. */
        }
      });
      _setPlaying(false);
      _reportError(error, stack);
      unawaited(stopped);
    }
  }

  final NeomModulatorEngine modulator = NeomModulatorEngine();
  final NeomIsochronicEngine isochronic = NeomIsochronicEngine();

  /// Exposed for unit testing only. Do not call directly in production.
  @visibleForTesting
  Uint8List generateBufferForTesting({
    int frames = NeomGeneratorConstants.framesPerBuffer,
  }) => _generateBuffer(frames: frames);

  /// One shared LFO tick per stereo frame, not one tick per channel. Depth
  /// controls audible modulation; `intensity` remains visual metadata.
  ({double pitchRatio, double amplitudeGain, double phaseOffset})
  _advanceModulation() {
    if (!modulator.enabled || modulator.type == NeomModulationType.none) {
      return (pitchRatio: 1, amplitudeGain: 1, phaseOffset: 0);
    }
    final rate = modulator.modFrequency.isFinite
        ? modulator.modFrequency.clamp(0.0, 1000.0)
        : 0.0;
    final depth = modulator.depth.isFinite
        ? modulator.depth.clamp(0.0, 1.0)
        : 0.0;
    modulator.restorePhase(
      modulator.phase + 2 * pi * rate / NeomGeneratorConstants.sampleRate,
    );
    final lfo = sin(modulator.phase);
    return switch (modulator.type) {
      NeomModulationType.fm => (
        pitchRatio: 1 + depth * lfo,
        amplitudeGain: 1,
        phaseOffset: 0,
      ),
      // Unipolar AM: gain stays in [1-depth, 1], with no DC added to audio.
      NeomModulationType.am => (
        pitchRatio: 1,
        amplitudeGain: 1 - depth + depth * (1 + lfo) / 2,
        phaseOffset: 0,
      ),
      // `phase` is the legacy name for PM; both are kept as JSON/UI aliases.
      NeomModulationType.phase || NeomModulationType.pm => (
        pitchRatio: 1,
        amplitudeGain: 1,
        phaseOffset: pi * depth * lfo,
      ),
      NeomModulationType.none => (
        pitchRatio: 1,
        amplitudeGain: 1,
        phaseOffset: 0,
      ),
    };
  }

  double _phaseIncrement(double hz) {
    // FM must not reverse an oscillator, create NaN phases, or drive its
    // instantaneous frequency above the render sample rate's Nyquist limit.
    final boundedHz = hz.isFinite
        ? hz.clamp(0.0, NeomGeneratorConstants.sampleRate / 2)
        : 0.0;
    return 2 * pi * boundedHz / NeomGeneratorConstants.sampleRate;
  }

  Uint8List _generateBuffer({
    int frames = NeomGeneratorConstants.framesPerBuffer,
  }) {
    final Int16List pcm = Int16List(frames * NeomGeneratorConstants.channels);
    const double twoPi = 2 * pi;
    final blockPhase = (_phaseR - _phaseL) % twoPi;
    double sumLeftHz = 0, sumRightHz = 0, sumSubHz = 0;
    double sumSquares = 0;
    final envelope = NeomSessionEnvelope(
      sampleRate: NeomGeneratorConstants.sampleRate,
      fadeInSeconds: fadeInSeconds,
      fadeOutSeconds: fadeOutSeconds,
      endFrame: fadeOutEndFrame,
    );

    for (int i = 0; i < frames; i++) {
      final modulation = _advanceModulation();
      final phaseOffset = modulation.phaseOffset;
      final envelopeGain = envelope.gainAt(generatedFrames + i);
      if (multiFrequencyMode) {
        // ═══════════════════════════════════════════════════
        // MULTI-FREQUENCY MODE: 3 independent oscillators
        // Sub → both channels, L → left only, R → right only
        // ═══════════════════════════════════════════════════
        final double incL = _phaseIncrement(frequencyL * modulation.pitchRatio);
        final double incR = _phaseIncrement(frequencyR * modulation.pitchRatio);
        final double incSub = _phaseIncrement(
          frequencySub * modulation.pitchRatio,
        );
        sumLeftHz += incL;
        sumRightHz += incR;
        sumSubHz += incSub;

        double amp = isochronic.apply(
          amplitude: volume * modulation.amplitudeGain,
          sampleRate: NeomGeneratorConstants.sampleRate,
        );
        amp = breathEngine.apply(
          baseAmplitude: amp,
          sampleRate: NeomGeneratorConstants.sampleRate,
        );

        final double scaledAmp = 32767 * amp.clamp(0.0, 1.0) * envelopeGain;
        // Gain staging: total must not exceed 1.0 to prevent clipping.
        // subGain + channelGain = subMix/(1+subMix) + 1/(1+subMix) = 1.0
        final double clampedSub = subMixLevel.clamp(0.0, 1.0);
        final double subGain = clampedSub / (1.0 + clampedSub);
        final double channelGain = 1.0 / (1.0 + clampedSub);
        final double subSample =
            sin(_phaseSub + phaseOffset) * scaledAmp * subGain;
        final double lSample =
            sin(_phaseL + phaseOffset) * scaledAmp * channelGain;
        final double rSample =
            sin(_phaseR + phaseOffset) * scaledAmp * channelGain;

        // Mix: L gets its own freq + sub, R gets its own freq + sub
        final int outL = (lSample + subSample).toInt();
        final int outR = (rSample + subSample).toInt();

        pcm[i * 2] = outL.clamp(-32768, 32767);
        pcm[i * 2 + 1] = outR.clamp(-32768, 32767);

        // What the ears get, normalised to [-1, 1] for the scope.
        //
        // This used to draw sin((phaseL + phaseR + phaseSub) / 3): a single
        // sine at the mean frequency. sin(a)+sin(b) beats — its envelope
        // pulses at |fR - fL| — while sin((a+b)/2) is flat, so the binaural
        // beat, the whole point of the session, was invisible. Averaging the
        // phases also dropped amplitude: every volume looked identical.
        final double visualSample =
            (((lSample + rSample) * 0.5 + subSample) / 32767.0).clamp(
              -1.0,
              1.0,
            );
        painterEngine?.pushSample(visualSample);
        painterEngine?.updatePhases(
          phaseL: _phaseL + phaseOffset,
          phaseR: _phaseR + phaseOffset,
        );
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

        // 1️⃣ Shared modulation preserves the selected LFO rate in stereo.
        final z = posZ.isFinite ? posZ.clamp(-1.0, 1.0) : 0.0;
        final double incL = _phaseIncrement(
          frequency * modulation.pitchRatio * (1.0 + z * 0.02),
        );
        final double incR = _phaseIncrement(
          (frequency + beat) * modulation.pitchRatio * (1.0 - z * 0.02),
        );
        sumLeftHz += incL;
        sumRightHz += incR;

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
          amplitude: volume * modulation.amplitudeGain,
          sampleRate: NeomGeneratorConstants.sampleRate,
        );

        amp = breathEngine.apply(
          baseAmplitude: amp,
          sampleRate: NeomGeneratorConstants.sampleRate,
        );

        final double scaledAmp = 32767 * amp.clamp(0.0, 1.0) * envelopeGain;
        final double ampL = scaledAmp * panL * distanceAttenuation;
        final double ampR = scaledAmp * panR * distanceAttenuation;

        // 3️⃣ GENERACIÓN DE LA ONDA
        final int sampleL = (sin(_phaseL + phaseOffset) * ampL).toInt();
        final int sampleR = (sin(_phaseR + phaseOffset) * ampR).toInt();

        // Same reasoning as above: the mix beats, the mean phase does not.
        final double visualSample =
            ((sin(_phaseL + phaseOffset) * ampL +
                        sin(_phaseR + phaseOffset) * ampR) *
                    0.5 /
                    32767.0)
                .clamp(-1.0, 1.0);

        painterEngine?.pushSample(visualSample);
        painterEngine?.updatePhases(
          phaseL: _phaseL + phaseOffset,
          phaseR: _phaseR + phaseOffset,
        );

        painterEngine?.tickBinaural(
          beat,
          1 / NeomGeneratorConstants.sampleRate,
        );

        pcm[i * 2] = sampleL.clamp(-32768, 32767);
        pcm[i * 2 + 1] = sampleR.clamp(-32768, 32767);

        // 4️⃣ AVANCE DE FASE
        _phaseL += incL;
        _phaseR += incR;

        if (_phaseL >= twoPi) _phaseL -= twoPi;
        if (_phaseR >= twoPi) _phaseR -= twoPi;
      }
      final normalizedL = pcm[i * 2] / 32768.0;
      final normalizedR = pcm[i * 2 + 1] / 32768.0;
      sumSquares += normalizedL * normalizedL + normalizedR * normalizedR;
    }

    if (frames > 0) {
      // Constant-size metadata per PCM block; no allocations per sample and
      // no per-sample listeners. Old blocks expire even while UI is hidden.
      // Offline deterministic rendering must not touch a platform backend.
      _pruneVisualBlocks(_running ? playedFrames : generatedFrames);
      final hzScale = NeomGeneratorConstants.sampleRate / (twoPi * frames);
      final subMix = subMixLevel.clamp(0.0, 1.0);
      _visualBlocks.add(
        NeomAudioSessionSnapshot(
          isPlaying: _running,
          multiFrequency: multiFrequencyMode,
          breathingEnabled: breathEngine.mode != NeomBreathMode.off,
          playedFrames: generatedFrames,
          sampleRate: NeomGeneratorConstants.sampleRate,
          leftHz: sumLeftHz * hzScale,
          rightHz: sumRightHz * hzScale,
          subHz: multiFrequencyMode && subMix > 0 ? sumSubHz * hzScale : 0,
          subGain: multiFrequencyMode ? subMix / (1 + subMix) : 0,
          level: sqrt(sumSquares / (2 * frames)).clamp(0.0, 1.0),
          breathValue: breathEngine.currentValue,
          breathRateHz: breathEngine.mode != NeomBreathMode.off
              ? breathEngine.breathsPerMinute / 60
              : 0,
          beatPhase: blockPhase,
          phaseRelationship: cos(blockPhase).abs(),
        ),
      );
    }

    painterEngine?.updateFromAudio(
      phase: (_phaseL + _phaseR) * 0.5,
      amplitude: volume,
      pan: posX,
      breath: breathEngine.currentValue,
      modulation: modulator.intensity,
      neuro: neuroStateEngine.intensity,
      frequency: (frequency - 20) / (20000 - 20),
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
        apply(pan <= 0 ? 1.0 : 0.0, pan >= 0 ? 1.0 : 0.0);
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
