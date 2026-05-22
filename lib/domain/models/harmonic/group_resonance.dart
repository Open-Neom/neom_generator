import 'dart:math' as math;

import 'harmonic_footprint.dart';

/// Computes the optimal group resonance frequency when multiple users
/// meditate together in a Ceremonia or Círculo de Unión.
///
/// Instead of using a generic frequency, the group resonance is
/// calculated from all participants' footprints to find the Hz where
/// the group vibrates best together.
///
/// Algorithm: weighted geometric mean of individual resonances, biased
/// toward consonant intervals. This produces a frequency that is
/// harmonically "between" all participants — not just an arithmetic average
/// which would sound musically wrong.
class GroupResonance {
  /// Individual resonance frequencies of all participants.
  final List<double> individualHz;

  /// The computed group frequency.
  final double groupHz;

  /// Coherence of the group (0–1): how consonant are all participants
  /// with each other? High = naturally compatible group.
  final double groupCoherence;

  /// Number of participants.
  int get participantCount => individualHz.length;

  const GroupResonance({
    required this.individualHz,
    required this.groupHz,
    required this.groupCoherence,
  });

  /// Compute group resonance from a list of footprints.
  factory GroupResonance.fromFootprints(List<HarmonicFootprint> footprints) {
    if (footprints.isEmpty) {
      return const GroupResonance(
        individualHz: [],
        groupHz: 432.0,
        groupCoherence: 0.0,
      );
    }

    final hzList = footprints
        .where((fp) => fp.totalCaptures > 0 && fp.resonanceHz > 20)
        .map((fp) => fp.resonanceHz)
        .toList();

    if (hzList.isEmpty) {
      return const GroupResonance(
        individualHz: [],
        groupHz: 432.0,
        groupCoherence: 0.0,
      );
    }

    if (hzList.length == 1) {
      return GroupResonance(
        individualHz: hzList,
        groupHz: hzList.first,
        groupCoherence: 1.0,
      );
    }

    // Geometric mean (musically correct averaging of frequencies).
    final logSum = hzList.fold<double>(0, (s, hz) => s + math.log(hz));
    final geoMean = math.exp(logSum / hzList.length);

    // Group coherence: average pairwise consonance.
    double consonanceSum = 0;
    int pairs = 0;
    for (int i = 0; i < hzList.length; i++) {
      for (int j = i + 1; j < hzList.length; j++) {
        consonanceSum += _pairConsonance(hzList[i], hzList[j]);
        pairs++;
      }
    }
    final coherence = pairs > 0 ? consonanceSum / pairs : 0.0;

    return GroupResonance(
      individualHz: List.unmodifiable(hzList),
      groupHz: geoMean.clamp(80.0, 2500.0),
      groupCoherence: coherence,
    );
  }

  /// Pairwise consonance (same logic as HarmonicCompatibility).
  static double _pairConsonance(double a, double b) {
    if (a <= 0 || b <= 0) return 0;
    final ratio = math.max(a, b) / math.min(a, b);
    const consonant = [1.0, 1.2, 1.25, 1.333, 1.5, 1.667, 2.0];
    double best = double.infinity;
    for (final c in consonant) {
      final d = (ratio - c).abs();
      if (d < best) best = d;
    }
    return (1.0 - best / 0.15).clamp(0.0, 1.0);
  }

  Map<String, dynamic> toJson() => {
        'individualHz': individualHz,
        'groupHz': groupHz,
        'groupCoherence': groupCoherence,
        'participantCount': participantCount,
      };
}
