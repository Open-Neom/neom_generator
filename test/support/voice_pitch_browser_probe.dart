// Compile to JavaScript and run via voice_pitch_browser_probe.cjs.
// The harness supplies a synthetic MediaStream, never a person's microphone.
import 'dart:js_interop';

import 'package:neom_generator/engine/audio/neom_voice_pitch_measurement.dart';

@JS('voicePitchResult')
external void report(JSAny result);

Future<void> main() async {
  final measurement = VoicePitchMeasurement(
    measurementDuration: const Duration(milliseconds: 1400),
  );
  final live = <double>[];
  try {
    final pitch = await measurement.measure(onPitch: live.add);
    await measurement.dispose();
    report({'ok': true, 'pitch': pitch, 'live': live}.jsify()!);
  } catch (error) {
    await measurement.dispose();
    report({'ok': false, 'error': '$error'}.jsify()!);
  }
}
