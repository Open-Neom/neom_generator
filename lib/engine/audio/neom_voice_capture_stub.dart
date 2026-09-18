import 'dart:typed_data';

import 'neom_voice_capture.dart';

NeomVoiceCapture createNeomVoiceCapture() => _UnsupportedVoiceCapture();

class _UnsupportedVoiceCapture implements NeomVoiceCapture {
  @override
  bool get isActive => false;
  @override
  int get sampleRate => 0;
  @override
  Future<int> start(void Function(Uint8List) onMonoPcm16) async =>
      throw UnsupportedError('Use the native recorder on this platform.');
  @override
  Future<void> stop() async {}
  @override
  Future<void> dispose() => stop();
}
