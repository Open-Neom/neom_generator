/// Emotional state inferred from a voice capture's spectral properties.
///
/// Uses the spectral centroid (brightness) and volume (energy) as
/// proxies for arousal and valence — validated correlations in
/// affective computing research (Schuller et al., 2013).
///
/// * High centroid + high volume → **tense** (aroused + negative)
/// * High centroid + low volume → **focused** (aroused + positive)
/// * Low centroid + high volume → **energized** (calm + positive)
/// * Low centroid + low volume → **calm** (calm + neutral/positive)
enum VocalEmotionalState {
  calm(
    'Calma',
    'Tu voz refleja serenidad. Buen momento para profundizar.',
    0xFF4CAF50, // green
  ),
  focused(
    'Enfoque',
    'Tu voz muestra concentración. Aprovecha el momentum.',
    0xFF2196F3, // blue
  ),
  energized(
    'Energía',
    'Tu voz tiene fuerza. Canaliza esa vibración.',
    0xFFFF9800, // amber
  ),
  tense(
    'Tensión',
    'Tu voz revela estrés. La Cámara Neom puede ayudarte.',
    0xFFF44336, // red
  );

  /// Display name in Spanish.
  final String displayName;

  /// Contextual suggestion for the user.
  final String suggestion;

  /// Color for UI indicators.
  final int color;

  const VocalEmotionalState(this.displayName, this.suggestion, this.color);

  /// Classify from spectral centroid (Hz) and volume (0-1 normalized).
  ///
  /// Thresholds derived from speech analysis literature:
  /// * Centroid > 1500 Hz = bright/aroused voice
  /// * Volume > 0.6 = high energy speech
  static VocalEmotionalState classify({
    required double spectralCentroid,
    required double volume,
  }) {
    final bright = spectralCentroid > 1500;
    final loud = volume > 0.6;

    if (bright && loud) return VocalEmotionalState.tense;
    if (bright && !loud) return VocalEmotionalState.focused;
    if (!bright && loud) return VocalEmotionalState.energized;
    return VocalEmotionalState.calm;
  }
}
