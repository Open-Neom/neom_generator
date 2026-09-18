import 'dart:math';

/// Optional, sample-clock fades. This never delays or intercepts a manual Stop.
///
/// Raised-cosine ramps start/end with a zero slope. When ramps overlap their
/// gains multiply, so a short session remains smooth and cannot gain volume.
class NeomSessionEnvelope {
  NeomSessionEnvelope({
    required int sampleRate,
    double fadeInSeconds = 0,
    double fadeOutSeconds = 0,
    this.endFrame,
  }) : _inFrames = durationFrames(fadeInSeconds, sampleRate),
       _outFrames = durationFrames(fadeOutSeconds, sampleRate);

  /// Exclusive scheduled end, not necessarily the eventual manual-stop frame.
  /// Null/zero means there was no scheduled ending and therefore no fade-out.
  final int? endFrame;
  final int _inFrames;
  final int _outFrames;

  /// Bound malformed external values while keeping disabled fades exact.
  static int durationFrames(double seconds, int sampleRate) {
    if (!seconds.isFinite || seconds <= 0 || sampleRate <= 0) return 0;
    return (seconds.clamp(0, 3600) * sampleRate).round();
  }

  double gainAt(int frame) {
    var gain = 1.0;
    if (_inFrames > 0 && frame < _inFrames) {
      gain = _ramp(frame / _inFrames);
    }
    final end = endFrame;
    if (_outFrames > 0 && end != null && end > 0) {
      // The last emitted sample is silent, including a partial final buffer.
      final remaining = end - 1 - frame;
      if (remaining < _outFrames) gain *= _ramp(remaining / _outFrames);
    }
    return gain;
  }

  static double _ramp(double progress) {
    if (progress <= 0) return 0;
    if (progress >= 1) return 1;
    return (1 - cos(pi * progress)) * .5;
  }
}
