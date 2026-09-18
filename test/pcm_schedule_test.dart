import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/engine/audio/neom_pcm_schedule.dart';

void main() {
  test('an immediate consumer cannot accumulate an unbounded PCM queue', () {
    final schedule = NeomPcmSchedule(sampleRate: 44100, leadSeconds: 0.004);
    var now = 0.0;
    for (var buffer = 0; buffer < 100000; buffer++) {
      now += schedule.waitSeconds(now, 1024) + 0.000000001;
      schedule.reserve(now, 1024);
      expect(schedule.remainingSeconds(now), lessThanOrEqualTo(0.080000001));
    }
    // Approx. 38 minutes of synthesis, not an immediate 38-minute queue.
    expect(now, greaterThan(2300));
  });

  test(
    'played frame clock excludes future PCM and preserves underrun gaps',
    () {
      final schedule = NeomPcmSchedule(sampleRate: 1000, leadSeconds: 0.004);
      expect(schedule.reserve(10, 20), 10.004);
      expect(schedule.playedFramesAt(10), 0);
      expect(schedule.playedFramesAt(10.0141), 10);
      expect(schedule.playedFramesAt(10.025), 20);
      // Suspended/throttled producer: do not count the silent gap as synthesis.
      expect(schedule.reserve(30, 20), 30.004);
      expect(schedule.playedFramesAt(30.000), 20);
      expect(schedule.playedFramesAt(30.0141), 30);
      expect(schedule.playedFramesAt(31), 40);
    },
  );

  test('last partial PCM buffer preserves exact final sample count', () {
    final schedule = NeomPcmSchedule(sampleRate: 44100);
    schedule.reserve(0, 1024);
    schedule.reserve(0, 276);
    expect(schedule.playedFramesAt(1), 1300);
  });

  test('producer without backpressure and oversized buffers are rejected', () {
    final schedule = NeomPcmSchedule(sampleRate: 1000);
    schedule.reserve(0, 60);
    expect(() => schedule.reserve(0, 30), throwsStateError);
    expect(() => schedule.reserve(1, 100), throwsArgumentError);
    expect(() => schedule.reserve(1, 0), throwsArgumentError);
  });
}
