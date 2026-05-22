import 'dart:math' as math;

import 'harmonic_capture.dart';

/// Aggregate of all [HarmonicCapture]s — the user's unique voice identity.
///
/// Computed getters derive the voice fingerprint from the raw captures:
/// resonance frequency, pitch range, harmonic signature, etc.
class HarmonicFootprint {
  /// Owner of this footprint.
  final String userId;

  /// All voice captures collected over time.
  final List<HarmonicCapture> captures;

  /// When the first capture was taken.
  final DateTime createdAt;

  /// When the last capture was added.
  DateTime updatedAt;

  HarmonicFootprint({
    required this.userId,
    List<HarmonicCapture>? captures,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : captures = captures ?? [],
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  // ---------------------------------------------------------------------------
  // Computed getters — the voice fingerprint
  // ---------------------------------------------------------------------------

  /// The pitch the user hits most often (mode of fundamentalHz, rounded to
  /// nearest Hz). Returns 0 if no captures.
  double get resonanceHz {
    if (captures.isEmpty) return 0;
    final freqCounts = <int, int>{};
    for (final c in captures) {
      final rounded = c.fundamentalHz.round();
      freqCounts[rounded] = (freqCounts[rounded] ?? 0) + 1;
    }
    int modeHz = 0;
    int maxCount = 0;
    for (final entry in freqCounts.entries) {
      if (entry.value > maxCount) {
        maxCount = entry.value;
        modeHz = entry.key;
      }
    }
    return modeHz.toDouble();
  }

  /// Lowest pitch detected across all captures.
  double get pitchRangeMin {
    if (captures.isEmpty) return 0;
    return captures.map((c) => c.pitchMin).reduce(math.min);
  }

  /// Highest pitch detected across all captures.
  double get pitchRangeMax {
    if (captures.isEmpty) return 0;
    return captures.map((c) => c.pitchMax).reduce(math.max);
  }

  /// Mean normalized volume across all captures.
  double get averageVolume {
    if (captures.isEmpty) return 0;
    return captures.map((c) => c.volumeDb).reduce((a, b) => a + b) /
        captures.length;
  }

  /// Element-wise average of all captures' harmonic lists (8 values).
  /// This is what makes each voice unique.
  List<double> get harmonicSignature {
    if (captures.isEmpty) return List.filled(8, 0.0);
    final sums = List.filled(8, 0.0);
    for (final c in captures) {
      for (int i = 0; i < 8; i++) {
        sums[i] += c.harmonics[i];
      }
    }
    return sums.map((s) => s / captures.length).toList();
  }

  /// Mean spectral centroid across all captures.
  double get spectralCentroidAvg {
    if (captures.isEmpty) return 0;
    return captures.map((c) => c.spectralCentroid).reduce((a, b) => a + b) /
        captures.length;
  }

  /// Vocal range in octaves: log2(pitchRangeMax / pitchRangeMin).
  double get vocalRangeOctaves {
    if (pitchRangeMin <= 0 || pitchRangeMax <= 0) return 0;
    return (math.log(pitchRangeMax / pitchRangeMin) / math.ln2);
  }

  /// Total number of captures.
  int get totalCaptures => captures.length;

  /// Time span between first and last capture.
  Duration get footprintAge => updatedAt.difference(createdAt);

  // ---------------------------------------------------------------------------
  // Mutation
  // ---------------------------------------------------------------------------

  /// Add a new capture and update the timestamp.
  void addCapture(HarmonicCapture c) {
    captures.add(c);
    updatedAt = c.timestamp;
  }

  // ---------------------------------------------------------------------------
  // Serialization
  // ---------------------------------------------------------------------------

  Map<String, dynamic> toJson() => {
        'userId': userId,
        'captures': captures.map((c) => c.toJson()).toList(),
        'createdAt': createdAt.millisecondsSinceEpoch,
        'updatedAt': updatedAt.millisecondsSinceEpoch,
      };

  factory HarmonicFootprint.fromJson(Map<String, dynamic> json) {
    return HarmonicFootprint(
      userId: json['userId'] as String,
      captures: (json['captures'] as List<dynamic>)
          .map((e) => HarmonicCapture.fromJson(e as Map<String, dynamic>))
          .toList(),
      createdAt:
          DateTime.fromMillisecondsSinceEpoch(json['createdAt'] as int),
      updatedAt:
          DateTime.fromMillisecondsSinceEpoch(json['updatedAt'] as int),
    );
  }
}
