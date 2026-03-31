import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';

import '../../domain/models/incienso.dart';

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
/// // On every frame/tick (~1 Hz):
/// recorder.captureKeyframe(
///   leftHz: 200, rightHz: 210,
///   coherence: 0.85, volume: 0.7,
///   neuroState: NeomNeuroState.calm,
///   breathPhase: 0.6,
/// );
///
/// // When user manually changes something:
/// recorder.captureKeyframe(..., isUserAction: true);
///
/// // On stop:
/// final incienso = recorder.stopAndBuild(name: 'Mi meditación nocturna');
/// ```
class InciensoRecorder extends ChangeNotifier {
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
      ? DateTime.now().difference(_startedAt!)
      : Duration.zero;

  /// Start recording a new Incienso.
  void startRecording() {
    _keyframes.clear();
    _isRecording = true;
    _startedAt = DateTime.now();

    // Auto-sample at 1 Hz for consistent timeline
    _sampleTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (_isRecording) {
        _addKeyframe(isUserAction: false);
      }
    });

    // Capture initial state immediately
    _addKeyframe(isUserAction: false);
    notifyListeners();
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
    if (!_isRecording) return;
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

  void _addKeyframe({required bool isUserAction}) {
    if (_startedAt == null) return;

    final elapsed = DateTime.now().difference(_startedAt!);
    _keyframes.add(InciensoKeyframe(
      timestampMs: elapsed.inMilliseconds.toDouble(),
      leftHz: _lastLeftHz,
      rightHz: _lastRightHz,
      coherence: _lastCoherence,
      volume: _lastVolume,
      neuroState: _lastState.name,
      breathPhase: _lastBreathPhase,
      visualExperience: _lastVisual,
      isUserAction: isUserAction,
    ));
  }

  /// Stop recording and build the [Incienso] preset.
  ///
  /// Returns null if no keyframes were captured or recording was too short.
  Incienso? stopAndBuild({
    required String name,
    String? description,
    String? creatorId,
    List<String> tags = const [],
  }) {
    _isRecording = false;
    _sampleTimer?.cancel();
    _sampleTimer = null;

    if (_keyframes.length < 5) return null; // Too short to be useful
    if (_startedAt == null) return null;

    final duration = DateTime.now().difference(_startedAt!);
    if (duration.inSeconds < 30) return null; // Minimum 30 seconds

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
      id: 'rec_${DateTime.now().millisecondsSinceEpoch}',
      names: {'es': name, 'en': name},
      descriptions: description != null
          ? {'es': description, 'en': description}
          : {},
      leftFrequencyHz: first.leftHz,
      rightFrequencyHz: first.rightHz,
      suggestedDuration: duration,
      timeline: List.unmodifiable(_keyframes),
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
