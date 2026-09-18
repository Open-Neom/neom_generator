// Compile to JavaScript and run using voice_web_capture_probe.cjs.
// getUserMedia, AudioContext and AudioWorklet are entirely mocked.
import 'dart:js_interop';

import 'package:neom_generator/engine/audio/neom_voice_capture.dart';

@JS('voiceTestGrant')
external void grant(int request);
@JS('voiceTestDeny')
external void deny(int request);
@JS('voiceTestFailWorklet')
external void failWorklet();
@JS('voiceTestEmit')
external void emitPcm();
@JS('voiceTestAssertClean')
external void assertClean();

Future<bool> rejected(Future<int> start) =>
    start.then((_) => false, onError: (Object _) => true);
void check(bool valid, String reason) {
  if (!valid) throw StateError(reason);
}

Future<void> main() async {
  final capture = createNeomVoiceCapture();
  check(
    !capture.isActive && capture.sampleRate == 0,
    'Construction requested mic',
  );
  var callbacks = 0;
  final first = capture.start((pcm) {
    callbacks++;
    check(
      capture.sampleRate == 48000,
      'Actual rate unavailable before callback',
    );
    check(pcm.length == 4096, 'Unexpected mono PCM size');
    final samples = pcm.buffer.asInt16List();
    check(samples[0] == 1234 && samples[1] == -1234, 'PCM delivery corrupted');
  });
  grant(0);
  check(await first == 48000 && capture.isActive, 'Capture did not start');
  emitPcm();
  check(callbacks == 1, 'No PCM callback');
  final stopped = capture.stop();
  check(!capture.isActive, 'Stop must invalidate capture synchronously');
  await stopped;
  emitPcm();
  check(callbacks == 1, 'Late stopped-session data reached consumer');
  assertClean();

  final denied = rejected(capture.start((_) {}));
  deny(1);
  check(await denied, 'Permission denial was not reported');
  assertClean();

  final cancelled = rejected(capture.start((_) {}));
  await capture.stop();
  assertClean();
  grant(2); // Permission finishes after user cancelled.
  check(await cancelled, 'Cancelled permission became an active session');
  assertClean();

  final stale = rejected(capture.start((_) {}));
  await capture.stop();
  final latest = capture.start((_) {});
  grant(4); // New request resolves before the previous permission request.
  await latest;
  grant(3);
  check(await stale, 'Stale request did not reject');
  check(capture.isActive, 'Old cleanup stopped the new capture');
  await capture.dispose();
  assertClean();

  failWorklet();
  final brokenModule = rejected(capture.start((_) {}));
  grant(5);
  check(await brokenModule, 'Module failure was not reported');
  assertClean();
  // Completion protocol consumed by the Node test harness.
  // ignore: avoid_print
  print('VOICE_WEB_PROBE_OK');
}
