import 'package:neom_core/domain/model/neom/neom_chamber_preset.dart';
import 'package:neom_core/domain/model/neom/neom_frequency.dart';
import 'package:neom_core/domain/model/neom/neom_parameter.dart';
import 'package:neom_core/utils/constants/core_constants.dart';
import 'package:neom_core/utils/enums/scale_degree.dart';

class NeomFrequencyPresetPack {

  /// Presets base oficiales Neom
  static final List<NeomChamberPreset> presets = [

    /// =========================
    /// DELTA – SUEÑO PROFUNDO
    /// =========================
    NeomChamberPreset(
      id: 'delta_2',
      name: 'Delta Profundo',
      description: 'Sueño profundo, regeneración física y descanso neuronal.',
      state: 5,
      neomParameter: NeomParameter(
        volume: 0.5,
        x: 0.0,
        y: 0.0,
        z: 0.0,
      ),
      mainFrequency: NeomFrequency(
        id: '100',
        name: 'Portadora Delta',
        frequency: 100.0,
        scaleDegree: ScaleDegree.tonic,
        isRoot: true,
        isMain: true,
        description: 'Frecuencia portadora estable para estados delta.',
      ),
      binauralFrequency: NeomFrequency(
        id: '102',
        name: 'Delta 2 Hz',
        frequency: 102.0,
        scaleDegree: ScaleDegree.subdominant,
        description: 'Batido binaural de 2 Hz (delta profundo).',
      ),
    ),

    /// =========================
    /// THETA – CREATIVIDAD
    /// =========================
    NeomChamberPreset(
      id: 'theta_6',
      name: 'Theta Creativo',
      description: 'Meditación profunda, imaginación y creatividad.',
      state: 4,
      neomParameter: NeomParameter(
        volume: 0.55,
        x: 0.0,
        y: 0.0,
        z: 0.0,
      ),
      mainFrequency: NeomFrequency(
        id: '200',
        name: 'Portadora Theta',
        frequency: 200.0,
        scaleDegree: ScaleDegree.tonic,
        isRoot: true,
        isMain: true,
        description: 'Portadora theta para estados creativos.',
      ),
      binauralFrequency: NeomFrequency(
        id: '206',
        name: 'Theta 6 Hz',
        frequency: 206.0,
        scaleDegree: ScaleDegree.mediant,
        description: 'Batido binaural de 6 Hz (theta).',
      ),
    ),

    /// =========================
    /// ALPHA – BALANCE
    /// =========================
    NeomChamberPreset(
      id: 'alpha_10',
      name: 'Alpha Balance',
      description: 'Calma, presencia y enfoque relajado.',
      state: 3,
      neomParameter: NeomParameter(
        volume: 0.6,
        x: 0.0,
        y: 0.0,
        z: 0.0,
      ),
      mainFrequency: NeomFrequency(
        id: '220',
        name: 'Portadora Alpha',
        frequency: 220.0,
        scaleDegree: ScaleDegree.tonic,
        isRoot: true,
        isMain: true,
        description: 'Portadora alpha equilibrante.',
      ),
      binauralFrequency: NeomFrequency(
        id: '230',
        name: 'Alpha 10 Hz',
        frequency: 230.0,
        scaleDegree: ScaleDegree.dominant,
        description: 'Batido binaural de 10 Hz (alpha).',
      ),
    ),

    /// =========================
    /// GAMMA – EXPANSIÓN
    /// =========================
    NeomChamberPreset(
      id: 'gamma_40',
      name: 'Gamma Expansión',
      description: 'Procesamiento elevado y claridad cognitiva.',
      state: 2,
      neomParameter: NeomParameter(
        volume: 0.65,
        x: 0.0,
        y: 0.0,
        z: 0.0,
      ),
      mainFrequency: NeomFrequency(
        id: '300',
        name: 'Portadora Gamma',
        frequency: 300.0,
        scaleDegree: ScaleDegree.tonic,
        isRoot: true,
        isMain: true,
        description: 'Portadora gamma de alta energía.',
      ),
      binauralFrequency: NeomFrequency(
        id: '340',
        name: 'Gamma 40 Hz',
        frequency: 340.0,
        scaleDegree: ScaleDegree.leadingTone,
        description: 'Batido binaural de 40 Hz (gamma).',
      ),
    ),

    /// =========================
    /// SOLFEGGIO 432
    /// =========================
    NeomChamberPreset(
      id: '${CoreConstants.customPreset}_432',
      name: 'Solfeggio 432',
      description: 'Armonía corporal, resonancia natural.',
      state: 5,
      neomParameter: NeomParameter(
        volume: 0.6,
        x: 0.0,
        y: 0.0,
        z: 0.0,
      ),
      mainFrequency: NeomFrequency(
        id: '432',
        name: '432 Hz',
        frequency: 432.0,
        scaleDegree: ScaleDegree.tonic,
        isRoot: true,
        isMain: true,
        description: 'Frecuencia de afinación natural.',
      ),
    ),

    /// =========================
    /// SOLFEGGIO 528
    /// =========================
    NeomChamberPreset(
      id: '${CoreConstants.customPreset}_528',
      name: 'Solfeggio 528',
      description: 'Regeneración, coherencia y transformación.',
      state: 5,
      neomParameter: NeomParameter(
        volume: 0.6,
        x: 0.0,
        y: 0.0,
        z: 0.0,
      ),
      mainFrequency: NeomFrequency(
        id: '528',
        name: '528 Hz',
        frequency: 528.0,
        scaleDegree: ScaleDegree.tonic,
        isRoot: true,
        isMain: true,
        description: 'Frecuencia solfeggio de transformación.',
      ),
    ),
  ];

  /// Obtener preset por ID
  static NeomChamberPreset? getById(String id) {
    try {
      return presets.firstWhere((p) => p.id == id).clone();
    } catch (_) {
      return null;
    }
  }

  /// Obtener copia segura de todos los presets
  static List<NeomChamberPreset> getAll() {
    return presets.map((p) => p.clone()).toList();
  }
}
