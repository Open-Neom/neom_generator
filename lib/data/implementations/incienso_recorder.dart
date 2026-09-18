import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';

import '../../domain/models/incienso.dart';
import '../../domain/models/incienso_audio_state.dart';

/// Records a live Cámara Neom session into a shareable [Incienso].
///
/// Captures keyframes at ~1 Hz sampling rate, recording the frequency
/// journey, coherence, breathing, and state changes. The resulting
/// [Incienso] can be "played back" by others to follow the same
/// frequency path.
///
/// Usage:
/// ```dart
/// final recorder = InciensoRecorder();
/// recorder.startRecording();
///
/// // On every frame/tick: keep the recorder's view of the session current.
/// // It samples these on its own timer at ~1 Hz.
/// recorder.updateValues(
///   leftHz: 200, rightHz: 210,
///   coherence: 0.85, volume: 0.7,
///   neuroState: NeomNeuroState.calm,
///   breathPhase: 0.6,
/// );
///
/// // When the user changes something, capture it immediately.
/// recorder.captureUserAction(leftHz: 220);
///
/// // On stop:
/// final incienso = recorder.stopAndBuild(name: 'Mi meditación nocturna');
/// ```
class InciensoRecorder extends ChangeNotifier {
  InciensoRecorder({Duration Function()? elapsed}) : _elapsedOverride = elapsed;
  final Duration Function()? _elapsedOverride;
  final Stopwatch _clock = Stopwatch();
  Duration _audioElapsed = Duration.zero;
  bool _audioClockMode = false;
  int _sampleRate = 44100;
  int _sampleFrame = 0;
  int _lastMetadataFrame = 0;
  InciensoAudioState? _lastAudioState;
  final List<InciensoKeyframe> _keyframes = [];
  bool _isRecording = false;
  DateTime? _startedAt;
  Timer? _sampleTimer;

  // Last known values for auto-sampling
  double _lastLeftHz = 200.0;
  double _lastRightHz = 210.0;
  double _lastCoherence = 0.0;
  double _lastVolume = 0.7;
  NeomNeuroState _lastState = NeomNeuroState.neutral;
  double _lastBreathPhase = 0.0;
  String? _lastVisual;

  /// Whether currently recording.
  bool get isRecording => _isRecording;

  /// Number of keyframes captured so far.
  int get keyframeCount => _keyframes.length;

  /// Recording duration so far.
  Duration get recordingDuration => _startedAt != null
      ? (_audioClockMode
            ? _audioElapsed
            : (_elapsedOverride?.call() ?? _clock.elapsed))
      : Duration.zero;

