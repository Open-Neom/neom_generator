import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';

/// INCIENSO — Inducción Cíclica de Enfoque Sostenido
///
/// A preset/template that configures the Cámara Neom for a specific
/// neuro-harmonic induction practice. Analogous to a "book" in EMXI
/// or an "album" in Gigmeout — the content definition, not the session.
///
/// Predefined Inciensos come from [FrequencyState] (13 states) and
/// [ParProtocolCatalog] (9 protocols). Users can also create custom ones.
class Incienso {
  /// Unique identifier.
  final String id;

  /// Display name per locale.
  final Map<String, String> names;

  /// Description per locale.
  final Map<String, String> descriptions;

  /// Left ear carrier frequency in Hz.
  final double leftFrequencyHz;

  /// Right ear carrier frequency in Hz.
  final double rightFrequencyHz;

  /// Computed binaural beat = |right - left|.
  double get binauralBeatHz => (rightFrequencyHz - leftFrequencyHz).abs();

  /// Target neuro state derived from the binaural beat.
  NeomNeuroState get targetState =>
      NeomNeuroState.fromBinauralBeatHz(binauralBeatHz);

  /// Suggested duration for this practice.
  final Duration suggestedDuration;

  /// Multi-phase frequency descent/ascent steps (empty = single phase).
  /// Used by predefined/protocol inciensos with discrete transitions.
  final List<InciensoPhase> phases;

  /// Whether this is a single-phase or multi-phase incienso.
  bool get isMultiPhase => phases.length > 1;

  /// Recorded frequency timeline — the full journey of frequency changes.
  /// Each keyframe captures a moment: [secondsFromStart, leftHz, rightHz, coherence].
  /// Used by user-recorded inciensos to reproduce the exact frequency exploration.
  /// Predefined inciensos use [phases] instead; recorded ones use this.
  final List<InciensoKeyframe> timeline;

  /// Whether this incienso was recorded from a live session (vs manually configured).
  bool get isRecorded => timeline.isNotEmpty;

  /// Total duration derived from timeline (if recorded) or suggestedDuration.
  Duration get effectiveDuration => isRecorded && timeline.isNotEmpty
      ? Duration(milliseconds: (timeline.last.timestampMs).round())
      : suggestedDuration;

  /// Visual experience to pair with this incienso.
  /// null = user chooses or uses default photic pulse.
  final InciensoVisual? defaultVisual;

  /// Screen color for photic driving (fallback if no visual experience).
  final int screenColorValue;

  /// Screen pulse frequency in Hz (0 = static color).
  final double pulseFrequencyHz;

  /// Whether stereo headphones are required (always true for binaural).
  final bool requiresHeadphones;

  /// Whether this needs speakers (infrasound protocols).
  final bool requiresSpeakers;

  /// Source: predefined state, PAR protocol, or user-created.
  final InciensoSource source;

  /// Original state ID if sourced from StateCatalog.
  final String? stateId;

  /// Original protocol ID if sourced from ParProtocolCatalog.
  final String? protocolId;

  /// Creator user ID (for custom inciensos).
  final String? creatorId;

  /// Whether this is a premium incienso.
  final bool isPro;

  /// Icon code point for UI display.
  final int? iconCodePoint;

  /// Tags for discovery/search.
  final List<String> tags;

  /// Times this incienso has been practiced (social proof).
  final int practiceCount;

  /// Average quality ratio across all sessions.
  final double avgQualityRatio;

  const Incienso({
    required this.id,
    required this.names,
    this.descriptions = const {},
    required this.leftFrequencyHz,
    required this.rightFrequencyHz,
    required this.suggestedDuration,
    this.phases = const [],
    this.timeline = const [],
    this.defaultVisual,
    this.screenColorValue = 0xFF1A0A2E,
    this.pulseFrequencyHz = 0.0,
    this.requiresHeadphones = true,
    this.requiresSpeakers = false,
    this.source = InciensoSource.predefined,
    this.stateId,
    this.protocolId,
    this.creatorId,
    this.isPro = false,
    this.iconCodePoint,
    this.tags = const [],
    this.practiceCount = 0,
    this.avgQualityRatio = 0.0,
  });

