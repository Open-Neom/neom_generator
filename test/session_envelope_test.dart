import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/domain/models/incienso_audio_state.dart';
import 'package:neom_generator/engine/incienso_synthesis_state.dart';
import 'package:neom_generator/engine/neom_session_envelope.dart';
import 'package:neom_generator/engine/neom_sine_engine.dart';
import 'package:neom_generator/utils/enums/neom_spatial_mode.dart';

import 'sine_engine_lifecycle_test.dart' show FakePcmBackend, settle;

/// Captures only in-memory PCM. No platform audio or microphone is opened.
class _MemoryBackend extends FakePcmBackend {
  final pcmBuffers = <Uint8List>[];

  @override
  Future<void> write(Uint8List pcm) async {
    pcmBuffers.add(Uint8List.fromList(pcm));
    await super.write(pcm);
  }
}

NeomSineEngine _constantPeak({bool multi = false, _MemoryBackend? backend}) {
  final engine = NeomSineEngine.withBackend(backend ?? _MemoryBackend())
    ..frequency = 0
    ..beat = 0
    ..volume = .5
    ..spatialMode = NeomSpatialMode.centered
    ..multiFrequencyMode = multi;
  engine.restorePhaseState((
    left: pi / 2,
    right: pi / 2,
    sub: pi / 2,
    orbit: 0,
  ));
  return engine;
}

InciensoAudioState _jsonRoundTrip(InciensoAudioState state) =>
    InciensoAudioState.fromJson(
      jsonDecode(jsonEncode(state.toJson())) as Map<String, dynamic>,
    );

