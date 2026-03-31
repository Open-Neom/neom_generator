import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';

import 'incienso.dart';

/// Records all data from a single practice of an [Incienso] preset.
///
/// Captures audio parameters, biofeedback metrics, visual experience context,
/// and user state throughout the session. Persisted to Hive locally and
/// synced to Firestore for logged-in users.
///
/// Analogous to NupaleSession (EMXI) and CaseteSession (Gigmeout).
class InciensoSession {
  /// Unique session identifier.
  final String id;

  /// User ID (null for guest sessions — migrated on account creation).
  final String? userId;

  /// The Incienso preset that was practiced.
  final String inciensoId;

  /// Source type of the incienso.
  final InciensoSource inciensoSource;

  // ── Timing ──

  /// When the session started (user pressed Start).
  final DateTime startedAt;

  /// When the session ended (completed, stopped, or interrupted).
  final DateTime endedAt;

  /// Actual duration of practice.
  Duration get duration => endedAt.difference(startedAt);

  /// Suggested duration from the Incienso preset.
  final Duration suggestedDuration;

  /// Whether the user completed the full suggested duration.
  bool get completed => duration >= suggestedDuration;

  /// Completion ratio (0.0–1.0+, can exceed 1.0 if user went overtime).
  double get completionRatio =>
      suggestedDuration.inSeconds > 0
          ? duration.inSeconds / suggestedDuration.inSeconds
          : 0.0;

  // ── Audio Parameters ──

  /// User's detected root vocal frequency (Hz). 0 if not detected.
  final double rootFrequencyHz;

  /// Carrier frequency for left ear (Hz).
  final double carrierLeftHz;

  /// Carrier frequency for right ear (Hz).
  final double carrierRightHz;

  /// Binaural beat = |right - left|.
  double get binauralBeatHz => (carrierRightHz - carrierLeftHz).abs();

  /// Volume level used (0.0–1.0).
  final double volume;

  /// Whether isochronic tones were active.
  final bool isochronicEnabled;

  /// Isochronic frequency if enabled.
  final double isochronicHz;

  // ── INCIENSO Core Metrics ──

  /// Total respiratory cycles detected during session.
  final int totalBreathCycles;

  /// Qualifying cycles (coherence ≥ 70%).
  /// THIS is the INCIENSO count.
  final int inciensoCount;

  /// Quality ratio = inciensoCount / totalBreathCycles.
  double get qualityRatio =>
      totalBreathCycles > 0 ? inciensoCount / totalBreathCycles : 0.0;

  /// Weighted score for rankings: (count × avgCoherence × minutes) / 10.
  double get inciensoScore =>
      (inciensoCount * avgCoherence * duration.inMinutes) / 10.0;

  // ── Coherence Metrics ──

  /// Mean hemispheric coherence across session (0.0–1.0).
  final double avgCoherence;

  /// Peak coherence reached.
  final double peakCoherence;

  /// Minimum coherence during session.
  final double minCoherence;

  /// Standard deviation of coherence (stability indicator).
  final double coherenceStdDev;

  /// Coherence samples over time (for charting).
  /// Each entry: [secondsFromStart, coherenceValue].
  final List<List<double>> coherenceTimeline;

  // ── Breath Metrics ──

  /// Average breath cycle duration in milliseconds.
  final double avgBreathCycleMs;

  /// Coefficient of variation of breath cycles (stability).
  final double breathCV;

  /// Breaths per minute (average).
  double get breathsPerMinute =>
      avgBreathCycleMs > 0 ? 60000.0 / avgBreathCycleMs : 0.0;

  // ── Neuro State Tracking ──

  /// Most frequent neuro state during session.
  final NeomNeuroState dominantState;

  /// Time spent in each neuro state (in seconds).
  final Map<String, int> stateTimeSeconds;

  /// Number of state transitions during session.
  final int stateTransitions;

  // ── Phase Tracking (multi-phase inciensos) ──

  /// Phases completed (for multi-phase inciensos).
  final int phasesCompleted;

  /// Total phases in the incienso.
  final int phasesTotal;

  // ── Experience Context ──

  /// Visual experience used during session (null = photic pulse only).
  final InciensoVisual? visualExperience;

  /// Whether breathing guide was active.
  final bool breathingGuideActive;

  /// Whether spatial audio was enabled.
  final bool spatialAudioEnabled;

  /// Neuro state used for visual modulation.
  final String? neuroStateOverride;

  // ── Environment ──

  /// Platform: 'web', 'ios', 'android', 'macos', 'windows', 'linux'.
  final String platform;

  /// Whether headphones were detected/used.
  final bool headphonesDetected;

  /// Whether session was in a Room (shared/social).
  final String? roomId;

  /// Number of participants in room (1 = solo).
  final int participantCount;

  // ── User Feedback (post-session) ──

