import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/domain/models/incienso_session.dart';

InciensoSession _mk({
  Duration practice = const Duration(minutes: 10),
  Duration suggested = const Duration(minutes: 10),
  int total = 0,
  int qualifying = 0,
  double avgCoherence = 0.0,
  double left = 200,
  double right = 210,
  double avgBreathMs = 0,
}) {
  final start = DateTime(2024, 1, 1, 12);
  return InciensoSession(
    id: 'x',
    inciensoId: 'p1',
    startedAt: start,
    endedAt: start.add(practice),
    suggestedDuration: suggested,
    totalBreathCycles: total,
    inciensoCount: qualifying,
    avgCoherence: avgCoherence,
    carrierLeftHz: left,
    carrierRightHz: right,
    avgBreathCycleMs: avgBreathMs,
  );
}

void main() {
  group('InciensoSession - duration / completion', () {
    test('completed = duration >= suggestedDuration', () {
      expect(_mk(practice: const Duration(minutes: 10),
                 suggested: const Duration(minutes: 10)).completed, isTrue);
      expect(_mk(practice: const Duration(minutes: 9, seconds: 59),
                 suggested: const Duration(minutes: 10)).completed, isFalse);
    });

    test('completionRatio == 1.0 at exact match', () {
      expect(_mk().completionRatio, closeTo(1.0, 1e-9));
    });

    test('completionRatio can exceed 1 when overtime', () {
      final s = _mk(practice: const Duration(minutes: 15),
                    suggested: const Duration(minutes: 10));
      expect(s.completionRatio, closeTo(1.5, 1e-9));
    });

    test('completionRatio guards against zero suggested duration', () {
      final s = _mk(suggested: Duration.zero);
      expect(s.completionRatio, 0.0);
      expect(() => s.completionRatio, returnsNormally);
    });
  });

  group('InciensoSession - quality math', () {
    test('qualityRatio guards against zero breaths', () {
      expect(_mk(total: 0, qualifying: 0).qualityRatio, 0.0);
    });

    test('qualityRatio = 1 when every breath qualifies', () {
      expect(_mk(total: 10, qualifying: 10).qualityRatio, 1.0);
    });

    test('quality tier boundaries: 0.49=explorer, 0.50=practitioner, 0.80=master', () {
      expect(_mk(total: 100, qualifying: 49).qualityTier,
             InciensoQualityTier.explorer);
      expect(_mk(total: 100, qualifying: 50).qualityTier,
             InciensoQualityTier.practitioner);
      expect(_mk(total: 100, qualifying: 79).qualityTier,
             InciensoQualityTier.practitioner);
      expect(_mk(total: 100, qualifying: 80).qualityTier,
             InciensoQualityTier.master);
    });

    test('inciensoScore formula uses minutes, count, coherence', () {
      // count=10, coherence=0.8, 5 min  ->  10 * 0.8 * 5 / 10 = 4.0
      final s = _mk(
        practice: const Duration(minutes: 5),
        total: 12, qualifying: 10, avgCoherence: 0.8,
      );
      expect(s.inciensoScore, closeTo(4.0, 1e-9));
    });

    test('inciensoScore is zero when duration < 1 minute', () {
      final s = _mk(
        practice: const Duration(seconds: 30),
        total: 12, qualifying: 10, avgCoherence: 0.8,
      );
      // duration.inMinutes truncates to 0
      expect(s.inciensoScore, 0.0);
    });
  });

  group('InciensoSession - audio derived metrics', () {
    test('binauralBeatHz = |R - L|', () {
      expect(_mk(left: 200, right: 210).binauralBeatHz, 10);
      expect(_mk(left: 210, right: 200).binauralBeatHz, 10);
      expect(_mk(left: 200, right: 200).binauralBeatHz, 0);
    });

    test('breathsPerMinute computes 60000/avgBreathCycleMs', () {
      expect(_mk(avgBreathMs: 6000).breathsPerMinute, closeTo(10, 1e-9));
    });

    test('breathsPerMinute is 0 when avgBreathCycleMs is 0', () {
      expect(_mk(avgBreathMs: 0).breathsPerMinute, 0);
    });
  });

  group('InciensoSession - JSON round trip', () {
    test('toJson/fromJson preserves core fields', () {
      final s = _mk(
        practice: const Duration(minutes: 7),
        suggested: const Duration(minutes: 10),
        total: 30, qualifying: 22, avgCoherence: 0.74,
        left: 195.5, right: 205.5, avgBreathMs: 5500,
      );
      final restored = InciensoSession.fromJson(s.toJson());
      expect(restored.totalBreathCycles, 30);
      expect(restored.inciensoCount, 22);
      expect(restored.avgCoherence, closeTo(0.74, 1e-9));
      expect(restored.carrierLeftHz, 195.5);
      expect(restored.carrierRightHz, 205.5);
      expect(restored.avgBreathCycleMs, 5500);
      expect(restored.duration, const Duration(minutes: 7));
      expect(restored.suggestedDuration, const Duration(minutes: 10));
    });

    test('fromJson defaults endReason to completed when unknown', () {
      final s = _mk();
      final json = s.toJson();
      json['endReason'] = 'martian_invasion';
      final restored = InciensoSession.fromJson(json);
      expect(restored.endReason, InciensoSessionEnd.completed);
    });
  });
}
