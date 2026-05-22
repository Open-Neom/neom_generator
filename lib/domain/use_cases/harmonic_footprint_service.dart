import '../models/harmonic/harmonic_capture.dart';
import '../models/harmonic/harmonic_footprint.dart';

/// Abstract interface for the Harmonic Footprint system.
///
/// Manages voice capture, analysis, and aggregation into the user's
/// unique vocal fingerprint (Huella Armonica).
abstract class HarmonicFootprintService {
  /// Record a mic sample, analyze it, and add the resulting
  /// [HarmonicCapture] to the current footprint.
  Future<void> captureVoiceSample({
    Duration duration = const Duration(seconds: 5),
  });

  /// The current aggregated footprint, or null if none loaded.
  HarmonicFootprint? get currentFootprint;

  /// Emits each new [HarmonicCapture] as it is processed.
  Stream<HarmonicCapture> get captureStream;

  /// Load an existing footprint for [userId] from persistence.
  Future<void> loadFootprint(String userId);

  /// Clear all captures and reset the footprint.
  Future<void> clearFootprint();
}
