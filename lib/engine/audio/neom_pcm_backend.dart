import 'dart:typed_data';

/// Output only: synthesis stays in Dart and never uses a microphone.
abstract interface class NeomPcmBackend {
  Future<void> init();

  /// Called synchronously from the play gesture, before serialized async work.
  Future<void> activate();

  Future<void> start({
    required int sampleRate,
    required int channels,
    required int framesPerBuffer,
  });
  Future<void> waitForCapacity(int frames);
  Future<void> write(Uint8List pcm);
  Future<void> drain();

  /// Synchronously cancels backpressure waits and any queued web sources.
  void interrupt();
  Future<void> stop();
  Future<void> dispose();

  /// Frames reached by the output clock, excluding queued future buffers.
  /// Native devices may add latency not exposed by the PCM stream API.
  int get playedFrames;
}
