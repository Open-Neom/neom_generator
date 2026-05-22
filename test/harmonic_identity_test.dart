import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/domain/models/harmonic/harmonic_capture.dart';
import 'package:neom_generator/domain/models/harmonic/harmonic_footprint.dart';
import 'package:neom_generator/domain/models/harmonic/vocal_emotional_state.dart';
import 'package:neom_generator/domain/models/harmonic/vocal_range.dart';
import 'package:neom_generator/domain/models/harmonic/sonic_avatar.dart';
import 'package:neom_generator/data/implementations/harmonic/resonance_bridge.dart';
import 'package:neom_generator/engine/neom_sine_engine.dart';

// ─── Helpers ────────────────────────────────────────────────────────────────

HarmonicCapture _cap({
  double hz = 220.0,
  double centroid = 1200.0,
  List<double>? harmonics,
  double volume = 0.5,
  double pitchMin = 200.0,
  double pitchMax = 250.0,
}) {
  return HarmonicCapture(
    id: 'c-${DateTime.now().microsecondsSinceEpoch}',
    timestamp: DateTime(2026, 1, 1),
    fundamentalHz: hz,
    volumeDb: volume,
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
  // VocalEmotionalState.classify
  // ═══════════════════════════════════════════════════════════════════════════

  group('VocalEmotionalState.classify', () {
    test('high centroid + high volume → tense', () {
      expect(
        VocalEmotionalState.classify(spectralCentroid: 2000, volume: 0.8),
        VocalEmotionalState.tense,
      );
    });

    test('high centroid + low volume → focused', () {
      expect(
        VocalEmotionalState.classify(spectralCentroid: 2000, volume: 0.3),
        VocalEmotionalState.focused,
      );
    });

    test('low centroid + high volume → energized', () {
      expect(
        VocalEmotionalState.classify(spectralCentroid: 600, volume: 0.8),
        VocalEmotionalState.energized,
      );
    });

    test('low centroid + low volume → calm', () {
      expect(
        VocalEmotionalState.classify(spectralCentroid: 600, volume: 0.3),
        VocalEmotionalState.calm,
      );
    });

    test('boundary: centroid exactly 1500, volume exactly 0.6 → calm', () {
      // bright = 1500 > 1500 → false; loud = 0.6 > 0.6 → false
      // !bright && !loud → calm
      expect(
        VocalEmotionalState.classify(spectralCentroid: 1500, volume: 0.6),
        VocalEmotionalState.calm,
      );
    });

    test('boundary: centroid 1501, volume 0.61 → tense', () {
      expect(
        VocalEmotionalState.classify(spectralCentroid: 1501, volume: 0.61),
        VocalEmotionalState.tense,
      );
    });

    test('negative centroid → calm (not crash)', () {
      // -100 > 1500 → false, volume 0.5 > 0.6 → false → calm
      expect(
        VocalEmotionalState.classify(spectralCentroid: -100, volume: 0.5),
        VocalEmotionalState.calm,
      );
    });

    test('volume > 1.0 → still classifies', () {
      // centroid 2000 > 1500 → bright, volume 5.0 > 0.6 → loud → tense
      expect(
        VocalEmotionalState.classify(spectralCentroid: 2000, volume: 5.0),
        VocalEmotionalState.tense,
      );
    });

    test('volume = 0.0, centroid = 0.0 → calm', () {
      expect(
        VocalEmotionalState.classify(spectralCentroid: 0, volume: 0),
        VocalEmotionalState.calm,
      );
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // SonicAvatar
  // ═══════════════════════════════════════════════════════════════════════════

  group('SonicAvatar.fromFootprint', () {
    test('0 captures → default avatar, does not crash', () {
      final fp = HarmonicFootprint(userId: 'u-empty');
      final avatar = SonicAvatar.fromFootprint(fp);
      expect(avatar.resonanceHz, 0.0);
      expect(avatar.sampleCount, 0);
      expect(avatar.steadiness, 0.0);
      expect(avatar.brightness, 0.5);
      expect(avatar.signature.length, 8);
      // Default signature: all 0.125
      for (final v in avatar.signature) {
        expect(v, closeTo(0.125, 1e-10));
      }
    });

    test('1 capture → valid avatar', () {
      final fp = _fp(hz: 330, centroid: 1500, count: 1);
      final avatar = SonicAvatar.fromFootprint(fp);
      expect(avatar.resonanceHz, 330.0);
      expect(avatar.sampleCount, 1);
      expect(avatar.vocalRange, VocalRange.classify(330.0));
    });

    test('steadiness with 1 capture → 1.0', () {
      final fp = _fp(hz: 200, count: 1);
      final avatar = SonicAvatar.fromFootprint(fp);
      // Less than 2 pitches → steadiness stays at 1.0
      expect(avatar.steadiness, 1.0);
    });

    test('steadiness with identical pitches → 1.0', () {
      final fp = _fp(hz: 440, count: 10);
      final avatar = SonicAvatar.fromFootprint(fp);
      // All same pitch → variance = 0, CV = 0, steadiness = 1.0
      expect(avatar.steadiness, closeTo(1.0, 1e-6));
    });

    test('steadiness with wildly varying pitches → low', () {
      final fp = HarmonicFootprint(
        userId: 'u-wild',
        captures: [
          _cap(hz: 100),
          _cap(hz: 500),
          _cap(hz: 100),
          _cap(hz: 500),
          _cap(hz: 100),
          _cap(hz: 500),
        ],
      );
      final avatar = SonicAvatar.fromFootprint(fp);
      expect(avatar.steadiness, lessThan(0.5));
    });

    test('brightness: centroid 200 → 0.0', () {
      final fp = _fp(hz: 220, centroid: 200, count: 3);
      final avatar = SonicAvatar.fromFootprint(fp);
      expect(avatar.brightness, closeTo(0.0, 1e-6));
    });

    test('brightness: centroid 4000 → ~1.0', () {
      final fp = _fp(hz: 220, centroid: 4000, count: 3);
      final avatar = SonicAvatar.fromFootprint(fp);
      expect(avatar.brightness, closeTo(1.0, 1e-6));
    });

    test('brightness: centroid below 200 → clamped to 0', () {
      final fp = _fp(hz: 220, centroid: 50, count: 3);
      final avatar = SonicAvatar.fromFootprint(fp);
      expect(avatar.brightness, 0.0);
    });

    test('brightness: centroid above 4000 → clamped to 1.0', () {
      final fp = _fp(hz: 220, centroid: 6000, count: 3);
      final avatar = SonicAvatar.fromFootprint(fp);
      expect(avatar.brightness, 1.0);
    });

    test('all-zero harmonics → signature = uniform 0.125', () {
      final h = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
      final fp = _fp(harmonics: h, count: 3);
      final avatar = SonicAvatar.fromFootprint(fp);
      // sum=0 → fallback to uniform
      for (final v in avatar.signature) {
        expect(v, closeTo(0.125, 1e-10));
      }
    });
  });

  group('SonicAvatar compact string', () {
    test('toCompactString → fromCompactString round-trip', () {
      final fp = _fp(hz: 256, centroid: 1800, count: 5);
      final avatar = SonicAvatar.fromFootprint(fp);
      final compact = avatar.toCompactString();
      final restored = SonicAvatar.fromCompactString(compact);

      expect(restored, isNotNull);
      expect(restored!.resonanceHz, closeTo(avatar.resonanceHz, 0.1));
      expect(restored.brightness, closeTo(avatar.brightness, 0.01));
      expect(restored.steadiness, closeTo(avatar.steadiness, 0.01));
      for (int i = 0; i < 8; i++) {
        expect(restored.signature[i], closeTo(avatar.signature[i], 0.001));
      }
    });

    test('fromCompactString with garbage → returns null', () {
      expect(SonicAvatar.fromCompactString('not-a-valid-string'), isNull);
    });

    test('fromCompactString with wrong prefix → returns null', () {
      expect(SonicAvatar.fromCompactString('XX:220.0:0.1:0.1:0.1:0.1:0.1:0.1:0.1:0.1:0.50:0.90'), isNull);
    });

    test('fromCompactString with missing fields → returns null', () {
      // Only 5 parts instead of 12
      expect(SonicAvatar.fromCompactString('SA:220.0:0.1:0.1:0.1'), isNull);
    });

    test('fromCompactString with non-numeric fields → returns null', () {
      expect(SonicAvatar.fromCompactString('SA:abc:0.1:0.1:0.1:0.1:0.1:0.1:0.1:0.1:0.50:0.90'), isNull);
    });

    test('compact string starts with SA: prefix', () {
      final fp = _fp(hz: 300, count: 2);
      final avatar = SonicAvatar.fromFootprint(fp);
      expect(avatar.toCompactString().startsWith('SA:'), true);
    });
  });

  // ═══════════════════════════════════════════════════════════════════════════
  // ResonanceBridge
  // ═══════════════════════════════════════════════════════════════════════════

  group('ResonanceBridge', () {
    late NeomSineEngine engine;

    setUp(() {
      // Reset singleton state for each test
      engine = NeomSineEngine();
      engine.frequency = 432.0; // default
    });

    test('apply with null footprint → frequency unchanged', () {
      ResonanceBridge.apply(null, engine);
      expect(engine.frequency, 432.0);
    });

    test('apply with 0 captures → frequency unchanged', () {
      final fp = HarmonicFootprint(userId: 'u-empty');
      ResonanceBridge.apply(fp, engine);
      expect(engine.frequency, 432.0);
    });

    test('apply with valid footprint → frequency = resonanceHz', () {
      final fp = _fp(hz: 256, count: 5);
      ResonanceBridge.apply(fp, engine);
      expect(engine.frequency, 256.0);
    });

    test('apply with resonanceHz < 20 → frequency unchanged', () {
      // resonanceHz = 10 (all captures at 10 Hz)
      final fp = _fp(hz: 10, count: 5);
      ResonanceBridge.apply(fp, engine);
      expect(engine.frequency, 432.0);
    });

    test('apply with resonanceHz > 2500 → frequency unchanged', () {
      final fp = _fp(hz: 3000, count: 5);
      ResonanceBridge.apply(fp, engine);
      expect(engine.frequency, 432.0);
    });

    test('apply with resonanceHz exactly 20 → frequency updated', () {
      final fp = _fp(hz: 20, count: 5);
      ResonanceBridge.apply(fp, engine);
      expect(engine.frequency, 20.0);
    });

    test('apply with resonanceHz exactly 2500 → frequency updated', () {
      final fp = _fp(hz: 2500, count: 5);
      ResonanceBridge.apply(fp, engine);
      expect(engine.frequency, 2500.0);
    });
  });

  group('ResonanceBridge.personalizedConfig', () {
    test('high centroid (>2000) → alpha target (10 Hz beat)', () {
      final fp = _fp(hz: 300, centroid: 2500, count: 3);
      final config = ResonanceBridge.personalizedConfig(fp);
      expect(config.beatHz, 10.0);
      expect(config.targetState, 'alpha');
    });

    test('low centroid (<800) → beta target (18 Hz beat)', () {
      final fp = _fp(hz: 300, centroid: 500, count: 3);
      final config = ResonanceBridge.personalizedConfig(fp);
      expect(config.beatHz, 18.0);
      expect(config.targetState, 'beta');
    });

    test('mid centroid (800-2000) → theta target (6 Hz beat)', () {
      final fp = _fp(hz: 300, centroid: 1200, count: 3);
      final config = ResonanceBridge.personalizedConfig(fp);
      expect(config.beatHz, 6.0);
      expect(config.targetState, 'theta');
    });

    test('carrierHz clamped to 80-2500 range', () {
      // resonanceHz = 10 (below 80)
      final fp = _fp(hz: 10, centroid: 1200, count: 3);
      final config = ResonanceBridge.personalizedConfig(fp);
      expect(config.carrierHz, greaterThanOrEqualTo(80.0));
    });

    test('centroid exactly 2000 → theta (not alpha)', () {
      // > 2000 is alpha, so exactly 2000 is NOT > 2000 → falls to else → theta
      final fp = _fp(hz: 300, centroid: 2000, count: 3);
      final config = ResonanceBridge.personalizedConfig(fp);
      expect(config.targetState, 'theta');
    });

    test('centroid exactly 800 → theta (not beta)', () {
      // < 800 is beta, so exactly 800 is NOT < 800 → falls to else → theta
      final fp = _fp(hz: 300, centroid: 800, count: 3);
      final config = ResonanceBridge.personalizedConfig(fp);
      expect(config.targetState, 'theta');
    });

    test('empty footprint → carrier clamped to 80 (resonanceHz=0)', () {
      final fp = HarmonicFootprint(userId: 'u-empty');
      final config = ResonanceBridge.personalizedConfig(fp);
      // resonanceHz=0, clamped to 80
      expect(config.carrierHz, 80.0);
      // centroid=0, <800 → beta
      expect(config.targetState, 'beta');
    });
  });
}
