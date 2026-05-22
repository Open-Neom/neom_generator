import '../../../domain/models/harmonic/harmonic_footprint.dart';
import '../../../engine/neom_sine_engine.dart';

/// Bridges the user's [HarmonicFootprint] to the [NeomSineEngine],
/// setting the carrier frequency to the user's personal resonance.
///
/// This is the core of **Propiarmonia**: instead of a generic 432 Hz for
/// everyone, each person hears THEIR own resonance frequency as the base
/// tone. The binaural beat / isochronic pulse is layered on top of this
/// personal carrier.
///
/// Usage:
/// ```dart
/// ResonanceBridge.apply(footprint, sineEngine);
/// // → engine.frequency is now the user's resonance Hz
/// ```
class ResonanceBridge {
  ResonanceBridge._();

  /// Apply the footprint's resonance to the sine engine.
  ///
  /// Sets `engine.frequency` to `footprint.resonanceHz` if valid (> 20 Hz
  /// and < 2500 Hz, the generator's supported range). Falls back to the
  /// default 432 Hz if the footprint has no captures or the resonance is
  /// out of range.
  static void apply(HarmonicFootprint? footprint, NeomSineEngine engine) {
    if (footprint == null || footprint.totalCaptures == 0) return;

    final hz = footprint.resonanceHz;
    if (hz >= 20.0 && hz <= 2500.0) {
      engine.frequency = hz;
    }
  }

  /// Generate a personalized binaural beat config from the footprint.
  ///
  /// The carrier is the user's resonance. The beat frequency targets the
  /// EEG band that the user's spectral centroid suggests they need:
  ///
  /// * High centroid (bright voice, likely stressed) → alpha 10 Hz (calm)
  /// * Low centroid (dark voice, likely tired) → beta 18 Hz (alert)
  /// * Mid centroid (balanced) → theta 6 Hz (meditative)
  static BinauralConfig personalizedConfig(HarmonicFootprint footprint) {
    final carrier = footprint.resonanceHz;
    final centroid = footprint.spectralCentroidAvg;

    double beatHz;
    String targetState;

    if (centroid > 2000) {
      // Bright/tense voice → calm down with alpha
      beatHz = 10.0;
      targetState = 'alpha';
    } else if (centroid < 800) {
      // Dark/tired voice → energize with beta
      beatHz = 18.0;
      targetState = 'beta';
    } else {
      // Balanced → meditative theta
      beatHz = 6.0;
      targetState = 'theta';
    }

    return BinauralConfig(
      carrierHz: carrier.clamp(80.0, 2500.0),
      beatHz: beatHz,
      targetState: targetState,
    );
  }
}

/// Personalized binaural beat configuration derived from the Huella Armónica.
class BinauralConfig {
  final double carrierHz;
  final double beatHz;
  final String targetState;

  const BinauralConfig({
    required this.carrierHz,
    required this.beatHz,
    required this.targetState,
  });
}
