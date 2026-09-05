import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/engine/neom_frequency_painter_engine.dart';
import 'package:neom_generator/utils/enums/eeg_band.dart';

/// The scope is the only way to see that a binaural beat is actually being
/// produced, so what it draws has to be the mix that reaches the ears.
///
/// It used to be fed `sin((phaseL + phaseR) / 2)`: a single sine at the mean
/// frequency. These pin why that could not work.
void main() {
  const sampleRate = 48000.0;

  /// Envelope of a windowed signal — the beat shows up here, not in the carrier.
  List<double> envelope(List<double> signal, int window) {
    final out = <double>[];
    for (var i = 0; i + window <= signal.length; i += window) {
      var peak = 0.0;
      for (var j = i; j < i + window; j++) {
        if (signal[j].abs() > peak) peak = signal[j].abs();
      }
      out.add(peak);
    }
    return out;
  }

  ({List<double> mix, List<double> meanPhase}) render({
    required double leftHz,
    required double rightHz,
    double gain = 1.0,
    int samples = 24000,
  }) {
    final mix = <double>[];
    final meanPhase = <double>[];
    var pl = 0.0, pr = 0.0;

    for (var i = 0; i < samples; i++) {
      pl += 2 * pi * leftHz / sampleRate;
      pr += 2 * pi * rightHz / sampleRate;
      mix.add((sin(pl) * gain + sin(pr) * gain) * 0.5);
      meanPhase.add(sin((pl + pr) * 0.5));
    }
    return (mix: mix, meanPhase: meanPhase);
  }

  group('what the scope must show', () {
    test('the mix beats at the difference frequency', () {
      // 200/210 Hz beats at 10 Hz: the envelope reaches full and near zero.
      final r = render(leftHz: 200, rightHz: 210);
      final env = envelope(r.mix, 240); // 5 ms windows, well under a 100 ms beat

      expect(env.reduce(max), greaterThan(0.9));
      expect(env.reduce(min), lessThan(0.2));
    });

    test('the mean phase does not beat at all', () {
      // Why the old formula hid the phenomenon the session is built on.
      final r = render(leftHz: 200, rightHz: 210);
      final env = envelope(r.meanPhase, 240);

      expect(env.reduce(max) - env.reduce(min), lessThan(0.05));
    });

    test('the mix carries amplitude, the mean phase does not', () {
      final quiet = render(leftHz: 200, rightHz: 210, gain: 0.1);
      final loud = render(leftHz: 200, rightHz: 210, gain: 1.0);

      final quietPeak = quiet.mix.map((v) => v.abs()).reduce(max);
      final loudPeak = loud.mix.map((v) => v.abs()).reduce(max);
      expect(loudPeak, greaterThan(quietPeak * 5));

      // The old formula ignored gain entirely: every volume looked the same.
      final quietMean = quiet.meanPhase.map((v) => v.abs()).reduce(max);
      final loudMean = loud.meanPhase.map((v) => v.abs()).reduce(max);
      expect((loudMean - quietMean).abs(), lessThan(0.01));
    });

    test('identical channels produce no beat', () {
      final r = render(leftHz: 200, rightHz: 200);
      final env = envelope(r.mix, 240);

      expect(env.reduce(max) - env.reduce(min), lessThan(0.05));
    });

    test('the drawn sample stays inside the scope range', () {
      final r = render(leftHz: 200, rightHz: 210);
      for (final v in r.mix) {
        expect(v, inInclusiveRange(-1.0, 1.0));
      }
    });
  });

  group('EEG band from the beat', () {
    EEGband bandFor(double beatHz) {
      final engine = NeomFrequencyPainterEngine();
      engine.tickBinaural(beatHz, 1 / sampleRate);
      return engine.eegBand;
    }

    test('each beat lands in its band', () {
      expect(bandFor(2), EEGband.delta);
      expect(bandFor(6), EEGband.theta);
      expect(bandFor(10), EEGband.alpha);
      expect(bandFor(20), EEGband.beta);
      expect(bandFor(40), EEGband.gamma);
    });

    test('the beat is read in Hz, not rescaled', () {
      // A copy of this engine multiplied the beat by 40, which put every
      // protocol above the gamma threshold.
      expect(bandFor(10), isNot(EEGband.gamma));
    });
  });
}
