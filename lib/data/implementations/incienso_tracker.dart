import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';

/// Tracks INCIENSO count in real-time during a Cámara Neom session.
///
/// Listens to breath cycle events and coherence readings.
/// Each qualifying cycle (coherence ≥ threshold) increments the count.
///
/// Usage:
/// ```dart
/// final tracker = InciensoTracker();
/// tracker.start();
/// // On each breath cycle completion:
/// tracker.onBreathCycle(coherence: 0.85);
/// // Read current count:
/// print(tracker.inciensoCount); // qualifying cycles
/// print(tracker.totalCycles);   // all cycles
/// tracker.stop();
/// ```
class InciensoTracker extends ChangeNotifier {
  /// Minimum coherence to qualify as 1 INCIENSO.
  static const double coherenceThreshold = 0.70;

  // ── Counters ──
  int _inciensoCount = 0;
  int _totalCycles = 0;
  double _coherenceSum = 0.0;
  double _peakCoherence = 0.0;
  double _minCoherence = 1.0;
  final List<double> _coherenceReadings = [];

  // ── State ──
  bool _isTracking = false;
  DateTime? _startedAt;
  final Map<NeomNeuroState, int> _stateTimeSeconds = {};
  NeomNeuroState _currentState = NeomNeuroState.neutral;
  int _stateTransitions = 0;
  Timer? _stateTimer;

  // ── Breath metrics ──
  final List<double> _cycleDurationsMs = [];
  DateTime? _lastCycleTime;

  // ── Public getters ──

  /// Qualifying breath cycles (coherence ≥ 70%).
  int get inciensoCount => _inciensoCount;

  /// Total breath cycles detected.
  int get totalCycles => _totalCycles;

  /// Quality ratio: qualifying / total.
  double get qualityRatio =>
      _totalCycles > 0 ? _inciensoCount / _totalCycles : 0.0;

  /// Average coherence across all readings.
  double get avgCoherence =>
      _coherenceReadings.isNotEmpty
          ? _coherenceSum / _coherenceReadings.length
          : 0.0;

  /// Peak coherence reached.
  double get peakCoherence => _peakCoherence;

  /// Minimum coherence during session.
  double get minCoherence =>
      _minCoherence > 1.0 ? 0.0 : _minCoherence;

  /// Coherence standard deviation.
  double get coherenceStdDev {
    if (_coherenceReadings.length < 2) return 0.0;
    final mean = avgCoherence;
    final sumSquaredDiffs = _coherenceReadings.fold<double>(
        0.0, (sum, v) => sum + (v - mean) * (v - mean));
    return (sumSquaredDiffs / _coherenceReadings.length).clamp(0.0, 1.0);
  }

  /// Average breath cycle duration in ms.
  double get avgBreathCycleMs {
    if (_cycleDurationsMs.isEmpty) return 0.0;
    return _cycleDurationsMs.reduce((a, b) => a + b) / _cycleDurationsMs.length;
  }

  /// Coefficient of variation of breath cycles.
  double get breathCV {
    if (_cycleDurationsMs.length < 3) return 0.5;
    final mean = avgBreathCycleMs;
    if (mean == 0) return 0.5;
    final sumSqDiffs = _cycleDurationsMs.fold<double>(
        0.0, (sum, v) => sum + (v - mean) * (v - mean));
    final stdDev =
        (sumSqDiffs / _cycleDurationsMs.length);
    return (stdDev / mean).clamp(0.0, 2.0);
  }

  /// Whether currently tracking.
  bool get isTracking => _isTracking;

  /// When tracking started.
  DateTime? get startedAt => _startedAt;

  /// Time spent per neuro state (seconds).
  Map<NeomNeuroState, int> get stateTimeMap =>
      Map.unmodifiable(_stateTimeSeconds);

  /// Number of state transitions.
  int get stateTransitions => _stateTransitions;

  /// Most time-spent state.
  NeomNeuroState get dominantState {
    if (_stateTimeSeconds.isEmpty) return NeomNeuroState.neutral;
    return _stateTimeSeconds.entries
        .reduce((a, b) => a.value >= b.value ? a : b)
        .key;
  }

  /// Coherence timeline for charts: [secondsFromStart, coherenceValue].
  List<List<double>> get coherenceTimeline {
    if (_startedAt == null) return [];
    // Downsample to 1 reading per second max
    return _coherenceReadings.asMap().entries.map((e) =>
        [e.key.toDouble(), e.value]).toList();
  }

  // ── Lifecycle ──

  /// Start tracking a new session.
  void start() {
    _reset();
    _isTracking = true;
    _startedAt = DateTime.now();

    // Track time per state every second
    _stateTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _stateTimeSeconds[_currentState] =
          (_stateTimeSeconds[_currentState] ?? 0) + 1;
    });

    notifyListeners();
  }

  /// Stop tracking.
  void stop() {
    _isTracking = false;
    _stateTimer?.cancel();
    _stateTimer = null;
    notifyListeners();
  }

  /// Reset all counters.
  void _reset() {
    _inciensoCount = 0;
    _totalCycles = 0;
    _coherenceSum = 0.0;
    _peakCoherence = 0.0;
    _minCoherence = 1.0;
    _coherenceReadings.clear();
    _cycleDurationsMs.clear();
    _lastCycleTime = null;
    _stateTimeSeconds.clear();
    _currentState = NeomNeuroState.neutral;
    _stateTransitions = 0;
  }

  // ── Events ──

  /// Call when a complete breath cycle is detected.
  /// [coherence] is the hemispheric coherence at cycle completion (0.0–1.0).
  void onBreathCycle({required double coherence}) {
    if (!_isTracking) return;

    _totalCycles++;
    _coherenceReadings.add(coherence);
    _coherenceSum += coherence;

    if (coherence > _peakCoherence) _peakCoherence = coherence;
    if (coherence < _minCoherence) _minCoherence = coherence;

    // Track cycle duration
    final now = DateTime.now();
    if (_lastCycleTime != null) {
      _cycleDurationsMs.add(
          now.difference(_lastCycleTime!).inMilliseconds.toDouble());
    }
    _lastCycleTime = now;

    // Qualifying cycle?
    if (coherence >= coherenceThreshold) {
      _inciensoCount++;
    }

    notifyListeners();
  }

  /// Call when a coherence reading is available (continuous, not just on cycles).
  void onCoherenceReading(double coherence) {
    if (!_isTracking) return;
    _coherenceReadings.add(coherence);
    _coherenceSum += coherence;
    if (coherence > _peakCoherence) _peakCoherence = coherence;
    if (coherence < _minCoherence) _minCoherence = coherence;
  }

  /// Call when the neuro state changes.
  void onStateChanged(NeomNeuroState newState) {
    if (!_isTracking) return;
    if (newState != _currentState) {
      _stateTransitions++;
      _currentState = newState;
    }
  }

  @override
  void dispose() {
    _stateTimer?.cancel();
    super.dispose();
  }
}
