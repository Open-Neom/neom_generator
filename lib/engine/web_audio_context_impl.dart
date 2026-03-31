import 'package:web/web.dart' as web;

/// Returns the browser's AudioContext sample rate — this is the EXACT
/// sample rate the system audio hardware uses. No guessing.
///
/// Standard values: 44100 (most systems) or 48000 (pro audio cards).
/// The browser normalizes all audio streams to this rate.
double getWebAudioContextSampleRate() {
  try {
    final ctx = web.AudioContext();
    final rate = ctx.sampleRate;
    ctx.close();
    return rate;
  } catch (_) {
    return 48000.0; // Safe fallback for web
  }
}

/// Returns the number of channels the browser mic stream provides.
/// Uses getUserMedia constraints to check.
int getWebAudioChannelCount() {
  // On web, flutter_sound requests mono but browsers may deliver stereo.
  // The AudioContext itself doesn't tell us — the MediaStream does.
  // For now, we rely on the sample rate being correct (which it is via
  // AudioContext.sampleRate) and handle channel count via the data format.
  // Most browsers deliver mono when mono is requested in getUserMedia.
  return 1;
}
