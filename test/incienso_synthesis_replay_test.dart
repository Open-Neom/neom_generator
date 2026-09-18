import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/data/implementations/incienso_playback.dart';
import 'package:neom_generator/data/implementations/incienso_recorder.dart';
import 'package:neom_generator/domain/models/incienso.dart';
import 'package:neom_generator/domain/models/incienso_audio_state.dart';
import 'package:neom_generator/engine/audio/neom_pcm_backend.dart';
import 'package:neom_generator/engine/incienso_synthesis_state.dart';
import 'package:neom_generator/engine/neom_breath_engine.dart';
import 'package:neom_generator/engine/neom_modulator_engine.dart';
import 'package:neom_generator/engine/neom_sine_engine.dart';
import 'package:neom_generator/utils/enums/neom_spatial_mode.dart';

/// These tests render PCM into memory only. Attempting platform output fails.
class _ForbiddenAudioBackend implements NeomPcmBackend {
  Never _forbidden() =>
      throw StateError('Audio output is forbidden in this test');
  @override
  Future<void> activate() async => _forbidden();
  @override
  Future<void> init() async => _forbidden();
  @override
  Future<void> start({
    required int sampleRate,
    required int channels,
    required int framesPerBuffer,
  }) async => _forbidden();
  @override
  Future<void> waitForCapacity(int frames) async => _forbidden();
  @override
  Future<void> write(Uint8List pcm) async => _forbidden();
  @override
  Future<void> drain() async => _forbidden();
  @override
  void interrupt() => _forbidden();
  @override
  Future<void> stop() async => _forbidden();
  @override
  Future<void> dispose() async => _forbidden();
  @override
  int get playedFrames => 0;
}

NeomSineEngine _engine() =>
    NeomSineEngine.withBackend(_ForbiddenAudioBackend());

void _modulationTests() {
  group('audible modulation synthesis', () {
    NeomSineEngine configured(
      NeomModulationType type, {
      bool multi = false,
      double depth = .8,
    }) {
      final engine = _engine()
        ..frequency = 440
        ..beat = 7
        ..volume = .6
        ..spatialMode = NeomSpatialMode.centered
        ..multiFrequencyMode = multi
        ..frequencyL = 440
        ..frequencyR = 447
        ..frequencySub = 62.5;
      engine.modulator
        ..enabled = true
        ..type = type
        ..depth = depth
        ..modFrequency = 3.7;
      engine.modulator.restorePhase(.7);
      return engine;
    }

    for (final type in [
      NeomModulationType.am,
      NeomModulationType.phase,
      NeomModulationType.pm,
      NeomModulationType.fm,
    ]) {
      for (final multi in [false, true]) {
        test(
          '${type.name} changes PCM in ${multi ? 'multi' : 'stereo'} mode',
          () {
            final modulated = configured(type, multi: multi);
            final dry = configured(NeomModulationType.none, multi: multi);
            expect(
              modulated.generateBufferForTesting(),
              isNot(equals(dry.generateBufferForTesting())),
            );
          },
        );
      }
      test('${type.name} uses one shared LFO tick per stereo frame', () {
        final engine = configured(type);
        engine.generateBufferForTesting();
        final expected = (.7 + 2 * pi * 3.7 * 1024 / 44100) % (2 * pi);
        expect(engine.modulator.phase, closeTo(expected, 1e-10));
      });
      test('${type.name} is neutral with zero depth or a disabled toggle', () {
        final zeroDepth = configured(type, depth: 0);
        final disabled = configured(type)..modulator.enabled = false;
        final dry = configured(
          NeomModulationType.none,
        ).generateBufferForTesting();
        expect(zeroDepth.generateBufferForTesting(), dry);
        expect(disabled.generateBufferForTesting(), dry);
        expect(disabled.modulator.phase, .7);
      });
      test('${type.name} restores exact PCM from a mid-cycle snapshot', () {
        final original = configured(type);
        original.generateBufferForTesting();
        final json =
            jsonDecode(jsonEncode(original.captureAudioState().toJson()))
                as Map<String, dynamic>;
        final replay = _engine()
          ..applyAudioState(InciensoAudioState.fromJson(json));
        for (var i = 0; i < 8; i++) {
          expect(
            replay.generateBufferForTesting(),
            original.generateBufferForTesting(),
          );
        }
      });
    }

    test('phase and pm are compatible aliases', () {
      final phase = configured(NeomModulationType.phase);
      final pm = configured(NeomModulationType.pm);
      for (var i = 0; i < 8; i++) {
        expect(phase.generateBufferForTesting(), pm.generateBufferForTesting());
      }
    });

    test('AM is unipolar and never exceeds the configured amplitude', () {
      final engine = configured(NeomModulationType.am)
        ..frequency = 0
        ..beat = 0
        ..volume = .8;
      engine.restorePhaseState((left: pi / 2, right: pi / 2, sub: 0, orbit: 0));
      engine.modulator
        ..modFrequency = 20
        ..depth = .6;
      var minAmplitude = double.infinity;
      var maxAmplitude = double.negativeInfinity;
      for (var i = 0; i < 4; i++) {
        final pcm = engine.generateBufferForTesting().buffer.asInt16List();
        for (final sample in pcm) {
          final amplitude = sample / 32767;
          minAmplitude = min(minAmplitude, amplitude);
          maxAmplitude = max(maxAmplitude, amplitude);
        }
      }
      expect(minAmplitude, greaterThanOrEqualTo(.8 * (1 - .6) - 1 / 32767));
      expect(maxAmplitude, lessThanOrEqualTo(.8));
      expect(maxAmplitude - minAmplitude, greaterThan(.45));
    });

    test(
      'FM clamps invalid, negative and above-Nyquist instantaneous frequencies',
      () {
        for (final frequency in [-440.0, double.nan, double.infinity, 1e30]) {
          final engine = configured(NeomModulationType.fm)
            ..frequency = frequency;
          for (var i = 0; i < 10; i++) {
            final output = engine.generateBufferForTesting();
            expect(output.length, 4096);
            expect(engine.phaseState.left.isFinite, isTrue);
            expect(engine.phaseState.right.isFinite, isTrue);
            expect(engine.phaseState.left, inInclusiveRange(0, 2 * pi));
            expect(engine.phaseState.right, inInclusiveRange(0, 2 * pi));
          }
        }
      },
    );
  });
}

