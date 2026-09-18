import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/engine/neom_frequency_painter_engine.dart';
import 'package:neom_generator/ui/painters/circuit_wave_painter.dart';
import 'package:neom_generator/ui/painters/perimeter_wave_painter.dart';

class _Signal extends NeomFrequencyPainterEngine {
  double phase = 0;

  @override
  double get visualPhase => phase;

  @override
  double get waveStretch => 2.5;

  @override
  double get glowIntensity => 1;

  @override
  double get breathPulse => 1;
}

List<Path> _traces(CustomPainter painter, Size size) {
  final canvas = TestRecordingCanvas();
  painter.paint(canvas, size);
  expect(canvas.getSaveCount(), 0, reason: 'Every local clip must be restored');
  return canvas.invocations
      .map((record) => record.invocation)
      .where((call) => call.memberName == #drawPath)
      .where(
        (call) => (call.positionalArguments[1] as Paint).maskFilter == null,
      )
      .map((call) => call.positionalArguments.first as Path)
      .toList();
}

List<Offset> _samples(Path path) => [
  for (final metric in path.computeMetrics())
    for (double distance = 0; distance < metric.length; distance += 2)
      metric.getTangentForOffset(distance)!.position,
];

void _expectBorder(Path path, Rect rect) {
  final metric = path.computeMetrics().single;
  expect(metric.isClosed, isTrue);
  expect(path.getBounds(), rect);
  for (final point in _samples(path)) {
    expect(rect.inflate(.001).contains(point), isTrue);
    expect(
      rect.deflate(6).contains(point),
      isFalse,
      reason: 'The trace crossed the control interior at $point',
    );
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'separate columns have closed borders with no cross-panel connector',
    () {
      final engine = _Signal();
      addTearDown(engine.dispose);
      const left = Rect.fromLTWH(0, 0, 170, 230);
      const right = Rect.fromLTWH(510, 0, 170, 210);
      final paths = _traces(
        CircuitWavePainter(
          engine: engine,
          childBounds: [left, right],
          time: .7,
        ),
        const Size(680, 400),
      );
      expect(paths, hasLength(4));
      for (var i = 0; i < paths.length; i++) {
        _expectBorder(paths[i], i.isEven ? left : right);
      }
    },
  );

  test('a shared short gutter is its own contour, clear of both controls', () {
    final engine = _Signal();
    addTearDown(engine.dispose);
    const upper = Rect.fromLTWH(20, 20, 200, 150);
    const lower = Rect.fromLTWH(40, 182, 180, 110);
    final paths = _traces(
      CircuitWavePainter(
        engine: engine,
        childBounds: [upper, lower],
        time: 1.3,
      ),
      const Size(320, 340),
    );
    final loops = paths.where((path) => path.computeMetrics().single.isClosed);
    final bridges = paths.where(
      (path) => !path.computeMetrics().single.isClosed,
    );
    expect(loops, hasLength(4));
    expect(bridges, hasLength(2));
    for (final path in bridges) {
      expect(path.computeMetrics().single.length, lessThan(14));
      for (final point in _samples(path)) {
        expect(point.dy, inInclusiveRange(upper.bottom, lower.top));
        expect(upper.deflate(.01).contains(point), isFalse);
        expect(lower.deflate(.01).contains(point), isFalse);
      }
    }
  });

  test(
    'duplicate, invalid, and occluded nodes do not add crossing bridges',
    () {
      final engine = _Signal();
      addTearDown(engine.dispose);
      const upper = Rect.fromLTWH(20, 20, 200, 100);
      const lower = Rect.fromLTWH(20, 144, 200, 100);
      const obstacle = Rect.fromLTWH(110, 124, 20, 16);
      final paths = _traces(
        CircuitWavePainter(
          engine: engine,
          childBounds: [
            upper,
            lower,
            obstacle,
            upper,
            Rect.zero,
            const Rect.fromLTWH(double.nan, 0, 10, 10),
          ],
        ),
        const Size(300, 300),
      );
      // An obstacle may have a short clear bridge to its neighbour; the
      // upper-to-lower route through its interior must not exist.
      for (final path in paths) {
        for (final point in _samples(path)) {
          expect(obstacle.deflate(6).contains(point), isFalse);
        }
      }
      final loops = paths.where(
        (path) => path.computeMetrics().single.isClosed,
      );
      expect(loops, hasLength(6));
      final longBridges = paths.where(
        (path) =>
            !path.computeMetrics().single.isClosed &&
            path.computeMetrics().single.length > 10,
      );
      expect(longBridges, isEmpty);
    },
  );

  test('perimeter samples corners and applies inset as a frame inset', () {
    final engine = _Signal();
    addTearDown(engine.dispose);
    const size = Size(313, 181);
    final paths = _traces(
      PerimeterWavePainter(engine: engine, time: .31, inset: 9),
      size,
    );
    expect(paths, hasLength(2));
    for (final path in paths) {
      _expectBorder(path, (Offset.zero & size).deflate(9));
    }
  });

  test(
    'audio phase wraps preserve density while visual time moves both waves',
    () {
      final engine = _Signal();
      addTearDown(engine.dispose);
      const size = Size(320, 240);
      for (final circuit in [true, false]) {
        CustomPainter painter(double time) => circuit
            ? CircuitWavePainter(
                engine: engine,
                time: time,
                childBounds: [Offset.zero & size],
              )
            : PerimeterWavePainter(engine: engine, time: time);
        final before = _samples(_traces(painter(.5), size).first);
        engine.phase = 6.28;
        final wrapped = _samples(_traces(painter(.5), size).first);
        expect(wrapped, orderedEquals(before));
        final advanced = _samples(_traces(painter(.9), size).first);
        expect(advanced, isNot(orderedEquals(before)));
        engine.phase = 0;
      }
    },
  );

  test('a cached painter refreshes its clipping after a viewport resize', () {
    final engine = _Signal();
    addTearDown(engine.dispose);
    final painter = CircuitWavePainter(
      engine: engine,
      childBounds: [const Rect.fromLTWH(10, 10, 260, 160)],
    );
    for (final size in [const Size(300, 200), const Size(180, 140)]) {
      final canvas = TestRecordingCanvas();
      painter.paint(canvas, size);
      final clip =
          canvas.invocations
                  .map((record) => record.invocation)
                  .firstWhere((call) => call.memberName == #clipPath)
                  .positionalArguments
                  .first
              as Path;
      expect(clip.contains(const Offset(290, 5)), size.width > 290);
      expect(clip.contains(const Offset(15, 15)), isTrue);
      expect(clip.contains(const Offset(60, 60)), isFalse);
    }
  });

  testWidgets(
    'scroll bounds stay in overlay coordinates with the viewport clip',
    (tester) async {
      final engine = _Signal();
      addTearDown(engine.dispose);
      final scroll = ScrollController();
      addTearDown(scroll.dispose);
      Widget fixture(double viewportHeight) => MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 240,
            child: CircuitWaveOverlay(
              engine: engine,
              isActive: true,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    height: viewportHeight,
                    child: SingleChildScrollView(
                      controller: scroll,
                      child: const CircuitNode(
                        child: SizedBox(width: 240, height: 420),
                      ),
                    ),
                  ),
                  const SizedBox(height: 80, child: Text('Pinned controls')),
                ],
              ),
            ),
          ),
        ),
      );
      CircuitWavePainter painter() => tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<CircuitWavePainter>()
          .single;

      await tester.pumpWidget(fixture(160));
      await tester.pump();
      expect(painter().childBounds.single, const Rect.fromLTWH(0, 0, 240, 420));
      expect(
        painter().clips!.value.single,
        const Rect.fromLTWH(0, 0, 240, 160),
      );
      scroll.jumpTo(100);
      await tester.pump();
      await tester.pump();
      expect(
        painter().childBounds.single,
        const Rect.fromLTWH(0, -100, 240, 420),
      );
      expect(
        painter().clips!.value.single,
        const Rect.fromLTWH(0, 0, 240, 160),
      );
      await tester.pumpWidget(fixture(200));
      await tester.pump();
      expect(
        painter().clips!.value.single,
        const Rect.fromLTWH(0, 0, 240, 200),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('rasterized strokes and glow leave control interiors untouched', (
    tester,
  ) async {
    final engine = _Signal();
    addTearDown(engine.dispose);
    await tester.runAsync(() async {
      const size = Size(640, 280);
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      CircuitWavePainter(
        engine: engine,
        time: .7,
        childBounds: [
          const Rect.fromLTWH(10, 10, 170, 220),
          const Rect.fromLTWH(450, 10, 170, 180),
        ],
      ).paint(canvas, size);
      final picture = recorder.endRecording();
      final image = await picture.toImage(640, 280);
      final data = (await image.toByteData())!;
      var borderPixels = 0;
      for (var y = 0; y < 280; y++) {
        for (var x = 0; x < 640; x++) {
          final alpha = data.getUint8((y * 640 + x) * 4 + 3);
          final point = Offset(x + .5, y + .5);
          if (const Rect.fromLTWH(17, 17, 156, 206).contains(point) ||
              const Rect.fromLTWH(457, 17, 156, 166).contains(point) ||
              const Rect.fromLTWH(220, 0, 190, 280).contains(point)) {
            expect(alpha, 0, reason: 'Unexpected paint over content at $point');
          }
          if (alpha > 0) borderPixels++;
        }
      }
      expect(borderPixels, greaterThan(1000));
      image.dispose();
      picture.dispose();
    });
  });
}
