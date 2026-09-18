import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/engine/audio/neom_voice_capture.dart';
import 'package:neom_generator/engine/audio/neom_voice_pitch_measurement.dart';

class _Capture implements NeomVoiceCapture {
  _Capture({this.sampleRate = 48000, this.autoGrant = true});
  @override
  final int sampleRate;
  bool autoGrant;
  @override
  bool isActive = false;
  int stops = 0;
  int disposals = 0;
  int? activeRequest;
  final callbacks = <void Function(Uint8List)>[];
  final starts = <Completer<int>>[];
  final cancelled = <int>{};

  @override
  Future<int> start(void Function(Uint8List) onMonoPcm16) {
    final request = starts.length;
    callbacks.add(onMonoPcm16);
    starts.add(Completer<int>());
    activeRequest = request;
    if (autoGrant) grant(request);
    return starts[request].future;
  }

  void grant(int request) {
    if (cancelled.contains(request)) {
      starts[request].completeError(StateError('Cancelled microphone grant.'));
    } else {
      isActive = true;
      starts[request].complete(sampleRate);
    }
  }

  void emit(Uint8List pcm, {int? request}) =>
      callbacks[request ?? activeRequest!](pcm);

  @override
  Future<void> stop() async {
    stops++;
    if (activeRequest != null) cancelled.add(activeRequest!);
    activeRequest = null;
    isActive = false;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await stop();
  }
}

class _Outcome {
  _Outcome(Future<double?> future) {
    future.then(
      (value) {
        completed = true;
        pitch = value;
      },
      onError: (Object failure) {
        completed = true;
        error = failure;
      },
    );
  }
  bool completed = false;
  double? pitch;
  Object? error;
}

Uint8List _pcm(int count, double Function(int) sample) {
  final pcm = Uint8List(count * 2);
  final bytes = ByteData.sublistView(pcm);
  for (var i = 0; i < count; i++) {
    bytes.setInt16(
      i * 2,
      (sample(i) * 32767).round().clamp(-32768, 32767),
      Endian.little,
    );
  }
  return pcm;
}

void _tone(
  FakeAsync clock,
  _Capture capture,
  double hz, {
  int windows = 24,
  int? request,
  bool fragmented = false,
}) {
  for (var frame = 0; frame < windows; frame++) {
    final pcm = _pcm(
      2048,
      (i) =>
          .3 *
          math.sin(2 * math.pi * hz * (frame * 2048 + i) / capture.sampleRate),
    );
    if (fragmented) {
      final padded = Uint8List(pcm.length + 5)
        ..setRange(3, pcm.length + 3, pcm);
      capture.emit(Uint8List.sublistView(padded, 3, 8), request: request);
      capture.emit(
        Uint8List.sublistView(padded, 8, pcm.length + 3),
        request: request,
      );
    } else {
      capture.emit(pcm, request: request);
    }
    clock.flushMicrotasks();
  }
}

