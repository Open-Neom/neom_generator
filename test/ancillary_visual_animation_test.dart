import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_core/data/implementations/neom_stopwatch.dart';
import 'package:neom_generator/engine/neom_frequency_painter_engine.dart';
import 'package:neom_generator/ui/painters/lissajous_3d_painter.dart';
import 'package:neom_generator/ui/widgets/session_time_meter.dart';
import 'package:neom_generator/ui/widgets/visual_animation.dart';

Widget host(Widget child, {bool visible = true, bool reducedMotion = false}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: TickerMode(
          enabled: visible,
          child: Center(child: SizedBox(width: 300, height: 300, child: child)),
        ),
      ),
    );

Lissajous3DPainter painter(WidgetTester tester) =>
    tester
            .widget<CustomPaint>(
              find.descendant(
                of: find.byType(Lissajous3DWidget),
                matching: find.byType(CustomPaint),
              ),
            )
            .painter!
        as Lissajous3DPainter;

Future<void> frames(
  WidgetTester tester,
  int count, [
  Duration duration = const Duration(milliseconds: 40),
]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(duration);
  }
}

void main() {
  testWidgets(
    'Lissajous repaints without replacing its painter or audio state',
    (tester) async {
      final engine = NeomFrequencyPainterEngine();
      addTearDown(engine.dispose);
      await tester.pumpWidget(host(Lissajous3DWidget(engine: engine)));
      final before = painter(tester);
      final revision = engine.sampleRevision;
      await frames(tester, 20);
      expect(identical(painter(tester), before), isTrue);
      expect(before.trail.length, greaterThan(1));
      expect(engine.sampleRevision, revision);
      expect(engine.lissajousX, 0);
      expect(engine.lissajousY, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('Lissajous stops drawing under TickerMode and resumes', (
    tester,
  ) async {
    final engine = NeomFrequencyPainterEngine();
    addTearDown(engine.dispose);
    await tester.pumpWidget(host(Lissajous3DWidget(engine: engine)));
    await frames(tester, 10);
    await tester.pumpWidget(
      host(Lissajous3DWidget(engine: engine), visible: false),
    );
    final stopped = painter(tester).trail.length;
    await frames(tester, 20);
    expect(painter(tester).trail.length, stopped);
    await tester.pumpWidget(host(Lissajous3DWidget(engine: engine)));
    await frames(tester, 10);
    expect(painter(tester).trail.length, greaterThan(stopped));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Lissajous supports reduced motion and background suspension', (
    tester,
  ) async {
    final engine = NeomFrequencyPainterEngine();
    addTearDown(engine.dispose);
    await tester.pumpWidget(
      host(Lissajous3DWidget(engine: engine), reducedMotion: true),
    );
    final initial = painter(tester).trail.length;
    await frames(tester, 10);
    expect(painter(tester).trail.length, initial);
    await tester.pumpWidget(host(Lissajous3DWidget(engine: engine)));
    await frames(tester, 5);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    final paused = painter(tester).trail.length;
    await frames(tester, 20);
    expect(painter(tester).trail.length, paused);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await frames(tester, 5);
    expect(painter(tester).trail.length, greaterThan(paused));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Lissajous phase uses elapsed time, not a frame count', (
    tester,
  ) async {
    final engine = NeomFrequencyPainterEngine();
    addTearDown(engine.dispose);
    await tester.pumpWidget(host(Lissajous3DWidget(engine: engine)));
    await tester.pump(); // Establish the ticker's initial timestamp.
    await frames(tester, 50);
    final first = painter(tester).trail.last;
    final position = (first.x, first.y, first.z);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpWidget(host(Lissajous3DWidget(engine: engine)));
    await tester.pump();
    await frames(tester, 20, const Duration(milliseconds: 100));
    final second = painter(tester).trail.last;
    expect(second.x, closeTo(position.$1, 0.000001));
    expect(second.y, closeTo(position.$2, 0.000001));
    expect(second.z, closeTo(position.$3, 0.000001));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Lissajous trail is bounded by time and point count', (
    tester,
  ) async {
    final engine = NeomFrequencyPainterEngine();
    addTearDown(engine.dispose);
    await tester.pumpWidget(host(Lissajous3DWidget(engine: engine)));
    await frames(tester, 200);
    final trail = painter(tester).trail;
    expect(trail.length, lessThanOrEqualTo(Lissajous3DPainter.maxTrail));
    expect(
      trail.last.elapsed - trail.first.elapsed,
      lessThanOrEqualTo(const Duration(seconds: 5)),
    );
    expect(trail.first.elapsed, greaterThan(Duration.zero));
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Session display refreshes at 1 Hz without starting a session', (
    tester,
  ) async {
    const ref = 'ancillary_visual_test_unstarted_session';
    final stopwatch = NeomStopwatch();
    final originalReference = stopwatch.currentReference;
    await tester.pumpWidget(
      host(const SessionChamberTimeMeter(referenceId: ref, showTitle: false)),
    );
    expect(find.text('00:00'), findsOneWidget);
    final animation = tester.widget<AnimatedBuilder>(
      find.byType(AnimatedBuilder),
    );
    final clock = animation.animation as VisualAnimationClock;
    var notifications = 0;
    void count() => notifications++;
    clock.addListener(count);
    await frames(tester, 20); // 800 ms: the value still has second precision.
    expect(notifications, 0);
    await frames(tester, 10);
    expect(notifications, 1);
    expect(stopwatch.isRunning(ref: ref), isFalse);
    expect(stopwatch.elapsed(ref: ref), 0);
    expect(stopwatch.currentReference, originalReference);
    clock.removeListener(count);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
