// Compile with dart compile js from an app package configuration, then run
// using pcm_web_backend_probe.cjs. The harness replaces AudioContext entirely:
// no browser, audio hardware, microphone, network, or Firebase is used.
import 'dart:typed_data';

import 'package:neom_generator/engine/audio/neom_pcm_backend_web.dart';

Future<void> main() async {
  final backend = createNeomPcmBackend();
  await backend.activate();
  await backend.start(sampleRate: 44100, channels: 2, framesPerBuffer: 1024);
  final pcm = Int16List(2048);
  for (var frame = 0; frame < 1024; frame++) {
    pcm[frame * 2] = 32767;
    pcm[frame * 2 + 1] = -32768;
  }
  for (var buffer = 0; buffer < 100; buffer++) {
    await backend.waitForCapacity(1024);
    await backend.write(pcm.buffer.asUint8List());
  }
  await backend.drain();
  if (backend.playedFrames != 102400) {
    throw StateError('Lost frames after drain: ${backend.playedFrames}');
  }
  await backend.stop();

  // Reuse the unlocked context and cancel a bounded backpressure wait.
  await backend.activate();
  await backend.start(sampleRate: 44100, channels: 2, framesPerBuffer: 1024);
  for (var buffer = 0; buffer < 3; buffer++) {
    await backend.waitForCapacity(1024);
    await backend.write(pcm.buffer.asUint8List());
  }
  final waiting = backend.waitForCapacity(1024);
  backend.interrupt();
  await waiting;
  await backend.dispose();
  // Completion protocol consumed by the Node test harness.
  // ignore: avoid_print
  print('PCM_WEB_PROBE_OK');
}