void main() {
  test(
    'PCM16 decoder preserves signed little-endian samples and byte views',
    () {
      final pcm = Uint8List.fromList([
        99,
        99,
        0,
        128,
        255,
        255,
        0,
        0,
        255,
        127,
        99,
      ]);
      expect(decodeMonoPcm16(Uint8List.sublistView(pcm, 2, 10)), [
        -1.0,
        -1 / 32768,
        0.0,
        32767 / 32768,
      ]);
      expect(() => decodeMonoPcm16(Uint8List(1)), throwsFormatException);
    },
  );

  for (final rate in [44100, 48000]) {
    for (final hz in [110.0, 220.0, 440.0]) {
      test(
        'measures actual $hz Hz PCM at $rate Hz and releases at five seconds',
        () {
          fakeAsync((clock) {
            final capture = _Capture(sampleRate: rate);
            final service = VoicePitchMeasurement(capture: capture);
            expect(capture.starts, isEmpty);
            final live = <double>[];
            final result = _Outcome(service.measure(onPitch: live.add));
            clock.flushMicrotasks();
            _tone(clock, capture, hz);
            expect(live, isNotEmpty);
            expect(live.every((pitch) => (pitch - hz).abs() < .6), isTrue);
            clock.elapse(const Duration(milliseconds: 4999));
            expect(result.completed, isFalse);
            expect(capture.isActive, isTrue);
            clock.elapse(const Duration(milliseconds: 1));
            clock.flushMicrotasks();
            expect(result.error, isNull);
            expect(result.pitch, closeTo(hz, .6));
            expect(capture.isActive, isFalse);
            expect(capture.stops, 1);
            expect(clock.pendingTimers, isEmpty);
          });
        },
      );
    }
  }

  test(
    'fractional pitch survives decoding split samples, outliers, and aggregation',
    () {
      fakeAsync((clock) {
        final capture = _Capture();
        final service = VoicePitchMeasurement(capture: capture);
        final result = _Outcome(service.measure(onPitch: (_) {}));
        clock.flushMicrotasks();
        _tone(clock, capture, 223.37, windows: 24, fragmented: true);
        _tone(clock, capture, 440, windows: 3);
        clock.elapse(const Duration(seconds: 5));
        expect(result.pitch, closeTo(223.37, .1));
        expect(result.pitch, isNot(result.pitch!.roundToDouble()));
      });
    },
  );

  for (final kind in ['silence', 'noise', 'dc', 'quiet']) {
    test('rejects $kind without a fabricated live or final pitch', () {
      fakeAsync((clock) {
        final capture = _Capture();
        final service = VoicePitchMeasurement(capture: capture);
        final live = <double>[];
        final result = _Outcome(service.measure(onPitch: live.add));
        clock.flushMicrotasks();
        final random = math.Random(729);
        for (var frame = 0; frame < 24; frame++) {
          capture.emit(
            _pcm(
              2048,
              (i) => switch (kind) {
                'noise' => (random.nextDouble() * 2 - 1) * .3,
                'dc' => .3,
                'quiet' =>
                  .002 * math.sin(2 * math.pi * 220 * i / capture.sampleRate),
                _ => 0,
              },
            ),
          );
          clock.flushMicrotasks();
        }
        clock.elapse(const Duration(seconds: 5));
        expect(result.completed, isTrue);
        expect(result.error, isNull);
        expect(result.pitch, isNull);
        expect(live, isEmpty);
        expect(capture.isActive, isFalse);
      });
    });
  }

  test('rejects voiced input with no stable dominant pitch', () {
    fakeAsync((clock) {
      final capture = _Capture();
      final service = VoicePitchMeasurement(capture: capture);
      final result = _Outcome(service.measure(onPitch: (_) {}));
      clock.flushMicrotasks();
      for (final hz in [110.0, 170.0, 220.0, 290.0, 370.0, 440.0]) {
        _tone(clock, capture, hz, windows: 4);
      }
      clock.elapse(const Duration(seconds: 5));
      expect(result.pitch, isNull);
      expect(result.error, isNull);
    });
  });

  test('requires substantial voiced audio, not a brief tone among silence', () {
    fakeAsync((clock) {
      final capture = _Capture();
      final service = VoicePitchMeasurement(capture: capture);
      final result = _Outcome(service.measure(onPitch: (_) {}));
      clock.flushMicrotasks();
      _tone(clock, capture, 220, windows: 3);
      for (var i = 0; i < 24; i++) {
        capture.emit(Uint8List(4096));
      }
      clock.flushMicrotasks();
      clock.elapse(const Duration(seconds: 5));
      expect(result.pitch, isNull);
    });
  });

  test(
    'permission waiting does not consume the five second capture window',
    () {
      fakeAsync((clock) {
        final capture = _Capture(autoGrant: false);
        final service = VoicePitchMeasurement(capture: capture);
        final result = _Outcome(service.measure(onPitch: (_) {}));
        clock.elapse(const Duration(seconds: 10));
        expect(capture.stops, 0);
        expect(result.completed, isFalse);
        capture.grant(0);
        clock.flushMicrotasks();
        _tone(clock, capture, 220);
        clock.elapse(const Duration(milliseconds: 4999));
        expect(capture.isActive, isTrue);
        expect(result.completed, isFalse);
        clock.elapse(const Duration(milliseconds: 1));
        expect(capture.isActive, isFalse);
        expect(result.pitch, closeTo(220, .6));
      });
    },
  );

  test(
    'permission timeout releases the request and retry ignores a late grant',
    () {
      fakeAsync((clock) {
        final capture = _Capture(autoGrant: false);
        final service = VoicePitchMeasurement(capture: capture);
        final first = _Outcome(
          service.measure(onPitch: (_) => fail('Timed out callback')),
        );
        clock.elapse(const Duration(seconds: 15));
        expect(first.error, isA<TimeoutException>());
        expect(capture.stops, 1);
        final second = _Outcome(service.measure(onPitch: (_) {}));
        capture.grant(1);
        clock.flushMicrotasks();
        capture.grant(0);
        clock.flushMicrotasks();
        expect(capture.isActive, isTrue);
        expect(capture.stops, 1);
        _tone(clock, capture, 440);
        clock.elapse(const Duration(seconds: 5));
        expect(second.pitch, closeTo(440, .6));
      });
    },
  );

  test('cancel and restart reject old PCM and stale permission results', () {
    fakeAsync((clock) {
      final capture = _Capture(autoGrant: false);
      final service = VoicePitchMeasurement(capture: capture);
      final first = _Outcome(
        service.measure(onPitch: (_) => fail('Cancelled callback')),
      );
      service.cancel();
      clock.flushMicrotasks();
      expect(first.completed, isTrue);
      expect(first.pitch, isNull);
      final second = _Outcome(service.measure(onPitch: (_) {}));
      capture.grant(1);
      clock.flushMicrotasks();
      _tone(clock, capture, 110, request: 0);
      capture.grant(0);
      clock.flushMicrotasks();
      expect(capture.isActive, isTrue);
      _tone(clock, capture, 220);
      clock.elapse(const Duration(seconds: 5));
      expect(second.pitch, closeTo(220, .6));
      expect(capture.stops, 2);
    });
  });

  test(
    'new measurement cancels current analysis and late callbacks cannot stop it',
    () {
      fakeAsync((clock) {
        final capture = _Capture();
        final service = VoicePitchMeasurement(capture: capture);
        var oldCallbacks = 0;
        final first = _Outcome(service.measure(onPitch: (_) => oldCallbacks++));
        clock.flushMicrotasks();
        capture.emit(
          _pcm(2048, (i) => .3 * math.sin(2 * math.pi * 110 * i / 48000)),
        );
        final second = _Outcome(service.measure(onPitch: (_) {}));
        clock.flushMicrotasks();
        expect(first.pitch, isNull);
        expect(first.completed, isTrue);
        expect(oldCallbacks, 0);
        _tone(clock, capture, 440, request: 0);
        expect(capture.isActive, isTrue);
        _tone(clock, capture, 220);
        clock.elapse(const Duration(seconds: 5));
        expect(second.pitch, closeTo(220, .6));
      });
    },
  );

  test(
    'permission denial propagates and a subsequent measurement can succeed',
    () {
      fakeAsync((clock) {
        final capture = _Capture(autoGrant: false);
        final service = VoicePitchMeasurement(capture: capture);
        final first = _Outcome(service.measure(onPitch: (_) {}));
        capture.starts[0].completeError(StateError('Permission denied'));
        clock.flushMicrotasks();
        expect(first.error, isStateError);
        expect(capture.stops, 1);
        final second = _Outcome(service.measure(onPitch: (_) {}));
        capture.grant(1);
        clock.flushMicrotasks();
        _tone(clock, capture, 110);
        clock.elapse(const Duration(seconds: 5));
        expect(second.pitch, closeTo(110, .6));
      });
    },
  );

  test('dispose cancels pending permission and prevents restart', () {
    fakeAsync((clock) {
      final capture = _Capture(autoGrant: false);
      final service = VoicePitchMeasurement(capture: capture);
      final result = _Outcome(
        service.measure(onPitch: (_) => fail('Disposed callback')),
      );
      service.dispose();
      clock.flushMicrotasks();
      capture.grant(0);
      clock.flushMicrotasks();
      final rejected = _Outcome(service.measure(onPitch: (_) {}));
      clock.flushMicrotasks();
      expect(result.completed, isTrue);
      expect(result.pitch, isNull);
      expect(rejected.error, isStateError);
      expect(capture.isActive, isFalse);
      expect(capture.disposals, 1);
      service.dispose();
      clock.flushMicrotasks();
      expect(capture.disposals, 1);
      expect(clock.pendingTimers, isEmpty);
    });
  });

  test('live callback failures release the microphone and propagate', () {
    fakeAsync((clock) {
      final capture = _Capture();
      final service = VoicePitchMeasurement(capture: capture);
      final result = _Outcome(
        service.measure(onPitch: (_) => throw StateError('UI failed')),
      );
      clock.flushMicrotasks();
      _tone(clock, capture, 220, windows: 3);
      expect(result.error, isStateError);
      expect(capture.isActive, isFalse);
      expect(clock.pendingTimers, isEmpty);
    });
  });
}
