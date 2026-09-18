import '../domain/models/incienso_audio_state.dart';
import '../utils/enums/neom_spatial_mode.dart';
import 'neom_breath_engine.dart';
import 'neom_modulator_engine.dart';
import 'neom_sine_engine.dart';

/// Complete synthesis snapshot. No audio data; UI metadata is additional.
extension InciensoSynthesisState on NeomSineEngine {
  InciensoAudioState captureAudioState({
    double? baseHz,
    int octave = 0,
    String neuroState = 'neutral',
    String visualMode = 'scientific',
    String? visualExperience,
  }) {
    final p = phaseState;
    return InciensoAudioState(
      parameters: {
        'carrierHz': frequency,
        'beatHz': beat,
        'volume': volume,
        'fadeInSeconds': fadeInSeconds,
        'fadeOutSeconds': fadeOutSeconds,
        'fadeOutEndFrame': fadeOutEndFrame ?? 0,
        'baseHz': baseHz ?? frequency,
        'octave': octave,
        'multi': multiFrequencyMode,
        'leftHz': frequencyL,
        'rightHz': frequencyR,
        'subHz': frequencySub,
        'subMix': subMixLevel,
        'posX': posX,
        'posY': posY,
        'posZ': posZ,
        'spatialMode': spatialMode.name,
        'spatialIntensity': spatialIntensity,
        'orbitSpeed': orbitSpeed,
        'orbitDirection': orbitDirection,
        'breathMode': breathEngine.mode.name,
        'breathRate': breathEngine.breathsPerMinute,
        'breathDepth': breathEngine.depth,
        'breathIntensity': breathEngine.intensity,
        'modEnabled': modulator.enabled,
        'modType': modulator.type.name,
        'modRate': modulator.modFrequency,
        'modDepth': modulator.depth,
        'modIntensity': modulator.intensity,
        'isoEnabled': isochronic.enabled,
        'isoFrequency': isochronic.pulseFrequency,
        'isoDuty': isochronic.dutyCycle,
        'neuroState': neuroState,
        'neuroIntensity': neuroStateEngine.intensity,
        'visualMode': visualMode,
        if (visualExperience != null) 'visualExperience': visualExperience,
      },
      phases: {
        'left': p.left,
        'right': p.right,
        'sub': p.sub,
        'orbit': p.orbit,
        'breath': breathEngine.phase,
        'modulation': modulator.phase,
        'isochronic': isochronic.phase,
      },
    );
  }

  void applyAudioState(InciensoAudioState state, {bool restorePhases = true}) {
    if (state.engineVersion != InciensoAudioState.currentEngineVersion) {
      throw UnsupportedError(
        'Unsupported Incienso synthesis version ${state.engineVersion}',
      );
    }
    double n(String k, double fallback, double min, double max) =>
        state.number(k, fallback).clamp(min, max);
    frequency = n('carrierHz', 432, 0, 22000);
    beat = n('beatHz', 0, -250, 250);
    volume = n('volume', .5, 0, 1);
    // Additive v1 parameters: legacy snapshots stay neutral. The original
    // scheduled end is not the shortened playback limit after a manual Stop.
    fadeInSeconds = n('fadeInSeconds', 0, 0, 3600);
    fadeOutSeconds = n('fadeOutSeconds', 0, 0, 3600);
    final fadeEnd = n('fadeOutEndFrame', 0, 0, 0x1FFFFFFFFFFFFF.toDouble());
    fadeOutEndFrame = fadeEnd > 0 ? fadeEnd.toInt() : null;
    multiFrequencyMode = state.flag('multi', false);
    frequencyL = n('leftHz', 0, 0, 22000);
    frequencyR = n('rightHz', 0, 0, 22000);
    frequencySub = n('subHz', 0, 0, 22000);
    subMixLevel = n('subMix', .5, 0, 1);
    posX = n('posX', 0, -1, 1);
    posY = n('posY', 0, -1, 1);
    posZ = n('posZ', 0, -1, 1);
    spatialMode = NeomSpatialMode.values.byName(
      state.text('spatialMode', 'softPan'),
    );
    spatialIntensity = n('spatialIntensity', .5, 0, 1);
    orbitSpeed = n('orbitSpeed', .15, 0, 20);
    orbitDirection = state.number('orbitDirection', 1) < 0 ? -1 : 1;
    breathEngine.mode = NeomBreathMode.values.byName(
      state.text('breathMode', 'off'),
    );
    breathEngine.breathsPerMinute = n('breathRate', 6, 0, 120);
    breathEngine.depth = n('breathDepth', .5, 0, 1);
    breathEngine.intensity = n('breathIntensity', .5, 0, 1);
    modulator.enabled = state.flag('modEnabled', false);
    modulator.type = NeomModulationType.values.byName(
      state.text('modType', 'none'),
    );
    modulator.modFrequency = n('modRate', .5, 0, 1000);
    modulator.depth = n('modDepth', .3, 0, 1);
    modulator.intensity = n('modIntensity', .5, 0, 1);
    isochronic.enabled = state.flag('isoEnabled', false);
    isochronic.pulseFrequency = n('isoFrequency', 4, 0, 1000);
    isochronic.dutyCycle = n('isoDuty', .5, 0, 1);
    neuroStateEngine.intensity = n('neuroIntensity', .5, 0, 1);
    if (restorePhases) {
      restorePhaseState((
        left: state.phases['left'] ?? 0,
        right: state.phases['right'] ?? 0,
        sub: state.phases['sub'] ?? 0,
        orbit: state.phases['orbit'] ?? 0,
      ));
      breathEngine.restorePhase(state.phases['breath'] ?? 0);
      modulator.restorePhase(state.phases['modulation'] ?? 0);
      isochronic.restorePhase(state.phases['isochronic'] ?? 0);
    }
  }
}
