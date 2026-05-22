import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/utils/constants/neom_chamber_preset_pack.dart';

void main() {
  group('NeomFrequencyPresetPack', () {
    test('all preset ids are unique', () {
      final ids = NeomFrequencyPresetPack.presets.map((p) => p.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'duplicate preset id detected');
    });

    test('every preset has a positive carrier frequency', () {
      for (final p in NeomFrequencyPresetPack.presets) {
        expect(p.mainFrequency, isNotNull, reason: '${p.id} has no main frequency');
        expect(p.mainFrequency!.frequency, greaterThan(0),
          reason: '${p.id} carrier must be > 0 Hz');
      }
    });

    test('binaural beat (when present) is positive and < 250 Hz', () {
      for (final p in NeomFrequencyPresetPack.presets) {
        if (p.binauralFrequency == null) continue;
        final beat = (p.binauralFrequency!.frequency - p.mainFrequency!.frequency).abs();
        expect(beat, greaterThan(0), reason: '${p.id} binaural beat == 0');
        expect(beat, lessThan(250),
          reason: '${p.id} beat $beat Hz is outside binaural usable range');
      }
    });

    test('volumes are within [0, 1]', () {
      for (final p in NeomFrequencyPresetPack.presets) {
        final params = p.neomParameter;
        expect(params, isNotNull, reason: '${p.id} has no neomParameter');
        expect(params!.volume, inInclusiveRange(0.0, 1.0),
          reason: '${p.id} volume out of range');
      }
    });

    test('positions x/y/z are within [-1, 1]', () {
      for (final p in NeomFrequencyPresetPack.presets) {
        final params = p.neomParameter!;
        expect(params.x, inInclusiveRange(-1.0, 1.0));
        expect(params.y, inInclusiveRange(-1.0, 1.0));
        expect(params.z, inInclusiveRange(-1.0, 1.0));
      }
    });

    test('getById returns null for unknown id', () {
      expect(NeomFrequencyPresetPack.getById('does_not_exist'), isNull);
    });

    test('getById returns a clone (mutating result does not affect catalogue)', () {
      final id = NeomFrequencyPresetPack.presets.first.id;
      final original = NeomFrequencyPresetPack.presets.first;
      final originalVolume = original.neomParameter!.volume;
      final fetched = NeomFrequencyPresetPack.getById(id)!;
      fetched.neomParameter!.volume = 0.123;
      expect(NeomFrequencyPresetPack.presets.first.neomParameter!.volume,
        originalVolume,
        reason: 'getById must return a defensive clone');
    });

    test('getAll returns the same length as presets', () {
      expect(NeomFrequencyPresetPack.getAll().length,
        NeomFrequencyPresetPack.presets.length);
    });
  });
}