void main() {
  group('sample-clock session envelope', () {
    test('disabled or malformed ramps are exactly neutral', () {
      for (final seconds in [0.0, -2.0, double.nan, double.infinity]) {
        final envelope = NeomSessionEnvelope(
          sampleRate: 44100,
          fadeInSeconds: seconds,
          fadeOutSeconds: seconds,
          endFrame: 1000,
        );
        for (final frame in [0, 1, 500, 999]) {
          expect(envelope.gainAt(frame), 1);
        }
      }
    });

    test('entrance is monotonic with exact silence, midpoint and unity', () {
      final envelope = NeomSessionEnvelope(sampleRate: 100, fadeInSeconds: 2);
      expect(envelope.gainAt(0), 0);
      expect(envelope.gainAt(100), closeTo(.5, 1e-12));
      expect(envelope.gainAt(200), 1);
      var previous = 0.0;
      for (var frame = 0; frame < 1000; frame++) {
        final value = envelope.gainAt(frame);
        expect(value, inInclusiveRange(previous, 1));
        previous = value;
      }
    });

    test('scheduled ending is smooth and its final sample is zero', () {
      final envelope = NeomSessionEnvelope(
        sampleRate: 100,
        fadeOutSeconds: 5,
        endFrame: 1000,
      );
      expect(envelope.gainAt(499), 1);
      expect(envelope.gainAt(749), closeTo(.5, 1e-12));
      expect(envelope.gainAt(999), 0);
      expect(envelope.gainAt(1000), 0);
      var previous = 1.0;
      for (var frame = 0; frame < 1000; frame++) {
        final value = envelope.gainAt(frame);
        expect(value, inInclusiveRange(0, previous));
        previous = value;
      }
    });

    test('free session never fades out merely because time passes', () {
      for (final end in [null, 0]) {
        final envelope = NeomSessionEnvelope(
          sampleRate: 44100,
          fadeOutSeconds: 5,
          endFrame: end,
        );
        for (final frame in [0, 44100, 44100 * 100000]) {
          expect(envelope.gainAt(frame), 1);
        }
      }
    });

    test('overlapping ramps and a one-frame session remain bounded', () {
      for (final end in [1, 10, 100]) {
        final envelope = NeomSessionEnvelope(
          sampleRate: 100,
          fadeInSeconds: 2,
          fadeOutSeconds: 5,
          endFrame: end,
        );
        expect(envelope.gainAt(0), 0);
        expect(envelope.gainAt(end - 1), 0);
        for (var frame = 0; frame < end; frame++) {
          expect(envelope.gainAt(frame), inInclusiveRange(0, 1));
        }
      }
    });

    test(
      'external durations are bounded and sub-sample durations are safe',
      () {
        expect(NeomSessionEnvelope.durationFrames(1e30, 44100), 3600 * 44100);
        expect(NeomSessionEnvelope.durationFrames(.00000001, 44100), 0);
        expect(NeomSessionEnvelope.durationFrames(5, 0), 0);
      },
    );
  });

  group('envelope synthesis and persisted replay', () {
    for (final multi in [false, true]) {
      test('applies once to both ${multi ? 'multi' : 'stereo'} channels', () {
        final engine = _constantPeak(multi: multi)
          ..fadeInSeconds = 100 / 44100
          ..fadeOutSeconds = 100 / 44100
          ..fadeOutEndFrame = 401;
        final pcm = engine
            .generateBufferForTesting(frames: 401)
            .buffer
            .asInt16List();
        final expected = NeomSessionEnvelope(
          sampleRate: 44100,
          fadeInSeconds: engine.fadeInSeconds,
          fadeOutSeconds: engine.fadeOutSeconds,
          endFrame: 401,
        );
        for (var frame = 0; frame < 401; frame++) {
          final amplitude = 32767 * .5 * expected.gainAt(frame);
          expect(pcm[frame * 2], closeTo(amplitude, 1));
          expect(pcm[frame * 2 + 1], pcm[frame * 2]);
        }
        expect(pcm.first, 0);
        expect(pcm.last, 0);
        expect(pcm[200], closeTo(16383, 1));
      });
    }

    test('buffer boundaries do not restart the entrance ramp', () {
      final split = _constantPeak()..fadeInSeconds = 2;
      final whole = _constantPeak()..fadeInSeconds = 2;
      final first = split.generateBufferForTesting();
      split.generatedFrames = 1024;
      final second = split.generateBufferForTesting();
      expect([
        ...first,
        ...second,
      ], whole.generateBufferForTesting(frames: 2048));
      expect(second.buffer.asInt16List().first, greaterThan(0));
    });

    test(
      'legacy snapshot disables fades on a previously configured engine',
      () {
        final original = _constantPeak();
        final json = original.captureAudioState().toJson();
        final parameters = Map<String, dynamic>.from(json['parameters'] as Map)
          ..remove('fadeInSeconds')
          ..remove('fadeOutSeconds')
          ..remove('fadeOutEndFrame');
        json['parameters'] = parameters;
        final replay = _constantPeak()
          ..frameLimit = 2048
          ..fadeInSeconds = 2
          ..fadeOutSeconds = 5
          ..fadeOutEndFrame = 2048
          ..applyAudioState(InciensoAudioState.fromJson(json));
        expect(replay.fadeInSeconds, 0);
        expect(replay.fadeOutSeconds, 0);
        expect(replay.fadeOutEndFrame, isNull);
        expect(replay.frameLimit, 2048);
        expect(
          replay.generateBufferForTesting(),
          original.generateBufferForTesting(),
        );
      },
    );

    test('free-session replay does not acquire an ending from frameLimit', () {
      final original = _constantPeak()
        ..fadeInSeconds = .01
        ..fadeOutSeconds = 5;
      final replay = _constantPeak()
        ..frameLimit = 1300
        ..applyAudioState(_jsonRoundTrip(original.captureAudioState()));
      expect(replay.fadeOutEndFrame, isNull);
      final expected = original.generateBufferForTesting(frames: 1300);
      final actual = replay.generateBufferForTesting(frames: 1300);
      expect(actual, expected);
      expect(actual.buffer.asInt16List().last, greaterThan(16000));
    });

    test('manual early stop preserves original scheduled fade horizon', () {
      final original = _constantPeak()
        ..fadeInSeconds = .01
        ..fadeOutSeconds = 2000 / 44100
        ..fadeOutEndFrame = 5000;
      final replay = _constantPeak()
        ..frameLimit = 4000
        ..applyAudioState(_jsonRoundTrip(original.captureAudioState()));
      expect(replay.fadeOutEndFrame, 5000);
      original.generatedFrames = replay.generatedFrames = 3000;
      final expected = original.generateBufferForTesting(frames: 1000);
      final actual = replay.generateBufferForTesting(frames: 1000);
      expect(actual, expected);
      expect(actual.buffer.asInt16List().last, greaterThan(8000));
    });

    test(
      'mid-session snapshots preserve absolute fade clock, not a new ramp',
      () {
        final original = _constantPeak()
          ..frequency = 381.25
          ..beat = 7.5
          ..fadeInSeconds = 2
          ..fadeOutSeconds = 5
          ..fadeOutEndFrame = 44100 * 60
          ..generatedFrames = 44100;
        original.generateBufferForTesting();
        original.generatedFrames += 1024;
        final replay = _constantPeak()
          ..generatedFrames = original.generatedFrames
          ..applyAudioState(_jsonRoundTrip(original.captureAudioState()));
        expect(replay.captureAudioState().engineVersion, 1);
        for (var block = 0; block < 8; block++) {
          expect(
            replay.generateBufferForTesting(),
            original.generateBufferForTesting(),
          );
          original.generatedFrames += 1024;
          replay.generatedFrames += 1024;
        }
      },
    );
  });

  group('envelope lifecycle has no wall-clock fade delays', () {
    late _MemoryBackend backend;
    late NeomSineEngine engine;
    setUp(() {
      backend = _MemoryBackend();
      engine = _constantPeak(backend: backend)
        ..fadeInSeconds = 2
        ..fadeOutSeconds = 5;
    });
    tearDown(() async => engine.dispose());

    test(
      'finite partial last buffer reaches silence before natural completion',
      () async {
        backend.freeCapacity = true;
        final complete = Completer<void>();
        engine
          ..frameLimit = 1300
          ..fadeOutEndFrame = 1300
          ..onPlaybackComplete = complete.complete;
        await engine.start();
        await complete.future.timeout(const Duration(seconds: 1));
        expect(backend.buffers, [1024, 276]);
        expect(engine.generatedFrames, 1300);
        expect(backend.pcmBuffers.first.buffer.asInt16List().first, 0);
        expect(backend.pcmBuffers.last.buffer.asInt16List().last, 0);
      },
    );

    test(
      'manual Stop interrupts synchronously without draining or fading',
      () async {
        engine.fadeOutEndFrame = 44100 * 60;
        await engine.start();
        backend.allowOneWrite();
        await settle();
        final stopped = engine.stop();
        expect(backend.cancelled.isCompleted, isTrue);
        expect(engine.isPlaying, isFalse);
        await stopped.timeout(const Duration(milliseconds: 250));
        expect(backend.drainCalls, 0);
        expect(backend.pcmBuffers, hasLength(1));
      },
    );

    test('restart begins a fresh entrance at frame zero', () async {
      await engine.start();
      backend.allowOneWrite();
      await settle();
      await engine.stop();
      expect(engine.generatedFrames, 1024);
      await engine.start();
      expect(engine.generatedFrames, 0);
      backend.allowOneWrite();
      await settle();
      expect(backend.pcmBuffers, hasLength(2));
      expect(backend.pcmBuffers[1], backend.pcmBuffers[0]);
      expect(backend.pcmBuffers[1].buffer.asInt16List().first, 0);
    });
  });
}
