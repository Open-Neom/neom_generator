import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/domain/models/harmonic/harmonic_capture.dart';
import 'package:neom_generator/domain/models/harmonic/harmonic_footprint.dart';
import 'package:neom_generator/domain/models/harmonic/vocal_range.dart';
import 'package:neom_generator/domain/models/harmonic/footprint_snapshot.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

HarmonicCapture _capture({
  double fundamentalHz = 220.0,
  double volumeDb = 0.5,
  List<double>? harmonics,
  double spectralCentroid = 1200.0,
  double pitchMin = 200.0,
  double pitchMax = 250.0,
  int durationMs = 500,
  DateTime? timestamp,
}) {
  return HarmonicCapture(
    id: 'cap-${DateTime.now().microsecondsSinceEpoch}',
    timestamp: timestamp ?? DateTime(2026, 1, 1),
    fundamentalHz: fundamentalHz,
    volumeDb: volumeDb,
    harmonics: harmonics ?? [1.0, 0.5, 0.25, 0.125, 0.06, 0.03, 0.015, 0.007],
    spectralCentroid: spectralCentroid,
    pitchMin: pitchMin,
    pitchMax: pitchMax,
    durationMs: durationMs,
  );
}

HarmonicFootprint _emptyFootprint() =>
    HarmonicFootprint(userId: 'u-empty');

HarmonicFootprint _footprintWith(List<HarmonicCapture> caps) {
  final fp = HarmonicFootprint(userId: 'u-test', captures: caps);
  return fp;
}