void _configureRichState(NeomSineEngine engine) {
  engine
    ..frequency = 381.25
    ..beat = 7.5
    ..volume = .63
    ..posX = .2
    ..posY = -.3
    ..posZ = .18
    ..spatialMode = NeomSpatialMode.orbit
    ..orbitSpeed = .23
    ..orbitDirection = -1
    ..spatialIntensity = .72;
  engine.breathEngine
    ..mode = NeomBreathMode.free
    ..breathsPerMinute = 5.4
    ..depth = .69
    ..intensity = .27;
  engine.modulator
    ..enabled = true
    ..type = NeomModulationType.fm
    ..modFrequency = 1.3
    ..depth = .17
    ..intensity = .8;
  engine.isochronic
    ..enabled = true
    ..pulseFrequency = 5.25
    ..dutyCycle = .61;
  engine.restorePhaseState((left: .31, right: 1.8, sub: .29, orbit: .45));
  engine.breathEngine.restorePhase(.37);
  engine.modulator.restorePhase(1.7);
  engine.isochronic.restorePhase(.9);
}

Incienso _session(
  List<InciensoKeyframe> frames, {
  int version = 2,
  int sampleRate = 44100,
  Duration duration = const Duration(seconds: 31),
}) => Incienso(
  id: 'in-memory-audit',
  names: const {'es': 'Prueba'},
  leftFrequencyHz: 200,
  rightFrequencyHz: 210,
  suggestedDuration: duration,
  timeline: frames,
  recordingVersion: version,
  sampleRate: sampleRate,
);

InciensoKeyframe _frame(
  int frame, {
  InciensoAudioState? state,
  double left = 200,
  double right = 210,
  bool manual = false,
}) => InciensoKeyframe(
  timestampMs: frame * 1000 / 44100,
  sampleFrame: frame,
  leftHz: left,
  rightHz: right,
  audioState: state,
  isUserAction: manual,
);

