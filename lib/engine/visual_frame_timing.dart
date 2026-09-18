/// Separates real ticker time from the lower-frequency, foreground-only UI.
///
/// The real delta remains available to session tracking and binaural state;
/// only the visual delta is capped after a delayed frame or suspension.
class VisualFrameTiming {
  VisualFrameTiming({
    this.frameInterval = const Duration(microseconds: 33333),
    this.maxVisualDelta = const Duration(milliseconds: 100),
  }) : assert(frameInterval > Duration.zero),
       assert(maxVisualDelta > Duration.zero);

  final Duration frameInterval;
  final Duration maxVisualDelta;
  Duration _previousElapsed = Duration.zero;
  int _cadenceMicros = 0;
  int _pendingVisualMicros = 0;
  bool _skipNextVisualDelta = false;

  /// Call whenever a Ticker starts again: its elapsed duration starts at zero.
  void reset() {
    _previousElapsed = Duration.zero;
    _cadenceMicros = 0;
    _pendingVisualMicros = 0;
    _skipNextVisualDelta = false;
  }

  /// Discards hidden time without resetting the real session clock.
  void resetVisual() {
    _cadenceMicros = 0;
    _pendingVisualMicros = 0;
    _skipNextVisualDelta = true;
  }

  VisualFrameDelta advance(Duration elapsed, {required bool visualEnabled}) {
    if (elapsed < _previousElapsed) {
      reset();
      _previousElapsed = elapsed;
      return const VisualFrameDelta(deltaSeconds: 0);
    }

    final deltaMicros = (elapsed - _previousElapsed).inMicroseconds;
    _previousElapsed = elapsed;
    final deltaSeconds = deltaMicros / Duration.microsecondsPerSecond;

    if (!visualEnabled) {
      resetVisual();
      return VisualFrameDelta(deltaSeconds: deltaSeconds);
    }
    if (_skipNextVisualDelta) {
      _skipNextVisualDelta = false;
      return VisualFrameDelta(deltaSeconds: deltaSeconds);
    }

    _cadenceMicros += deltaMicros;
    _pendingVisualMicros += deltaMicros;
    if (_cadenceMicros < frameInterval.inMicroseconds) {
      return VisualFrameDelta(deltaSeconds: deltaSeconds);
    }

    // Retain fractional cadence at 60/120/144 Hz, without issuing catch-up
    // frames or counting the remainder twice in the phase delta.
    _cadenceMicros %= frameInterval.inMicroseconds;
    final visualMicros = _pendingVisualMicros.clamp(
      0,
      maxVisualDelta.inMicroseconds,
    );
    _pendingVisualMicros = 0;
    return VisualFrameDelta(
      deltaSeconds: deltaSeconds,
      visualDeltaSeconds: visualMicros / Duration.microsecondsPerSecond,
    );
  }
}

class VisualFrameDelta {
  const VisualFrameDelta({required this.deltaSeconds, this.visualDeltaSeconds});

  final double deltaSeconds;
  final double? visualDeltaSeconds;
}
