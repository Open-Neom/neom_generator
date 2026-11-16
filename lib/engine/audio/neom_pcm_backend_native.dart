import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;

import 'neom_pcm_backend.dart';
import 'neom_pcm_schedule.dart';

NeomPcmBackend createNeomPcmBackend() => _NativePcmBackend();

class _NativePcmBackend implements NeomPcmBackend {
  FlutterSoundPlayer? _player;
  bool _pluginAvailable = true;
  final Stopwatch _clock = Stopwatch();
  Completer<void> _cancelled = Completer<void>()..complete();
  NeomPcmSchedule? _schedule;
  int _channels = 2;
  int _stoppedFrames = 0;

  static bool get _isDesktopPlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.macOS ||
          defaultTargetPlatform == TargetPlatform.windows ||
          defaultTargetPlatform == TargetPlatform.linux);

  double get _now => _clock.elapsedMicroseconds / 1000000;
  bool get _active => !_cancelled.isCompleted;

  @override
  Future<void> init() async {
    if (_isDesktopPlatform || !_pluginAvailable) {
      _pluginAvailable = false;
      return;
    }
    try {
      final player = _player ??= FlutterSoundPlayer(logLevel: Level.off);
      if (!player.isOpen()) {
        await player.openPlayer();
      }
    } on MissingPluginException {
      _pluginAvailable = false;
    } on PlatformException {
      _pluginAvailable = false;
    } catch (_) {
      _pluginAvailable = false;
    }
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
    if (_pluginAvailable && _player != null) {
      try {
        await _player!.startPlayerFromStream(
          codec: Codec.pcm16,
          numChannels: channels,
          sampleRate: sampleRate,
          interleaved: true,
          bufferSize: framesPerBuffer * channels * 2,
        );
      } on MissingPluginException {
        _pluginAvailable = false;
      } on PlatformException {
        _pluginAvailable = false;
      }
    }
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
    if (!_pluginAvailable || _player == null) return;
    // Stop can unblock this wait even when a plugin feed callback is pending.
    await Future.any<void>([
      _player!
          .feedUint8FromStream(pcm)
          .then<void>((_) {})
          .catchError((Object error) {
            if (error is MissingPluginException || error is PlatformException) {
              _pluginAvailable = false;
            }
          }),
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
    final player = _player;
    if (_pluginAvailable && player != null && player.isOpen() && player.isPlaying) {
      try {
        await player.stopPlayer();
      } on MissingPluginException {
        _pluginAvailable = false;
      } on PlatformException {
        _pluginAvailable = false;
      }
    }
  }

  @override
  Future<void> dispose() async {
    await stop();
    final player = _player;
    _player = null;
    if (_pluginAvailable && player != null && player.isOpen()) {
      try {
        await player.closePlayer();
      } on MissingPluginException {
        _pluginAvailable = false;
      } on PlatformException {
        _pluginAvailable = false;
      }
    }
  }
}