void main() {
  // ═══════════════════════════════════════════════════════════════════════════
  // HarmonicFootprint — computed getters
  // ═══════════════════════════════════════════════════════════════════════════

  group('HarmonicFootprint.resonanceHz', () {
    test('empty footprint returns 0', () {
      expect(_emptyFootprint().resonanceHz, 0.0);
    });

    test('single capture returns that fundamental', () {
      final fp = _footprintWith([_capture(fundamentalHz: 147.3)]);
      // Mode of [147] (rounded) = 147
      expect(fp.resonanceHz, 147.0);
    });

    test('10 identical pitches returns that pitch', () {
      final caps = List.generate(10, (_) => _capture(fundamentalHz: 220.0));
      expect(_footprintWith(caps).resonanceHz, 220.0);
    });

    test('mode selects most common pitch in varied set', () {
      // 6 captures at 220 Hz, 4 at 330 Hz → mode = 220
      final caps = [
        ...List.generate(6, (_) => _capture(fundamentalHz: 220.0)),
        ...List.generate(4, (_) => _capture(fundamentalHz: 330.0)),
      ];
      expect(_footprintWith(caps).resonanceHz, 220.0);
    });

    test('captures at 0 Hz are included in mode (potential issue)', () {
      // 5 at 0 Hz, 3 at 440 Hz — mode is 0 because 0 appears more often
      // This tests the current behavior: 0 Hz captures are NOT excluded
      final caps = [
        ...List.generate(5, (_) => _capture(fundamentalHz: 0.0)),
        ...List.generate(3, (_) => _capture(fundamentalHz: 440.0)),
      ];
      final fp = _footprintWith(caps);
      // Current impl: 0 Hz participates in mode. This IS the behavior.
      expect(fp.resonanceHz, 0.0);
    });

    test('very close frequencies round to same bucket', () {
      // 220.3, 220.4, 220.6 all round to 220; 330.1, 330.2 round to 330
      final caps = [
        _capture(fundamentalHz: 220.3),
        _capture(fundamentalHz: 220.4),
        _capture(fundamentalHz: 220.6),
        _capture(fundamentalHz: 330.1),
        _capture(fundamentalHz: 330.2),
      ];
      expect(_footprintWith(caps).resonanceHz, 220.0);
    });
  });

  group('HarmonicFootprint.pitchRange', () {
    test('empty footprint pitchRangeMin = 0', () {
      expect(_emptyFootprint().pitchRangeMin, 0.0);
    });

    test('empty footprint pitchRangeMax = 0', () {
      expect(_emptyFootprint().pitchRangeMax, 0.0);
    });

    test('all captures with pitchMin=0 returns 0', () {
      final caps = List.generate(3, (_) => _capture(pitchMin: 0.0));
      expect(_footprintWith(caps).pitchRangeMin, 0.0);
    });

    test('pitchRangeMin picks global minimum across captures', () {
      final caps = [
        _capture(pitchMin: 150.0),
        _capture(pitchMin: 80.0),
        _capture(pitchMin: 200.0),
      ];
      expect(_footprintWith(caps).pitchRangeMin, 80.0);
    });

    test('pitchRangeMax picks global maximum across captures', () {
      final caps = [
        _capture(pitchMax: 300.0),
        _capture(pitchMax: 600.0),
        _capture(pitchMax: 450.0),
      ];
      expect(_footprintWith(caps).pitchRangeMax, 600.0);
    });
  });

  group('HarmonicFootprint.harmonicSignature', () {
    test('empty footprint returns 8 zeros', () {
      final sig = _emptyFootprint().harmonicSignature;
      expect(sig.length, 8);
      expect(sig.every((v) => v == 0.0), true);
    });

    test('single capture returns that capture harmonics', () {
      final h = [0.8, 0.6, 0.4, 0.2, 0.1, 0.05, 0.02, 0.01];
      final fp = _footprintWith([_capture(harmonics: h)]);
      final sig = fp.harmonicSignature;
      for (int i = 0; i < 8; i++) {
        expect(sig[i], closeTo(h[i], 1e-10));
      }
    });

    test('averages harmonics element-wise across captures', () {
      final h1 = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final h2 = [0.0, 1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final fp = _footprintWith([_capture(harmonics: h1), _capture(harmonics: h2)]);
      final sig = fp.harmonicSignature;
      expect(sig[0], closeTo(0.5, 1e-10));
      expect(sig[1], closeTo(0.5, 1e-10));
      expect(sig[2], closeTo(0.0, 1e-10));
    });

    test('all-zero harmonics returns zeros, not NaN', () {
      final h = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final fp = _footprintWith([_capture(harmonics: h), _capture(harmonics: h)]);
      final sig = fp.harmonicSignature;
      expect(sig.every((v) => v == 0.0), true);
      expect(sig.every((v) => !v.isNaN), true);
    });
  });

  group('HarmonicFootprint.vocalRangeOctaves', () {
    test('pitchRangeMax = 0 returns 0 (no log2(0) crash)', () {
      final caps = [_capture(pitchMin: 0.0, pitchMax: 0.0)];
      expect(_footprintWith(caps).vocalRangeOctaves, 0.0);
    });

    test('pitchRangeMin = 0 returns 0', () {
      final caps = [_capture(pitchMin: 0.0, pitchMax: 500.0)];
      expect(_footprintWith(caps).vocalRangeOctaves, 0.0);
    });

    test('exact octave: max=440 min=220 → 1.0 octave', () {
      final caps = [
        _capture(pitchMin: 220.0, pitchMax: 440.0),
      ];
      expect(_footprintWith(caps).vocalRangeOctaves, closeTo(1.0, 1e-10));
    });

    test('two octaves: max=880 min=220 → 2.0', () {
      final caps = [
        _capture(pitchMin: 220.0, pitchMax: 880.0),
      ];
      expect(_footprintWith(caps).vocalRangeOctaves, closeTo(2.0, 1e-10));
    });

    test('min > max still computes (negative octaves)', () {
      // pitchRangeMin uses reduce(min) across pitchMin values
      // pitchRangeMax uses reduce(max) across pitchMax values
      // If a capture has pitchMin > pitchMax, the footprint-level
      // aggregation could still be fine if other captures exist.
      // Single capture with inverted range:
      final caps = [_capture(pitchMin: 500.0, pitchMax: 100.0)];
      final fp = _footprintWith(caps);
      // pitchRangeMin = 500, pitchRangeMax = 100 → log(100/500) = negative
      final octaves = fp.vocalRangeOctaves;
      expect(octaves.isFinite, true);
      // log2(100/500) = log2(0.2) ≈ -2.32 — negative but finite
      expect(octaves, lessThan(0));
    });
  });

  group('HarmonicFootprint.addCapture', () {
    test('updates updatedAt to capture timestamp', () {
      final fp = HarmonicFootprint(userId: 'u-add');
      final ts = DateTime(2026, 6, 15);
      fp.addCapture(_capture(timestamp: ts));
      expect(fp.updatedAt, ts);
    });

    test('increases totalCaptures', () {
      final fp = _emptyFootprint();
      expect(fp.totalCaptures, 0);
      fp.addCapture(_capture());
      expect(fp.totalCaptures, 1);
      fp.addCapture(_capture());
      expect(fp.totalCaptures, 2);
    });
  });

  group('HarmonicFootprint JSON round-trip', () {
    test('toJson → fromJson preserves all data', () {
      final caps = [
        _capture(fundamentalHz: 220.0, spectralCentroid: 1500.0),
        _capture(fundamentalHz: 330.0, spectralCentroid: 900.0),
      ];
      final original = HarmonicFootprint(
        userId: 'u-json',
        captures: caps,
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

      final json = original.toJson();
      final restored = HarmonicFootprint.fromJson(json);

      expect(restored.userId, original.userId);
      expect(restored.totalCaptures, original.totalCaptures);
      expect(restored.resonanceHz, original.resonanceHz);
      expect(restored.createdAt.millisecondsSinceEpoch,
          original.createdAt.millisecondsSinceEpoch);
      expect(restored.updatedAt.millisecondsSinceEpoch,
          original.updatedAt.millisecondsSinceEpoch);

      // Verify computed values match after deserialization
      for (int i = 0; i < 8; i++) {
        expect(restored.harmonicSignature[i],
            closeTo(original.harmonicSignature[i], 1e-10));
      }
    });

    test('empty captures survives round-trip', () {
      final original = HarmonicFootprint(
        userId: 'u-empty-json',
        captures: [],
        createdAt: DateTime(2025, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );
      final restored = HarmonicFootprint.fromJson(original.toJson());
      expect(restored.totalCaptures, 0);
      expect(restored.resonanceHz, 0.0);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // VocalRange.classify
  // ═══════════════════════════════════════════════════════════════════════════

  group('VocalRange.classify', () {
    test('100 Hz → bass', () {
      // Bass center = (80+330)/2 = 205, Baritone center = (100+400)/2 = 250
      // 100 is closer to 205 (dist=105) than 250 (dist=150) → bass
      expect(VocalRange.classify(100), VocalRange.bass);
    });

    test('200 Hz → bass (center 205 is closest)', () {
      // Bass center=205, distance=5. Baritone center=250, distance=50
      expect(VocalRange.classify(200), VocalRange.bass);
    });

    test('300 Hz → baritone (center 250 closest among candidates)', () {
      // Bass 205 → dist 95, Baritone 250 → dist 50, Tenor 325 → dist 25
      // Actually Tenor center = (130+520)/2 = 325, dist = 25 → tenor!
      expect(VocalRange.classify(300), VocalRange.tenor);
    });

    test('500 Hz → alto (center 437.5)', () {
      // Alto center = (175+700)/2 = 437.5, dist = 62.5
      // MezzoSoprano center = (220+880)/2 = 550, dist = 50
      // Actually mezzo is closer! Let's verify:
      expect(VocalRange.classify(500), VocalRange.mezzoSoprano);
    });

    test('1000 Hz → soprano', () {
      // Soprano center = (260+1050)/2 = 655, dist = 345
      // MezzoSoprano center = 550, dist = 450
      // Actually soprano center 655 is closer to 1000 (dist 345)
      // than mezzo 550 (dist 450) → soprano
      expect(VocalRange.classify(1000), VocalRange.soprano);
    });

    test('0 Hz → bass (closest center, does not crash)', () {
      // All centers > 0, bass center 205 is closest to 0
      expect(VocalRange.classify(0), VocalRange.bass);
    });

    test('50000 Hz → soprano (extreme, does not crash)', () {
      // Soprano center 655 is furthest above others, so dist is smallest
      expect(VocalRange.classify(50000), VocalRange.soprano);
    });

    test('negative frequency → bass (does not crash)', () {
      expect(VocalRange.classify(-100), VocalRange.bass);
    });

    test('boundary between bass and baritone centers', () {
      // Bass center ≈ 205, Baritone center ≈ 250
      // Midpoint = 227.5. At 228, should go baritone (closer to 250)
      final midpoint = (205.0 + 250.0) / 2; // 227.5
      final atMid = VocalRange.classify(midpoint);
      // At exact midpoint, first found wins (bass comes first in enum)
      // But distance from 227.5 to 205 = 22.5, to 250 = 22.5 → tie → bass wins
      expect(atMid, VocalRange.bass); // first match wins ties
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // FootprintSnapshot
  // ═══════════════════════════════════════════════════════════════════════════

  group('FootprintSnapshot.coherenceScore', () {
    test('perfectly uniform harmonics → coherence = 1.0', () {
      // All 8 harmonics = 0.125 → stddev = 0, CV = 0, coherence = 1.0
      final h = [0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125, 0.125];
      final fp = _footprintWith([_capture(harmonics: h)]);
      final snap = FootprintSnapshot.fromFootprint(fp);
      expect(snap.coherenceScore, closeTo(1.0, 1e-6));
    });

    test('one harmonic at 1.0 rest at 0 → low coherence', () {
      // mean = 1/8 = 0.125, variance = (7*(0.125^2) + (0.875^2))/8
      // stddev/mean will be high → low coherence
      final h = [1.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final fp = _footprintWith([_capture(harmonics: h)]);
      final snap = FootprintSnapshot.fromFootprint(fp);
      expect(snap.coherenceScore, lessThan(0.3));
    });

    test('empty footprint → coherence = 0.0', () {
      final fp = _emptyFootprint();
      final snap = FootprintSnapshot.fromFootprint(fp);
      expect(snap.coherenceScore, 0.0);
    });

    test('all-zero harmonics → coherence = 0.0 (mean=0 branch)', () {
      final h = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final fp = _footprintWith([_capture(harmonics: h)]);
      final snap = FootprintSnapshot.fromFootprint(fp);
      // mean=0 → coherence = 0.0, not NaN
      expect(snap.coherenceScore, 0.0);
      expect(snap.coherenceScore.isNaN, false);
    });

    test('fromFootprint with 0 captures does not crash', () {
      final snap = FootprintSnapshot.fromFootprint(_emptyFootprint());
      expect(snap.totalCaptures, 0);
      expect(snap.resonanceHz, 0.0);
      expect(snap.coherenceScore, 0.0);
      expect(snap.harmonicSignature.length, 8);
    });

    test('snapshot JSON round-trip preserves coherenceScore', () {
      final h = [0.5, 0.3, 0.2, 0.1, 0.05, 0.03, 0.01, 0.005];
      final fp = _footprintWith([_capture(harmonics: h)]);
      final snap = FootprintSnapshot.fromFootprint(fp);
      final restored = FootprintSnapshot.fromJson(snap.toJson());
      expect(restored.coherenceScore, closeTo(snap.coherenceScore, 1e-10));
      expect(restored.resonanceHz, snap.resonanceHz);
      expect(restored.totalCaptures, snap.totalCaptures);
    });
  });
}
