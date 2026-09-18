import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_core/domain/use_cases/neom_audio_visual_signal.dart';
import 'package:neom_generator/engine/neom_frequency_painter_engine.dart';
import 'package:neom_generator/ui/painters/lissajous_3d_painter.dart';
import 'package:neom_generator/ui/painters/lissajous_painter.dart';
import 'package:neom_generator/ui/widgets/signal_paint.dart';

const _captureKey = ValueKey('lissajous-pixels');

NeomAudioSessionSnapshot _session({
  bool playing = true,
  double leftHz = 220,
  double rightHz = 220,
  double beatPhase = 0,
  bool breathing = false,
  double breathValue = 0,
}) => NeomAudioSessionSnapshot(
  isPlaying: playing,
  leftHz: leftHz,
  rightHz: rightHz,
  beatPhase: beatPhase,
  breathingEnabled: breathing,
  breathValue: breathValue,
  level: playing ? 0.2 : 0,
);

Widget _host(Widget child, {bool visible = true, bool reducedMotion = false}) =>
    Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: MediaQueryData(disableAnimations: reducedMotion),
        child: TickerMode(
          enabled: visible,
          child: Center(
            child: RepaintBoundary(
              key: _captureKey,
              child: SizedBox(width: 240, height: 240, child: child),
            ),
          ),
        ),
      ),
    );

Widget _twoDimensional(NeomFrequencyPainterEngine engine) => SignalPaint(
  active: true,
  builder: (repaint) =>
      LissajousPainter(engine: engine, color: Colors.cyan, repaint: repaint),
);

Future<void> _frames(WidgetTester tester, int count) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<Uint8List> _pixels(WidgetTester tester) async {
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  return (await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
    image.dispose();
    return bytes!.buffer.asUint8List();
  }))!;
}

int _changedBytes(Uint8List first, Uint8List second) {
  expect(second.length, first.length);
  var changes = 0;
  for (var i = 0; i < first.length; i++) {
    if (first[i] != second[i]) changes++;
  }
  return changes;
}

Lissajous3DPainter _threeDimensionalPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((widget) => widget.painter)
    .whereType<Lissajous3DPainter>()
    .single;

