import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:pitch_detector_dart/pitch_detector.dart';

import 'neom_voice_capture.dart';

/// Signed, little-endian mono PCM16, including views with a nonzero offset.
///
/// Decode explicitly: pitch_detector_dart 0.0.7's integer-buffer conversion
/// does not preserve signed little-endian samples. No audio is persisted.
Float64List decodeMonoPcm16(Uint8List pcm) {
  if (pcm.length.isOdd) {
    throw const FormatException('PCM16 requires complete two-byte samples.');
  }
  final bytes = ByteData.sublistView(pcm);
  return Float64List.fromList([
    for (var offset = 0; offset < pcm.length; offset += 2)
      bytes.getInt16(offset, Endian.little) / 32768.0,
  ]);
}

/// A short, explicitly requested microphone measurement, with no playback,
/// recording files, remote writes, or synthetic fallback frequency.
///
/// The default web capture owns its microphone session. Native callers can
/// supply a native [NeomVoiceCapture]; the default native adapter is unsupported.
/// [measure] returns null on cancellation or insufficient stable voiced audio.
/// Capture/permission failures propagate to the caller. A new measurement
/// cancels the previous one; late results cannot stop or update its replacement.
class VoicePitchMeasurement {
  VoicePitchMeasurement({
    NeomVoiceCapture? capture,
    this.measurementDuration = const Duration(seconds: 5),
    this.permissionTimeout = const Duration(seconds: 15),
  }) : _capture = capture ?? createNeomVoiceCapture() {
    if (measurementDuration <= Duration.zero ||
        permissionTimeout <= Duration.zero) {
      throw ArgumentError(
        'Measurement and permission durations must be positive.',
      );
    }
  }

  final Duration measurementDuration;
  final Duration permissionTimeout;
  final NeomVoiceCapture _capture;
  _PitchMeasurement? _current;
  Future<void> _lastStop = Future<void>.value();
  Future<void>? _disposing;
  bool _disposed = false;

  Future<double?> measure({required void Function(double) onPitch}) {
    if (_disposed) {
      return Future<double?>.error(
        StateError('Voice measurement is disposed.'),
      );
    }
    final previous = _current;
    if (previous != null) unawaited(_finish(previous));
    final session = _PitchMeasurement(onPitch);
    _current = session;
    session.permissionTimer = Timer(permissionTimeout, () {
      unawaited(
        _finish(
          session,
          error: TimeoutException(
            'Microphone permission or setup timed out.',
            permissionTimeout,
          ),
        ),
      );
    });

    // Invoke start synchronously from the caller's gesture. stop() invalidates
    // the previous adapter session synchronously, before any new start.
    try {
      final started = _capture.start((pcm) => _acceptPcm(session, pcm));
      unawaited(
        started.then<void>(
          (sampleRate) {
            if (!_isCurrent(session)) return;
            if (sampleRate <= 0) {
              unawaited(
                _finish(
                  session,
                  error: StateError('Invalid microphone sample rate.'),
                ),
              );
              return;
            }
            session.permissionTimer?.cancel();
            session.sampleRate = sampleRate;
            session.detector = PitchDetector(
              audioSampleRate: sampleRate.toDouble(),
              bufferSize: _PitchMeasurement.windowSamples,
            );
            // Permission waiting is not part of the five seconds of measurement.
            session.measurementTimer = Timer(measurementDuration, () {
              unawaited(_finish(session, result: session.stablePitch()));
            });
          },
          onError: (Object error, StackTrace stack) {
            // The capture adapter releases late grants for cancelled sessions.
            // Calling stop here for a stale start would stop the new microphone.
            if (_isCurrent(session)) {
              unawaited(_finish(session, error: error, stack: stack));
            }
          },
        ),
      );
    } catch (error, stack) {
      unawaited(_finish(session, error: error, stack: stack));
    }
    return session.result.future;
  }

  bool _isCurrent(_PitchMeasurement session) =>
      identical(_current, session) && !session.closed && !_disposed;

  void _acceptPcm(_PitchMeasurement session, Uint8List pcm) {
    if (!_isCurrent(session) || session.detector == null || pcm.isEmpty) return;
    // Preserve a sample split across callbacks without reading outside a view.
    var complete = pcm;
    if (session.trailingByte != null) {
      complete = Uint8List(pcm.length + 1)
        ..[0] = session.trailingByte!
        ..setRange(1, pcm.length + 1, pcm);
      session.trailingByte = null;
    }
    if (complete.length.isOdd) {
      session.trailingByte = complete.last;
      complete = Uint8List.sublistView(complete, 0, complete.length - 1);
    }
    session.samples.addAll(decodeMonoPcm16(complete));
    // Bound queued memory if a device delivers audio faster than it is analysed.
    // Keep complete sample alignment and prefer the most recent signal.
    const maxQueuedSamples = _PitchMeasurement.windowSamples * 8;
    if (session.samples.length > maxQueuedSamples) {
      session.samples.removeRange(0, session.samples.length - maxQueuedSamples);
    }
    if (!session.processing) unawaited(_analyse(session));
  }

