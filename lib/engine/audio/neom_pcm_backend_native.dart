import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:logger/logger.dart' show Level;
import 'package:neom_sound/data/implementations/soloud_realtime_pcm_sink.dart';

import 'neom_pcm_backend.dart';
import 'neom_pcm_schedule.dart';

NeomPcmBackend createNeomPcmBackend() => _NativePcmBackend();

/// Native PCM16 output backend for [NeomSineEngine].
///
/// Primary path (`flutter_soloud` 5.3+ via [SoLoudRealtimePcmSink]):
/// - Uses SoLoud's lock-free SPSC `RealtimeStream` + FFI `RealtimeNativeBuffer`
///   across Android, iOS, macOS, Windows, and Linux with zero `MethodChannel`
///   allocations, 64-frame raised-cosine underrun protection, safety limiter,
///   and 8-band parametric EQ integration.
///
/// Fallback path:
/// - Falls back to `FlutterSoundPlayer` on mobile or deterministic software
///   scheduling (`NeomPcmSchedule`) when no native audio hardware is available
///   (e.g. headless CI / `flutter test`).
class _NativePcmBackend implements NeomPcmBackend {
  final SoLoudRealtimePcmSink _soloudSink = SoLoudRealtimePcmSink();
  bool _soloudAvailable = !Platform.environment.containsKey('FLUTTER_TEST');
  bool _usingSoloud = false;

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
    // SoLoud realtime stream opens lazily in start() with exact sampleRate /
    // channel count so construction and init() remain side-effect free in tests.
  }

  Future<void> _initFallbackPlayer() async {
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
    _usingSoloud = false;
    if (_soloudAvailable) {
      final opened = await _soloudSink.open(
        sampleRate: sampleRate,
        channels: channels,
        framesPerBuffer: framesPerBuffer,
      );
      if (opened) {
        _usingSoloud = true;
      } else {
        _soloudAvailable = false;
      }
    }

    if (!_usingSoloud) {
      await _initFallbackPlayer();
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
      if (_usingSoloud && _soloudSink.isOpen) {
        // Also respect hardware ring-buffer backpressure if host audio stalls.
        if (_soloudSink.availableToWrite < frames) {
          await _wait(frames / (_schedule?.sampleRate ?? 44100) * 0.5);
          continue;
        }
      }
      final wait = _schedule!.waitSeconds(_now, frames);
      if (wait <= 0) return;
      await _wait(wait);
    }
  }

  @override
  Future<void> write(Uint8List pcm) async {
    if (!_active) return;
    final frames = pcm.lengthInBytes ~/ (_channels * 2);
    if (frames <= 0) return;
    _schedule!.reserve(_now, frames);

    if (_usingSoloud && _soloudSink.isOpen) {
      _soloudSink.pushPcm16Bytes(pcm);
      return;
    }

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
    if (_usingSoloud) {
      _usingSoloud = false;
      await _soloudSink.close();
      return;
    }
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
    await _soloudSink.close();
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
