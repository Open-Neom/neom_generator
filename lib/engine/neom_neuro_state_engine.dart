import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';

import '../engine/neom_breath_engine.dart';
import '../engine/neom_modulator_engine.dart';
import '../utils/enums/neom_spatial_mode.dart';

class NeomNeuroStateEngine {

  double intensity = 0.5;

  void applyState({
    required NeomNeuroState state,
    required NeomBreathEngine breath,
    required NeomModulatorEngine modulator,
    required void Function(bool) setIsochronic,
    required void Function(double) setIsoFreq,
    required void Function(NeomSpatialMode) setSpatialMode,
    required void Function(double) setSpatialIntensity,
  }) {

    switch (state) {

      case NeomNeuroState.calm:
        breath.mode = NeomBreathMode.box;
        breath.breathsPerMinute = 5.5;
        breath.depth = 0.6;

        modulator.type = NeomModulationType.none;

        setIsochronic(true);
        setIsoFreq(4.0);

        setSpatialMode(NeomSpatialMode.crossfade);
        setSpatialIntensity(0.4);
        break;

      case NeomNeuroState.focus:
        breath.mode = NeomBreathMode.free;
        breath.breathsPerMinute = 7.0;
        breath.depth = 0.3;

        modulator.type = NeomModulationType.fm;
        modulator.modFrequency = 0.3;
        modulator.depth = 0.2;

        setIsochronic(true);
        setIsoFreq(14.0);

        setSpatialMode(NeomSpatialMode.centered);
        setSpatialIntensity(0.2);
        break;

      case NeomNeuroState.sleep:
        breath.mode = NeomBreathMode.fourSevenEight;
        breath.breathsPerMinute = 4.0;
        breath.depth = 0.8;

        modulator.type = NeomModulationType.none;

        setIsochronic(true);
        setIsoFreq(2.5);

        setSpatialMode(NeomSpatialMode.orbit);
        setSpatialIntensity(0.15);
        break;

      case NeomNeuroState.creativity:
        breath.mode = NeomBreathMode.free;
        breath.breathsPerMinute = 6.5;
        breath.depth = 0.4;

        modulator.type = NeomModulationType.fm;
        modulator.modFrequency = 0.6;
        modulator.depth = 0.35;

        setIsochronic(false);
        setSpatialMode(NeomSpatialMode.orbit);
        setSpatialIntensity(0.6);
        break;

      case NeomNeuroState.integration:
        breath.mode = NeomBreathMode.free;
        breath.breathsPerMinute = 6.0;
        breath.depth = 0.5;

        modulator.type = NeomModulationType.pm;
        modulator.modFrequency = 0.2;
        modulator.depth = 0.25;

        setIsochronic(false);
        setSpatialMode(NeomSpatialMode.crossfade);
        setSpatialIntensity(0.5);
        break;

      case NeomNeuroState.neutral:
        breath.mode = NeomBreathMode.off;
        modulator.type = NeomModulationType.none;
        setIsochronic(false);
        setSpatialMode(NeomSpatialMode.centered);
        setSpatialIntensity(0.0);
    }
  }
}
