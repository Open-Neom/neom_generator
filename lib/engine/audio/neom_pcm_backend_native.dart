import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;

import 'neom_pcm_backend.dart';
import 'neom_pcm_schedule.dart';

NeomPcmBackend createNeomPcmBackend() => _NativePcmBackend();

class _NativePcmBackend implements NeomPcmBackend {
  final FlutterSoundPlayer _player = FlutterSoundPlayer(logLevel: Level.off);
  final Stopwatch _clock = Stopwatch();
  Completer<void> _cancelled = Completer<void>()..complete();
  NeomPcmSchedule? _schedule;
  int _channels = 2;
  int _stoppedFrames = 0;

  double get _now => _clock.elapsedMicroseconds / 1000000;
  bool get _active => !_cancelled.isCompleted;

  @override
  Future<void> init() async {
    if (!_player.isOpen()) await _player.openPlayer();
  }

  @override
  Future<void> activate() async {}

  @override
  Future<void> start({
    required int sampleRate,
    required int channels,
    required int framesPerBuffer,
  }) async {
    await init();
    await _player.startPlayerFromStream(
      codec: Codec.pcm16,
      numChannels: channels,
      sampleRate: sampleRate,
      interleaved: true,
      bufferSize: framesPerBuffer * channels * 2,
    );
    _channels = channels;
    _schedule = NeomPcmSchedule(sampleRate: sampleRate);
    _stoppedFrames = 0;
    _cancelled = Completer<void>();
    _clock
      ..reset()
      ..start();
  }

  Future<void> _wait(double seconds) async {
    if (seconds <= 0 || !_active) return;
    await Future.any<void>([
      Future<void>.delayed(Duration(microseconds: (seconds * 1000000).ceil())),
      _cancelled.future,
    ]);
  }

  @override
  Future<void> waitForCapacity(int frames) async {
    while (_active) {
      final wait = _schedule!.waitSeconds(_now, frames);
      if (wait <= 0) return;
      await _wait(wait);
    }
  }

  @override
  Future<void> write(Uint8List pcm) async {
    if (!_active) return;
    _schedule!.reserve(_now, pcm.lengthInBytes ~/ (_channels * 2));
    // Stop can unblock this wait even when a plugin feed callback is pending.
    await Future.any<void>([
      _player.feedUint8FromStream(pcm).then<void>((_) {}),
      _cancelled.future,
    ]);
  }

  @override
  Future<void> drain() async {
    while (_active) {
      final wait = _schedule!.remainingSeconds(_now);
      if (wait <= 0) return;
      await _wait(wait);
    }
  }

  @override
  int get playedFrames =>
      _active ? (_schedule?.playedFramesAt(_now) ?? 0) : _stoppedFrames;

  @override
  void interrupt() {
    if (!_active) return;
    _stoppedFrames = _schedule?.playedFramesAt(_now) ?? 0;
    _cancelled.complete();
    _clock.stop();
  }

  @override
  Future<void> stop() async {
    interrupt();
    if (_player.isOpen() && _player.isPlaying) await _player.stopPlayer();
  }

  @override
  Future<void> dispose() async {
    await stop();
    if (_player.isOpen()) await _player.closePlayer();
  }
}
