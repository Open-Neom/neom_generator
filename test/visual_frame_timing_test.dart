import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/engine/visual_frame_timing.dart';

void main() {
  test('real delta is incremental, not the cumulative ticker duration', () {
    final clock = VisualFrameTiming();
    final first = clock.advance(
      const Duration(milliseconds: 16),
      visualEnabled: true,
    );
    final second = clock.advance(
      const Duration(milliseconds: 32),
      visualEnabled: true,
    );
    final third = clock.advance(
      const Duration(milliseconds: 48),
      visualEnabled: true,
    );

    expect(first.deltaSeconds, closeTo(0.016, 0.000001));
    expect(second.deltaSeconds, closeTo(0.016, 0.000001));
    expect(third.deltaSeconds, closeTo(0.016, 0.000001));
    expect(first.visualDeltaSeconds, isNull);
    expect(second.visualDeltaSeconds, isNull);
    expect(third.visualDeltaSeconds, closeTo(0.048, 0.000001));
  });

  for (final refreshRate in [60, 120, 144, 240]) {
    test('dispatches about 30 visual frames at $refreshRate Hz', () {
      final clock = VisualFrameTiming();
      var visualFrames = 0;
      var realSeconds = 0.0;
      var visualSeconds = 0.0;

      for (var tick = 0; tick <= refreshRate * 10; tick++) {
        final frame = clock.advance(
          Duration(microseconds: (tick * 1000000 / refreshRate).round()),
          visualEnabled: true,
        );
        realSeconds += frame.deltaSeconds;
        if (frame.visualDeltaSeconds != null) {
          visualFrames++;
          visualSeconds += frame.visualDeltaSeconds!;
        }
      }

      expect(visualFrames, inInclusiveRange(299, 300));
      expect(realSeconds, closeTo(10, 0.000001));
      expect(visualSeconds, closeTo(10, 0.04));
    });
  }

  test('reset discards the previous ticker duration on restart', () {
    final clock = VisualFrameTiming();
    clock.advance(const Duration(seconds: 10), visualEnabled: true);
    clock.reset();
    final first = clock.advance(Duration.zero, visualEnabled: true);
    final second = clock.advance(
      const Duration(milliseconds: 34),
      visualEnabled: true,
    );

    expect(first.deltaSeconds, 0);
    expect(first.visualDeltaSeconds, isNull);
    expect(second.deltaSeconds, closeTo(0.034, 0.000001));
    expect(second.visualDeltaSeconds, closeTo(0.034, 0.000001));
  });

  test('suspension caps visual movement but keeps the full real delta', () {
    final clock = VisualFrameTiming();
    clock.advance(Duration.zero, visualEnabled: true);
    final resumed = clock.advance(
      const Duration(seconds: 30),
      visualEnabled: true,
    );

    expect(resumed.deltaSeconds, 30);
    expect(resumed.visualDeltaSeconds, 0.1);
    final next = clock.advance(
      const Duration(seconds: 30, milliseconds: 34),
      visualEnabled: true,
    );
    expect(next.visualDeltaSeconds, closeTo(0.034, 0.000001));
  });

  test(
    'hidden ticks retain real time and do not dispatch or accumulate visuals',
    () {
      final clock = VisualFrameTiming();
      clock.advance(Duration.zero, visualEnabled: true);
      final hidden = clock.advance(
        const Duration(seconds: 1),
        visualEnabled: false,
      );
      final stillHidden = clock.advance(
        const Duration(seconds: 2),
        visualEnabled: false,
      );
      final resumed = clock.advance(
        const Duration(seconds: 30),
        visualEnabled: true,
      );
      final visible = clock.advance(
        const Duration(seconds: 30, milliseconds: 34),
        visualEnabled: true,
      );

      expect(hidden.deltaSeconds, 1);
      expect(stillHidden.deltaSeconds, 1);
      expect(resumed.deltaSeconds, 28);
      expect(hidden.visualDeltaSeconds, isNull);
      expect(stillHidden.visualDeltaSeconds, isNull);
      expect(resumed.visualDeltaSeconds, isNull);
      expect(visible.visualDeltaSeconds, closeTo(0.034, 0.000001));
    },
  );

  test(
    'lifecycle reset preserves tracking when no hidden ticks are delivered',
    () {
      final clock = VisualFrameTiming();
      clock.advance(const Duration(milliseconds: 34), visualEnabled: true);
      clock.resetVisual();
      final resumed = clock.advance(
        const Duration(seconds: 20, milliseconds: 34),
        visualEnabled: true,
      );

      expect(resumed.deltaSeconds, 20);
      expect(resumed.visualDeltaSeconds, isNull);
      final next = clock.advance(
        const Duration(seconds: 20, milliseconds: 68),
        visualEnabled: true,
      );
      expect(next.visualDeltaSeconds, closeTo(0.034, 0.000001));
    },
  );
}
