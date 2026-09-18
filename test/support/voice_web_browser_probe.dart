// Real browser probe fed by a synthetic MediaStream, never getUserMedia input.
import 'dart:async';
import 'dart:js_interop';

import 'package:neom_generator/engine/audio/neom_voice_capture.dart';

@JS('voiceBrowserResult')
external void report(JSAny result);

Future<void> main() async {
  final capture = createNeomVoiceCapture();
  final received = Completer<void>();
  var buffers = 0;
  var nonzero = 0;
  var rate = 0;
  try {
    rate = await capture.start((pcm) {
      buffers++;
      for (final sample in pcm.buffer.asInt16List()) {
        if (sample.abs() > 100) nonzero++;
      }
      if (buffers >= 3 && nonzero > 100 && !received.isCompleted) {
        received.complete();
      }
    });
    await received.future.timeout(const Duration(seconds: 8));
    await capture.stop();
    report(
      {
        'ok': true,
        'buffers': buffers,
        'nonzeroSamples': nonzero,
        'sampleRate': rate,
        'isActiveAfterStop': capture.isActive,
      }.jsify()!,
    );
  } catch (error) {
    await capture.stop();
    report(
      {
        'ok': false,
        'error': '$error',
        'buffers': buffers,
        'nonzeroSamples': nonzero,
        'sampleRate': rate,
      }.jsify()!,
    );
  }
}
