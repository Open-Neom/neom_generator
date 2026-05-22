import 'harmonic_footprint.dart';
import 'vocal_range.dart';

/// A compact, shareable representation of a user's Huella Armónica.
///
/// The sonic avatar is the "identity card" of a user in the vibrational
/// networks of Cyberneom. It's derived from the full footprint but
/// reduced to a portable format that can be:
///
/// * Displayed as a badge in profiles and chat
/// * Shared via QR code or deep link
/// * Used to match users for Ceremonias
/// * Verified against a live voice capture (is this person who they say?)
///
/// The 8-value [signature] is like a fingerprint — statistically unique
/// per person because it encodes the relative strengths of vocal harmonics,
/// which depend on throat shape, vocal cord thickness, nasal cavity
/// resonance, and speaking habits.
class SonicAvatar {
  /// The user's most common pitch (mode of all captures).
  final double resonanceHz;

  /// Vocal classification (bass → soprano).
  final VocalRange vocalRange;

  /// 8-value harmonic signature normalized to sum = 1.0.
  /// This is the "shape" of the avatar — unique per person.
  final List<double> signature;

  /// Spectral brightness (0–1 normalized from centroid Hz).
  final double brightness;

  /// Voice steadiness (0–1). High = consistent pitch across captures.
  final double steadiness;

  /// How many captures contributed to this avatar.
  final int sampleCount;

  const SonicAvatar({
    required this.resonanceHz,
    required this.vocalRange,
    required this.signature,
    required this.brightness,
    required this.steadiness,
    required this.sampleCount,
  });

  /// Generate from a full footprint.
  factory SonicAvatar.fromFootprint(HarmonicFootprint fp) {
    if (fp.totalCaptures == 0) {
      return SonicAvatar(
        resonanceHz: 0,
        vocalRange: VocalRange.tenor,
        signature: List.filled(8, 0.125),
        brightness: 0.5,
        steadiness: 0,
        sampleCount: 0,
      );
    }

    // Normalize signature to sum = 1.0.
    final raw = fp.harmonicSignature;
    final sum = raw.fold<double>(0, (s, v) => s + v);
    final normalized = sum > 0
        ? raw.map((v) => v / sum).toList()
        : List.filled(8, 0.125);

    // Brightness: centroid mapped to 0–1 (200 Hz = 0, 4000 Hz = 1).
    final brightness = ((fp.spectralCentroidAvg - 200) / 3800).clamp(0.0, 1.0);

    // Steadiness: 1 - coefficient of variation of resonance across captures.
    final pitches = fp.captures.map((c) => c.fundamentalHz).toList();
    double steadiness = 1.0;
    if (pitches.length >= 2) {
      final mean = pitches.reduce((a, b) => a + b) / pitches.length;
      if (mean > 0) {
        final variance = pitches
                .map((p) => (p - mean) * (p - mean))
                .reduce((a, b) => a + b) /
            pitches.length;
        final cv = _sqrt(variance) / mean;
        steadiness = (1.0 - cv).clamp(0.0, 1.0);
      }
    }

    return SonicAvatar(
      resonanceHz: fp.resonanceHz,
      vocalRange: VocalRange.classify(fp.resonanceHz),
      signature: List.unmodifiable(normalized),
      brightness: brightness,
      steadiness: steadiness,
      sampleCount: fp.totalCaptures,
    );
  }

  /// Compact string representation for QR codes / deep links.
  /// Format: `SA:resonanceHz:sig0:sig1:...:sig7:brightness:steadiness`
  String toCompactString() {
    final sigStr = signature.map((v) => v.toStringAsFixed(3)).join(':');
    return 'SA:${resonanceHz.toStringAsFixed(1)}:$sigStr:'
        '${brightness.toStringAsFixed(2)}:${steadiness.toStringAsFixed(2)}';
  }

  /// Parse from compact string.
  static SonicAvatar? fromCompactString(String s) {
    final parts = s.split(':');
    if (parts.length < 12 || parts[0] != 'SA') return null;
    try {
      final hz = double.parse(parts[1]);
      final sig = List.generate(8, (i) => double.parse(parts[2 + i]));
      final br = double.parse(parts[10]);
      final st = double.parse(parts[11]);
      return SonicAvatar(
        resonanceHz: hz,
        vocalRange: VocalRange.classify(hz),
        signature: List.unmodifiable(sig),
        brightness: br,
        steadiness: st,
        sampleCount: 0,
      );
    } catch (_) {
      return null;
    }
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
        'resonanceHz': resonanceHz,
        'vocalRange': vocalRange.name,
        'signature': signature,
        'brightness': brightness,
        'steadiness': steadiness,
        'sampleCount': sampleCount,
      };
}
