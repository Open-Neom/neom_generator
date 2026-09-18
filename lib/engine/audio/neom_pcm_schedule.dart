import 'dart:math' as math;

/// Bounded software queue shared by web scheduling and native pacing.
///
/// No wall-clock time: callers supply AudioContext.currentTime or Stopwatch.
/// This prevents an output implementation accepting buffers immediately from
/// running synthesis seconds ahead of the controls (or growing without bound).
class NeomPcmSchedule {
  NeomPcmSchedule({
    required this.sampleRate,
    this.maxBufferedSeconds = 0.080,
    this.leadSeconds = 0,
  });

  final int sampleRate;
  final double maxBufferedSeconds;
  final double leadSeconds;
  final List<({double start, int frames})> _pending = [];
  double _end = 0;
  int _completedFrames = 0;

  double waitSeconds(double now, int frames) =>
      math.max(0, _end - now + frames / sampleRate - maxBufferedSeconds);

  double reserve(double now, int frames) {
    if (frames <= 0 || frames / sampleRate + leadSeconds > maxBufferedSeconds) {
      throw ArgumentError.value(frames, 'frames', 'Exceeds bounded PCM queue');
    }
    if (waitSeconds(now, frames) > 0.000001) {
      throw StateError('PCM producer exceeded output backpressure');
    }
    playedFramesAt(now); // Keep only the handful of not-yet-played buffers.
    final start = math.max(_end, now + leadSeconds);
    _end = start + frames / sampleRate;
    _pending.add((start: start, frames: frames));
    return start;
  }

  double remainingSeconds(double now) => math.max(0, _end - now);

  int playedFramesAt(double now) {
    while (_pending.isNotEmpty) {
      final first = _pending.first;
      if (now + 0.000000001 < first.start + first.frames / sampleRate) break;
      _completedFrames += first.frames;
      _pending.removeAt(0);
    }
    if (_pending.isEmpty) return _completedFrames;
    final first = _pending.first;
    return _completedFrames +
        ((now - first.start) * sampleRate).floor().clamp(0, first.frames);
  }
}
