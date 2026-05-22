/// Voice classification based on fundamental frequency range.
enum VocalRange {
  bass(80, 330, 'Bajo'),
  baritone(100, 400, 'Baritono'),
  tenor(130, 520, 'Tenor'),
  alto(175, 700, 'Alto/Contralto'),
  mezzoSoprano(220, 880, 'Mezzosoprano'),
  soprano(260, 1050, 'Soprano');

  /// Lower bound of this vocal range in Hz.
  final double minHz;

  /// Upper bound of this vocal range in Hz.
  final double maxHz;

  /// Human-readable display name.
  final String displayName;

  const VocalRange(this.minHz, this.maxHz, this.displayName);

  /// Classify a fundamental frequency into the best matching vocal range.
  ///
  /// Finds the range whose center frequency is closest to [fundamentalHz].
  static VocalRange classify(double fundamentalHz) {
    VocalRange best = VocalRange.bass;
    double bestDistance = double.infinity;

    for (final range in VocalRange.values) {
      final center = (range.minHz + range.maxHz) / 2;
      final distance = (fundamentalHz - center).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        best = range;
      }
    }

    return best;
  }
}