void main() {
  _modulationTests();
  test(
    'complete snapshot JSON roundtrip retains parameters and all DSP phases',
    () {
      final original = _engine();
      _configureRichState(original);
      original.generateBufferForTesting();
      final snapshot = original.captureAudioState(
        baseHz: 190.625,
        octave: 1,
        neuroState: 'calm',
        visualMode: 'immersive',
        visualExperience: 'fractals',
      );
      final decoded = InciensoAudioState.fromJson(
        jsonDecode(jsonEncode(snapshot.toJson())) as Map<String, dynamic>,
      );
      expect(decoded.toJson(), snapshot.toJson());
      expect(decoded.parameters['baseHz'], 190.625);
      expect(decoded.parameters['octave'], 1);
      expect(decoded.parameters['visualExperience'], 'fractals');
      expect(
        decoded.phases.keys,
        containsAll([
          'left',
          'right',
          'sub',
          'orbit',
          'breath',
          'modulation',
          'isochronic',
        ]),
      );
      expect(() => decoded.parameters['volume'] = .1, throwsUnsupportedError);
      expect(() => decoded.phases['left'] = 0, throwsUnsupportedError);

      final replay = _engine()..applyAudioState(decoded);
      for (var i = 0; i < 20; i++) {
        expect(
          replay.generateBufferForTesting(),
          original.generateBufferForTesting(),
          reason:
              'Snapshot must resume the next identical PCM buffer, not reset phases',
        );
      }
    },
  );

  for (final withFades in [false, true]) {
    test(
      '30-second recorded parameter journey replays every PCM byte identically${withFades ? ' with scheduled fades' : ''}',
      () {
        const blocks = 1400;
        const framesPerBuffer = 1024;
        final original = _engine();
        _configureRichState(original);
        if (withFades) {
          original
            ..fadeInSeconds = 2
            ..fadeOutSeconds = 5
            ..fadeOutEndFrame = blocks * framesPerBuffer;
        }
        final recorder = InciensoRecorder();
        addTearDown(recorder.dispose);
        recorder.startRecording(
          audioClock: true,
          initialState: original.captureAudioState(),
        );
        final buffers = <Uint8List>[];
        for (var block = 0; block < blocks; block++) {
          if (block == 100) {
            original
              ..frequency = 432.125
              ..beat = 11.25
              ..volume = .42
              ..spatialMode = NeomSpatialMode.softPan
              ..posX = -.47;
            original.breathEngine.mode = NeomBreathMode.box;
          }
          if (block == 200) original.modulator.type = NeomModulationType.am;
          if (block == 350) {
            original
              ..multiFrequencyMode = true
              ..frequencyL = 220.5
              ..frequencyR = 229.25
              ..frequencySub = 55.125
              ..subMixLevel = .33;
            original.breathEngine.mode = NeomBreathMode.fourSevenEight;
            original.isochronic.pulseFrequency = 7.5;
          }
          if (block == 800) {
            original
              ..frequencyL = 555
              ..frequencyR = 556.25
              ..frequencySub = 63.375
              ..subMixLevel = .42;
            original.breathEngine.mode = NeomBreathMode.free;
            original.isochronic.enabled = false;
          }
          if (block == 900) original.modulator.type = NeomModulationType.phase;
          if (block == 1000) original.modulator.type = NeomModulationType.pm;
          if (block == 1200) {
            original
              ..multiFrequencyMode = false
              ..frequency = 528.4
              ..beat = -7.5
              ..volume = .24
              ..posX = -.67
              ..posY = .12
              ..posZ = -.08;
            original.modulator
              ..type = NeomModulationType.fm
              ..modFrequency = 2.2
              ..depth = .32;
            original.isochronic
              ..enabled = true
              ..pulseFrequency = 9.25
              ..dutyCycle = .33;
            original.breathEngine
              ..mode = NeomBreathMode.box
              ..breathsPerMinute = 11;
          }
          final frame = block * framesPerBuffer;
          original.generatedFrames = frame;
          recorder.captureAudioFrame(
            original.captureAudioState(),
            frame,
            coherence: .77,
            breathPhase: original.breathEngine.cyclePosition,
          );
          buffers.add(original.generateBufferForTesting());
          recorder.advanceAudioClock(frame + framesPerBuffer);
        }
        final recorded = recorder.stopAndBuild(
          name: 'Reproducción determinista',
          endFrame: blocks * framesPerBuffer,
        )!;
        final restored = Incienso.fromJson(
          jsonDecode(jsonEncode(recorded.toJson())) as Map<String, dynamic>,
        );
        expect(restored.recordingVersion, 2);
        expect(restored.timeline.first.leftHz, 381.25);
        expect(restored.timeline.first.rightHz, 388.75);
        expect(restored.timeline.first.volume, .63);
        expect(restored.timeline.last.sampleFrame, blocks * framesPerBuffer);
        expect(
          restored.timeline.where((k) => k.audioState != null),
          hasLength(8),
        );
        expect(
          restored.timeline.where((k) => k.audioState == null).length,
          greaterThan(20),
        );
        expect(
          restored.timeline.length,
          lessThan(45),
          reason:
              'Sparse control events plus 1 Hz metadata, not every PCM buffer',
        );

        final cursor = InciensoPlayback(restored);
        expect(cursor.endFrame, blocks * framesPerBuffer);
        final replay = _engine();
        for (var block = 0; block < blocks; block++) {
          replay.generatedFrames = block * framesPerBuffer;
          cursor.applyAt(
            block * framesPerBuffer,
            applyState: replay.applyAudioState,
            applyLegacy: (_) => fail('v2 must not use the lossy legacy path'),
          );
          expect(
            replay.generateBufferForTesting(),
            buffers[block],
            reason:
                'PCM mismatch at buffer $block (${block * framesPerBuffer} samples)',
          );
        }
        if (withFades) {
          expect(buffers.first.buffer.asInt16List().first, 0);
          expect(buffers.last.buffer.asInt16List().last, 0);
        }
      },
    );
  }

  test(
    'sample-clock recording ignores phase-only changes and has a precise final frame',
    () {
      final engine = _engine();
      _configureRichState(engine);
      final initial = engine.captureAudioState();
      final recorder = InciensoRecorder();
      addTearDown(recorder.dispose);
      recorder.startRecording(initialState: initial, audioClock: true);
      for (var second = 0; second <= 31; second++) {
        engine.generateBufferForTesting();
        recorder.captureAudioFrame(
          engine.captureAudioState(),
          second * 44100,
          coherence: .8,
          breathPhase: .6,
        );
      }
      recorder.advanceAudioClock(31 * 44100 + 317);
      final result = recorder.stopAndBuild(name: 'Reloj de muestras')!;
      expect(result.timeline.where((k) => k.audioState != null), hasLength(1));
      expect(result.timeline.last.sampleFrame, 31 * 44100 + 317);
      expect(InciensoPlayback(result).endFrame, 31 * 44100 + 317);
      expect(result.timeline[1].coherence, .8);
      expect(result.timeline[1].breathPhase, .6);
    },
  );

  test(
    'manual stop trims unheard future parameters and future visual metadata',
    () {
      final engine = _engine()
        ..frequency = 432
        ..beat = 8
        ..volume = .4;
      final state = engine.captureAudioState(
        neuroState: 'calm',
        visualExperience: 'breathing',
      );
      final recorder = InciensoRecorder();
      addTearDown(recorder.dispose);
      recorder.startRecording(initialState: state, audioClock: true);
      for (var second = 1; second <= 31; second++) {
        recorder.captureAudioFrame(state, second * 44100);
      }
      engine
        ..frequency = 900
        ..beat = 40
        ..volume = .9;
      recorder.captureAudioFrame(
        engine.captureAudioState(
          neuroState: 'neutral',
          visualExperience: 'fractals',
        ),
        31 * 44100 + 1024,
      );
      recorder.advanceAudioClock(31 * 44100 + 2048);
      final heardEnd = 31 * 44100 + 250;
      final result = recorder.stopAndBuild(
        name: 'Corte manual',
        endFrame: heardEnd,
      )!;
      expect(InciensoPlayback(result).endFrame, heardEnd);
      expect(result.timeline.where((k) => k.audioState != null), hasLength(1));
      expect(result.timeline.last.leftHz, 432);
      expect(result.timeline.last.volume, .4);
      expect(result.timeline.last.neuroState, 'calm');
      expect(result.timeline.last.visualExperience, 'breathing');
    },
  );

  test(
    'starting another recording never inherits the previous initial state',
    () {
      final engine = _engine()
        ..frequency = 432
        ..beat = 8;
      final recorder = InciensoRecorder();
      addTearDown(recorder.dispose);
      recorder.startRecording(
        initialState: engine.captureAudioState(),
        audioClock: true,
      );
      recorder.captureAudioFrame(
        (_engine()
              ..frequency = 900
              ..beat = 40)
            .captureAudioState(),
        44100,
      );
      engine
        ..frequency = 345
        ..beat = 6;
      recorder.startRecording(
        initialState: engine.captureAudioState(),
        audioClock: true,
      );
      for (var second = 1; second <= 31; second++) {
        recorder.captureAudioFrame(engine.captureAudioState(), second * 44100);
      }
      final result = recorder.stopAndBuild(name: 'Segunda sesión')!;
      expect(result.timeline.first.leftHz, 345);
      expect(result.timeline.first.rightHz, 351);
      expect(result.timeline.first.sampleFrame, 0);
    },
  );

  test(
    'v2 cursor applies first and last events once, and rewind restarts state',
    () {
      final a = (_engine()..frequency = 432).captureAudioState();
      final b = (_engine()..frequency = 528).captureAudioState();
      final cursor = InciensoPlayback(
        _session([_frame(0, state: a), _frame(1024), _frame(2048, state: b)]),
      );
      final applied = <InciensoAudioState>[];
      void at(int frame) => cursor.applyAt(
        frame,
        applyState: applied.add,
        applyLegacy: (_) => fail('Unexpected legacy path'),
      );
      at(0);
      at(512);
      at(1024);
      at(2047);
      expect(applied, [a]);
      at(2048);
      at(4096);
      expect(applied, [a, b]);
      at(0);
      expect(applied, [a, b, a]);
    },
  );

  test('legacy manual changes are steps, not premature interpolated ramps', () {
    final cursor = InciensoPlayback(
      _session([
        _frame(0),
        _frame(22050, right: 220, manual: true),
        _frame(44100, right: 225),
      ], version: 1),
    );
    final values = <double>[];
    for (final frame in [0, 11025, 22049, 22050, 33075, 44100, 88200]) {
      cursor.applyAt(
        frame,
        applyState: (_) => fail('Unexpected v2 path'),
        applyLegacy: (keyframe) => values.add(keyframe.beatHz),
      );
    }
    expect(values, [10, 10, 10, 20, 22.5, 25, 25]);
  });

  test(
    'unsupported recording versions and sample rates fail before replay',
    () {
      final state = _engine().captureAudioState();
      final timeline = [_frame(0, state: state)];
      expect(
        () => InciensoPlayback(_session(timeline, version: 3)),
        throwsUnsupportedError,
      );
      expect(
        () => InciensoPlayback(_session(timeline, sampleRate: 48000)),
        throwsUnsupportedError,
      );
      final futureState = InciensoAudioState(
        engineVersion: 99,
        parameters: state.parameters,
        phases: state.phases,
      );
      expect(
        () => InciensoPlayback(_session([_frame(0, state: futureState)])),
        throwsUnsupportedError,
      );
      expect(
        () => _engine().applyAudioState(futureState),
        throwsUnsupportedError,
      );
    },
  );

  test(
    'v2 timeline requires initial synthesis and ordered finite timestamps',
    () {
      final state = _engine().captureAudioState();
      expect(
        () => InciensoPlayback(_session([_frame(0)])),
        throwsFormatException,
      );
      expect(
        () => InciensoPlayback(_session([_frame(1024, state: state)])),
        throwsFormatException,
      );
      expect(
        () => InciensoPlayback(
          _session([_frame(0, state: state), _frame(2048), _frame(1024)]),
        ),
        throwsFormatException,
      );
      expect(
        () => InciensoPlayback(
          _session([
            _frame(0, state: state),
            const InciensoKeyframe(
              timestampMs: double.nan,
              leftHz: 200,
              rightHz: 210,
            ),
          ]),
        ),
        throwsFormatException,
      );
    },
  );
}