  /// Start recording a new Incienso.
  void startRecording({
    InciensoAudioState? initialState,
    bool audioClock = false,
    int sampleRate = 44100,
  }) {
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _clock
      ..reset()
      ..start();
    _audioClockMode = audioClock;
    _sampleRate = sampleRate;
    _sampleFrame = 0;
    _lastMetadataFrame = 0;
    _audioElapsed = Duration.zero;
    _lastLeftHz = 200;
    _lastRightHz = 210;
    _lastVolume = .7;
    _lastCoherence = 0;
    _lastState = NeomNeuroState.neutral;
    _lastBreathPhase = 0;
    _lastVisual = null;
    _lastAudioState = initialState;
    if (initialState != null) _cacheState(initialState);
    _keyframes.clear();
    _isRecording = true;
    _startedAt = DateTime.now();

    // Auto-sample at 1 Hz for consistent timeline
    if (!audioClock) {
      _sampleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
        if (_isRecording) {
          _addKeyframe(isUserAction: false);
        }
      });
    }

    // Capture initial state immediately
    _addKeyframe(isUserAction: false, audioState: initialState);
    notifyListeners();
  }

  void _cacheState(InciensoAudioState state) {
    final carrier = state.number('carrierHz', 432);
    final multi = state.flag('multi', false);
    _lastLeftHz = multi ? state.number('leftHz', carrier) : carrier;
    _lastRightHz = multi
        ? state.number('rightHz', carrier)
        : carrier + state.number('beatHz', 0);
    _lastVolume = state.number('volume', .5);
    _lastState = NeomNeuroState.values.firstWhere(
      (v) => v.name == state.text('neuroState', 'neutral'),
      orElse: () => NeomNeuroState.neutral,
    );
    _lastVisual = state.parameters['visualExperience'] as String?;
  }

  /// Called at an audio buffer boundary, independently of rendering frames.
  /// Full snapshots are stored only on changes, avoiding ~1KB per second of
  /// redundant oscillator state in long sessions. Metadata remains at 1 Hz.
  void captureAudioFrame(
    InciensoAudioState state,
    int frame, {
    double coherence = 0,
    double breathPhase = 0,
  }) {
    if (!_isRecording || !_audioClockMode) return;
    advanceAudioClock(frame);
    final changed =
        _lastAudioState == null || !_lastAudioState!.sameParameters(state);
    _cacheState(state);
    _lastCoherence = coherence;
    _lastBreathPhase = breathPhase;
    if (changed || frame - _lastMetadataFrame >= _sampleRate) {
      _addKeyframe(isUserAction: changed, audioState: changed ? state : null);
      _lastMetadataFrame = frame;
    }
    _lastAudioState = state;
  }

  void advanceAudioClock(int frame) {
    if (!_isRecording || !_audioClockMode) return;
    _sampleFrame = frame;
    _audioElapsed = Duration(
      microseconds: (frame * 1000000 / _sampleRate).round(),
    );
  }

  /// Update current values (called frequently from generator controller).
  /// Does NOT create a keyframe — the timer handles that at 1 Hz.
  void updateValues({
    double? leftHz,
    double? rightHz,
    double? coherence,
    double? volume,
    NeomNeuroState? neuroState,
    double? breathPhase,
    String? visualExperience,
  }) {
    if (leftHz != null) _lastLeftHz = leftHz;
    if (rightHz != null) _lastRightHz = rightHz;
    if (coherence != null) _lastCoherence = coherence;
    if (volume != null) _lastVolume = volume;
    if (neuroState != null) _lastState = neuroState;
    if (breathPhase != null) _lastBreathPhase = breathPhase;
    if (visualExperience != null) _lastVisual = visualExperience;
  }

  /// Manually capture a keyframe (e.g., user changed frequency or state).
  /// This adds an extra keyframe beyond the 1 Hz auto-sampling.
  void captureUserAction({
    double? leftHz,
    double? rightHz,
    double? coherence,
    double? volume,
    NeomNeuroState? neuroState,
    double? breathPhase,
    String? visualExperience,
  }) {
    if (!_isRecording || _audioClockMode) return;
    updateValues(
      leftHz: leftHz,
      rightHz: rightHz,
      coherence: coherence,
      volume: volume,
      neuroState: neuroState,
      breathPhase: breathPhase,
      visualExperience: visualExperience,
    );
    _addKeyframe(isUserAction: true);
  }

  void _addKeyframe({
    required bool isUserAction,
    InciensoAudioState? audioState,
  }) {
    if (_startedAt == null) return;

    final elapsed = recordingDuration;
    _keyframes.add(
      InciensoKeyframe(
        timestampMs: elapsed.inMicroseconds / 1000,
        leftHz: _lastLeftHz,
        rightHz: _lastRightHz,
        coherence: _lastCoherence,
        volume: _lastVolume,
        neuroState: _lastState.name,
        breathPhase: _lastBreathPhase,
        visualExperience: _lastVisual,
        isUserAction: isUserAction,
        audioState: audioState,
        sampleFrame: _audioClockMode ? _sampleFrame : null,
      ),
    );
  }

  /// Stop recording and build the [Incienso] preset.
  ///
  /// Returns null if no keyframes were captured or recording was too short.
  /// Minimum material for a session worth keeping.
  static const int minKeyframes = 5;
  static const Duration minDuration = Duration(seconds: 30);

  /// Whether [stopAndBuild] would return a session rather than null.
  ///
  /// Lets a caller offer to save without having to stop the recording first
  /// to find out.
  bool get hasEnoughToBuild {
    if (_keyframes.length < minKeyframes) return false;
    final startedAt = _startedAt;
    if (startedAt == null) return false;
    return recordingDuration >= minDuration;
  }

  Incienso? stopAndBuild({
    required String name,
    String? description,
    String? creatorId,
    List<String> tags = const [],
    int? endFrame,
  }) {
    if (!_isRecording) return null;
    if (_audioClockMode && endFrame != null) {
      advanceAudioClock(endFrame.clamp(0, _sampleFrame));
      _keyframes.removeWhere((f) => (f.sampleFrame ?? 0) > _sampleFrame);
      // Discard parameter changes still queued, not yet heard at stop.
      if (_keyframes.isNotEmpty) {
        final tail = _keyframes.last;
        _lastLeftHz = tail.leftHz;
        _lastRightHz = tail.rightHz;
        _lastVolume = tail.volume;
        _lastCoherence = tail.coherence;
        _lastBreathPhase = tail.breathPhase;
        _lastState = NeomNeuroState.values.firstWhere(
          (v) => v.name == tail.neuroState,
          orElse: () => NeomNeuroState.neutral,
        );
        _lastVisual = tail.visualExperience;
      }
    }
    _addKeyframe(isUserAction: false);
    _isRecording = false;
    _clock.stop();
    _sampleTimer?.cancel();
    _sampleTimer = null;

    if (_keyframes.length < minKeyframes) return null; // Too short to be useful
    if (_startedAt == null) return null;

    final duration = recordingDuration;
    if (duration < minDuration) return null;

    // Derive initial frequencies from first keyframe
    final first = _keyframes.first;
    final _ = _keyframes.last;

    // Find dominant visual experience
    final visualCounts = <String, int>{};
    for (final kf in _keyframes) {
      if (kf.visualExperience != null) {
        visualCounts[kf.visualExperience!] =
            (visualCounts[kf.visualExperience!] ?? 0) + 1;
      }
    }
    InciensoVisual? dominantVisual;
    if (visualCounts.isNotEmpty) {
      final topVisual = visualCounts.entries
          .reduce((a, b) => a.value >= b.value ? a : b)
          .key;
      dominantVisual = InciensoVisual.values
          .where((v) => v.name == topVisual)
          .firstOrNull;
    }

    // Average coherence for metadata
    final avgCoherence = _keyframes.isNotEmpty
        ? _keyframes.fold<double>(0.0, (sum, kf) => sum + kf.coherence) /
              _keyframes.length
        : 0.0;

    final incienso = Incienso(
      id: 'rec_${DateTime.now().microsecondsSinceEpoch}',
      names: {'es': name, 'en': name},
      descriptions: description != null
          ? {'es': description, 'en': description}
          : {},
      leftFrequencyHz: first.leftHz,
      rightFrequencyHz: first.rightHz,
      suggestedDuration: duration,
      timeline: List.unmodifiable(_keyframes),
      recordingVersion: _audioClockMode && _lastAudioState != null ? 2 : 1,
      sampleRate: _sampleRate,
      defaultVisual: dominantVisual,
      source: InciensoSource.userCreated,
      creatorId: creatorId,
      tags: tags,
      avgQualityRatio: avgCoherence,
    );

    notifyListeners();
    return incienso;
  }

  /// Cancel recording without building.
  void cancel() {
    _isRecording = false;
    _clock
      ..stop()
      ..reset();
    _sampleTimer?.cancel();
    _sampleTimer = null;
    _keyframes.clear();
    _startedAt = null;
    notifyListeners();
  }

  /// Get a preview of the frequency range explored.
  ({double minBeat, double maxBeat, int userActions}) get preview {
    if (_keyframes.isEmpty) return (minBeat: 0, maxBeat: 0, userActions: 0);
    double minB = double.infinity, maxB = 0;
    int actions = 0;
    for (final kf in _keyframes) {
      final beat = kf.beatHz;
      if (beat < minB) minB = beat;
      if (beat > maxB) maxB = beat;
      if (kf.isUserAction) actions++;
    }
    return (minBeat: minB, maxBeat: maxB, userActions: actions);
  }

  @override
  void dispose() {
    _sampleTimer?.cancel();
    super.dispose();
  }
}
