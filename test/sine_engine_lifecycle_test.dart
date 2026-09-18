import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/engine/audio/neom_pcm_backend.dart';
import 'package:neom_generator/engine/neom_sine_engine.dart';

/// No platform audio, microphone, Firebase, or browser is opened by these tests.
class FakePcmBackend implements NeomPcmBackend {
  Completer<void>? startBarrier;
  Completer<void>? drainBarrier;
  Completer<void> cancelled = Completer<void>()..complete();
  Completer<void> capacity = Completer<void>();
  final List<int> buffers = [];
  int starts = 0;
  int activations = 0;
  int stops = 0;
  int disposals = 0;
  int writesAllowed = 0;
  int waitCalls = 0;
  int concurrentStarts = 0;
  int maximumConcurrentStarts = 0;
  int drainCalls = 0;
  bool freeCapacity = false;
  bool failStart = false;
  bool failActivation = false;
  bool failWrite = false;
  int _played = 0;

  void allowOneWrite() {
    writesAllowed++;
    if (!capacity.isCompleted) capacity.complete();
  }

  @override
  Future<void> init() async {}
  @override
  Future<void> activate() async {
    activations++;
    if (failActivation) throw StateError('activation failed');
  }

  @override
  Future<void> start({
    required int sampleRate,
    required int channels,
    required int framesPerBuffer,
  }) async {
    starts++;
    concurrentStarts++;
    if (concurrentStarts > maximumConcurrentStarts) {
      maximumConcurrentStarts = concurrentStarts;
    }
    await startBarrier?.future;
    concurrentStarts--;
    if (failStart) throw StateError('start failed');
    cancelled = Completer<void>();
    capacity = Completer<void>();
    _played = 0;
  }

  @override
  Future<void> waitForCapacity(int frames) async {
    waitCalls++;
    while (!cancelled.isCompleted && !freeCapacity && writesAllowed == 0) {
      await Future.any([capacity.future, cancelled.future]);
      if (capacity.isCompleted) capacity = Completer<void>();
    }
    if (writesAllowed > 0) writesAllowed--;
  }

  @override
  Future<void> write(Uint8List pcm) async {
    if (failWrite) throw StateError('output failed');
    buffers.add(pcm.lengthInBytes ~/ 4);
  }

  @override
  Future<void> drain() async {
    drainCalls++;
    await Future.any([
      if (drainBarrier != null) drainBarrier!.future,
      if (drainBarrier == null) Future<void>.value(),
      cancelled.future,
    ]);
    if (!cancelled.isCompleted) {
      _played = buffers.fold(0, (total, frames) => total + frames);
    }
  }

  @override
  void interrupt() {
    if (!cancelled.isCompleted) cancelled.complete();
  }

  @override
  Future<void> stop() async {
    stops++;
    interrupt();
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await stop();
  }

  @override
  int get playedFrames => _played;
}

Future<void> settle() => Future<void>.delayed(const Duration(milliseconds: 10));

