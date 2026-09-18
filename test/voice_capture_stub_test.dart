import 'package:flutter_test/flutter_test.dart';
// Import the stub explicitly so even a Chrome test run cannot request a mic.
import 'package:neom_generator/engine/audio/neom_voice_capture_stub.dart';

void main() {
  test(
    'native stub never requests a microphone or replaces native recorder',
    () async {
      final capture = createNeomVoiceCapture();
      expect(capture.isActive, isFalse);
      expect(capture.sampleRate, 0);
      await expectLater(
        capture.start((_) => fail('Unexpected PCM')),
        throwsUnsupportedError,
      );
      await capture.stop();
      await capture.dispose();
      expect(capture.isActive, isFalse);
    },
  );
}
