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

  /// Output source compatibility map.
  ///
  /// Tells the user WHERE they can play this incienso and HOW effective
  /// each output source will be. Replaces the old boolean requires* fields.
  ///
  /// Default (binaural protocols): headphones=optimal, speakers=partial.
  /// Direct carrier protocols (>40 Hz): all sources effective.
  /// Physical vibration protocols: speakers/subwoofer=optimal.
  final Map<OutputSource, SourceEffectiveness> compatibility;

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

  /// Scientific references supporting this incienso's frequency protocol.
  /// Empty for non-research-based presets.
  final List<InciensoReference> references;

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
    this.compatibility = defaultBinauralCompatibility,
    this.source = InciensoSource.predefined,
    this.stateId,
    this.protocolId,
    this.creatorId,
    this.isPro = false,
    this.iconCodePoint,
    this.tags = const [],
    this.references = const [],
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
    'compatibility': compatibility.map(
      (source, eff) => MapEntry(source.name, eff.name),
    ),
    'source': source.name,
    if (stateId != null) 'stateId': stateId,
    if (protocolId != null) 'protocolId': protocolId,
    if (creatorId != null) 'creatorId': creatorId,
    'isPro': isPro,
    if (iconCodePoint != null) 'iconCodePoint': iconCodePoint,
    'tags': tags,
    if (references.isNotEmpty) 'references': references.map((r) => r.toJson()).toList(),
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
    compatibility: _parseCompatibility(json),
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
    references: (json['references'] as List?)
        ?.map((r) => InciensoReference.fromJson(r as Map<String, dynamic>))
        .toList() ?? [],
    practiceCount: json['practiceCount'] as int? ?? 0,
    avgQualityRatio: (json['avgQualityRatio'] as num?)?.toDouble() ?? 0.0,
  );

  /// Parses compatibility from JSON, with backward compat for old bool fields.
  static Map<OutputSource, SourceEffectiveness> _parseCompatibility(
    Map<String, dynamic> json,
  ) {
    // New format: { "compatibility": { "headphones": "optimal", ... } }
    if (json['compatibility'] is Map) {
      final raw = json['compatibility'] as Map;
      return raw.map((key, value) => MapEntry(
        OutputSource.values.firstWhere(
          (s) => s.name == key,
          orElse: () => OutputSource.headphones,
        ),
        SourceEffectiveness.values.firstWhere(
          (e) => e.name == value,
          orElse: () => SourceEffectiveness.effective,
        ),
      ));
    }

    // Legacy format: { "requiresHeadphones": true, "requiresSpeakers": false }
    final needsHeadphones = json['requiresHeadphones'] as bool? ?? true;
    final needsSpeakers = json['requiresSpeakers'] as bool? ?? false;

    if (needsSpeakers && !needsHeadphones) {
      return defaultVibrationCompatibility;
    }
    if (needsSpeakers && needsHeadphones) {
      return defaultDirectCarrierCompatibility;
    }
    return defaultBinauralCompatibility;
  }
}

/// Output source for playing an Incienso.
enum OutputSource {
  /// Over-ear or in-ear stereo headphones (binaural-capable).
  headphones,

  /// Desktop, bookshelf, or monitor speakers.
  speakers,

  /// Phone built-in speaker (limited bass, usually mono).
  smartphone,

  /// Dedicated subwoofer (physical vibration, deep bass).
  subwoofer,

  /// Bone conduction headphones (vibration to skull, open-ear).
  boneConduction,

  /// Sleep headband or pillow speaker (for sleep protocols).
  sleepBand,
}

/// How effective a given output source is for an Incienso.
enum SourceEffectiveness {
  /// Best possible results with this source.
  optimal,

  /// Good results — recommended alternative.
  effective,

  /// Works but with reduced effectiveness.
  partial,

  /// Won't achieve the intended therapeutic effect.
  notRecommended,
}

// ─────────────────────────────────────────────────────────────
//  Preset compatibility maps (const, reusable across catalog)
// ─────────────────────────────────────────────────────────────

/// Binaural protocols (beat = |R−L|): headphones are optimal because
/// they preserve stereo separation. Speakers lose the binaural effect
/// but isochronic/carrier components still work.
const defaultBinauralCompatibility = <OutputSource, SourceEffectiveness>{
  OutputSource.headphones: SourceEffectiveness.optimal,
  OutputSource.boneConduction: SourceEffectiveness.effective,
  OutputSource.speakers: SourceEffectiveness.partial,
  OutputSource.smartphone: SourceEffectiveness.partial,
};

