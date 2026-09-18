import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/ui/widgets/visual_animation.dart';

class _BuildCounts {
  int builder = 0;
  int child = 0;
  int disposes = 0;
}

class _Probe extends StatefulWidget {
  const _Probe(this.counts);
  final _BuildCounts counts;

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> {
  @override
  Widget build(BuildContext context) {
    widget.counts.child++;
    return const SizedBox(width: 40, height: 40);
  }

  @override
  void dispose() {
    widget.counts.disposes++;
    super.dispose();
  }
}

class _Fixture {
  final counts = _BuildCounts();
  VisualAnimationClock? clock;

  Widget build({
    bool active = true,
    bool visible = true,
    bool reduced = false,
  }) => Directionality(
    textDirection: TextDirection.ltr,
    child: MediaQuery(
      data: MediaQueryData(disableAnimations: reduced),
      child: TickerMode(
        enabled: visible,
        child: VisualAnimation(
          active: active,
          child: _Probe(counts),
          builder: (_, value, child) {
            clock = value;
            counts.builder++;
            return child!;
          },
        ),
      ),
    ),
  );
}

Future<void> _frames(
  WidgetTester tester,
  int count, [
  Duration frame = const Duration(microseconds: 8334),
]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(frame);
  }
}

void main() {
  testWidgets('fractional display intervals keep the target paint cadence', (
    tester,
  ) async {
    for (final micros in [16666, 8333, 6944, 4166]) {
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.build());
      await tester.pump();
      var notifications = 0;
      fixture.clock!.addListener(() => notifications++);
      await _frames(tester, 1000000 ~/ micros, Duration(microseconds: micros));
      expect(notifications, inInclusiveRange(29, 30));
      await tester.pumpWidget(const SizedBox.shrink());
    }
  });

  testWidgets('reduced motion freezes decoration, not informational refresh', (
    tester,
  ) async {
    late VisualAnimationClock information;
    late VisualAnimationClock decoration;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: VisualActivityScope(
            child: Column(
              children: [
                VisualAnimation(
                  respectReducedMotion: false,
                  frameInterval: const Duration(seconds: 1),
                  builder: (_, clock, _) {
                    information = clock;
                    return const SizedBox();
                  },
                ),
                VisualAnimation(
                  builder: (_, clock, _) {
                    decoration = clock;
                    return const SizedBox();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    var notifications = 0;
    information.addListener(() => notifications++);
    await _frames(tester, 125);
    expect(notifications, 1);
    expect(decoration.elapsed, Duration.zero);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    await tester.pump();
    final stopped = information.elapsed;
    await _frames(tester, 125);
    expect(information.elapsed, stopped);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpWidget(const SizedBox.shrink());
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    '120 Hz frames notify painters at most 30 times per second without rebuilding',
    (tester) async {
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.build());
      await tester.pump();
      final clock = fixture.clock!;
      var notifications = 0;
      clock.addListener(() => notifications++);
      final builder = fixture.counts.builder;
      final child = fixture.counts.child;
      await _frames(tester, 120);
      expect(notifications, inInclusiveRange(29, 30));
      expect(clock.elapsed.inMicroseconds, closeTo(1000000, 10000));
      expect(fixture.counts.builder, builder);
      expect(fixture.counts.child, child);
      expect(fixture.counts.disposes, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(fixture.counts.disposes, 1);
      final stopped = notifications;
      await _frames(tester, 30);
      expect(notifications, stopped);
      expect(tester.takeException(), isNull);
    },
  );

  for (final gate in ['inactive', 'TickerMode', 'reducedMotion']) {
    testWidgets(
      '$gate freezes phase and notifications, then resumes the same clock',
      (tester) async {
        final fixture = _Fixture();
        await tester.pumpWidget(fixture.build());
        await _frames(tester, 12);
        final clock = fixture.clock!;
        var notifications = 0;
        clock.addListener(() => notifications++);
        await tester.pumpWidget(
          fixture.build(
            active: gate != 'inactive',
            visible: gate != 'TickerMode',
            reduced: gate == 'reducedMotion',
          ),
        );
        final elapsed = clock.elapsed;
        final phase = clock.value;
        final before = notifications;
        expect(clock.isAnimating, isFalse);
        await _frames(tester, 60);
        expect(clock.elapsed, elapsed);
        expect(clock.value, phase);
        expect(notifications, before);
        expect(fixture.counts.disposes, 0);

        await tester.pumpWidget(fixture.build());
        expect(fixture.clock, same(clock));
        expect(clock.isAnimating, isTrue);
        await _frames(tester, 12);
        expect(clock.elapsed, greaterThan(elapsed));
        expect(notifications, greaterThan(before));
        expect(fixture.counts.disposes, 0);
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }

  for (final lifecycle in [
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    testWidgets(
      '${lifecycle.name} suspends visual time without a jump on resume',
      (tester) async {
        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        addTearDown(
          () => tester.binding.handleAppLifecycleStateChanged(
            AppLifecycleState.resumed,
          ),
        );
        final fixture = _Fixture();
        await tester.pumpWidget(fixture.build());
        await _frames(tester, 12);
        final clock = fixture.clock!;
        var notifications = 0;
        clock.addListener(() => notifications++);
        tester.binding.handleAppLifecycleStateChanged(lifecycle);
        expect(clock.isAnimating, isFalse);
        final elapsed = clock.elapsed;
        final phase = clock.value;
        await tester.pump(const Duration(seconds: 10));
        expect(clock.elapsed, elapsed);
        expect(clock.value, phase);
        expect(notifications, 0);

        tester.binding.handleAppLifecycleStateChanged(
          AppLifecycleState.resumed,
        );
        await tester.pump();
        expect(
          clock.elapsed,
          elapsed,
          reason: 'Background wall time is excluded',
        );
        await _frames(tester, 12);
        expect(
          clock.elapsed - elapsed,
          lessThanOrEqualTo(const Duration(milliseconds: 101)),
        );
        expect(clock.elapsed, greaterThan(elapsed));
        expect(notifications, greaterThan(0));
        await tester.pumpWidget(const SizedBox.shrink());
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'initial inactive/reduced/TickerMode state schedules no animation',
    (tester) async {
      for (final config in [
        (false, true, false),
        (true, false, false),
        (true, true, true),
      ]) {
        final fixture = _Fixture();
        await tester.pumpWidget(
          fixture.build(
            active: config.$1,
            visible: config.$2,
            reduced: config.$3,
          ),
        );
        final clock = fixture.clock!;
        var notifications = 0;
        clock.addListener(() => notifications++);
        await _frames(tester, 60);
        expect(clock.isAnimating, isFalse);
        expect(clock.elapsed, Duration.zero);
        expect(clock.value, 0);
        expect(notifications, 0);
        await tester.pumpWidget(const SizedBox.shrink());
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'disposal detaches lifecycle observer and leaves no active ticker',
    (tester) async {
      final fixture = _Fixture();
      await tester.pumpWidget(fixture.build());
      await _frames(tester, 10);
      await tester.pumpWidget(const SizedBox.shrink());
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump(const Duration(seconds: 1));
      expect(fixture.counts.disposes, 1);
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
