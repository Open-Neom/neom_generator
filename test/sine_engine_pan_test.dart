import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/engine/neom_sine_engine.dart';
import 'package:neom_generator/utils/enums/neom_spatial_mode.dart';

/// computePan() exposes the equal-power / hard / crossfade / orbit panning
/// laws used by the binaural engine. We exercise the boundary cases that
/// previous releases have broken (out-of-range posX, energy preservation,
/// hard-pan endpoint behaviour).
void main() {
  late NeomSineEngine engine;

  setUp(() {
    engine = NeomSineEngine.shared;
  });

  double l = 0, r = 0;
  void capture(double x, double y) { l = x; r = y; }

  group('softPan (equal power)', () {
    setUp(() => engine.spatialMode = NeomSpatialMode.softPan);

    test('center keeps energy split sqrt(2)/2 each side', () {
      engine.computePan(posX: 0, outL: 0, outR: 0, apply: capture);
      expect(l, closeTo(sqrt(2) / 2, 1e-9));
      expect(r, closeTo(sqrt(2) / 2, 1e-9));
    });

    test('full left routes energy to L only', () {
      engine.computePan(posX: -1, outL: 0, outR: 0, apply: capture);
      expect(l, closeTo(1.0, 1e-9));
      expect(r, closeTo(0.0, 1e-9));
    });

    test('full right routes energy to R only', () {
      engine.computePan(posX: 1, outL: 0, outR: 0, apply: capture);
      expect(l, closeTo(0.0, 1e-9));
      expect(r, closeTo(1.0, 1e-9));
    });

    test('out-of-range posX is clamped (no NaN, energy <= 1+ε)', () {
      engine.computePan(posX: 5, outL: 0, outR: 0, apply: capture);
      expect(l.isFinite, isTrue);
      expect(r.isFinite, isTrue);
      // softPan: L^2 + R^2 == 1 (equal power)
      expect(l * l + r * r, closeTo(1.0, 1e-9));
    });

    test('soft pan preserves equal power across the sweep', () {
      for (var p = -1.0; p <= 1.0; p += 0.1) {
        engine.computePan(posX: p, outL: 0, outR: 0, apply: capture);
        expect(l * l + r * r, closeTo(1.0, 1e-9));
      }
    });
  });

  group('hardPan', () {
    setUp(() => engine.spatialMode = NeomSpatialMode.hardPan);

    test('center is dead center: both channels get full gain', () {
      engine.computePan(posX: 0, outL: 0, outR: 0, apply: capture);
      // pan==0 satisfies both <=0 and >=0 branches → both 1.0
      expect(l, 1.0);
      expect(r, 1.0);
    });

    test('positive pan kills L', () {
      engine.computePan(posX: 0.5, outL: 0, outR: 0, apply: capture);
      expect(l, 0.0);
      expect(r, 1.0);
    });

    test('negative pan kills R', () {
      engine.computePan(posX: -0.5, outL: 0, outR: 0, apply: capture);
      expect(l, 1.0);
      expect(r, 0.0);
    });
  });

  group('crossfade', () {
    setUp(() => engine.spatialMode = NeomSpatialMode.crossfade);

    test('center splits 0.5/0.5', () {
      engine.computePan(posX: 0, outL: 0, outR: 0, apply: capture);
      expect(l, closeTo(0.5, 1e-9));
      expect(r, closeTo(0.5, 1e-9));
    });

    test('crossfade always sums to 1.0 across the sweep', () {
      for (var p = -1.0; p <= 1.0; p += 0.05) {
        engine.computePan(posX: p, outL: 0, outR: 0, apply: capture);
        expect(l + r, closeTo(1.0, 1e-9));
        expect(l, inInclusiveRange(0.0, 1.0));
        expect(r, inInclusiveRange(0.0, 1.0));
      }
    });

    test('out-of-range pan still clamped to [0,1]', () {
      engine.computePan(posX: 10, outL: 0, outR: 0, apply: capture);
      expect(l, inInclusiveRange(0.0, 1.0));
      expect(r, inInclusiveRange(0.0, 1.0));
    });
  });

  group('orbit', () {
    setUp(() => engine.spatialMode = NeomSpatialMode.orbit);

    test('orbit gains stay non-negative and bounded', () {
      for (var i = 0; i < 100; i++) {
        engine.computePan(posX: 0, outL: 0, outR: 0, apply: capture);
        expect(l, inInclusiveRange(0.0, 1.0));
        expect(r, inInclusiveRange(0.0, 1.0));
      }
    });
  });
}