  /// Emotion selected after session (emoji key).
  final String? emotionAfter;

  /// Optional 1-5 star rating.
  final int? rating;

  /// Free-text note from user.
  final String? note;

  // ── Session State ──

  /// How the session ended.
  final InciensoSessionEnd endReason;

  /// Whether this session was interrupted (phone call, app background, etc.).
  bool get wasInterrupted => endReason == InciensoSessionEnd.interrupted;

  const InciensoSession({
    required this.id,
    this.userId,
    required this.inciensoId,
    this.inciensoSource = InciensoSource.predefined,
    required this.startedAt,
    required this.endedAt,
    required this.suggestedDuration,
    // Audio
    this.rootFrequencyHz = 0.0,
    this.carrierLeftHz = 200.0,
    this.carrierRightHz = 210.0,
    this.volume = 0.7,
    this.isochronicEnabled = false,
    this.isochronicHz = 0.0,
    // INCIENSO metrics
    this.totalBreathCycles = 0,
    this.inciensoCount = 0,
    // Coherence
    this.avgCoherence = 0.0,
    this.peakCoherence = 0.0,
    this.minCoherence = 0.0,
    this.coherenceStdDev = 0.0,
    this.coherenceTimeline = const [],
    // Breath
    this.avgBreathCycleMs = 0.0,
    this.breathCV = 0.0,
    // Neuro state
    this.dominantState = NeomNeuroState.neutral,
    this.stateTimeSeconds = const {},
    this.stateTransitions = 0,
    // Phases
    this.phasesCompleted = 0,
    this.phasesTotal = 1,
    // Experience
    this.visualExperience,
    this.breathingGuideActive = false,
    this.spatialAudioEnabled = false,
    this.neuroStateOverride,
    // Environment
    this.platform = 'web',
    this.headphonesDetected = false,
    this.roomId,
    this.participantCount = 1,
    // Feedback
    this.emotionAfter,
    this.rating,
    this.note,
    // State
    this.endReason = InciensoSessionEnd.completed,
  });

  /// Quality tier based on qualityRatio.
  InciensoQualityTier get qualityTier {
    if (qualityRatio >= 0.80) return InciensoQualityTier.master;
    if (qualityRatio >= 0.50) return InciensoQualityTier.practitioner;
    return InciensoQualityTier.explorer;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    if (userId != null) 'userId': userId,
    'inciensoId': inciensoId,
    'inciensoSource': inciensoSource.name,
    'startedAt': startedAt.millisecondsSinceEpoch,
    'endedAt': endedAt.millisecondsSinceEpoch,
    'suggestedDuration': suggestedDuration.inSeconds,
    // Audio
    'rootFrequencyHz': rootFrequencyHz,
    'carrierLeftHz': carrierLeftHz,
    'carrierRightHz': carrierRightHz,
    'volume': volume,
    'isochronicEnabled': isochronicEnabled,
    'isochronicHz': isochronicHz,
    // INCIENSO
    'totalBreathCycles': totalBreathCycles,
    'inciensoCount': inciensoCount,
    // Coherence
    'avgCoherence': avgCoherence,
    'peakCoherence': peakCoherence,
    'minCoherence': minCoherence,
    'coherenceStdDev': coherenceStdDev,
    'coherenceTimeline': coherenceTimeline.map((e) => e.toList()).toList(),
    // Breath
    'avgBreathCycleMs': avgBreathCycleMs,
    'breathCV': breathCV,
    // Neuro state
    'dominantState': dominantState.name,
    'stateTimeSeconds': stateTimeSeconds,
    'stateTransitions': stateTransitions,
    // Phases
    'phasesCompleted': phasesCompleted,
    'phasesTotal': phasesTotal,
    // Experience
    if (visualExperience != null) 'visualExperience': visualExperience!.name,
    'breathingGuideActive': breathingGuideActive,
    'spatialAudioEnabled': spatialAudioEnabled,
    if (neuroStateOverride != null) 'neuroStateOverride': neuroStateOverride,
    // Environment
    'platform': platform,
    'headphonesDetected': headphonesDetected,
    if (roomId != null) 'roomId': roomId,
    'participantCount': participantCount,
    // Feedback
    if (emotionAfter != null) 'emotionAfter': emotionAfter,
    if (rating != null) 'rating': rating,
    if (note != null) 'note': note,
    // State
    'endReason': endReason.name,
  };

