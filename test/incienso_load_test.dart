import 'package:flutter_test/flutter_test.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:neom_generator/data/incienso_catalog.dart';
import 'package:neom_generator/domain/models/incienso.dart';

void main() {
  // ═══════════════════════════════════════════════════════════
  //  GROUP 1: Incienso model basics
  // ═══════════════════════════════════════════════════════════

  group('Incienso model basics', () {
    test('binauralBeatHz = |right - left| for standard pair', () {
      final inc = Incienso(
        id: 'test-1',
        names: const {'en': 'Test'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 210,
        suggestedDuration: const Duration(minutes: 10),
      );
      expect(inc.binauralBeatHz, 10.0);
    });

    test('binauralBeatHz = |right - left| when left > right', () {
      final inc = Incienso(
        id: 'test-2',
        names: const {'en': 'Test'},
        leftFrequencyHz: 210,
        rightFrequencyHz: 200,
        suggestedDuration: const Duration(minutes: 10),
      );
      expect(inc.binauralBeatHz, 10.0);
    });

    test('binauralBeatHz = 0 when frequencies are equal', () {
      final inc = Incienso(
        id: 'test-3',
        names: const {'en': 'Test'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 200,
        suggestedDuration: const Duration(minutes: 10),
      );
      expect(inc.binauralBeatHz, 0.0);
    });

    test('binauralBeatHz with fractional frequencies', () {
      final inc = Incienso(
        id: 'test-frac',
        names: const {'en': 'Test'},
        leftFrequencyHz: 200.5,
        rightFrequencyHz: 207.3,
        suggestedDuration: const Duration(minutes: 10),
      );
      expect(inc.binauralBeatHz, closeTo(6.8, 1e-9));
    });

    test('isMultiPhase = true when phases.length > 1', () {
      final inc = Incienso(
        id: 'test-mp',
        names: const {'en': 'Multi'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 210,
        suggestedDuration: const Duration(minutes: 10),
        phases: const [
          InciensoPhase(startBeatHz: 10, endBeatHz: 7, duration: Duration(minutes: 5)),
          InciensoPhase(startBeatHz: 7, endBeatHz: 4, duration: Duration(minutes: 5)),
        ],
      );
      expect(inc.isMultiPhase, isTrue);
    });

    test('isMultiPhase = false with 0 or 1 phases', () {
      final noPhases = Incienso(
        id: 'test-0p',
        names: const {'en': 'None'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 210,
        suggestedDuration: const Duration(minutes: 10),
      );
      expect(noPhases.isMultiPhase, isFalse);

      final onePhase = Incienso(
        id: 'test-1p',
        names: const {'en': 'One'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 210,
        suggestedDuration: const Duration(minutes: 10),
        phases: const [
          InciensoPhase(startBeatHz: 10, endBeatHz: 10, duration: Duration(minutes: 10)),
        ],
      );
      expect(onePhase.isMultiPhase, isFalse);
    });

    test('isRecorded = true when timeline is not empty', () {
      final inc = Incienso(
        id: 'test-rec',
        names: const {'en': 'Recorded'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 210,
        suggestedDuration: const Duration(minutes: 10),
        timeline: const [
          InciensoKeyframe(timestampMs: 0, leftHz: 200, rightHz: 210),
          InciensoKeyframe(timestampMs: 5000, leftHz: 200, rightHz: 208),
        ],
      );
      expect(inc.isRecorded, isTrue);
    });

    test('isRecorded = false when timeline is empty', () {
      final inc = Incienso(
        id: 'test-norec',
        names: const {'en': 'Not Recorded'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 210,
        suggestedDuration: const Duration(minutes: 10),
      );
      expect(inc.isRecorded, isFalse);
    });

    test('effectiveDuration returns suggestedDuration when no timeline', () {
      final inc = Incienso(
        id: 'test-dur',
        names: const {'en': 'Suggested'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 210,
        suggestedDuration: const Duration(minutes: 15),
      );
      expect(inc.effectiveDuration, const Duration(minutes: 15));
    });

    test('effectiveDuration returns timeline-derived when recorded', () {
      final inc = Incienso(
        id: 'test-dur-rec',
        names: const {'en': 'Recorded Duration'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 210,
        suggestedDuration: const Duration(minutes: 15),
        timeline: [
          const InciensoKeyframe(timestampMs: 0, leftHz: 200, rightHz: 210),
          const InciensoKeyframe(timestampMs: 120000, leftHz: 200, rightHz: 206),
          const InciensoKeyframe(timestampMs: 600000, leftHz: 200, rightHz: 204),
        ],
      );
      // 600000 ms = 10 minutes (from last keyframe)
      expect(inc.effectiveDuration, const Duration(milliseconds: 600000));
      expect(inc.effectiveDuration.inMinutes, 10);
    });

    test('targetState returns correct NeomNeuroState for various beats', () {
      // <0.5 Hz -> neutral
      final neutral = Incienso(
        id: 'ts-neutral',
        names: const {'en': 'N'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 200.3,
        suggestedDuration: const Duration(minutes: 10),
      );
      expect(neutral.targetState, NeomNeuroState.neutral);

      // 2 Hz -> sleep (delta 0.5-4)
      final sleep = Incienso(
        id: 'ts-sleep',
        names: const {'en': 'S'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 202,
        suggestedDuration: const Duration(minutes: 10),
      );
      expect(sleep.targetState, NeomNeuroState.sleep);

      // 5 Hz -> creativity (theta 4-6)
      final creativity = Incienso(
        id: 'ts-creativity',
        names: const {'en': 'C'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 205,
        suggestedDuration: const Duration(minutes: 10),
      );
      expect(creativity.targetState, NeomNeuroState.creativity);

      // 7 Hz -> calm (theta 6-8)
      final calm = Incienso(
        id: 'ts-calm',
        names: const {'en': 'Calm'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 207,
        suggestedDuration: const Duration(minutes: 10),
      );
      expect(calm.targetState, NeomNeuroState.calm);

      // 10 Hz -> neutral (alpha 8-13)
      final alphaNeutral = Incienso(
        id: 'ts-alpha',
        names: const {'en': 'AN'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 210,
        suggestedDuration: const Duration(minutes: 10),
      );
      expect(alphaNeutral.targetState, NeomNeuroState.neutral);

      // 20 Hz -> focus (beta 13-30)
      final focus = Incienso(
        id: 'ts-focus',
        names: const {'en': 'F'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 220,
        suggestedDuration: const Duration(minutes: 10),
      );
      expect(focus.targetState, NeomNeuroState.focus);

      // 40 Hz -> integration (gamma 30+)
      final integration = Incienso(
        id: 'ts-gamma',
        names: const {'en': 'G'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 240,
        suggestedDuration: const Duration(minutes: 10),
      );
      expect(integration.targetState, NeomNeuroState.integration);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  GROUP 2: InciensoPhase
  // ═══════════════════════════════════════════════════════════

  group('InciensoPhase', () {
    test('fromJson/toJson round-trip preserves all fields', () {
      const phase = InciensoPhase(
        startBeatHz: 10.0,
        endBeatHz: 4.0,
        duration: Duration(minutes: 5),
        startAt: Duration(minutes: 2),
      );

      final json = phase.toJson();
      final restored = InciensoPhase.fromJson(json);

      expect(restored.startBeatHz, 10.0);
      expect(restored.endBeatHz, 4.0);
      expect(restored.duration, const Duration(minutes: 5));
      expect(restored.startAt, const Duration(minutes: 2));
    });

    test('fromJson/toJson round-trip with default startAt (zero)', () {
      const phase = InciensoPhase(
        startBeatHz: 7.5,
        endBeatHz: 3.0,
        duration: Duration(minutes: 8),
      );

      final json = phase.toJson();
      final restored = InciensoPhase.fromJson(json);

      expect(restored.startBeatHz, 7.5);
      expect(restored.endBeatHz, 3.0);
      expect(restored.duration, const Duration(minutes: 8));
      expect(restored.startAt, Duration.zero);
    });

    test('Phase with non-zero startAt offset', () {
      const phase = InciensoPhase(
        startBeatHz: 14.0,
        endBeatHz: 10.0,
        duration: Duration(seconds: 90),
        startAt: Duration(seconds: 300),
      );

      expect(phase.startAt.inSeconds, 300);
      expect(phase.duration.inSeconds, 90);

      // Verify JSON keys
      final json = phase.toJson();
      expect(json['startAt'], 300);
      expect(json['duration'], 90);
      expect(json['startBeatHz'], 14.0);
      expect(json['endBeatHz'], 10.0);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  GROUP 3: InciensoKeyframe
  // ═══════════════════════════════════════════════════════════

  group('InciensoKeyframe', () {
    test('fromJson/toJson round-trip with compressed keys', () {
      const keyframe = InciensoKeyframe(
        timestampMs: 5000.0,
        leftHz: 200.0,
        rightHz: 206.5,
        coherence: 0.85,
        volume: 0.9,
        neuroState: 'creativity',
        breathPhase: 0.6,
        visualExperience: 'fractals',
        isUserAction: true,
      );

      final json = keyframe.toJson();

      // Verify compressed keys
      expect(json['t'], 5000.0);
      expect(json['l'], 200.0);
      expect(json['r'], 206.5);
      expect(json['c'], 0.85);
      expect(json['v'], 0.9);
      expect(json['s'], 'creativity');
      expect(json['b'], 0.6);
      expect(json['x'], 'fractals');
      expect(json['a'], true);

      final restored = InciensoKeyframe.fromJson(json);
      expect(restored.timestampMs, 5000.0);
      expect(restored.leftHz, 200.0);
      expect(restored.rightHz, 206.5);
      expect(restored.coherence, 0.85);
      expect(restored.volume, 0.9);
      expect(restored.neuroState, 'creativity');
      expect(restored.breathPhase, 0.6);
      expect(restored.visualExperience, 'fractals');
      expect(restored.isUserAction, true);
    });

    test('toJson omits optional fields when null/default', () {
      const keyframe = InciensoKeyframe(
        timestampMs: 1000.0,
        leftHz: 200.0,
        rightHz: 210.0,
      );

      final json = keyframe.toJson();

      // visualExperience is null, should not be in JSON
      expect(json.containsKey('x'), isFalse);
      // isUserAction defaults to false, should not be in JSON
      expect(json.containsKey('a'), isFalse);
    });

    test('beatHz getter = |rightHz - leftHz|', () {
      const kf1 = InciensoKeyframe(
        timestampMs: 0,
        leftHz: 200,
        rightHz: 210,
      );
      expect(kf1.beatHz, 10.0);

      const kf2 = InciensoKeyframe(
        timestampMs: 0,
        leftHz: 210,
        rightHz: 200,
      );
      expect(kf2.beatHz, 10.0);

      const kf3 = InciensoKeyframe(
        timestampMs: 0,
        leftHz: 200,
        rightHz: 200,
      );
      expect(kf3.beatHz, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  GROUP 4: InciensoReference evidence fields
  // ═══════════════════════════════════════════════════════════

  group('InciensoReference', () {
    test('fromJson/toJson round-trip with all evidence fields', () {
      const ref = InciensoReference(
        citation: 'Smith et al. (2023)',
        title: 'Effects of binaural beats on cognition',
        journal: 'Journal of Neuroscience',
        year: 2023,
        doi: '10.1016/j.jns.2023.001',
        pmcId: 'PMC1234567',
        url: 'https://example.com/paper',
        finding: 'Significant improvement in attention span',
        studyType: StudyType.rctDoubleBlind,
        evidenceLevel: EvidenceLevel.high,
        safetyProfile: SafetyProfile.minimal,
        sampleSize: 120,
        safetyNote: 'Avoid with photosensitive epilepsy',
      );

      final json = ref.toJson();
      final restored = InciensoReference.fromJson(json);

      expect(restored.citation, 'Smith et al. (2023)');
      expect(restored.title, 'Effects of binaural beats on cognition');
      expect(restored.journal, 'Journal of Neuroscience');
      expect(restored.year, 2023);
      expect(restored.doi, '10.1016/j.jns.2023.001');
      expect(restored.pmcId, 'PMC1234567');
      expect(restored.url, 'https://example.com/paper');
      expect(restored.finding, 'Significant improvement in attention span');
      expect(restored.studyType, StudyType.rctDoubleBlind);
      expect(restored.evidenceLevel, EvidenceLevel.high);
      expect(restored.safetyProfile, SafetyProfile.minimal);
      expect(restored.sampleSize, 120);
      expect(restored.safetyNote, 'Avoid with photosensitive epilepsy');
    });

    test('toJson omits null optional fields', () {
      const ref = InciensoReference(
        citation: 'Doe (2020)',
        title: 'A Study',
        year: 2020,
        finding: 'Some finding',
      );

      final json = ref.toJson();

      expect(json.containsKey('doi'), isFalse);
      expect(json.containsKey('pmcId'), isFalse);
      expect(json.containsKey('url'), isFalse);
      expect(json.containsKey('sampleSize'), isFalse);
      expect(json.containsKey('safetyNote'), isFalse);
      // Empty journal is also omitted
      expect(json.containsKey('journal'), isFalse);
    });

    test('link getter resolves DOI first', () {
      const ref = InciensoReference(
        citation: 'Test',
        title: 'Test',
        year: 2023,
        doi: '10.1016/j.example.2023',
        pmcId: 'PMC9999999',
        url: 'https://fallback.com',
        finding: 'Test finding',
      );
      expect(ref.link, 'https://doi.org/10.1016/j.example.2023');
    });

    test('link getter falls back to PMC when no DOI', () {
      const ref = InciensoReference(
        citation: 'Test',
        title: 'Test',
        year: 2023,
        pmcId: 'PMC9999999',
        url: 'https://fallback.com',
        finding: 'Test finding',
      );
      expect(ref.link, 'https://www.ncbi.nlm.nih.gov/pmc/articles/PMC9999999/');
    });

    test('link getter falls back to url when no DOI or PMC', () {
      const ref = InciensoReference(
        citation: 'Test',
        title: 'Test',
        year: 2023,
        url: 'https://fallback.com',
        finding: 'Test finding',
      );
      expect(ref.link, 'https://fallback.com');
    });

    test('link getter returns empty string when nothing available', () {
      const ref = InciensoReference(
        citation: 'Test',
        title: 'Test',
        year: 2023,
        finding: 'Test finding',
      );
      expect(ref.link, '');
    });

    test('studyTypeLabel returns correct strings', () {
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          studyType: StudyType.metaAnalysis,
        ).studyTypeLabel,
        'Meta-analysis',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          studyType: StudyType.rctDoubleBlind,
        ).studyTypeLabel,
        'Double-blind RCT',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          studyType: StudyType.rct,
        ).studyTypeLabel,
        'Randomized Controlled Trial',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          studyType: StudyType.controlledStudy,
        ).studyTypeLabel,
        'Controlled Study',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          studyType: StudyType.pilotStudy,
        ).studyTypeLabel,
        'Pilot Study',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          studyType: StudyType.inVitro,
        ).studyTypeLabel,
        'In Vitro (Laboratory)',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          studyType: StudyType.preclinical,
        ).studyTypeLabel,
        'Preclinical (Animal Model)',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          studyType: StudyType.caseReport,
        ).studyTypeLabel,
        'Case Report',
      );
    });

    test('evidenceLevelLabel returns correct strings', () {
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          evidenceLevel: EvidenceLevel.high,
        ).evidenceLevelLabel,
        'High',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          evidenceLevel: EvidenceLevel.moderateHigh,
        ).evidenceLevelLabel,
        'Moderate-High',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          evidenceLevel: EvidenceLevel.moderate,
        ).evidenceLevelLabel,
        'Moderate',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          evidenceLevel: EvidenceLevel.lowModerate,
        ).evidenceLevelLabel,
        'Low-Moderate',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          evidenceLevel: EvidenceLevel.low,
        ).evidenceLevelLabel,
        'Low',
      );
    });

    test('safetyLabel returns correct strings', () {
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          safetyProfile: SafetyProfile.noRisk,
        ).safetyLabel,
        'No known risk',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          safetyProfile: SafetyProfile.minimal,
        ).safetyLabel,
        'Minimal risk',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          safetyProfile: SafetyProfile.low,
        ).safetyLabel,
        'Low risk',
      );
      expect(
        const InciensoReference(
          citation: '', title: '', year: 0, finding: '',
          safetyProfile: SafetyProfile.moderate,
        ).safetyLabel,
        'Medical supervision recommended',
      );
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  GROUP 5: Compatibility (via Incienso.fromJson)
  // ═══════════════════════════════════════════════════════════

  group('Compatibility parsing (via Incienso.fromJson)', () {
    test('new format JSON produces correct compatibility map', () {
      final json = <String, dynamic>{
        'id': 'compat-new',
        'names': {'en': 'New Format'},
        'leftFrequencyHz': 200,
        'rightFrequencyHz': 210,
        'suggestedDuration': 600,
        'compatibility': {
          'headphones': 'optimal',
          'speakers': 'effective',
          'smartphone': 'partial',
          'subwoofer': 'notRecommended',
        },
      };

      final inc = Incienso.fromJson(json);

      expect(inc.compatibility[OutputSource.headphones],
          SourceEffectiveness.optimal);
      expect(inc.compatibility[OutputSource.speakers],
          SourceEffectiveness.effective);
      expect(inc.compatibility[OutputSource.smartphone],
          SourceEffectiveness.partial);
      expect(inc.compatibility[OutputSource.subwoofer],
          SourceEffectiveness.notRecommended);
    });

    test('legacy format requiresHeadphones=true yields defaultBinauralCompatibility', () {
      final json = <String, dynamic>{
        'id': 'compat-legacy-bin',
        'names': {'en': 'Legacy Binaural'},
        'leftFrequencyHz': 200,
        'rightFrequencyHz': 210,
        'suggestedDuration': 600,
        'requiresHeadphones': true,
        'requiresSpeakers': false,
      };

      final inc = Incienso.fromJson(json);
      expect(inc.compatibility, defaultBinauralCompatibility);
    });

    test('legacy format requiresSpeakers=true, requiresHeadphones=false yields defaultVibrationCompatibility', () {
      final json = <String, dynamic>{
        'id': 'compat-legacy-vib',
        'names': {'en': 'Legacy Vibration'},
        'leftFrequencyHz': 50,
        'rightFrequencyHz': 60,
        'suggestedDuration': 600,
        'requiresSpeakers': true,
        'requiresHeadphones': false,
      };

      final inc = Incienso.fromJson(json);
      expect(inc.compatibility, defaultVibrationCompatibility);
    });

    test('legacy format both speakers and headphones yields defaultDirectCarrierCompatibility', () {
      final json = <String, dynamic>{
        'id': 'compat-legacy-dc',
        'names': {'en': 'Legacy Direct'},
        'leftFrequencyHz': 100,
        'rightFrequencyHz': 140,
        'suggestedDuration': 600,
        'requiresSpeakers': true,
        'requiresHeadphones': true,
      };

      final inc = Incienso.fromJson(json);
      expect(inc.compatibility, defaultDirectCarrierCompatibility);
    });

    test('no compatibility field at all defaults to defaultBinauralCompatibility', () {
      final json = <String, dynamic>{
        'id': 'compat-none',
        'names': {'en': 'No Compat'},
        'leftFrequencyHz': 200,
        'rightFrequencyHz': 210,
        'suggestedDuration': 600,
      };

      final inc = Incienso.fromJson(json);
      expect(inc.compatibility, defaultBinauralCompatibility);
    });
  });

  // ═══════════════════════════════════════════════════════════
  //  GROUP 6: Catalog integrity
  // ═══════════════════════════════════════════════════════════

  group('Catalog integrity', () {
    test('InciensoCatalog.all contains expected count', () {
      expect(InciensoCatalog.all.length, 37);
    });

    test('InciensoCatalog.free.length = 12', () {
      expect(InciensoCatalog.free.length, 12);
    });

    test('InciensoCatalog.pro.length = 25', () {
      expect(InciensoCatalog.pro.length, 25);
    });

    test('all = free + pro (no missing entries)', () {
      expect(InciensoCatalog.all.length,
          InciensoCatalog.free.length + InciensoCatalog.pro.length);
    });

    test('all therapeutic protocols have at least 1 reference', () {
      // Therapeutic protocols are the ones tagged with medical/therapeutic tags
      // and marked isPro. All entries with references must have >= 1.
      final withRefs = InciensoCatalog.all
          .where((i) => i.references.isNotEmpty)
          .toList();

      // There are exactly 12 inciensos with references in the catalog
      expect(withRefs.length, 12);

      for (final inc in withRefs) {
        expect(inc.references.length, greaterThanOrEqualTo(1),
            reason: '${inc.id} should have at least 1 reference');
      }
    });

    test('all references have non-empty citation and finding', () {
      for (final inc in InciensoCatalog.all) {
        for (final ref in inc.references) {
          expect(ref.citation.isNotEmpty, isTrue,
              reason: '${inc.id} has a reference with empty citation');
          expect(ref.finding.isNotEmpty, isTrue,
              reason: '${inc.id} has a reference with empty finding');
        }
      }
    });

    test('no duplicate IDs in catalog', () {
      final ids = InciensoCatalog.all.map((i) => i.id).toList();
      final uniqueIds = ids.toSet();
      expect(uniqueIds.length, ids.length,
          reason: 'Found duplicate IDs: '
              '${ids.where((id) => ids.where((x) => x == id).length > 1).toSet()}');
    });

    test('all IDs start with incienso-', () {
      for (final inc in InciensoCatalog.all) {
        expect(inc.id.startsWith('incienso-'), isTrue,
            reason: '${inc.id} does not start with incienso-');
      }
    });

    test('free inciensos are not marked isPro', () {
      for (final inc in InciensoCatalog.free) {
        expect(inc.isPro, isFalse,
            reason: '${inc.id} is in free list but marked isPro=true');
      }
    });

    test('every incienso has at least one name', () {
      for (final inc in InciensoCatalog.all) {
        expect(inc.names.isNotEmpty, isTrue,
            reason: '${inc.id} has no names');
      }
    });
  });
}
