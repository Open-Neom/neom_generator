import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/engine/neom_modulator_engine.dart';
import 'package:neom_generator/engine/neom_isochronic_engine.dart';
import 'package:neom_generator/engine/neom_breath_engine.dart';

void main() {
  group('NeomModulatorEngine', () {
    test('disabled engine returns carrier untouched', () {
      final m = NeomModulatorEngine();
      m.enabled = false;
      m.type = NeomModulationType.fm;
      expect(m.apply(carrierFreq: 432, sampleRate: 48000), 432);
    });

    test('type=none always returns carrier even when enabled', () {
      final m = NeomModulatorEngine()
        ..enabled = true
        ..type = NeomModulationType.none;
      expect(m.apply(carrierFreq: 432, sampleRate: 48000), 432);
    });

    test('FM keeps output within ±depth × carrier', () {
      final m = NeomModulatorEngine()
        ..enabled = true
        ..type = NeomModulationType.fm
        ..depth = 0.25
        ..modFrequency = 1.0;
      const carrier = 1000.0;
      var minOut = double.infinity;
      var maxOut = double.negativeInfinity;
      for (var i = 0; i < 48000; i++) {
        final v = m.apply(carrierFreq: carrier, sampleRate: 48000);
        if (v < minOut) minOut = v;
        if (v > maxOut) maxOut = v;
      }
      expect(minOut, greaterThanOrEqualTo(carrier * (1 - 0.25) - 1e-6));
      expect(maxOut, lessThanOrEqualTo(carrier * (1 + 0.25) + 1e-6));
    });

    test('FM at depth 0 reduces to identity', () {
      final m = NeomModulatorEngine()
        ..enabled = true
        ..type = NeomModulationType.fm
        ..depth = 0.0;
      for (var i = 0; i < 100; i++) {
        expect(m.apply(carrierFreq: 440, sampleRate: 48000), 440);
      }
    });

    test('AM only acts via applyAmplitude, not apply()', () {
      final m = NeomModulatorEngine()
        ..enabled = true
        ..type = NeomModulationType.am
        ..depth = 0.5;
      // apply() returns carrier unchanged for AM
      expect(m.apply(carrierFreq: 440, sampleRate: 48000), 440);
      // applyAmplitude scales amplitude, never above the input.
      final out = m.applyAmplitude(0.5);
      expect(out, lessThanOrEqualTo(0.5 + 1e-9));
      expect(out, greaterThanOrEqualTo(0.0));
    });

    test('applyAmplitude is identity when type != am', () {
      final m = NeomModulatorEngine()
        ..type = NeomModulationType.fm;
      expect(m.applyAmplitude(0.7), 0.7);
    });
  });

  group('NeomIsochronicEngine', () {
    test('disabled returns input amplitude unchanged', () {
      final iso = NeomIsochronicEngine()..enabled = false;
      expect(iso.apply(amplitude: 0.42, sampleRate: 48000), 0.42);
    });

    test('duty-cycle 0.5 yields ON for first half and OFF for second half', () {
      // pulseFrequency 1 Hz, sampleRate 100 -> exactly 100 samples per cycle.
      final iso = NeomIsochronicEngine()
        ..enabled = true
        ..pulseFrequency = 1.0
        ..dutyCycle = 0.5;
      var onCount = 0;
      for (var i = 0; i < 100; i++) {
        if (iso.apply(amplitude: 1.0, sampleRate: 100) > 0) onCount++;
      }
      expect(onCount, inInclusiveRange(48, 52));
    });

    test('duty-cycle 0.0 means always silent', () {
      final iso = NeomIsochronicEngine()
        ..enabled = true
        ..pulseFrequency = 1.0
        ..dutyCycle = 0.0;
      for (var i = 0; i < 200; i++) {
        expect(iso.apply(amplitude: 1.0, sampleRate: 100), 0.0);
      }
    });
  });

  group('NeomBreathEngine', () {
    test('mode=off returns base amplitude untouched', () {
      final b = NeomBreathEngine()..mode = NeomBreathMode.off;
      expect(b.apply(baseAmplitude: 0.6, sampleRate: 48000), 0.6);
    });

    test('free mode envelope stays within [base*(1-depth), base]', () {
      final b = NeomBreathEngine()
        ..mode = NeomBreathMode.free
        ..depth = 0.4
        ..breathsPerMinute = 6;
      const base = 0.5;
      var minV = double.infinity;
      var maxV = double.negativeInfinity;
      for (var i = 0; i < 48000; i++) {
        final v = b.apply(baseAmplitude: base, sampleRate: 48000);
        if (v < minV) minV = v;
        if (v > maxV) maxV = v;
      }
      expect(minV, greaterThanOrEqualTo(base * (1 - 0.4) - 1e-9));
      expect(maxV, lessThanOrEqualTo(base + 1e-9));
    });

    test('box envelope hits both 0 and full base across a cycle', () {
      final b = NeomBreathEngine()
        ..mode = NeomBreathMode.box
        ..depth = 1.0
        ..breathsPerMinute = 6;
      var sawZero = false;
      var sawFull = false;
      for (var i = 0; i < 480000; i++) {
        final v = b.apply(baseAmplitude: 1.0, sampleRate: 48000);
        if (v < 1e-6) sawZero = true;
        if (v > 0.99) sawFull = true;
        if (sawZero && sawFull) break;
      }
      expect(sawZero && sawFull, isTrue);
    });
  });
}