  /// Create from a simple frequency pair (quick custom).
  factory Incienso.custom({
    required String name,
    required double leftHz,
    required double rightHz,
    Duration duration = const Duration(minutes: 10),
    String? creatorId,
  }) {
    return Incienso(
      id: 'custom_${DateTime.now().millisecondsSinceEpoch}',
      names: {'es': name, 'en': name},
      leftFrequencyHz: leftHz,
      rightFrequencyHz: rightHz,
      suggestedDuration: duration,
      source: InciensoSource.userCreated,
      creatorId: creatorId,
    );
  }

  String getName(String locale) =>
      names[locale] ?? names['es'] ?? names['en'] ?? id;

  String getDescription(String locale) =>
      descriptions[locale] ?? descriptions['es'] ?? descriptions['en'] ?? '';

  Map<String, dynamic> toJson() => {
    'id': id,
    'names': names,
    'descriptions': descriptions,
    'leftFrequencyHz': leftFrequencyHz,
    'rightFrequencyHz': rightFrequencyHz,
    'suggestedDuration': suggestedDuration.inSeconds,
    'phases': phases.map((p) => p.toJson()).toList(),
    if (timeline.isNotEmpty) 'timeline': timeline.map((k) => k.toJson()).toList(),
    if (defaultVisual != null) 'defaultVisual': defaultVisual!.name,
    'screenColorValue': screenColorValue,
    'pulseFrequencyHz': pulseFrequencyHz,
    'requiresHeadphones': requiresHeadphones,
    'requiresSpeakers': requiresSpeakers,
    'source': source.name,
    if (stateId != null) 'stateId': stateId,
    if (protocolId != null) 'protocolId': protocolId,
    if (creatorId != null) 'creatorId': creatorId,
    'isPro': isPro,
    if (iconCodePoint != null) 'iconCodePoint': iconCodePoint,
    'tags': tags,
    'practiceCount': practiceCount,
    'avgQualityRatio': avgQualityRatio,
  };

  factory Incienso.fromJson(Map<String, dynamic> json) => Incienso(
    id: json['id'] as String? ?? '',
    names: Map<String, String>.from(json['names'] as Map? ?? {}),
    descriptions: Map<String, String>.from(json['descriptions'] as Map? ?? {}),
    leftFrequencyHz: (json['leftFrequencyHz'] as num?)?.toDouble() ?? 200.0,
    rightFrequencyHz: (json['rightFrequencyHz'] as num?)?.toDouble() ?? 210.0,
    suggestedDuration: Duration(seconds: json['suggestedDuration'] as int? ?? 600),
    phases: (json['phases'] as List?)
        ?.map((p) => InciensoPhase.fromJson(p as Map<String, dynamic>))
        .toList() ?? [],
    timeline: (json['timeline'] as List?)
        ?.map((k) => InciensoKeyframe.fromJson(k as Map<String, dynamic>))
        .toList() ?? [],
    defaultVisual: json['defaultVisual'] != null
        ? InciensoVisual.values.firstWhere(
            (v) => v.name == json['defaultVisual'],
            orElse: () => InciensoVisual.photonicPulse,
          )
        : null,
    screenColorValue: json['screenColorValue'] as int? ?? 0xFF1A0A2E,
    pulseFrequencyHz: (json['pulseFrequencyHz'] as num?)?.toDouble() ?? 0.0,
    requiresHeadphones: json['requiresHeadphones'] as bool? ?? true,
    requiresSpeakers: json['requiresSpeakers'] as bool? ?? false,
    source: InciensoSource.values.firstWhere(
      (s) => s.name == json['source'],
      orElse: () => InciensoSource.predefined,
    ),
    stateId: json['stateId'] as String?,
    protocolId: json['protocolId'] as String?,
    creatorId: json['creatorId'] as String?,
    isPro: json['isPro'] as bool? ?? false,
    iconCodePoint: json['iconCodePoint'] as int?,
    tags: (json['tags'] as List?)?.cast<String>() ?? [],
    practiceCount: json['practiceCount'] as int? ?? 0,
    avgQualityRatio: (json['avgQualityRatio'] as num?)?.toDouble() ?? 0.0,
  );
}

/// A frequency transition phase within an Incienso.
class InciensoPhase {
  /// Starting binaural beat in Hz.
  final double startBeatHz;