/// Direct carrier protocols (e.g. 90 Hz, 100 Hz): the target frequency
/// is audible directly — no binaural separation needed. Any output works.
const defaultDirectCarrierCompatibility = <OutputSource, SourceEffectiveness>{
  OutputSource.headphones: SourceEffectiveness.optimal,
  OutputSource.speakers: SourceEffectiveness.optimal,
  OutputSource.boneConduction: SourceEffectiveness.effective,
  OutputSource.smartphone: SourceEffectiveness.effective,
  OutputSource.subwoofer: SourceEffectiveness.effective,
};

/// Physical vibration protocols (bone density, respiratory): require
/// actual mechanical vibration through body contact. Subwoofer/speakers
/// are optimal; headphones provide neural entrainment only.
const defaultVibrationCompatibility = <OutputSource, SourceEffectiveness>{
  OutputSource.subwoofer: SourceEffectiveness.optimal,
  OutputSource.speakers: SourceEffectiveness.optimal,
  OutputSource.boneConduction: SourceEffectiveness.effective,
  OutputSource.headphones: SourceEffectiveness.partial,
  OutputSource.smartphone: SourceEffectiveness.partial,
};

/// Sleep protocols: headband/pillow speakers are optimal for comfort;
/// standard headphones work but may be uncomfortable for sleeping.
const defaultSleepCompatibility = <OutputSource, SourceEffectiveness>{
  OutputSource.sleepBand: SourceEffectiveness.optimal,
  OutputSource.headphones: SourceEffectiveness.effective,
  OutputSource.boneConduction: SourceEffectiveness.effective,
  OutputSource.speakers: SourceEffectiveness.partial,
  OutputSource.smartphone: SourceEffectiveness.partial,
};

/// Audiovisual protocols (40 Hz gamma + photic): headphones for binaural
/// + screen for photic pulse. Speakers lose binaural but photic still works.
const defaultAudiovisualCompatibility = <OutputSource, SourceEffectiveness>{
  OutputSource.headphones: SourceEffectiveness.optimal,
  OutputSource.boneConduction: SourceEffectiveness.effective,
  OutputSource.speakers: SourceEffectiveness.effective,
  OutputSource.smartphone: SourceEffectiveness.partial,
};

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

/// Type of scientific study behind a reference.
enum StudyType {
  /// Systematic review pooling multiple RCTs.
  metaAnalysis,

  /// Double-blind randomized controlled trial.
  rctDoubleBlind,

  /// Randomized controlled trial (single-blind or open-label).
  rct,

  /// Non-randomized controlled study.
  controlledStudy,

  /// Pilot or feasibility study.
  pilotStudy,

  /// In vitro (cell/tissue cultures in laboratory).
  inVitro,

  /// Animal model (in vivo preclinical).
  preclinical,

  /// Case report or case series.
  caseReport,
}

/// Strength of the scientific evidence.
enum EvidenceLevel {
  /// Meta-analysis of RCTs or Phase II+ clinical trials.
  high,

  /// Single DB-RCT or multiple independent RCTs.
  moderateHigh,

  /// Multiple controlled studies with consistent results.
  moderate,

  /// Controlled studies with small samples or limitations.
  lowModerate,

  /// Pilot, preclinical, or in vitro only.
  low,
}

/// Safety/risk profile for end users.
enum SafetyProfile {
  /// No known risks — passive listening at normal volume.
  noRisk,

  /// Minimal risk — specific contraindications exist (e.g. epilepsy for photic).
  minimal,

  /// Low risk — some populations should avoid (pregnancy, pacemakers, etc.).
  low,

  /// Medical supervision recommended.
  moderate,
}

/// A scientific reference supporting an Incienso's frequency protocol.
///
/// Stores structured metadata so the UI can render clickable citations,
/// evidence quality badges, and safety indicators. Users can verify
/// the research independently via DOI/PMC links.
class InciensoReference {
  /// Short citation label, e.g. "Choi et al. (2022)".
  final String citation;

  /// Full paper title.
  final String title;

  /// Journal or conference name.
  final String journal;

  /// Publication year.
  final int year;

  /// DOI identifier (without URL prefix), e.g. "10.1016/j.bbrc.2022.03.088".
  final String? doi;

  /// PubMed Central ID, e.g. "PMC9316100".
  final String? pmcId;

