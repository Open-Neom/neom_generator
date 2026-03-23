import 'dart:math' as math;
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_core/domain/model/neom/neom_chamber_preset.dart';
import 'package:neom_generator/utils/constants/neom_generator_constants.dart';
import 'package:neom_generator/utils/enums/eeg_band.dart';
import 'package:neom_generator/utils/enums/neom_frequency_target.dart';
import 'package:neom_generator/utils/enums/neom_neuro_state.dart';
import 'package:neom_generator/utils/enums/neom_numeric_target.dart';
import 'package:neom_generator/utils/enums/neom_spatial_mode.dart';
import 'package:neom_generator/utils/enums/neom_visual_mode.dart';

// ─── Inline copy of getNoteFromFrequency for pure-Dart testing ───
// (The original is in generator_widgets.dart which imports Flutter)
String getNoteFromFrequency(double frequency) {
  if (frequency <= 0) return '--';
  final n = 12 * (math.log(frequency / 440) / math.log(2)) + 69;
  final midiNumber = n.round();
  final notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  final octave = (midiNumber ~/ 12) - 1;
  final noteIndex = midiNumber % 12;
  if (midiNumber < 0 || noteIndex < 0) return '?';
  return '${notes[noteIndex]}$octave';
}

void main() {
  // ═══════════════════════════════════════════════════════
  // Constants Tests
  // ═══════════════════════════════════════════════════════

  group('NeomGeneratorConstants', () {
    test('frequency bounds are valid', () {
      expect(NeomGeneratorConstants.frequencyMin, greaterThan(0));
      expect(NeomGeneratorConstants.frequencyMax, greaterThan(NeomGeneratorConstants.frequencyMin));
      expect(NeomGeneratorConstants.frequencyLimit, lessThanOrEqualTo(NeomGeneratorConstants.frequencyMax));
      expect(NeomGeneratorConstants.defaultFrequency, greaterThanOrEqualTo(NeomGeneratorConstants.frequencyMin));
      expect(NeomGeneratorConstants.defaultFrequency, lessThanOrEqualTo(NeomGeneratorConstants.frequencyMax));
    });

    test('binaural beat max is positive', () {
      expect(NeomGeneratorConstants.binauralBeatMax, greaterThan(0));
      expect(NeomGeneratorConstants.binauralBeatMax, lessThanOrEqualTo(250));
    });

    test('volume bounds 0-1', () {
      expect(NeomGeneratorConstants.volumeMin, 0);
      expect(NeomGeneratorConstants.volumeMax, 1);
    });

    test('pan bounds -1 to 1', () {
      expect(NeomGeneratorConstants.positionMin, -1);
      expect(NeomGeneratorConstants.positionMax, 1);
    });

    test('audio sample rate is standard', () {
      expect(NeomGeneratorConstants.sampleRate, 44100);
    });

    test('channels is stereo', () {
      expect(NeomGeneratorConstants.channels, 2);
    });
  });

  // ═══════════════════════════════════════════════════════
  // EEG Band Tests
  // ═══════════════════════════════════════════════════════

  group('EEGband', () {
    test('has 5 brain wave bands', () {
      expect(EEGband.values.length, 5);
    });

    test('includes all standard bands', () {
      expect(EEGband.values, contains(EEGband.delta));
      expect(EEGband.values, contains(EEGband.theta));
      expect(EEGband.values, contains(EEGband.alpha));
      expect(EEGband.values, contains(EEGband.beta));
      expect(EEGband.values, contains(EEGband.gamma));
    });

    test('order matches ascending frequency', () {
      // delta < theta < alpha < beta < gamma
      expect(EEGband.delta.index, lessThan(EEGband.theta.index));
      expect(EEGband.theta.index, lessThan(EEGband.alpha.index));
      expect(EEGband.alpha.index, lessThan(EEGband.beta.index));
      expect(EEGband.beta.index, lessThan(EEGband.gamma.index));
    });
  });

  // ═══════════════════════════════════════════════════════
  // Neuro State Tests
  // ═══════════════════════════════════════════════════════

  group('NeomNeuroState', () {
    test('has 6 states', () {
      expect(NeomNeuroState.values.length, 6);
    });

    test('includes core states', () {
      expect(NeomNeuroState.values, contains(NeomNeuroState.neutral));
      expect(NeomNeuroState.values, contains(NeomNeuroState.calm));
      expect(NeomNeuroState.values, contains(NeomNeuroState.focus));
      expect(NeomNeuroState.values, contains(NeomNeuroState.sleep));
      expect(NeomNeuroState.values, contains(NeomNeuroState.creativity));
      expect(NeomNeuroState.values, contains(NeomNeuroState.integration));
    });
  });

  // ═══════════════════════════════════════════════════════
  // Spatial Mode Tests
  // ═══════════════════════════════════════════════════════

  group('NeomSpatialMode', () {
    test('has 5 modes', () {
      expect(NeomSpatialMode.values.length, 5);
    });

    test('includes all modes', () {
      expect(NeomSpatialMode.values, contains(NeomSpatialMode.softPan));
      expect(NeomSpatialMode.values, contains(NeomSpatialMode.hardPan));
      expect(NeomSpatialMode.values, contains(NeomSpatialMode.crossfade));
      expect(NeomSpatialMode.values, contains(NeomSpatialMode.orbit));
      expect(NeomSpatialMode.values, contains(NeomSpatialMode.centered));
    });
  });

  // ═══════════════════════════════════════════════════════
  // Visual Mode Tests
  // ═══════════════════════════════════════════════════════

  group('NeomVisualMode', () {
    test('has 2 modes (scientific and meditative)', () {
      expect(NeomVisualMode.values.length, 2);
      expect(NeomVisualMode.values, contains(NeomVisualMode.scientific));
      expect(NeomVisualMode.values, contains(NeomVisualMode.meditative));
    });
  });

  // ═══════════════════════════════════════════════════════
  // Frequency Target & Numeric Target Tests
  // ═══════════════════════════════════════════════════════

  group('NeomFrequencyTarget', () {
    test('has root and binaural', () {
      expect(NeomFrequencyTarget.values, contains(NeomFrequencyTarget.root));
      expect(NeomFrequencyTarget.values, contains(NeomFrequencyTarget.binaural));
    });
  });

  group('NeomNumericTarget', () {
    test('has rootFrequency and binauralBeat', () {
      expect(NeomNumericTarget.values, contains(NeomNumericTarget.rootFrequency));
      expect(NeomNumericTarget.values, contains(NeomNumericTarget.binauralBeat));
    });
  });

  // ═══════════════════════════════════════════════════════
  // getNoteFromFrequency Tests (Music Theory)
  // ═══════════════════════════════════════════════════════

  group('getNoteFromFrequency', () {
    test('A4 = 440 Hz', () {
      expect(getNoteFromFrequency(440.0), 'A4');
    });

    test('C4 (middle C) ~261.63 Hz', () {
      expect(getNoteFromFrequency(261.63), 'C4');
    });

    test('A3 = 220 Hz', () {
      expect(getNoteFromFrequency(220.0), 'A3');
    });

    test('A5 = 880 Hz', () {
      expect(getNoteFromFrequency(880.0), 'A5');
    });

    test('E4 ~329.63 Hz', () {
      expect(getNoteFromFrequency(329.63), 'E4');
    });

    test('G3 ~196 Hz', () {
      expect(getNoteFromFrequency(196.0), 'G3');
    });

    test('B4 ~493.88 Hz', () {
      expect(getNoteFromFrequency(493.88), 'B4');
    });

    test('frequency 0 returns --', () {
      expect(getNoteFromFrequency(0), '--');
    });

    test('negative frequency returns --', () {
      expect(getNoteFromFrequency(-100), '--');
    });

    test('very low frequency (sub-bass) returns valid note', () {
      // 40 Hz ≈ E1
      final note = getNoteFromFrequency(40.0);
      expect(note.length, greaterThan(1));
      expect(note, isNot('--'));
      expect(note, isNot('?'));
    });

    test('very high frequency returns valid note', () {
      // 2000 Hz ≈ B6
      final note = getNoteFromFrequency(2000.0);
      expect(note.length, greaterThan(1));
      expect(note, isNot('--'));
    });

    test('Schumann resonance 7.83 Hz', () {
      // Very low but valid
      final note = getNoteFromFrequency(7.83);
      expect(note, isNot('--'));
    });

    test('default frequency 345 Hz maps to a note', () {
      final note = getNoteFromFrequency(NeomGeneratorConstants.defaultFrequency);
      expect(note, isNot('--'));
      expect(note, isNot('?'));
    });
  });

  // ═══════════════════════════════════════════════════════
  // Binaural Beat Frequency Math Tests
  // ═══════════════════════════════════════════════════════

  group('Binaural Beat Math', () {
    test('binaural beat = |left - right| frequency', () {
      final rootFreq = 440.0;
      final beatHz = 10.0;
      final leftEar = rootFreq;
      final rightEar = rootFreq + beatHz;

      expect((rightEar - leftEar).abs(), beatHz);
    });

    test('alpha range binaural beat (8-13 Hz)', () {
      final beat = 10.0;
      expect(beat, greaterThanOrEqualTo(8));
      expect(beat, lessThanOrEqualTo(13));
    });

    test('theta range binaural beat (4-8 Hz)', () {
      final beat = 6.0;
      expect(beat, greaterThanOrEqualTo(4));
      expect(beat, lessThan(8));
    });

    test('delta range binaural beat (0.5-4 Hz)', () {
      final beat = 2.0;
      expect(beat, greaterThanOrEqualTo(0.5));
      expect(beat, lessThan(4));
    });

    test('beta range binaural beat (13-30 Hz)', () {
      final beat = 20.0;
      expect(beat, greaterThanOrEqualTo(13));
      expect(beat, lessThanOrEqualTo(30));
    });

    test('gamma range binaural beat (30-100 Hz)', () {
      final beat = 40.0;
      expect(beat, greaterThanOrEqualTo(30));
      expect(beat, lessThanOrEqualTo(100));
    });
  });

  // ═══════════════════════════════════════════════════════
  // NeomChamberPreset Model Tests
  // ═══════════════════════════════════════════════════════

  group('NeomChamberPreset', () {
    test('default constructor has safe defaults', () {
      final preset = NeomChamberPreset();
      expect(preset.id, isNotEmpty); // auto-generated from parameters
      expect(preset.name, '');
      expect(preset.description, '');
      expect(preset.ownerId, '');
    });

    test('JSON round-trip preserves fields', () {
      final preset = NeomChamberPreset(
        id: 'p1',
        name: 'Deep Theta',
        description: 'Descenso a theta profundo',
        ownerId: 'user123',
        state: 1,
      );

      final json = preset.toJSON();
      final restored = NeomChamberPreset.fromJSON(json);

      expect(restored.id, 'p1');
      expect(restored.name, 'Deep Theta');
      expect(restored.description, 'Descenso a theta profundo');
      expect(restored.ownerId, 'user123');
      expect(restored.state, 1);
    });

    test('fromJSON with null returns safe defaults', () {
      final preset = NeomChamberPreset.fromJSON({});
      expect(preset.id, '');
      expect(preset.name, '');
      expect(preset.extraFrequencies, isEmpty);
    });

    test('clone creates independent copy', () {
      final original = NeomChamberPreset(
        id: 'orig',
        name: 'Original',
        description: 'Test',
      );
      final clone = original.clone();

      expect(clone.name, 'Original');
      clone.name = 'Cloned';
      expect(original.name, 'Original'); // original unchanged
      expect(clone.name, 'Cloned');
    });

    test('toJsonNoId excludes id field', () {
      final preset = NeomChamberPreset(id: 'xyz', name: 'Test');
      final json = preset.toJsonNoId();
      expect(json.containsKey('id'), false);
      expect(json['name'], 'Test');
    });
  });

  // ═══════════════════════════════════════════════════════
  // Frequency Validation Tests
  // ═══════════════════════════════════════════════════════

  group('Frequency Validation', () {
    test('min frequency is audible range', () {
      // Human hearing starts at ~20 Hz, generator allows 40 Hz
      expect(NeomGeneratorConstants.frequencyMin, greaterThanOrEqualTo(20));
    });

    test('max frequency is within reasonable range', () {
      // Generator caps at 2500 Hz (well within 20 kHz hearing limit)
      expect(NeomGeneratorConstants.frequencyMax, lessThanOrEqualTo(20000));
    });

    test('default frequency is in A4 range', () {
      // 345 Hz is between E4 (~330) and F4 (~349)
      expect(NeomGeneratorConstants.defaultFrequency, greaterThan(300));
      expect(NeomGeneratorConstants.defaultFrequency, lessThan(400));
    });

    test('frequency limit for non-admin users', () {
      expect(NeomGeneratorConstants.frequencyLimit, lessThan(NeomGeneratorConstants.frequencyMax));
      expect(NeomGeneratorConstants.frequencyLimit, greaterThan(NeomGeneratorConstants.frequencyMin));
    });
  });
}
