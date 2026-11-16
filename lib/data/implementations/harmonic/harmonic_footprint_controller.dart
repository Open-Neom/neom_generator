import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:pitch_detector_dart/pitch_detector.dart';
import 'package:sint/sint.dart';

import '../../../domain/models/harmonic/harmonic_capture.dart';
import '../../../domain/models/harmonic/harmonic_footprint.dart';
import '../../../domain/use_cases/harmonic_footprint_service.dart';

/// SintController implementation of [HarmonicFootprintService].
///
/// Captures microphone audio via FlutterSoundRecorder, detects pitch via
/// pitch_detector_dart (autocorrelation), computes harmonic amplitudes via
/// simple DFT, and aggregates into [HarmonicFootprint].
/// Persists all data to a Hive box ('harmonic_footprint').
class HarmonicFootprintController extends SintController
    implements HarmonicFootprintService {
  static const String _hiveBox = 'harmonic_footprint';
  static const int _sampleRate = 44100;
  static const int _harmonicCount = 8;
  static const int _bytesPerSample = 2; // PCM16
  static const int _maxPcmBytes = _sampleRate * _bytesPerSample * 60; // 60s cap

  final Rxn<HarmonicFootprint> footprint = Rxn<HarmonicFootprint>();
  final RxBool isCapturing = false.obs;
  final RxBool isProcessing = false.obs;
  final Map<String, String> _memoryFallback = {};
  bool _disposed = false;

  final _captureStreamController =
      StreamController<HarmonicCapture>.broadcast();

  FlutterSoundRecorder? _recorder;
  bool _recorderOpened = false;
  Future<void>? _closingRecorderFuture;
  StreamController<Uint8List>? _audioStreamController;
  final List<int> _accumulatedPcm = [];

  static bool get _isMobilePlatform =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  static bool get _supportsFlutterSoundRecorder =>
      kIsWeb || _isMobilePlatform;

  Future<Box?> _openSafeBox() async {
    if (Hive.isBoxOpen(_hiveBox)) return Hive.box(_hiveBox);
    final completer = Completer<Box?>();
    runZonedGuarded(
      () async {
        try {
          final box = await Hive.openBox(_hiveBox);
          if (!completer.isCompleted) completer.complete(box);
        } catch (_) {
          if (!completer.isCompleted) completer.complete(null);
        }
      },
      (_, _) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    return completer.future;
  }

  @override
  HarmonicFootprint? get currentFootprint => footprint.value;

  @override
  Stream<HarmonicCapture> get captureStream => _captureStreamController.stream;

  @override
  void onInit() {
    super.onInit();
    _initRecorder();
  }

  @override
  void onClose() {
    _disposed = true;
    _captureStreamController.close();
    _audioStreamController?.close();
    _audioStreamController = null;
    unawaited(_closeRecorderSafely());
    footprint.close();
    isCapturing.close();
    isProcessing.close();
    super.onClose();
  }

  Future<void> _closeRecorderSafely() {
    return _closingRecorderFuture ??= () async {
      final recorder = _recorder;
      final wasOpened = _recorderOpened;
      _recorder = null;
      _recorderOpened = false;
      if (recorder == null || !wasOpened) return;
      try {
        if (recorder.isRecording) {
          await recorder.stopRecorder();
        }
      } catch (_) {}
      try {
        await recorder.closeRecorder();
      } catch (_) {}
    }();
  }

  Future<void> _initRecorder() async {
    if (_disposed || _recorderOpened || !_supportsFlutterSoundRecorder) return;
    try {
      if (_isMobilePlatform) {
        await Permission.microphone.request();
      }
      final recorder = _recorder ??= FlutterSoundRecorder();
      await recorder.openRecorder();
      if (_disposed) {
        await recorder.closeRecorder();
        return;
      }
      _recorderOpened = true;
    } on MissingPluginException catch (e) {
      debugPrint('[HarmonicFootprint] Recorder plugin unavailable: $e');
    } catch (e) {
      debugPrint('[HarmonicFootprint] Recorder init error: $e');
    }
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  @override
  Future<void> captureVoiceSample({
    Duration duration = const Duration(seconds: 5),
  }) async {
    if (_disposed || isCapturing.value || isProcessing.value) return;
    if (duration <= Duration.zero) return;
    if (!_recorderOpened) {
      await _initRecorder();
      if (!_recorderOpened || _disposed) return;
    }

    try {
      isCapturing.value = true;
      update();

      _accumulatedPcm.clear();

      // Set up audio stream
      await _audioStreamController?.close();
      _audioStreamController = StreamController<Uint8List>(sync: true);
      _audioStreamController!.stream.listen((data) {
        final remaining = _maxPcmBytes - _accumulatedPcm.length;
        if (remaining <= 0) return;
        if (data.length <= remaining) {
          _accumulatedPcm.addAll(data);
        } else {
          _accumulatedPcm.addAll(data.sublist(0, remaining));
        }
      });

      // Start recording PCM16 mono to stream
      await _recorder!.startRecorder(
        codec: Codec.pcm16,
        sampleRate: _sampleRate,
        numChannels: 1,
        toStream: _audioStreamController!.sink,
      );

      // Wait for the capture duration
      await Future.delayed(duration);

      // Stop recording
      if (_recorder != null && _recorderOpened) {
        await _recorder!.stopRecorder();
      }
      if (_disposed) return;

      isCapturing.value = false;
      isProcessing.value = true;
      update();

      // Convert PCM16 bytes to normalized doubles
      final samples = _pcmBytesToDoubles(_accumulatedPcm);

      // Process the captured audio
      final capture = await _processAudio(samples, duration.inMilliseconds);
      if (capture != null && !_disposed) {
        _addCaptureToFootprint(capture);
        if (!_captureStreamController.isClosed) {
          _captureStreamController.add(capture);
        }
        await _persist();
      }
    } catch (e) {
      debugPrint('[HarmonicFootprint] Capture error: $e');
    } finally {
      await _audioStreamController?.close();
      _audioStreamController = null;
      if (!_disposed) {
        isCapturing.value = false;
        isProcessing.value = false;
        update();
      }
    }
  }

  @override
  Future<void> loadFootprint(String userId) async {
    if (_disposed || userId.isEmpty) return;
    try {
      final box = await _openSafeBox();
      final stored = box != null ? box.get(userId) : _memoryFallback[userId];
      if (stored is String) {
        final json = Map<String, dynamic>.from(jsonDecode(stored) as Map);
        footprint.value = HarmonicFootprint.fromJson(json);
      } else {
        footprint.value = HarmonicFootprint(userId: userId);
      }
      if (!_disposed) update();
    } catch (e) {
      debugPrint('[HarmonicFootprint] Load error: $e');
      if (!_disposed) {
        footprint.value = HarmonicFootprint(userId: userId);
        update();
      }
    }
  }

  @override
  Future<void> clearFootprint() async {
    if (_disposed) return;
    final userId = footprint.value?.userId;
    if (userId != null) {
      footprint.value = HarmonicFootprint(userId: userId);
      final box = await _openSafeBox();
      if (box != null) {
        await box.delete(userId);
      } else {
        _memoryFallback.remove(userId);
      }
      if (!_disposed) update();
    }
  }

  // ---------------------------------------------------------------------------
  // Audio Processing Pipeline
  // ---------------------------------------------------------------------------

  List<double> _pcmBytesToDoubles(List<int> pcmBytes) {
    final byteData =
        ByteData.sublistView(Uint8List.fromList(pcmBytes));
    final samples = <double>[];
    for (int i = 0; i < byteData.lengthInBytes - 1; i += _bytesPerSample) {
      samples.add(byteData.getInt16(i, Endian.little) / 32768.0);
    }
    return samples;
  }

  Future<HarmonicCapture?> _processAudio(List<double> samples, int durationMs) async {
    if (samples.length < _sampleRate) return null; // Need at least 1 second

    // 1. Detect fundamental pitch
    final fundamentalHz = await _detectPitch(samples);
    if (fundamentalHz <= 0 || fundamentalHz > 2000) return null;

    // 2. Compute RMS volume (normalized 0-1)
    final rms = _computeRms(samples);
    final volumeDb = (rms * 3.0).clamp(0.0, 1.0);

    // 3. Compute DFT magnitudes
    final magnitudes = _computeDftMagnitudes(samples);

    // 4. Extract harmonic amplitudes relative to fundamental
    final harmonics = _extractHarmonics(magnitudes, fundamentalHz);

    // 5. Compute spectral centroid
    final spectralCentroid = _computeSpectralCentroid(magnitudes);

    // 6. Detect pitch range within the window (analyze sub-windows)
    final pitchRange = await _detectPitchRange(samples);

    final now = DateTime.now();
    return HarmonicCapture(
      id: '${now.millisecondsSinceEpoch}_${now.microsecond}',
      timestamp: now,
      fundamentalHz: fundamentalHz,
      volumeDb: volumeDb,
      harmonics: harmonics,
      spectralCentroid: spectralCentroid,
      pitchMin: pitchRange.$1,
      pitchMax: pitchRange.$2,
      durationMs: durationMs,
    );
  }

  /// Detect fundamental frequency via pitch_detector_dart (autocorrelation).
  Future<double> _detectPitch(List<double> samples) async {
    try {
      final windowSize = math.min(samples.length, _sampleRate);
      final start = (samples.length - windowSize) ~/ 2;
      final window = samples.sublist(start, start + windowSize);

      // Convert to PCM16 bytes for pitch_detector_dart
      final pcmBytes = Uint8List(window.length * _bytesPerSample);
      final byteData = ByteData.sublistView(pcmBytes);
      for (int i = 0; i < window.length; i++) {
        final v = window[i];
        final sample = v.isFinite ? (v * 32767).round().clamp(-32768, 32767) : 0;
        byteData.setInt16(i * _bytesPerSample, sample, Endian.little);
      }

      final detector = PitchDetector(
        audioSampleRate: _sampleRate.toDouble(),
        bufferSize: windowSize,
      );
      final result = await detector.getPitchFromIntBuffer(pcmBytes);
      return result.pitch > 0 ? result.pitch : 0;
    } catch (e) {
      debugPrint('[HarmonicFootprint] Pitch detection error: $e');
      return 0;
    }
  }

  /// Compute RMS (root mean square) of the audio signal.
  double _computeRms(List<double> samples) {
    double sum = 0;
    for (final s in samples) {
      sum += s * s;
    }
    return math.sqrt(sum / samples.length);
  }

  /// Simple DFT to compute magnitude spectrum.
  /// Only computes bins up to ~5000 Hz for performance.
  List<double> _computeDftMagnitudes(List<double> samples) {
    final n = math.min(samples.length, _sampleRate);
    final halfN = n ~/ 2;
    final magnitudes = List.filled(halfN, 0.0);

    final maxBin = math.min(halfN, (5000 * n / _sampleRate).ceil());

    for (int k = 1; k < maxBin; k++) {
      double realPart = 0;
      double imagPart = 0;
      final freq = 2 * math.pi * k / n;
      for (int i = 0; i < n; i++) {
        realPart += samples[i] * math.cos(freq * i);
        imagPart -= samples[i] * math.sin(freq * i);
      }
      magnitudes[k] =
          math.sqrt(realPart * realPart + imagPart * imagPart) / n;
    }

    return magnitudes;
  }

  /// Extract harmonic amplitudes at f, 2f, ... 8f relative to fundamental.
  List<double> _extractHarmonics(List<double> magnitudes, double fundamental) {
    final n = magnitudes.length * 2;
    final harmonics = <double>[];

    final fundamentalBin = (fundamental * n / _sampleRate).round();
    final fundamentalMag = _peakMagnitudeAround(magnitudes, fundamentalBin);

    if (fundamentalMag <= 0) return List.filled(_harmonicCount, 0.0);

    for (int h = 1; h <= _harmonicCount; h++) {
      final harmonicHz = fundamental * h;
      final bin = (harmonicHz * n / _sampleRate).round();
      final mag = _peakMagnitudeAround(magnitudes, bin);
      harmonics.add((mag / fundamentalMag).clamp(0.0, 1.0));
    }

    return harmonics;
  }

  /// Find the peak magnitude in a small window around [bin].
  double _peakMagnitudeAround(List<double> magnitudes, int bin) {
    double peak = 0;
    const window = 3;
    for (int i = math.max(0, bin - window);
        i <= math.min(magnitudes.length - 1, bin + window);
        i++) {
      if (magnitudes[i] > peak) peak = magnitudes[i];
    }
    return peak;
  }

  /// Compute spectral centroid (brightness indicator).
  double _computeSpectralCentroid(List<double> magnitudes) {
    double weightedSum = 0;
    double totalMag = 0;
    final n = magnitudes.length * 2;

    for (int k = 1; k < magnitudes.length; k++) {
      final freq = k * _sampleRate / n;
      weightedSum += freq * magnitudes[k];
      totalMag += magnitudes[k];
    }

    return totalMag > 0 ? weightedSum / totalMag : 0;
  }

  /// Detect pitch range by analyzing sub-windows of the audio.
  Future<(double, double)> _detectPitchRange(List<double> samples) async {
    const subWindowSeconds = 0.5;
    final subWindowSize = (_sampleRate * subWindowSeconds).round();
    double minPitch = double.infinity;
    double maxPitch = 0;

    for (int offset = 0;
        offset + subWindowSize <= samples.length;
        offset += subWindowSize) {
      final window = samples.sublist(offset, offset + subWindowSize);
      try {
        final pcmBytes = Uint8List(window.length * _bytesPerSample);
        final byteData = ByteData.sublistView(pcmBytes);
        for (int i = 0; i < window.length; i++) {
          final v = window[i];
          final sample = v.isFinite ? (v * 32767).round().clamp(-32768, 32767) : 0;
          byteData.setInt16(i * _bytesPerSample, sample, Endian.little);
        }

        final detector = PitchDetector(
          audioSampleRate: _sampleRate.toDouble(),
          bufferSize: subWindowSize,
        );
        final result = await detector.getPitchFromIntBuffer(pcmBytes);
        if (result.pitch > 50 && result.pitch < 2000) {
          if (result.pitch < minPitch) minPitch = result.pitch;
          if (result.pitch > maxPitch) maxPitch = result.pitch;
        }
      } catch (_) {}
    }

    if (minPitch == double.infinity) minPitch = 0;
    if (maxPitch == 0 && minPitch > 0) maxPitch = minPitch;

    return (minPitch, maxPitch);
  }

  // ---------------------------------------------------------------------------
  // Persistence
  // ---------------------------------------------------------------------------

  void _addCaptureToFootprint(HarmonicCapture capture) {
    footprint.value ??= HarmonicFootprint(userId: 'default');
    footprint.value!.addCapture(capture);
    update();
  }

  Future<void> _persist() async {
    final fp = footprint.value;
    if (fp == null) return;
    try {
      final encoded = jsonEncode(fp.toJson());
      final box = await _openSafeBox();
      if (box != null) {
        await box.put(fp.userId, encoded);
      } else {
        _memoryFallback[fp.userId] = encoded;
      }
    } catch (e) {
      debugPrint('[HarmonicFootprint] Persist error: $e');
    }
  }
}