  factory InciensoSession.fromJson(Map<String, dynamic> json) {
    return InciensoSession(
      id: json['id'] as String? ?? '',
      userId: json['userId'] as String?,
      inciensoId: json['inciensoId'] as String? ?? '',
      inciensoSource: InciensoSource.values.firstWhere(
        (s) => s.name == json['inciensoSource'],
        orElse: () => InciensoSource.predefined,
      ),
      startedAt: DateTime.fromMillisecondsSinceEpoch(
          json['startedAt'] as int? ?? 0),
      endedAt: DateTime.fromMillisecondsSinceEpoch(
          json['endedAt'] as int? ?? 0),
      suggestedDuration: Duration(
          seconds: json['suggestedDuration'] as int? ?? 600),
      // Audio
      rootFrequencyHz:
          (json['rootFrequencyHz'] as num?)?.toDouble() ?? 0.0,
      carrierLeftHz:
          (json['carrierLeftHz'] as num?)?.toDouble() ?? 200.0,
      carrierRightHz:
          (json['carrierRightHz'] as num?)?.toDouble() ?? 210.0,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.7,
      isochronicEnabled: json['isochronicEnabled'] as bool? ?? false,
      isochronicHz:
          (json['isochronicHz'] as num?)?.toDouble() ?? 0.0,
      // INCIENSO
      totalBreathCycles: json['totalBreathCycles'] as int? ?? 0,
      inciensoCount: json['inciensoCount'] as int? ?? 0,
      // Coherence
      avgCoherence:
          (json['avgCoherence'] as num?)?.toDouble() ?? 0.0,
      peakCoherence:
          (json['peakCoherence'] as num?)?.toDouble() ?? 0.0,
      minCoherence:
          (json['minCoherence'] as num?)?.toDouble() ?? 0.0,
      coherenceStdDev:
          (json['coherenceStdDev'] as num?)?.toDouble() ?? 0.0,
      coherenceTimeline: (json['coherenceTimeline'] as List?)
          ?.map((e) => (e as List).map((v) => (v as num).toDouble()).toList())
          .toList() ?? [],
      // Breath
      avgBreathCycleMs:
          (json['avgBreathCycleMs'] as num?)?.toDouble() ?? 0.0,
      breathCV: (json['breathCV'] as num?)?.toDouble() ?? 0.0,
      // Neuro state
      dominantState: NeomNeuroState.values.firstWhere(
        (s) => s.name == json['dominantState'],
        orElse: () => NeomNeuroState.neutral,
      ),
      stateTimeSeconds:
          Map<String, int>.from(json['stateTimeSeconds'] as Map? ?? {}),
      stateTransitions: json['stateTransitions'] as int? ?? 0,
      // Phases
      phasesCompleted: json['phasesCompleted'] as int? ?? 0,
      phasesTotal: json['phasesTotal'] as int? ?? 1,
      // Experience
      visualExperience: json['visualExperience'] != null
          ? InciensoVisual.values.firstWhere(
              (v) => v.name == json['visualExperience'],
              orElse: () => InciensoVisual.photonicPulse,
            )
          : null,
      breathingGuideActive:
          json['breathingGuideActive'] as bool? ?? false,
      spatialAudioEnabled:
          json['spatialAudioEnabled'] as bool? ?? false,
      neuroStateOverride: json['neuroStateOverride'] as String?,
      // Environment
      platform: json['platform'] as String? ?? 'web',
      headphonesDetected:
          json['headphonesDetected'] as bool? ?? false,
      roomId: json['roomId'] as String?,
      participantCount: json['participantCount'] as int? ?? 1,
      // Feedback
      emotionAfter: json['emotionAfter'] as String?,
      rating: json['rating'] as int?,
      note: json['note'] as String?,
      // State
      endReason: InciensoSessionEnd.values.firstWhere(
        (e) => e.name == json['endReason'],
        orElse: () => InciensoSessionEnd.completed,
      ),
    );
  }

  @override
  String toString() =>
      'InciensoSession(id=$id, incienso=$inciensoId, '
      'duration=${duration.inMinutes}min, '
      'incienso=$inciensoCount/$totalBreathCycles '
      '(${(qualityRatio * 100).toStringAsFixed(0)}%), '
      'coherence=${avgCoherence.toStringAsFixed(2)}, '
      'tier=${qualityTier.name})';
}

/// How a session ended.
enum InciensoSessionEnd {
  /// User completed the full suggested duration.
  completed,

  /// User manually stopped early.
  stoppedByUser,

  /// App went to background / phone call / etc.
  interrupted,

  /// Timer expired (for timed sessions).
  timerExpired,
}

/// Quality tier based on qualityRatio.
enum InciensoQualityTier {
  /// < 50% qualifying cycles.
  explorer,

  /// 50-79% qualifying cycles.
  practitioner,

  /// ≥ 80% qualifying cycles.
  master;

  String get nameKeyEs => switch (this) {
    explorer => 'Explorador',
    practitioner => 'Practicante',
    master => 'Maestro',
  };

  String get nameKeyEn => switch (this) {
    explorer => 'Explorer',
    practitioner => 'Practitioner',
    master => 'Master',
  };

  int get stars => switch (this) {
    explorer => 1,
    practitioner => 2,
    master => 3,
  };
}