  /// Ending binaural beat in Hz.
  final double endBeatHz;

  /// Duration of this phase.
  final Duration duration;

  /// Offset from session start when this phase begins.
  final Duration startAt;

  const InciensoPhase({
    required this.startBeatHz,
    required this.endBeatHz,
    required this.duration,
    this.startAt = Duration.zero,
  });

  Map<String, dynamic> toJson() => {
    'startBeatHz': startBeatHz,
    'endBeatHz': endBeatHz,
    'duration': duration.inSeconds,
    'startAt': startAt.inSeconds,
  };

  factory InciensoPhase.fromJson(Map<String, dynamic> json) => InciensoPhase(
    startBeatHz: (json['startBeatHz'] as num?)?.toDouble() ?? 10.0,
    endBeatHz: (json['endBeatHz'] as num?)?.toDouble() ?? 10.0,
    duration: Duration(seconds: json['duration'] as int? ?? 300),
    startAt: Duration(seconds: json['startAt'] as int? ?? 0),
  );
}

/// Source of an Incienso preset.
enum InciensoSource {
  /// From StateCatalog (13 predefined states).
  predefined,

  /// From ParProtocolCatalog (9 tactical/universal protocols).
  protocol,

  /// Created by a user.
  userCreated,

  /// Shared by community (future).
  community,
}

/// A single moment captured during a recorded Incienso session.
///
/// Keyframes are sampled at ~1 Hz (every second) during recording.
/// When someone "plays" a recorded Incienso, the system interpolates
/// between keyframes to reproduce the frequency journey.
class InciensoKeyframe {
  /// Milliseconds from session start.
  final double timestampMs;

  /// Left ear frequency at this moment (Hz).
  final double leftHz;

  /// Right ear frequency at this moment (Hz).
  final double rightHz;

  /// Binaural beat at this moment.
  double get beatHz => (rightHz - leftHz).abs();

  /// Coherence reading at this moment (0.0–1.0).
  final double coherence;

  /// Volume level at this moment (0.0–1.0).
  final double volume;

  /// Neuro state active at this moment.
  final String neuroState;

  /// Breath phase at this moment (0.0 = exhale, 1.0 = inhale peak).
  final double breathPhase;

  /// Visual experience active at this moment (may change mid-session).
  final String? visualExperience;

  /// Whether this keyframe marks a manual state change by the user.
  final bool isUserAction;

  const InciensoKeyframe({
    required this.timestampMs,
    required this.leftHz,
    required this.rightHz,
    this.coherence = 0.0,
    this.volume = 0.7,
    this.neuroState = 'neutral',
    this.breathPhase = 0.0,
    this.visualExperience,
    this.isUserAction = false,
  });

  Map<String, dynamic> toJson() => {
    't': timestampMs,
    'l': leftHz,
    'r': rightHz,
    'c': coherence,
    'v': volume,
    's': neuroState,
    'b': breathPhase,
    if (visualExperience != null) 'x': visualExperience,
    if (isUserAction) 'a': true,
  };

  factory InciensoKeyframe.fromJson(Map<String, dynamic> json) => InciensoKeyframe(
    timestampMs: (json['t'] as num?)?.toDouble() ?? 0.0,
    leftHz: (json['l'] as num?)?.toDouble() ?? 200.0,
    rightHz: (json['r'] as num?)?.toDouble() ?? 210.0,
    coherence: (json['c'] as num?)?.toDouble() ?? 0.0,
    volume: (json['v'] as num?)?.toDouble() ?? 0.7,
    neuroState: json['s'] as String? ?? 'neutral',
    breathPhase: (json['b'] as num?)?.toDouble() ?? 0.0,
    visualExperience: json['x'] as String?,
    isUserAction: json['a'] as bool? ?? false,
  );
}

/// Visual experience paired with an Incienso.
enum InciensoVisual {
  /// Default: screen pulses at beat frequency (photic driving).
  photonicPulse,

  /// Emergent boid swarm.
  flocking,

  /// Synchronized breathing circles.
  breathing,

  /// Infinite Mandelbrot zoom.
  fractals,

  /// Chladni plate resonance patterns.
  neomatics,

  /// Generative sacred geometry.
  neuroMandala,
}
