import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/domain/models/harmonic/harmonic_capture.dart';
import 'package:neom_generator/domain/models/harmonic/harmonic_compatibility.dart';
import 'package:neom_generator/domain/models/harmonic/harmonic_footprint.dart';
import 'package:neom_generator/domain/models/harmonic/group_resonance.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

HarmonicCapture _cap({
  double hz = 220.0,
  double centroid = 1200.0,
  List<double>? harmonics,
  double pitchMin = 200.0,
  double pitchMax = 250.0,
}) {
  return HarmonicCapture(
    id: 'c-${DateTime.now().microsecondsSinceEpoch}',
    timestamp: DateTime(2026, 1, 1),
    fundamentalHz: hz,
    volumeDb: 0.5,
    harmonics: harmonics ?? [1.0, 0.5, 0.25, 0.125, 0.06, 0.03, 0.015, 0.007],
    spectralCentroid: centroid,
    pitchMin: pitchMin,
    pitchMax: pitchMax,
    durationMs: 500,
  );
}

HarmonicFootprint _fp({
  double hz = 220.0,
  double centroid = 1200.0,
  List<double>? harmonics,
  int count = 5,
}) {
  return HarmonicFootprint(
    userId: 'u-${hz.toInt()}',
    captures: List.generate(count, (_) => _cap(
      hz: hz,
      centroid: centroid,
      harmonics: harmonics,
    )),
  );
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // Pitch consonance edge cases
  // ═══════════════════════════════════════════════════════════════════════════

  group('HarmonicCompatibility — pitchConsonance', () {
    test('unison (same frequency) → consonance = 1.0', () {
      final c = HarmonicCompatibility.compute(_fp(hz: 220), _fp(hz: 220));
      expect(c.pitchConsonance, 1.0);
    });

    test('octave (2:1 ratio) → high consonance', () {
      final c = HarmonicCompatibility.compute(_fp(hz: 220), _fp(hz: 440));
      expect(c.pitchConsonance, greaterThanOrEqualTo(0.9));
    });

    test('fifth (3:2 ratio = 1.5) → high consonance', () {
      final c = HarmonicCompatibility.compute(_fp(hz: 200), _fp(hz: 300));
      expect(c.pitchConsonance, greaterThanOrEqualTo(0.9));
    });

    test('tritone (~1.414 ratio) → low consonance', () {
      // Tritone = sqrt(2) ≈ 1.4142. Not close to any consonant ratio.
      // Nearest consonant: 1.333 (dist 0.081) or 1.5 (dist 0.086)
      final c = HarmonicCompatibility.compute(
        _fp(hz: 200),
        _fp(hz: 283), // 283/200 = 1.415
      );
      expect(c.pitchConsonance, lessThan(0.8));
    });

    test('one frequency = 0 → consonance = 0.0', () {
      final c = HarmonicCompatibility.compute(
        _fp(hz: 0, count: 1),
        _fp(hz: 440),
      );
      expect(c.pitchConsonance, 0.0);
    });

    test('both frequencies = 0 → consonance = 0.0', () {
      final c = HarmonicCompatibility.compute(
        _fp(hz: 0, count: 1),
        _fp(hz: 0, count: 1),
      );
      expect(c.pitchConsonance, 0.0);
    });

    test('very different frequencies (100 vs 5000) → does not crash', () {
      final c = HarmonicCompatibility.compute(_fp(hz: 100), _fp(hz: 5000));
      expect(c.pitchConsonance.isFinite, true);
      expect(c.pitchConsonance, greaterThanOrEqualTo(0.0));
      expect(c.pitchConsonance, lessThanOrEqualTo(1.0));
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Signature similarity (cosine)
  // ═══════════════════════════════════════════════════════════════════════════

  group('HarmonicCompatibility — signatureSimilarity', () {
    test('identical signatures → 1.0', () {
      final h = [0.8, 0.6, 0.4, 0.2, 0.1, 0.05, 0.02, 0.01];
      final c = HarmonicCompatibility.compute(
        _fp(harmonics: h),
        _fp(harmonics: h),
      );
      expect(c.signatureSimilarity, closeTo(1.0, 1e-6));
    });

    test('orthogonal signatures → 0.0', () {
      final h1 = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final h2 = [0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final c = HarmonicCompatibility.compute(
        _fp(harmonics: h1),
        _fp(harmonics: h2),
      );
      expect(c.signatureSimilarity, closeTo(0.0, 1e-6));
    });

    test('all-zero signature → 0.0, not NaN', () {
      final h = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final c = HarmonicCompatibility.compute(
        _fp(harmonics: h),
        _fp(harmonics: [1.0, 0.5, 0.25, 0.125, 0.06, 0.03, 0.015, 0.007]),
      );
      expect(c.signatureSimilarity, 0.0);
      expect(c.signatureSimilarity.isNaN, false);
    });

    test('both all-zero signatures → 0.0, not NaN', () {
      final h = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final c = HarmonicCompatibility.compute(
        _fp(harmonics: h),
        _fp(harmonics: h),
      );
      expect(c.signatureSimilarity, 0.0);
      expect(c.signatureSimilarity.isNaN, false);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Centroid complementarity
  // ═══════════════════════════════════════════════════════════════════════════

  group('HarmonicCompatibility — centroidComplementarity', () {
    test('same centroid → low complementarity', () {
      final c = HarmonicCompatibility.compute(
        _fp(centroid: 1200),
        _fp(centroid: 1200),
      );
      // diff = 0 → formula: 0/200*0.5 = 0
      expect(c.centroidComplementarity, closeTo(0.0, 1e-6));
    });

    test('diff ~1000 Hz → high complementarity (in rising zone)', () {
      final c = HarmonicCompatibility.compute(
        _fp(centroid: 500),
        _fp(centroid: 1500),
      );
      // diff=1000: 0.5 + (1000-200)/1300*0.5 = 0.5 + 0.308 = 0.808
      expect(c.centroidComplementarity, greaterThan(0.7));
    });

    test('diff = 1500 Hz → peak complementarity = 1.0', () {
      final c = HarmonicCompatibility.compute(
        _fp(centroid: 500),
        _fp(centroid: 2000),
      );
      // diff=1500: 0.5 + (1500-200)/1300*0.5 = 0.5 + 0.5 = 1.0
      expect(c.centroidComplementarity, closeTo(1.0, 1e-6));
    });

    test('diff = 5000 Hz → declining, but still in range', () {
      final c = HarmonicCompatibility.compute(
        _fp(centroid: 500),
        _fp(centroid: 5500),
      );
      // diff=5000: (1.0 - (5000-1500)/2000) = 1.0 - 1.75 → clamped to 0.0
      expect(c.centroidComplementarity, 0.0);
    });

    test('one centroid = 0 → complementarity = 0', () {
      // Captures with centroid 0 → spectralCentroidAvg = 0 → guard clause
      final fpZero = HarmonicFootprint(
        userId: 'u-zero-cent',
        captures: [_cap(centroid: 0.0)],
      );
      final c = HarmonicCompatibility.compute(fpZero, _fp(centroid: 1200));
      expect(c.centroidComplementarity, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // Overall score & labels
  // ═══════════════════════════════════════════════════════════════════════════

  group('HarmonicCompatibility — overallScore & label', () {
    test('identical footprints → high overall, "Resonancia Profunda"', () {
      final fp = _fp(hz: 220, centroid: 1200);
      final c = HarmonicCompatibility.compute(fp, fp);
      // pitchConsonance=1.0, signatureSimilarity=1.0, centroidComplementarity=0
      // overall = 1.0*0.4 + 1.0*0.35 + 0*0.25 = 0.75
      expect(c.overallScore, closeTo(0.75, 0.01));
      expect(c.label, 'Armonía Natural'); // 0.75 >= 0.6
    });

    test('completely different footprints → low overall', () {
      final h1 = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final h2 = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 1.0];
      final c = HarmonicCompatibility.compute(
        _fp(hz: 100, centroid: 400, harmonics: h1),
        _fp(hz: 777, centroid: 3500, harmonics: h2),
      );
      expect(c.overallScore, lessThan(0.6));
    });

    test('score boundaries for labels are correct', () {
      // Test each label boundary
      const boundary = HarmonicCompatibility(
        resonanceA: 100, resonanceB: 100,
        pitchConsonance: 1.0, signatureSimilarity: 1.0,
        centroidComplementarity: 1.0,
      );
      expect(boundary.overallScore, 1.0);
      expect(boundary.label, 'Resonancia Profunda');

      const mid = HarmonicCompatibility(
        resonanceA: 100, resonanceB: 100,
        pitchConsonance: 0.5, signatureSimilarity: 0.5,
        centroidComplementarity: 0.5,
      );
      expect(mid.overallScore, 0.5);
      expect(mid.label, 'Complementarios');

      const low = HarmonicCompatibility(
        resonanceA: 100, resonanceB: 100,
        pitchConsonance: 0.0, signatureSimilarity: 0.0,
        centroidComplementarity: 0.0,
      );
      expect(low.overallScore, 0.0);
      expect(low.label, 'Disonancia Exploratoria');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // intervalName
  // ═══════════════════════════════════════════════════════════════════════════

  group('HarmonicCompatibility — intervalName', () {
    test('220 vs 440 → "Octava"', () {
      final c = HarmonicCompatibility.compute(_fp(hz: 220), _fp(hz: 440));
      expect(c.intervalName, 'Octava');
    });

    test('220 vs 330 → "Quinta Justa" (ratio 1.5)', () {
      final c = HarmonicCompatibility.compute(_fp(hz: 220), _fp(hz: 330));
      expect(c.intervalName, 'Quinta Justa');
    });

    test('220 vs 293 → "Cuarta Justa" (ratio ≈1.332)', () {
      final c = HarmonicCompatibility.compute(_fp(hz: 220), _fp(hz: 293));
      expect(c.intervalName, 'Cuarta Justa');
    });

    test('0 vs 0 → "Unísono" (not crash)', () {
      final c = HarmonicCompatibility.compute(
        _fp(hz: 0, count: 1),
        _fp(hz: 0, count: 1),
      );
      // When both are 0, ratio defaults to 1.0 → Unísono
      expect(c.intervalName, 'Unísono');
    });

    test('0 vs 440 → "Unísono" (one zero, ratio defaults to 1.0)', () {
      final c = HarmonicCompatibility.compute(
        _fp(hz: 0, count: 1),
        _fp(hz: 440),
      );
      expect(c.intervalName, 'Unísono');
    });

    test('non-standard ratio → "Intervalo Libre"', () {
      // 200 vs 283 → ratio 283/200 = 1.415 — tritone, outside all tolerance bands
      // (1.333 ± 0.08 stops at 1.413, 1.5 ± 0.08 starts at 1.42)
      final c = HarmonicCompatibility.compute(_fp(hz: 200), _fp(hz: 283));
      expect(c.intervalName, 'Intervalo Libre');
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // GroupResonance
  // ═══════════════════════════════════════════════════════════════════════════

  group('GroupResonance', () {
    test('empty list → groupHz = 432 default', () {
      final gr = GroupResonance.fromFootprints([]);
      expect(gr.groupHz, 432.0);
      expect(gr.groupCoherence, 0.0);
      expect(gr.participantCount, 0);
    });

    test('single participant → groupHz = their resonance', () {
      final gr = GroupResonance.fromFootprints([_fp(hz: 256)]);
      expect(gr.groupHz, 256.0);
      expect(gr.groupCoherence, 1.0);
    });

    test('two participants at octave → geometric mean', () {
      final gr = GroupResonance.fromFootprints([
        _fp(hz: 220),
        _fp(hz: 440),
      ]);
      // Geometric mean of 220 and 440 = sqrt(220*440) ≈ 311.13
      final expected = math.sqrt(220.0 * 440.0);
      expect(gr.groupHz, closeTo(expected, 0.1));
    });

    test('10 participants with same Hz → groupHz = that Hz, coherence = 1.0', () {
      final fps = List.generate(10, (_) => _fp(hz: 300));
      final gr = GroupResonance.fromFootprints(fps);
      expect(gr.groupHz, closeTo(300.0, 0.1));
      expect(gr.groupCoherence, closeTo(1.0, 1e-6));
    });

    test('participants with 0 Hz resonance are filtered out', () {
      final gr = GroupResonance.fromFootprints([
        _fp(hz: 0, count: 1), // resonanceHz = 0, should be excluded
        _fp(hz: 300),
      ]);
      // Only the 300 Hz participant counts
      expect(gr.groupHz, 300.0);
      expect(gr.participantCount, 1);
    });

    test('all participants with 0 Hz → fallback 432', () {
      final gr = GroupResonance.fromFootprints([
        _fp(hz: 0, count: 1),
        _fp(hz: 0, count: 1),
      ]);
      expect(gr.groupHz, 432.0);
    });

    test('empty footprints (no captures) → filtered out', () {
      final fp1 = HarmonicFootprint(userId: 'u-empty1');
      final fp2 = _fp(hz: 400);
      final gr = GroupResonance.fromFootprints([fp1, fp2]);
      expect(gr.groupHz, 400.0);
    });

    test('very diverse group → coherence < 0.5', () {
      // Frequencies that are NOT consonant with each other
      final fps = [
        _fp(hz: 100),
        _fp(hz: 173), // ratio 1.73 — dissonant
        _fp(hz: 277), // ratio 1.6 with 173 — dissonant
        _fp(hz: 411), // etc.
      ];
      final gr = GroupResonance.fromFootprints(fps);
      expect(gr.groupCoherence, lessThan(0.5));
    });

    test('participants below 20 Hz are filtered out', () {
      final gr = GroupResonance.fromFootprints([
        _fp(hz: 15), // Below 20 Hz threshold
        _fp(hz: 500),
      ]);
      expect(gr.participantCount, 1);
      expect(gr.groupHz, 500.0);
    });

    test('groupHz is clamped to 80-2500 range', () {
      // All very low frequencies that are still > 20
      final gr = GroupResonance.fromFootprints([
        _fp(hz: 25),
        _fp(hz: 30),
      ]);
      // Geometric mean of 25 and 30 ≈ 27.4, clamped to 80
      expect(gr.groupHz, greaterThanOrEqualTo(80.0));
    });
  });
}
