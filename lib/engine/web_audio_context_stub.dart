/// Stub for non-web platforms. Returns default 44100.
double getWebAudioContextSampleRate() => 44100.0;

/// Stub — always returns 1 (mono) on non-web.
int getWebAudioChannelCount() => 1;