  /// Direct URL to the paper (fallback if neither DOI nor PMC).
  final String? url;

  /// One-line summary of why this paper is relevant.
  final String finding;

  /// Type of study design.
  final StudyType studyType;

  /// Overall strength of evidence.
  final EvidenceLevel evidenceLevel;

  /// Safety/risk profile for the end user.
  final SafetyProfile safetyProfile;

  /// Number of participants (null for in vitro / preclinical).
  final int? sampleSize;

  /// Free-text safety note shown to the user, e.g. "Avoid with photosensitive epilepsy".
  final String? safetyNote;

  const InciensoReference({
    required this.citation,
    required this.title,
    this.journal = '',
    required this.year,
    this.doi,
    this.pmcId,
    this.url,
    required this.finding,
    this.studyType = StudyType.controlledStudy,
    this.evidenceLevel = EvidenceLevel.moderate,
    this.safetyProfile = SafetyProfile.noRisk,
    this.sampleSize,
    this.safetyNote,
  });

  /// Resolves the best available link for this reference.
  String get link {
    if (doi != null) return 'https://doi.org/$doi';
    if (pmcId != null) return 'https://www.ncbi.nlm.nih.gov/pmc/articles/$pmcId/';
    return url ?? '';
  }

  /// Human-readable label for the study type.
  String get studyTypeLabel {
    switch (studyType) {
      case StudyType.metaAnalysis: return 'Meta-analysis';
      case StudyType.rctDoubleBlind: return 'Double-blind RCT';
      case StudyType.rct: return 'Randomized Controlled Trial';
      case StudyType.controlledStudy: return 'Controlled Study';
      case StudyType.pilotStudy: return 'Pilot Study';
      case StudyType.inVitro: return 'In Vitro (Laboratory)';
      case StudyType.preclinical: return 'Preclinical (Animal Model)';
      case StudyType.caseReport: return 'Case Report';
    }
  }

  /// Human-readable label for the evidence level.
  String get evidenceLevelLabel {
    switch (evidenceLevel) {
      case EvidenceLevel.high: return 'High';
      case EvidenceLevel.moderateHigh: return 'Moderate-High';
      case EvidenceLevel.moderate: return 'Moderate';
      case EvidenceLevel.lowModerate: return 'Low-Moderate';
      case EvidenceLevel.low: return 'Low';
    }
  }

  /// Human-readable label for safety.
  String get safetyLabel {
    switch (safetyProfile) {
      case SafetyProfile.noRisk: return 'No known risk';
      case SafetyProfile.minimal: return 'Minimal risk';
      case SafetyProfile.low: return 'Low risk';
      case SafetyProfile.moderate: return 'Medical supervision recommended';
    }
  }

  Map<String, dynamic> toJson() => {
    'citation': citation,
    'title': title,
    if (journal.isNotEmpty) 'journal': journal,
    'year': year,
    if (doi != null) 'doi': doi,
    if (pmcId != null) 'pmcId': pmcId,
    if (url != null) 'url': url,
    'finding': finding,
    'studyType': studyType.name,
    'evidenceLevel': evidenceLevel.name,
    'safetyProfile': safetyProfile.name,
    if (sampleSize != null) 'sampleSize': sampleSize,
    if (safetyNote != null) 'safetyNote': safetyNote,
  };

  factory InciensoReference.fromJson(Map<String, dynamic> json) =>
      InciensoReference(
        citation: json['citation'] as String? ?? '',
        title: json['title'] as String? ?? '',
        journal: json['journal'] as String? ?? '',
        year: json['year'] as int? ?? 0,
        doi: json['doi'] as String?,
        pmcId: json['pmcId'] as String?,
        url: json['url'] as String?,
        finding: json['finding'] as String? ?? '',
        studyType: StudyType.values.firstWhere(
          (e) => e.name == json['studyType'],
          orElse: () => StudyType.controlledStudy,
        ),
        evidenceLevel: EvidenceLevel.values.firstWhere(
          (e) => e.name == json['evidenceLevel'],
          orElse: () => EvidenceLevel.moderate,
        ),
        safetyProfile: SafetyProfile.values.firstWhere(
          (e) => e.name == json['safetyProfile'],
          orElse: () => SafetyProfile.noRisk,
        ),
        sampleSize: json['sampleSize'] as int?,
        safetyNote: json['safetyNote'] as String?,
      );
}
