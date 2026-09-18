import 'dart:async';
import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'neom_pcm_backend.dart';
import 'neom_pcm_schedule.dart';

NeomPcmBackend createNeomPcmBackend() => _WebPcmBackend();

/// Module-owned Web Audio output, avoiding flutter_sound_web's PCM worklet
/// queue. No generated JS asset, pub-cache patch, or per-app integration.
class _WebPcmBackend implements NeomPcmBackend {
  web.AudioContext? _context;
  final Set<web.AudioBufferSourceNode> _sources = {};
  Completer<void> _cancelled = Completer<void>()..complete();
  NeomPcmSchedule? _schedule;
  int _sampleRate = 44100;
  int _channels = 2;
  int _stoppedFrames = 0;

  bool get _active => !_cancelled.isCompleted;

  @override
  Future<void> init() async {} // AudioContext is created by a play gesture.

  @override
  Future<void> activate() {
    // Do not defer this call behind another await: Safari/iOS require the
    // initial context resume to originate from the user's play gesture.
    final context = _context ??= web.AudioContext(
      web.AudioContextOptions(latencyHint: 'interactive'.toJS),
    );
    return context.resume().toDart.then<void>((_) {});
  }

  @override
  Future<void> start({
    required int sampleRate,
    required int channels,
    required int framesPerBuffer,
  }) async {
    final context = _context;
    if (context == null || context.state != 'running') {
      throw StateError('Browser audio is suspended. Press play to enable it.');
    }
    _sampleRate = sampleRate;
    _channels = channels;
    _schedule = NeomPcmSchedule(sampleRate: sampleRate, leadSeconds: 0.004);
    _cancelled = Completer<void>();
    _stoppedFrames = 0;
  }

  Future<void> _wait(double seconds) async {
    if (seconds <= 0 || !_active) return;
    await Future.any<void>([
      Future<void>.delayed(Duration(microseconds: (seconds * 1000000).ceil())),
      _cancelled.future,
    ]);
  }

  void _verifyRunning() {
    if (_context?.state != 'running') {
      throw StateError('Browser suspended audio. Press play to resume.');
    }
  }

  @override
  Future<void> waitForCapacity(int frames) async {
    while (_active) {
      _verifyRunning();
      final wait = _schedule!.waitSeconds(_context!.currentTime, frames);
      if (wait <= 0) return;
      await _wait(wait);
    }
  }

  @override
  Future<void> write(Uint8List pcm) async {
    if (!_active) return;
    _verifyRunning();
    final context = _context!;
    final input = ByteData.sublistView(pcm);
    final frames = pcm.lengthInBytes ~/ (_channels * 2);
    final audio = context.createBuffer(_channels, frames, _sampleRate);
    for (var channel = 0; channel < _channels; channel++) {
      final samples = Float32List(frames);
      for (var frame = 0; frame < frames; frame++) {
        samples[frame] =
            input.getInt16((frame * _channels + channel) * 2, Endian.little) /
            32768;
      }
      audio.copyToChannel(samples.toJS, channel);
    }
    final start = _schedule!.reserve(context.currentTime, frames);
    final source = context.createBufferSource()..buffer = audio;
    source.connect(context.destination);
    source.onended = ((web.Event _) {
      source.disconnect();
      _sources.remove(source);
    }).toJS;
    _sources.add(source);
    source.start(start);
  }

  @override
  Future<void> drain() async {
    while (_active) {
      _verifyRunning();
      final wait = _schedule!.remainingSeconds(_context!.currentTime);
      if (wait <= 0) return;
      await _wait(wait);
    }
  }

  @override
  int get playedFrames => _active
      ? (_schedule?.playedFramesAt(_context!.currentTime) ?? 0)
      : _stoppedFrames;

  @override
  void interrupt() {
    if (_active) {
      _stoppedFrames = _schedule?.playedFramesAt(_context!.currentTime) ?? 0;
      _cancelled.complete();
    }
    // Drop the software queue immediately; do not play a tail after Stop.
    for (final source in _sources.toList()) {
      source.onended = null;
      try {
        source.stop();
      } catch (_) {
        /* Already ended. */
      }
      source.disconnect();
    }
    _sources.clear();
  }

  @override
  Future<void> stop() async {
    interrupt();
    // Keep the unlocked context reusable. No source remains connected.
  }

  @override
  Future<void> dispose() async {
    interrupt();
    final context = _context;
    _context = null;
    if (context != null && context.state != 'closed') {
      await context.close().toDart;
    }
  }
}
