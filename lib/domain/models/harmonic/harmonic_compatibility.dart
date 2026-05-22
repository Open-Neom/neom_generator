import 'dart:math' as math;

import 'harmonic_footprint.dart';

/// Result of comparing two users' Harmonic Footprints for resonance
/// compatibility — used by Cyberneom's Ceremonias and Círculos de Unión
/// to suggest ideal meditation partners.
///
/// Compatibility is measured across 3 dimensions:
/// 1. **Pitch consonance** — are their resonance frequencies harmonically
///    related? (octave, fifth, fourth = high consonance)
/// 2. **Signature similarity** — how similar are their 8-harmonic shapes?
/// 3. **Centroid complementarity** — one bright + one dark voice balances
///    the pair's combined spectrum
class HarmonicCompatibility {
  /// User A's resonance Hz.
  final double resonanceA;

  /// User B's resonance Hz.
  final double resonanceB;

  /// Pitch consonance (0–1). 1.0 = perfect octave/unison.
  final double pitchConsonance;

  /// Harmonic signature similarity (0–1). 1.0 = identical shapes.
  final double signatureSimilarity;

  /// Centroid complementarity (0–1). 1.0 = perfect bright+dark balance.
  final double centroidComplementarity;

  /// Overall compatibility score (weighted average).
  double get overallScore =>
      pitchConsonance * 0.4 +
      signatureSimilarity * 0.35 +
      centroidComplementarity * 0.25;

  /// Human-readable label.
  String get label {
    final s = overallScore;
    if (s >= 0.8) return 'Resonancia Profunda';
    if (s >= 0.6) return 'Armonía Natural';
    if (s >= 0.4) return 'Complementarios';
    if (s >= 0.2) return 'Contraste Creativo';
    return 'Disonancia Exploratoria';
  }

  /// Musical interval name between the two resonances.
  String get intervalName {
    final ratio = resonanceA > 0 && resonanceB > 0
        ? (math.max(resonanceA, resonanceB) /
            math.min(resonanceA, resonanceB))
        : 1.0;
    if ((ratio - 1.0).abs() < 0.05) return 'Unísono';
    if ((ratio - 2.0).abs() < 0.1) return 'Octava';
    if ((ratio - 1.5).abs() < 0.08) return 'Quinta Justa';
    if ((ratio - 1.333).abs() < 0.08) return 'Cuarta Justa';
    if ((ratio - 1.25).abs() < 0.06) return 'Tercera Mayor';
    if ((ratio - 1.2).abs() < 0.06) return 'Tercera Menor';
    if ((ratio - 1.667).abs() < 0.08) return 'Sexta Mayor';
    return 'Intervalo Libre';
  }

  const HarmonicCompatibility({
    required this.resonanceA,
    required this.resonanceB,
    required this.pitchConsonance,
    required this.signatureSimilarity,
    required this.centroidComplementarity,
  });

  /// Compare two footprints and compute compatibility.
  factory HarmonicCompatibility.compute(
    HarmonicFootprint a,
    HarmonicFootprint b,
  ) {
    return HarmonicCompatibility(
      resonanceA: a.resonanceHz,
      resonanceB: b.resonanceHz,
      pitchConsonance: _computeConsonance(a.resonanceHz, b.resonanceHz),
      signatureSimilarity: _computeSimilarity(
        a.harmonicSignature,
        b.harmonicSignature,
      ),
      centroidComplementarity: _computeComplementarity(
        a.spectralCentroidAvg,
        b.spectralCentroidAvg,
      ),
    );
  }

  /// Consonance based on simple integer ratios (just intonation).
  /// Closer to a simple ratio (2:1, 3:2, 4:3) = higher consonance.
  static double _computeConsonance(double hzA, double hzB) {
    if (hzA <= 0 || hzB <= 0) return 0.0;
    final ratio = math.max(hzA, hzB) / math.min(hzA, hzB);

    // Check proximity to consonant ratios (unison through octave).
    const consonantRatios = [1.0, 1.2, 1.25, 1.333, 1.5, 1.667, 2.0];
    double bestDist = double.infinity;
    for (final cr in consonantRatios) {
      final dist = (ratio - cr).abs();
      if (dist < bestDist) bestDist = dist;
    }
    // Map distance to score: 0 distance = 1.0, >0.15 distance = 0.0.
    return (1.0 - (bestDist / 0.15)).clamp(0.0, 1.0);
  }

  /// Cosine similarity of the 8-harmonic signatures.
  static double _computeSimilarity(List<double> sigA, List<double> sigB) {
    if (sigA.isEmpty || sigB.isEmpty) return 0.0;
    final n = math.min(sigA.length, sigB.length);
    double dot = 0, magA = 0, magB = 0;
    for (int i = 0; i < n; i++) {
      dot += sigA[i] * sigB[i];
      magA += sigA[i] * sigA[i];
      magB += sigB[i] * sigB[i];
    }
    if (magA == 0 || magB == 0) return 0.0;
    return (dot / (math.sqrt(magA) * math.sqrt(magB))).clamp(0.0, 1.0);
  }

  /// Complementarity: bright+dark voices balance better than two bright or
  /// two dark. Score peaks when centroids are moderately different.
  static double _computeComplementarity(double centA, double centB) {
    if (centA <= 0 || centB <= 0) return 0.0;
    final diff = (centA - centB).abs();
    // Sweet spot: ~500-1500 Hz difference. Too close = redundant, too far = clash.
    if (diff < 200) return diff / 200 * 0.5; // Low complementarity
    if (diff <= 1500) return 0.5 + (diff - 200) / 1300 * 0.5; // Rising
    return (1.0 - (diff - 1500) / 2000).clamp(0.0, 1.0); // Declining
  }

  Map<String, dynamic> toJson() => {
        'resonanceA': resonanceA,
        'resonanceB': resonanceB,
        'pitchConsonance': pitchConsonance,
        'signatureSimilarity': signatureSimilarity,
        'centroidComplementarity': centroidComplementarity,
        'overallScore': overallScore,
        'label': label,
        'intervalName': intervalName,
      };
}