  Future<void> _analyse(_PitchMeasurement session) async {
    session.processing = true;
    try {
      while (_isCurrent(session) &&
          session.samples.length >= _PitchMeasurement.windowSamples) {
        final window = session.samples.sublist(
          0,
          _PitchMeasurement.windowSamples,
        );
        session.samples.removeRange(0, _PitchMeasurement.windowSamples);
        session.analysedWindows++;
        // Remove DC before both RMS gating and YIN. A constant input is silence.
        final mean = window.reduce((a, b) => a + b) / window.length;
        var power = 0.0;
        for (var i = 0; i < window.length; i++) {
          window[i] -= mean;
          power += window[i] * window[i];
        }
        if (math.sqrt(power / window.length) < .008) {
          session.recentPitches.clear();
          continue;
        }
        final detected = await session.detector!.getPitchFromFloatBuffer(
          window,
        );
        if (!_isCurrent(session)) return;
        final hz = detected.pitch;
        if (!detected.pitched ||
            !detected.probability.isFinite ||
            detected.probability < .9 ||
            !hz.isFinite ||
            hz < 65 ||
            hz > 1000) {
          session.recentPitches.clear();
          continue;
        }
        session.pitches.add(hz);
        session.recentPitches.add(hz);
        if (session.recentPitches.length > 5) session.recentPitches.removeAt(0);
        if (session.recentPitches.length >= 3) {
          final live = _median(session.recentPitches);
          if (session.recentPitches.every(
            (pitch) => (pitch / live - 1).abs() <= .04,
          )) {
            session.onPitch(live);
          }
        }
      }
    } catch (error, stack) {
      if (_isCurrent(session)) {
        await _finish(session, error: error, stack: stack);
      }
    } finally {
      session.processing = false;
    }
  }

  Future<void> _finish(
    _PitchMeasurement session, {
    double? result,
    Object? error,
    StackTrace? stack,
  }) {
    if (session.closed) return session.stopped ?? Future<void>.value();
    session.closed = true;
    session.permissionTimer?.cancel();
    session.measurementTimer?.cancel();
    session.samples.clear();
    session.trailingByte = null;
    if (!identical(_current, session)) return Future<void>.value();
    _current = null;
    // Calling stop, not awaiting a previous start, releases active tracks now
    // and makes the adapter close any late permission grant for this session.
    Future<void> stop;
    try {
      stop = _capture.stop();
    } catch (stopError, stopStack) {
      error ??= stopError;
      stack ??= stopStack;
      stop = Future<void>.value();
    }
    final failure = error;
    final failureStack = stack;
    return session.stopped = _lastStop = stop.then<void>(
      (_) {
        if (failure != null) {
          session.result.completeError(
            failure,
            failureStack ?? StackTrace.current,
          );
        } else {
          session.result.complete(result);
        }
      },
      onError: (Object stopError, StackTrace stopStack) {
        session.result.completeError(
          failure ?? stopError,
          failureStack ?? stopStack,
        );
      },
    );
  }

  Future<void> cancel() {
    final session = _current;
    return session == null ? _lastStop : _finish(session);
  }

  Future<void> dispose() {
    if (_disposing != null) return _disposing!;
    _disposed = true;
    return _disposing = cancel().then((_) => _capture.dispose());
  }
}

class _PitchMeasurement {
  _PitchMeasurement(this.onPitch);
  static const windowSamples = 2048;
  final void Function(double) onPitch;
  final result = Completer<double?>();
  final samples = <double>[];
  final pitches = <double>[];
  final recentPitches = <double>[];
  Timer? permissionTimer;
  Timer? measurementTimer;
  Future<void>? stopped;
  PitchDetector? detector;
  int sampleRate = 0;
  int analysedWindows = 0;
  int? trailingByte;
  bool processing = false;
  bool closed = false;

  double? stablePitch() {
    // Require at least 400 ms of stable audio, a majority of voiced estimates,
    // and enough of the actual analysed signal to reject isolated noise peaks.
    final minimumWindows = math.max(
      8,
      (sampleRate * .4 / windowSamples).ceil(),
    );
    if (pitches.length < minimumWindows) return null;
    final centre = _median(pitches);
    final stable = pitches
        .where((pitch) => (pitch / centre - 1).abs() <= .03)
        .toList();
    if (stable.length < minimumWindows ||
        stable.length < pitches.length * .65 ||
        stable.length < analysedWindows * .15) {
      return null;
    }
    return _median(stable);
  }
}

double _median(List<double> values) {
  final ordered = [...values]..sort();
  final middle = ordered.length ~/ 2;
  return ordered.length.isOdd
      ? ordered[middle]
      : (ordered[middle - 1] + ordered[middle]) / 2;
}
