import 'harmonic_footprint.dart';

/// A frozen snapshot of a [HarmonicFootprint] at a specific point in time.
///
/// Taken weekly (or on-demand) to track how the user's voice evolves
/// with Cyberneom practice. A timeline of snapshots shows visual proof
/// that the app is working — harmonics become more symmetric, volume
/// stabilizes, resonance sharpens.
class FootprintSnapshot {
  final DateTime takenAt;
  final double resonanceHz;
  final List<double> harmonicSignature;
  final double spectralCentroidAvg;
  final double averageVolume;
  final double pitchRangeMin;
  final double pitchRangeMax;
  final int totalCaptures;

  /// Coherence score (0-1): how symmetric the harmonic signature is.
  /// Higher = more balanced harmonics = more "coherent" voice.
  /// Calculated as 1 - (stddev / mean) of the 8 harmonic values.
  final double coherenceScore;

  const FootprintSnapshot({
    required this.takenAt,
    required this.resonanceHz,
    required this.harmonicSignature,
    required this.spectralCentroidAvg,
    required this.averageVolume,
    required this.pitchRangeMin,
    required this.pitchRangeMax,
    required this.totalCaptures,
    required this.coherenceScore,
  });

  /// Create a snapshot from the current state of a footprint.
  factory FootprintSnapshot.fromFootprint(HarmonicFootprint fp) {
    final sig = fp.harmonicSignature;
    final mean = sig.isEmpty
        ? 0.0
        : sig.reduce((a, b) => a + b) / sig.length;
    final variance = sig.isEmpty
        ? 0.0
        : sig.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            sig.length;
    final stddev = variance > 0 ? _sqrt(variance) : 0.0;
    final coherence = mean > 0 ? (1.0 - (stddev / mean)).clamp(0.0, 1.0) : 0.0;

    return FootprintSnapshot(
      takenAt: DateTime.now(),
      resonanceHz: fp.resonanceHz,
      harmonicSignature: List.unmodifiable(sig),
      spectralCentroidAvg: fp.spectralCentroidAvg,
      averageVolume: fp.averageVolume,
      pitchRangeMin: fp.pitchRangeMin,
      pitchRangeMax: fp.pitchRangeMax,
      totalCaptures: fp.totalCaptures,
      coherenceScore: coherence,
    );
  }

  static double _sqrt(double v) {
    if (v <= 0) return 0;
    double x = v;
    for (int i = 0; i < 20; i++) {
      x = (x + v / x) / 2;
    }
    return x;
  }

  Map<String, dynamic> toJson() => {
        'takenAt': takenAt.toIso8601String(),
        'resonanceHz': resonanceHz,
        'harmonicSignature': harmonicSignature,
        'spectralCentroidAvg': spectralCentroidAvg,
        'averageVolume': averageVolume,
        'pitchRangeMin': pitchRangeMin,
        'pitchRangeMax': pitchRangeMax,
        'totalCaptures': totalCaptures,
        'coherenceScore': coherenceScore,
      };

  factory FootprintSnapshot.fromJson(Map<String, dynamic> json) {
    return FootprintSnapshot(
      takenAt: DateTime.parse(json['takenAt'] as String),
      resonanceHz: (json['resonanceHz'] as num?)?.toDouble() ?? 0.0,
      harmonicSignature: (json['harmonicSignature'] as List?)
              ?.map((e) => (e as num).toDouble())
              .toList() ??
          const [],
      spectralCentroidAvg:
          (json['spectralCentroidAvg'] as num?)?.toDouble() ?? 0.0,
      averageVolume: (json['averageVolume'] as num?)?.toDouble() ?? 0.0,
      pitchRangeMin: (json['pitchRangeMin'] as num?)?.toDouble() ?? 0.0,
      pitchRangeMax: (json['pitchRangeMax'] as num?)?.toDouble() ?? 0.0,
      totalCaptures: (json['totalCaptures'] as int?) ?? 0,
      coherenceScore: (json['coherenceScore'] as num?)?.toDouble() ?? 0.0,
    );
  }
}
