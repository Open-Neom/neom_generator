import '../../domain/models/incienso.dart';
import '../../domain/models/incienso_audio_state.dart';

/// Audio-frame cursor, independent of UI tickers, timers and wall-clock jumps.
/// v2 replays actual control events as steps; legacy samples interpolate only
/// where the destination is not a manual action.
class InciensoPlayback {
  InciensoPlayback(this.incienso) {
    if (incienso.recordingVersion > 2 || incienso.sampleRate != 44100) {
      throw UnsupportedError('Unsupported Incienso recording format');
    }
    var previous = -1;
    for (final k in incienso.timeline) {
      if (!k.timestampMs.isFinite ||
          k.timestampMs < 0 ||
          !k.leftHz.isFinite ||
          !k.rightHz.isFinite ||
          !k.volume.isFinite) {
        throw FormatException('Invalid Incienso timeline');
      }
      final frame = frameOf(k);
      if (frame < previous) {
        throw FormatException('Unordered Incienso timeline');
      }
      previous = frame;
      if (k.audioState != null &&
          k.audioState!.engineVersion !=
              InciensoAudioState.currentEngineVersion) {
        throw UnsupportedError('Unsupported Incienso synthesis version');
      }
    }
    if (incienso.recordingVersion >= 2 &&
        (incienso.timeline.isEmpty ||
            incienso.timeline.first.audioState == null ||
            frameOf(incienso.timeline.first) != 0)) {
      throw FormatException('Recorded session has no initial synthesis state');
    }
  }

  final Incienso incienso;
  int _cursor = -1;
  int _lastFrame = -1;
  int get endFrame =>
      (incienso.effectiveDuration.inMicroseconds *
              incienso.sampleRate /
              1000000)
          .round();
  int frameOf(InciensoKeyframe k) =>
      k.sampleFrame ?? (k.timestampMs * incienso.sampleRate / 1000).round();
  void reset() {
    _cursor = -1;
    _lastFrame = -1;
  }

  void applyAt(
    int frame, {
    required void Function(InciensoAudioState) applyState,
    required void Function(InciensoKeyframe) applyLegacy,
  }) {
    if (frame < _lastFrame) reset();
    _lastFrame = frame;
    final timeline = incienso.timeline;
    if (timeline.isEmpty) return;
    if (incienso.recordingVersion >= 2) {
      while (_cursor + 1 < timeline.length &&
          frameOf(timeline[_cursor + 1]) <= frame) {
        final k = timeline[++_cursor];
        if (k.audioState != null) applyState(k.audioState!);
      }
      return;
    }
    while (_cursor + 1 < timeline.length &&
        frameOf(timeline[_cursor + 1]) <= frame) {
      _cursor++;
    }
    final a = timeline[_cursor < 0 ? 0 : _cursor];
    final b = timeline[(_cursor + 1).clamp(0, timeline.length - 1)];
    final start = frameOf(a), span = frameOf(b) - start;
    final t = b.isUserAction || span <= 0
        ? 0.0
        : ((frame - start) / span).clamp(0.0, 1.0);
    applyLegacy(
      InciensoKeyframe(
        timestampMs: frame * 1000 / incienso.sampleRate,
        leftHz: a.leftHz + (b.leftHz - a.leftHz) * t,
        rightHz: a.rightHz + (b.rightHz - a.rightHz) * t,
        volume: a.volume + (b.volume - a.volume) * t,
        neuroState: a.neuroState,
        visualExperience: a.visualExperience,
        breathPhase: a.breathPhase,
      ),
    );
  }
}
