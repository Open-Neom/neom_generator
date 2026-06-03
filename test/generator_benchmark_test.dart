import 'package:flutter_test/flutter_test.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';

import '../lib/domain/models/incienso.dart';
import '../lib/domain/models/incienso_session.dart';

void main() {
  group('🚀 Cámara Neom & INCIENSO Performance Benchmarks', () {
    
    test('1. Benchmark: Interpolación de Línea de Tiempo (timeline playback)', () {
      // Setup a large timeline with 1,000 keyframes (approx. 16 minutes of session)
      final List<InciensoKeyframe> timeline = List.generate(
        1000,
        (i) => InciensoKeyframe(
          timestampMs: i * 1000.0,
          leftHz: 200.0 + (i % 20) * 2,
          rightHz: 210.0 + (i % 20) * 2 + (i % 10),
          coherence: 0.5 + (i % 10) * 0.05,
          volume: 0.7,
        ),
      );

      final stopwatch = Stopwatch()..start();

      // Simulate 100,000 timeline lookups (typical of a highly active real-time slider/visualizer)
      int lookups = 100000;
      double dummyResult = 0;

      for (int step = 0; step < lookups; step++) {
        final elapsedMs = (step % 1000) * 1000.0 + 250.0; // Seek in the middle of keyframes

        // Inline binary seek or bracket seek similar to _startTimelinePlayback
        int lo = 0;
        for (int i = 1; i < timeline.length; i++) {
          if (timeline[i].timestampMs > elapsedMs) break;
          lo = i;
        }
        final hi = (lo + 1).clamp(0, timeline.length - 1);

        final a = timeline[lo];
        final b = timeline[hi];

        final span = b.timestampMs - a.timestampMs;
        final t = span > 0 ? ((elapsedMs - a.timestampMs) / span).clamp(0.0, 1.0) : 1.0;

        final leftHz = a.leftHz + (b.leftHz - a.leftHz) * t;
        final rightHz = a.rightHz + (b.rightHz - a.rightHz) * t;
        
        dummyResult += leftHz + rightHz; // Prevent compiler optimization discarding loop
      }

      stopwatch.stop();
      final ms = stopwatch.elapsedMilliseconds;
      final avgMicroseconds = (stopwatch.elapsedMicroseconds / lookups).toStringAsFixed(2);

      print('--------------------------------------------------');
      print('📊 BENCHMARK: TIMELINE PLAYBACK INTERPOLATOR');
      print('  - Total Lookups: $lookups');
      print('  - Total Time: ${ms}ms');
      print('  - Avg Time per Lookup: $avgMicroseconds µs');
      print('  - Dummy Output Verification: ${dummyResult.toStringAsFixed(0)}');
      print('--------------------------------------------------');

      expect(ms, lessThan(800)); // Should run 100k seeking ops in under 800ms
    });

    test('2. Benchmark: Serialización JSON (Incienso toJson / fromJson)', () {
      final List<InciensoKeyframe> timeline = List.generate(
        500,
        (i) => InciensoKeyframe(
          timestampMs: i * 1000.0,
          leftHz: 200.0 + i * 0.1,
          rightHz: 210.0 + i * 0.1,
          coherence: 0.8,
          neuroState: 'calm',
        ),
      );

      final Incienso original = Incienso(
        id: 'bench_preset_1',
        names: {'es': 'Preset de Benchmark', 'en': 'Benchmark Preset'},
        leftFrequencyHz: 200,
        rightFrequencyHz: 210,
        suggestedDuration: const Duration(minutes: 10),
        timeline: timeline,
        source: InciensoSource.userCreated,
      );

      final stopwatch = Stopwatch()..start();

      // Measure 50 rounds of complete JSON serialization & parsing (typical sync workload)
      int rounds = 50;
      for (int i = 0; i < rounds; i++) {
        final jsonMap = original.toJson();
        final Incienso parsed = Incienso.fromJson(jsonMap);
        expect(parsed.id, equals('bench_preset_1'));
        expect(parsed.timeline.length, equals(500));
      }

      stopwatch.stop();
      final ms = stopwatch.elapsedMilliseconds;
      final avgMs = (ms / rounds).toStringAsFixed(2);

      print('--------------------------------------------------');
      print('📊 BENCHMARK: JSON ROUND-TRIP (500 KEYFRAMES)');
      print('  - Total Rounds: $rounds');
      print('  - Total Time: ${ms}ms');
      print('  - Avg Round-trip Time: ${avgMs}ms');
      print('--------------------------------------------------');

      expect(ms, lessThan(400)); // Should serialize/parse 500 nodes under 400ms total
    });
  });
}