void main() {
  test('equal actual frequencies retain a line or phase-offset ellipse', () {
    final line = LissajousGeometry.fromFrequencies(
      leftHz: 432,
      rightHz: 432,
      phaseDifference: 0,
    )!;
    final circle = LissajousGeometry.fromFrequencies(
      leftHz: 432,
      rightHz: 432,
      phaseDifference: math.pi / 2,
    )!;
    for (var i = 0; i <= 80; i++) {
      final parameter = i * math.pi / 40;
      final point = line.pointAt(parameter);
      expect(point.dx, closeTo(point.dy, 1e-12));
      final offset = circle.pointAt(parameter);
      expect(offset.dx * offset.dx + offset.dy * offset.dy, closeTo(1, 1e-12));
    }
  });

  test('2:1 and 3:2 use Hz ratios, including zero/wrapped relative phase', () {
    for (final (left, right, phase) in [
      (440.0, 220.0, 0.0),
      (330.0, 220.0, 0.7),
      (330.0, 220.0, 0.7 + 2 * math.pi),
    ]) {
      final geometry = LissajousGeometry.fromFrequencies(
        leftHz: left,
        rightHz: right,
        phaseDifference: phase,
      )!;
      for (var i = 0; i <= 80; i++) {
        final parameter = i * math.pi / 40;
        final point = geometry.pointAt(parameter);
        expect(point.dx, closeTo(math.sin(parameter * left / right), 1e-12));
        expect(point.dy, closeTo(math.sin(parameter + phase), 1e-12));
      }
      expect(geometry.pointAt(geometry.sweepRadians).dx, closeTo(0, 1e-12));
      expect(
        geometry.pointAt(geometry.sweepRadians).dy,
        closeTo(math.sin(phase), 1e-12),
      );
      expect(geometry.sweepRadians, left == 440 ? 2 * math.pi : 4 * math.pi);
    }
  });

  test('missing or invalid frequency data never fabricates a 1:1 curve', () {
    for (final (left, right) in [
      (0.0, 0.0),
      (double.nan, 220.0),
      (220.0, double.infinity),
      (-1.0, 220.0),
    ]) {
      expect(
        LissajousGeometry.fromFrequencies(
          leftHz: left,
          rightHz: right,
          phaseDifference: 0,
        ),
        isNull,
      );
    }
  });

  testWidgets('2D mono keeps its figure while its tracer changes pixels', (
    tester,
  ) async {
    final engine = NeomFrequencyPainterEngine()
      ..audioSessionReader = () => _session();
    addTearDown(engine.dispose);
    await tester.pumpWidget(_host(_twoDimensional(engine)));
    await _frames(tester, 2);
    final delegate = tester
        .widgetList<CustomPaint>(find.byType(CustomPaint))
        .map((widget) => widget.painter)
        .whereType<LissajousPainter>()
        .single;
    final before = await _pixels(tester);
    await _frames(tester, 10);
    expect(_changedBytes(before, await _pixels(tester)), greaterThan(100));
    expect(
      tester
          .widgetList<CustomPaint>(find.byType(CustomPaint))
          .map((widget) => widget.painter)
          .whereType<LissajousPainter>()
          .single,
      same(delegate),
    );
    expect(engine.phaseL, 0);
    expect(engine.phaseR, 0);
    expect(engine.sampleRevision, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('2D uses actual channel Hz while generated phases stay equal', (
    tester,
  ) async {
    var session = _session();
    final engine = NeomFrequencyPainterEngine()
      ..audioSessionReader = () => session;
    addTearDown(engine.dispose);
    await tester.pumpWidget(
      _host(_twoDimensional(engine), reducedMotion: true),
    );
    final mono = await _pixels(tester);
    session = _session(leftHz: 440, rightHz: 220);
    await tester.pumpWidget(
      _host(_twoDimensional(engine), reducedMotion: true),
    );
    expect(_changedBytes(mono, await _pixels(tester)), greaterThan(1000));
    expect(engine.phaseL, engine.phaseR);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('2D without telemetry draws no fallback line', (tester) async {
    final engine = NeomFrequencyPainterEngine();
    addTearDown(engine.dispose);
    await tester.pumpWidget(_host(_twoDimensional(engine)));
    await _frames(tester, 5);
    expect((await _pixels(tester)).every((value) => value == 0), isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  for (final threeDimensional in [false, true]) {
    testWidgets(
      '${threeDimensional ? '3D' : '2D'} freezes pixels for hidden/reduced motion',
      (tester) async {
        final engine = NeomFrequencyPainterEngine()
          ..audioSessionReader = () => _session(rightHz: 330);
        addTearDown(engine.dispose);
        Widget visual() => threeDimensional
            ? Lissajous3DWidget(engine: engine)
            : _twoDimensional(engine);
        await tester.pumpWidget(_host(visual()));
        await _frames(tester, 8);
        for (final reduced in [false, true]) {
          await tester.pumpWidget(
            _host(visual(), visible: reduced, reducedMotion: reduced),
          );
          final before = await _pixels(tester);
          await _frames(tester, 12);
          expect(_changedBytes(before, await _pixels(tester)), 0);
        }
        await tester.pumpWidget(_host(visual()));
        final beforeResume = await _pixels(tester);
        await _frames(tester, 8);
        expect(
          _changedBytes(beforeResume, await _pixels(tester)),
          greaterThan(100),
        );
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }

  testWidgets('3D keeps actual equal channels equal and has no invented Z', (
    tester,
  ) async {
    var session = _session();
    final engine = NeomFrequencyPainterEngine()
      ..audioSessionReader = () => session;
    addTearDown(engine.dispose);
    await tester.pumpWidget(_host(Lissajous3DWidget(engine: engine)));
    final delegate = _threeDimensionalPainter(tester);
    final before = await _pixels(tester);
    await _frames(tester, 15);
    expect(_changedBytes(before, await _pixels(tester)), greaterThan(100));
    expect(_threeDimensionalPainter(tester), same(delegate));
    expect(delegate.trail.length, greaterThan(10));
    for (final point in delegate.trail) {
      expect(point.x, closeTo(point.y, 1e-12));
      expect(point.z, 0);
    }
    session = _session(playing: false);
    await _frames(tester, 1);
    final stopped = await _pixels(tester);
    await _frames(tester, 10);
    expect(_changedBytes(stopped, await _pixels(tester)), 0);
    expect(engine.sampleRevision, 0);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('3D samples the real frequency ratio and breathing envelope', (
    tester,
  ) async {
    final engine = NeomFrequencyPainterEngine()
      ..audioSessionReader = () => _session(
        leftHz: 440,
        rightHz: 220,
        breathing: true,
        breathValue: 0.75,
      );
    addTearDown(engine.dispose);
    await tester.pumpWidget(_host(Lissajous3DWidget(engine: engine)));
    await _frames(tester, 12);
    final point = _threeDimensionalPainter(tester).trail.last;
    final parameter = point.elapsed.inMicroseconds / 1000000 * 1.8 / 2;
    expect(point.x, closeTo(math.sin(parameter * 2), 1e-12));
    expect(point.y, closeTo(math.sin(parameter), 1e-12));
    expect(point.z, 0.5);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('3D legacy repeated samples remain quiet without fake beats', (
    tester,
  ) async {
    final engine = NeomFrequencyPainterEngine();
    addTearDown(engine.dispose);
    await tester.pumpWidget(_host(Lissajous3DWidget(engine: engine)));
    final before = await _pixels(tester);
    await _frames(tester, 12);
    expect(_changedBytes(before, await _pixels(tester)), 0);
    for (final point in _threeDimensionalPainter(tester).trail) {
      expect((point.x, point.y, point.z), (0, 0, 0));
    }
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('3D reprojects the complete trail when beat phase changes', (
    tester,
  ) async {
    var session = _session(leftHz: 408, rightHz: 418, breathing: true);
    final engine = NeomFrequencyPainterEngine()
      ..audioSessionReader = () => session;
    addTearDown(engine.dispose);
    await tester.pumpWidget(_host(Lissajous3DWidget(engine: engine)));
    await tester.pump();
    final delegate = _threeDimensionalPainter(tester);
    for (var frame = 1; frame <= 24; frame++) {
      final seconds = frame * 0.04;
      session = _session(
        leftHz: 408,
        rightHz: 418,
        beatPhase: seconds * 10 * 2 * math.pi % (2 * math.pi),
        breathing: true,
        breathValue: seconds / 2,
      );
      await _frames(tester, 1);
      for (var i = 0; i < delegate.trail.length; i++) {
        final point = delegate.trail[i];
        final pointSeconds = point.elapsed.inMicroseconds / 1000000;
        final parameter = pointSeconds * 1.8 / (418 / 408);
        expect(point.x, closeTo(math.sin(parameter), 1e-10));
        expect(
          point.y,
          closeTo(math.sin(parameter * (418 / 408) + session.beatPhase), 1e-10),
          reason: 'Every historical point must use this frame\'s beat phase',
        );
        expect(point.z, closeTo(pointSeconds - 1, 1e-10));
        if (i > 0 && !point.breakBefore) {
          final previous = delegate.trail[i - 1];
          final distance = math.sqrt(
            math.pow(point.x - previous.x, 2) +
                math.pow(point.y - previous.y, 2),
          );
          expect(
            distance,
            lessThan(0.11),
            reason: 'A 40 ms step must not connect unrelated curves into bars',
          );
        }
      }
    }
    final preserved = delegate.trail.first;
    session = _session(
      leftHz: 440,
      rightHz: 220,
      beatPhase: math.pi / 2,
      breathing: true,
      breathValue: 0.5,
    );
    await _frames(tester, 1);
    for (final point in delegate.trail) {
      final parameter = point.sweepFraction! * 2 * math.pi;
      expect(point.x, closeTo(math.sin(parameter * 2), 1e-10));
      expect(point.y, closeTo(math.sin(parameter + math.pi / 2), 1e-10));
    }
    expect(delegate.trail.first.elapsed, preserved.elapsed);
    expect(delegate.trail.first.z, preserved.z);
    expect(delegate.trail.first.sweepFraction, preserved.sweepFraction);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
