/// Single voice snapshot captured from the microphone at a point in time.
///
/// Contains the fundamental pitch, volume, harmonic amplitudes (1st-8th),
/// spectral centroid, and detected pitch bounds for this capture window.
class HarmonicCapture {
  /// Unique identifier (UUID).
  final String id;

  /// When this capture was taken.
  final DateTime timestamp;

  /// Detected fundamental pitch in Hz.
  final double fundamentalHz;

  /// Normalized volume level (0.0 = silence, 1.0 = max).
  final double volumeDb;

  /// Relative amplitudes of harmonics 1-8 vs the fundamental.
  /// Each value is 0.0-1.0 where 1.0 = same amplitude as fundamental.
  final List<double> harmonics;

  /// Spectral centroid in Hz — indicates voice brightness.
  final double spectralCentroid;

  /// Lowest pitch detected in this capture window (Hz).
  final double pitchMin;

  /// Highest pitch detected in this capture window (Hz).
  final double pitchMax;

  /// Duration of this capture window in milliseconds.
  final int durationMs;

  const HarmonicCapture({
    required this.id,
    required this.timestamp,
    required this.fundamentalHz,
    required this.volumeDb,
    required this.harmonics,
    required this.spectralCentroid,
    required this.pitchMin,
    required this.pitchMax,
    required this.durationMs,
  }) : assert(harmonics.length == 8, 'harmonics must have exactly 8 values');

  Map<String, dynamic> toJson() => {
        'id': id,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'fundamentalHz': fundamentalHz,
        'volumeDb': volumeDb,
        'harmonics': harmonics,
        'spectralCentroid': spectralCentroid,
        'pitchMin': pitchMin,
        'pitchMax': pitchMax,
        'durationMs': durationMs,
      };

  factory HarmonicCapture.fromJson(Map<String, dynamic> json) {
    return HarmonicCapture(
      id: json['id'] as String,
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp'] as int),
      fundamentalHz: (json['fundamentalHz'] as num).toDouble(),
      volumeDb: (json['volumeDb'] as num).toDouble(),
      harmonics: (json['harmonics'] as List<dynamic>)
          .map((e) => (e as num).toDouble())
          .toList(),
      spectralCentroid: (json['spectralCentroid'] as num).toDouble(),
      pitchMin: (json['pitchMin'] as num).toDouble(),
      pitchMax: (json['pitchMax'] as num).toDouble(),
      durationMs: json['durationMs'] as int,
    );
  }
}