void main() {
  test('isolated production engines do not share state or activate audio', () {
    final first = NeomSineEngine.isolated();
    final second = NeomSineEngine.isolated();
    expect(identical(first, second), isFalse);
    expect(identical(first, NeomSineEngine.shared), isFalse);
    first.frequency = 999;
    expect(second.frequency, 432);
    expect(first.isPlaying, isFalse);
    expect(first.isTransitioning, isFalse);
    expect(first.generatedFrames, 0);
    expect(second.isPlaying, isFalse);
    // No init/start/dispose call: construction owns no open platform resources.
  });

  late FakePcmBackend backend;
  late NeomSineEngine engine;
  setUp(() {
    backend = FakePcmBackend();
    engine = NeomSineEngine.withBackend(backend);
  });
  tearDown(() async {
    await engine.dispose();
  });

  test(
    'prepare output activates synchronously without synthesis or playback',
    () async {
      final prepared = engine.preparePlayback();
      expect(backend.activations, 1);
      expect(backend.starts, 0);
      expect(engine.isPlaying, isFalse);
      await prepared;
      expect(backend.buffers, isEmpty);
      expect(engine.generatedFrames, 0);
      await engine.start();
      expect(engine.isPlaying, isTrue);
      expect(backend.starts, 1);
    },
  );

  test('failed preparation propagates without starting a producer', () async {
    backend.failActivation = true;
    await expectLater(engine.preparePlayback(), throwsStateError);
    expect(backend.starts, 0);
    expect(engine.isPlaying, isFalse);
    expect(backend.buffers, isEmpty);
  });

  test('stop wins over a pending start without emitting PCM', () async {
    backend.startBarrier = Completer<void>();
    final started = engine.start();
    await settle();
    expect(backend.starts, 1);
    final stopped = engine.stop();
    expect(engine.isPlaying, isFalse);
    backend.startBarrier!.complete();
    await Future.wait([started, stopped]);
    expect(engine.isPlaying, isFalse);
    expect(backend.buffers, isEmpty);
    expect(engine.isTransitioning, isFalse);
  });

  test(
    'play-stop-play serializes output and only the newest play survives',
    () async {
      backend.startBarrier = Completer<void>();
      final first = engine.start();
      await settle();
      final stopped = engine.stop();
      final last = engine.start();
      backend.startBarrier!.complete();
      await Future.wait([first, stopped, last]);
      expect(backend.starts, 2);
      expect(backend.maximumConcurrentStarts, 1);
      expect(engine.isPlaying, isTrue);
      backend.allowOneWrite();
      await settle();
      expect(backend.buffers, [1024]);
    },
  );

  test('repeated play starts one producer and one output', () async {
    await Future.wait([engine.start(), engine.start(), engine.start()]);
    expect(backend.starts, 1);
    backend.allowOneWrite();
    await settle();
    expect(backend.buffers, [1024]);
    expect(backend.waitCalls, 2); // One write plus one pending capacity wait.
  });

  test(
    'stop unblocks backpressure, and restart leaves no stale producer',
    () async {
      await engine.start();
      await engine.stop().timeout(const Duration(milliseconds: 250));
      await engine.start();
      backend.allowOneWrite();
      await settle();
      expect(backend.buffers, [1024]);
      expect(engine.generatedFrames, 1024);
    },
  );

  test('activation errors are observable, cleaned up, and retryable', () async {
    final errors = <Object>[];
    engine.onError = (error, _) => errors.add(error);
    backend.failActivation = true;
    await expectLater(engine.start(), throwsStateError);
    expect(backend.starts, 0);
    expect(engine.isPlaying, isFalse);
    expect(errors, hasLength(1));
    backend.failActivation = false;
    await engine.start();
    expect(engine.lastError, isNull);
    expect(engine.isPlaying, isTrue);
  });

  test('start errors do not poison the serialized queue', () async {
    backend.failStart = true;
    await expectLater(engine.start(), throwsStateError);
    expect(engine.lastError, isA<StateError>());
    expect(engine.isPlaying, isFalse);
    backend.failStart = false;
    await engine.start();
    expect(engine.isPlaying, isTrue);
  });

  test('producer failure is caught once and output can restart', () async {
    final errors = <Object>[];
    engine.onError = (error, _) => errors.add(error);
    backend.failWrite = true;
    await engine.start();
    backend.allowOneWrite();
    await settle();
    expect(errors, hasLength(1));
    expect(engine.isPlaying, isFalse);
    expect(backend.stops, greaterThan(0));
    backend.failWrite = false;
    await engine.start();
    backend.allowOneWrite();
    await settle();
    expect(backend.buffers, [1024]);
  });

  test('finite playback renders exact samples and waits for drain', () async {
    backend.freeCapacity = true;
    backend.drainBarrier = Completer<void>();
    final before = <int>[];
    final after = <int>[];
    var completed = 0;
    engine
      ..frameLimit = 1300
      ..beforeBuffer = before.add
      ..afterBuffer = after.add
      ..onPlaybackComplete = () {
        completed++;
      };
    await engine.start();
    await settle();
    expect(backend.buffers, [1024, 276]);
    expect(before, [0, 1024]);
    expect(after, [1024, 1300]);
    expect(engine.generatedFrames, 1300);
    expect(engine.playedFrames, 0);
    expect(engine.isPlaying, isTrue);
    expect(completed, 0);
    backend.drainBarrier!.complete();
    await settle();
    expect(engine.playedFrames, 1300);
    expect(engine.isPlaying, isFalse);
    expect(completed, 1);
  });

  test(
    'manual stop during drain does not emit completion or deadlock',
    () async {
      backend
        ..freeCapacity = true
        ..drainBarrier = Completer<void>();
      var completed = false;
      engine
        ..frameLimit = 100
        ..onPlaybackComplete = () {
          completed = true;
        };
      await engine.start();
      await settle();
      expect(backend.drainCalls, 1);
      await engine.stop().timeout(const Duration(milliseconds: 250));
      expect(engine.isPlaying, isFalse);
      expect(completed, isFalse);
    },
  );

  test('zero frame replay completes without generating audio', () async {
    engine.frameLimit = 0;
    var completed = false;
    engine.onPlaybackComplete = () {
      completed = true;
    };
    await engine.start();
    await settle();
    expect(backend.buffers, isEmpty);
    expect(completed, isTrue);
  });

  test(
    'a hook may stop at a buffer boundary without writing that buffer',
    () async {
      engine.beforeBuffer = (_) {
        engine.stop();
      };
      await engine.start();
      backend.allowOneWrite();
      await settle();
      expect(backend.buffers, isEmpty);
      expect(engine.generatedFrames, 0);
      expect(engine.isPlaying, isFalse);
    },
  );

  test('dispose closes output and the shared API remains reusable', () async {
    await engine.start();
    await engine.dispose();
    expect(backend.disposals, 1);
    await engine.start();
    expect(engine.isPlaying, isTrue);
  });

  test(
    'new play supersedes pending disposal without closing its activation',
    () async {
      backend.startBarrier = Completer<void>();
      final first = engine.start();
      await settle();
      final disposed = engine.dispose();
      final restarted = engine.start();
      backend.startBarrier!.complete();
      await Future.wait([first, disposed, restarted]);
      expect(engine.isPlaying, isTrue);
      expect(backend.disposals, 0);
      expect(backend.starts, 2);
    },
  );

  test('restoring oscillator phase state reproduces identical next PCM', () {
    final phase = engine.phaseState;
    final first = engine.generateBufferForTesting();
    engine.restorePhaseState(phase);
    final second = engine.generateBufferForTesting();
    expect(second, first);
  });
}
