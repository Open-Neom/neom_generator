import 'dart:typed_data';

import 'neom_voice_capture_stub.dart'
    if (dart.library.js_interop) 'neom_voice_capture_web.dart'
    as platform;

/// Short, explicit microphone measurement; never writes an audio file.
abstract interface class NeomVoiceCapture {
  bool get isActive;
  int get sampleRate;
  Future<int> start(void Function(Uint8List monoPcm16) onMonoPcm16);
  Future<void> stop();
  Future<void> dispose();
}

NeomVoiceCapture createNeomVoiceCapture() => platform.createNeomVoiceCapture();
