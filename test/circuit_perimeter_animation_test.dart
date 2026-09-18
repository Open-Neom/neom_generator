import 'dart:ui' show PointerDeviceKind;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/engine/neom_frequency_painter_engine.dart';
import 'package:neom_generator/ui/painters/circuit_wave_painter.dart';
import 'package:neom_generator/ui/painters/perimeter_wave_painter.dart';

enum _Decoration { circuit, perimeter, nested }

class _Counters {
  int mounts = 0;
  int disposes = 0;
  int builds = 0;
  int taps = 0;
  int dragStarts = 0;
  int dragEnds = 0;
  final values = <double>[];
}

class _Controls extends StatefulWidget {
  const _Controls(this.counters);
  final _Counters counters;

  @override
  State<_Controls> createState() => _ControlsState();
}

class _ControlsState extends State<_Controls> {
  double _value = .25;

  @override
  void initState() {
    super.initState();
    widget.counters.mounts++;
  }

  @override
  void dispose() {
    widget.counters.disposes++;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    widget.counters.builds++;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CircuitNode(
          child: GestureDetector(
            key: const ValueKey('stop'),
            behavior: HitTestBehavior.opaque,
            onTap: () => widget.counters.taps++,
            child: const SizedBox(width: 160, height: 64, child: Text('Stop')),
          ),
        ),
        CircuitNode(
          child: Slider(
            value: _value,
            onChangeStart: (_) => widget.counters.dragStarts++,
            onChangeEnd: (_) => widget.counters.dragEnds++,
            onChanged: (value) {
              widget.counters.values.add(value);
              setState(() => _value = value);
            },
          ),
        ),
      ],
    );
  }
}

Widget _decorate(
  _Decoration decoration,
  NeomFrequencyPainterEngine engine,
  bool active,
  Widget child,
) {
  if (decoration != _Decoration.circuit) {
    child = PerimeterWaveWidget(engine: engine, isActive: active, child: child);
  }
  if (decoration != _Decoration.perimeter) {
    child = CircuitWaveOverlay(engine: engine, isActive: active, child: child);
  }
  return child;
}

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Center(child: SizedBox(width: 320, child: child)),
  ),
);

Future<void> _frames(WidgetTester tester, [int count = 8]) async {
  for (var i = 0; i < count; i++) {
    await tester.pump(const Duration(milliseconds: 17));
  }
}

CircuitWavePainter _circuitPainter(WidgetTester tester) => tester
    .widgetList<CustomPaint>(find.byType(CustomPaint))
    .map((widget) => widget.painter)
    .whereType<CircuitWavePainter>()
    .single;

