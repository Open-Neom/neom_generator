class NeomVisualState {
  final double phase;
  final double amplitude;
  final double pan;        // -1..1
  final double breath;     // 0..1
  final double modulation; // 0..1
  final double neuro;      // 0..1
  final double frequency; // 0.0 → grave | 1.0 → agudo

  const NeomVisualState({
    required this.phase,
    required this.amplitude,
    required this.pan,
    required this.breath,
    required this.modulation,
    required this.neuro,
    this.frequency = 0,
  });

  static NeomVisualState zero() => const NeomVisualState(
    phase: 0,
    amplitude: 0,
    pan: 0,
    breath: 0,
    modulation: 0,
    neuro: 0,
    frequency: 0
  );
}