void main() {
  const scenarios = [
    (TargetPlatform.android, PointerDeviceKind.touch, Size(390, 844)),
    (TargetPlatform.iOS, PointerDeviceKind.touch, Size(390, 844)),
    (TargetPlatform.macOS, PointerDeviceKind.mouse, Size(1440, 900)),
  ];

  for (final (platform, pointerKind, size) in scenarios) {
    for (final decoration in _Decoration.values) {
      testWidgets(
        '${platform.name} ${decoration.name}: active frames preserve tap and child',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final engine = NeomFrequencyPainterEngine();
          addTearDown(engine.dispose);
          final counters = _Counters();
          final active = ValueNotifier(true);
          addTearDown(active.dispose);
          await tester.pumpWidget(
            _host(
              ValueListenableBuilder<bool>(
                valueListenable: active,
                builder: (_, value, _) =>
                    _decorate(decoration, engine, value, _Controls(counters)),
              ),
            ),
          );
          final state = tester.state(find.byType(_Controls));
          final builds = counters.builds;
          final gesture = await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('stop'))),
            kind: pointerKind,
          );
          await _frames(tester);
          expect(
            counters.builds,
            builds,
            reason: 'Paint ticks must not rebuild controls',
          );
          expect(tester.state(find.byType(_Controls)), same(state));
          expect(counters.disposes, 0);
          await gesture.up();
          await tester.pump();
          expect(counters.taps, 1);

          // Keep a pointer down while both decorations change active state.
          final nextGesture = await tester.startGesture(
            tester.getCenter(find.byKey(const ValueKey('stop'))),
            kind: pointerKind,
          );
          active.value = false;
          await tester.pump();
          await _frames(tester, 3);
          active.value = true;
          await tester.pump();
          await _frames(tester, 3);
          await nextGesture.up();
          await tester.pump();
          expect(counters.taps, 2);
          expect(tester.state(find.byType(_Controls)), same(state));
          expect(counters.mounts, 1);
          expect(counters.disposes, 0);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(counters.disposes, 1);
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );

      testWidgets(
        '${platform.name} ${decoration.name}: slider drag survives visual frames',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final engine = NeomFrequencyPainterEngine();
          addTearDown(engine.dispose);
          final counters = _Counters();
          await tester.pumpWidget(
            _host(_decorate(decoration, engine, true, _Controls(counters))),
          );
          final gesture = await tester.startGesture(
            tester.getCenter(find.byType(Slider)),
            kind: pointerKind,
          );
          for (var i = 0; i < 5; i++) {
            await gesture.moveBy(const Offset(16, 0));
            await _frames(tester, 3);
          }
          await gesture.up();
          await tester.pump();
          expect(counters.dragStarts, 1);
          expect(counters.dragEnds, 1);
          expect(counters.values.length, greaterThanOrEqualTo(5));
          expect(counters.values.last, greaterThan(.65));
          for (var i = 1; i < counters.values.length; i++) {
            expect(
              counters.values[i],
              greaterThanOrEqualTo(counters.values[i - 1]),
            );
          }
          expect(counters.mounts, 1);
          expect(counters.disposes, 0);
          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();
          expect(tester.takeException(), isNull);
        },
        variant: TargetPlatformVariant.only(platform),
      );
    }
  }

  testWidgets(
    'CircuitNode keeps state-owned key and bounds registration across new widgets',
    (tester) async {
      final engine = NeomFrequencyPainterEngine();
      addTearDown(engine.dispose);
      Widget fixture({bool second = true, double width = 120}) => _host(
        CircuitWaveOverlay(
          engine: engine,
          isActive: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircuitNode(
                key: const ValueKey('first-node'),
                child: SizedBox(width: width, height: 50),
              ),
              if (second)
                const CircuitNode(
                  key: ValueKey('second-node'),
                  child: SizedBox(width: 80, height: 40),
                ),
            ],
          ),
        ),
      );
      await tester.pumpWidget(fixture());
      await tester.pump();
      final node = find.byKey(const ValueKey('first-node'));
      final state = tester.state(node);
      final subtreeKey = tester
          .widget<KeyedSubtree>(
            find.descendant(of: node, matching: find.byType(KeyedSubtree)),
          )
          .key;
      expect(subtreeKey, isA<GlobalKey>());
      expect(_circuitPainter(tester).childBounds.length, 2);

      // Construct a fresh CircuitNode, as the generator does when controls update.
      await tester.pumpWidget(fixture(width: 160));
      await tester.pump();
      expect(tester.state(node), same(state));
      expect(
        tester
            .widget<KeyedSubtree>(
              find.descendant(of: node, matching: find.byType(KeyedSubtree)),
            )
            .key,
        same(subtreeKey),
      );
      expect(_circuitPainter(tester).childBounds.length, 2);
      expect(_circuitPainter(tester).childBounds.first.width, 160);

      await tester.pumpWidget(fixture(second: false, width: 160));
      await _frames(tester, 20);
      expect(_circuitPainter(tester).childBounds.length, 1);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('active perimeter safely accepts a null child', (tester) async {
    final engine = NeomFrequencyPainterEngine();
    addTearDown(engine.dispose);
    await tester.pumpWidget(
      _host(
        SizedBox(
          width: 100,
          height: 80,
          child: PerimeterWaveWidget(engine: engine, isActive: true),
        ),
      ),
    );
    await _frames(tester, 20);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
