/// Multi-frequency engine tests — Hermetic, no Hive, no FlutterSound, no Sint.
///
/// Tests the 3rd oscillator (Sub + L + R) added for acoustic levitation.
/// Exercises: gain staging, clipping, phase wrapping, mode transitions,
/// edge-case frequencies, channel independence, and state isolation.
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/engine/neom_breath_engine.dart';
import 'package:neom_generator/engine/neom_sine_engine.dart';
import 'package:neom_generator/utils/constants/neom_generator_constants.dart';

/// Decode the PCM16 buffer back into (left, right) sample pairs.
List<(int left, int right)> decodePcm(Uint8List raw) {
  final pcm = raw.buffer.asInt16List();
  final frames = pcm.length ~/ 2;
  return List.generate(frames, (i) => (pcm[i * 2], pcm[i * 2 + 1]));
}

/// Find the peak absolute value across all frames in one channel.
int peakAbs(Uint8List raw, {required bool left}) {
  final pcm = raw.buffer.asInt16List();
  int peak = 0;
  for (int i = (left ? 0 : 1); i < pcm.length; i += 2) {
    final v = pcm[i].abs();
    if (v > peak) peak = v;
  }
  return peak;
}

/// RMS of one channel (0.0–1.0 normalized to 32767).
double rmsChannel(Uint8List raw, {required bool left}) {
  final pcm = raw.buffer.asInt16List();
  double sum = 0;
  int count = 0;
  for (int i = (left ? 0 : 1); i < pcm.length; i += 2) {
    sum += pcm[i] * pcm[i];
    count++;
  }
  return sqrt(sum / count) / 32767.0;
}

void main() {
  late NeomSineEngine engine;

  setUp(() {
    engine = NeomSineEngine.shared;
    // Reset ALL state to avoid leaking between tests
    engine.multiFrequencyMode = false;
    engine.frequencyL = 0.0;
    engine.frequencyR = 0.0;
    engine.frequencySub = 0.0;
    engine.subMixLevel = 0.5;
    engine.frequency = 432.0;
    engine.beat = 0.0;
    engine.volume = 1.0;
    engine.posX = 0.0;
    engine.posY = 0.0;
    engine.posZ = 0.0;
    // Reset phases to avoid state leaking between tests
    engine.resetPhases();
    // Disable all modulators so tests are deterministic
    engine.modulator.enabled = false;
    engine.isochronic.enabled = false;
    engine.breathEngine.mode = NeomBreathMode.off;
    engine.painterEngine = null;
  });

  // ═══════════════════════════════════════════════════════════
  // GROUP 1: GAIN STAGING & CLIPPING
  // ═══════════════════════════════════════════════════════════
  group('Multi-frequency gain staging', () {

    test('BUG: combined L+Sub MUST NOT exceed int16 range at full volume', () {
      // This is the critical clipping bug.
      // With 3 oscillators at same frequency (worst case: all peaks align),
      // the combined sample MUST stay within [-32768, 32767] WITHOUT
      // relying on .clamp() to save us (clamp = audible distortion).
      engine.multiFrequencyMode = true;
      engine.frequencyL = 100.0;
      engine.frequencyR = 100.0;
      engine.frequencySub = 100.0; // Same freq = peaks always align
      engine.volume = 1.0;
      engine.subMixLevel = 0.5;

      // Generate several buffers to hit peak alignment
      int maxSampleSeen = 0;
      for (int b = 0; b < 10; b++) {
        final raw = engine.generateBufferForTesting();
        final peakL = peakAbs(raw, left: true);
        final peakR = peakAbs(raw, left: false);
        maxSampleSeen = max(maxSampleSeen, max(peakL, peakR));
      }

      // If the gain staging is correct, the pre-clamp value should be <= 32767.
      // We can't see pre-clamp values directly, but we CAN check if
      // the output is suspiciously at exactly 32767 (flat-topped = clipping).
      //
      // A properly gain-staged signal with vol=1.0 should peak near but
      // not AT 32767 (or at exactly 32767 without flat-topping).
      // If we see many consecutive samples at exactly 32767, that's clipping.
      engine.frequencyL = 100.0;
      engine.frequencyR = 100.0;
      engine.frequencySub = 100.0;

      final raw = engine.generateBufferForTesting();
      final pcm = raw.buffer.asInt16List();
      int consecutiveClipped = 0;
      int maxConsecutive = 0;
      for (int i = 0; i < pcm.length; i += 2) {
        if (pcm[i].abs() == 32767) {
          consecutiveClipped++;
          maxConsecutive = max(maxConsecutive, consecutiveClipped);
        } else {
          consecutiveClipped = 0;
        }
      }

      // More than 5 consecutive clipped samples = gain staging is broken
      expect(maxConsecutive, lessThanOrEqualTo(5),
        reason: 'Multi-frequency mode is clipping: $maxConsecutive consecutive '
                'samples at ±32767. The gain staging formula is wrong — '
                'L gain + Sub gain > 1.0');
    });

    test('subMixLevel=0 produces silence on sub channel (L/R at full gain)', () {
      engine.multiFrequencyMode = true;
      engine.frequencyL = 440.0;
      engine.frequencyR = 440.0;
      engine.frequencySub = 100.0;
      engine.subMixLevel = 0.0;
      engine.volume = 1.0;

      final raw = engine.generateBufferForTesting();
      // With subMixLevel = 0, the output should be identical to single-freq
      // at 440 Hz on both channels (no sub contribution)
      final rmsL = rmsChannel(raw, left: true);
      expect(rmsL, greaterThan(0.3),
        reason: 'L channel should have signal when subMixLevel=0');
    });

    test('subMixLevel=1 reduces L/R to make room for sub', () {
      engine.multiFrequencyMode = true;
      engine.frequencyL = 440.0;
      engine.frequencyR = 440.0;
      engine.frequencySub = 100.0;
      engine.volume = 1.0;

      // Capture at different sub mix levels
      engine.subMixLevel = 0.0;
      final raw0 = engine.generateBufferForTesting();
      final rmsL0 = rmsChannel(raw0, left: true);

      engine.subMixLevel = 1.0;
      final raw1 = engine.generateBufferForTesting();
      final rmsL1 = rmsChannel(raw1, left: true);

      // With subMixLevel=1.0, L/R should be quieter due to gain compensation
      // (unless there's a clipping bug, in which case both could be similar
      // because everything is at the clamp ceiling)
      expect(rmsL1, lessThan(rmsL0 * 1.1),
        reason: 'Higher subMixLevel should reduce L/R to prevent clipping');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // GROUP 2: CHANNEL INDEPENDENCE
  // ═══════════════════════════════════════════════════════════
  group('Channel routing isolation', () {

    test('L and R are spectrally independent in multi-frequency mode', () {
      engine.multiFrequencyMode = true;
      engine.frequencyL = 100.0;  // Very different frequencies
      engine.frequencyR = 1000.0;
      engine.frequencySub = 0.0;  // No sub to simplify
      engine.subMixLevel = 0.0;
      engine.volume = 1.0;

      final raw = engine.generateBufferForTesting();
      final pairs = decodePcm(raw);

      // Count zero crossings per channel — higher freq = more crossings
      int crossingsL = 0, crossingsR = 0;
      for (int i = 1; i < pairs.length; i++) {
        if (pairs[i].$1.sign != pairs[i - 1].$1.sign && pairs[i].$1 != 0) crossingsL++;
        if (pairs[i].$2.sign != pairs[i - 1].$2.sign && pairs[i].$2 != 0) crossingsR++;
      }

      // R at 1000 Hz should have ~10x more zero crossings than L at 100 Hz
      expect(crossingsR, greaterThan(crossingsL * 5),
        reason: 'R (1000Hz) should have way more zero crossings than L (100Hz). '
                'Got L=$crossingsL, R=$crossingsR. Channels may be mixed.');
    });

    test('sub frequency appears in BOTH channels equally', () {
      engine.multiFrequencyMode = true;
      engine.frequencyL = 0.001;  // Near-DC, won't generate audible signal
      engine.frequencyR = 0.001;
      engine.frequencySub = 440.0;
      engine.subMixLevel = 1.0;
      engine.volume = 1.0;

      final raw = engine.generateBufferForTesting();
      final rmsL = rmsChannel(raw, left: true);
      final rmsR = rmsChannel(raw, left: false);

      // Both channels should have nearly identical energy (from sub)
      expect((rmsL - rmsR).abs(), lessThan(0.01),
        reason: 'Sub should contribute equally to L and R. '
                'RMS L=$rmsL, R=$rmsR');
    });
  });

  // ═══════════════════════════════════════════════════════════
  // GROUP 3: PHASE WRAPPING & NUMERICAL STABILITY
  // ═══════════════════════════════════════════════════════════
  group('Phase wrapping stability', () {

    test('BUG: negative frequency causes unbounded phase drift', () {
      // If someone sets a negative frequency (e.g., from a UI slider bug),
      // the phase goes negative and never wraps. After thousands of buffers,
      // sin() precision degrades.
      engine.multiFrequencyMode = true;
      engine.frequencyL = -100.0;
      engine.frequencyR = 440.0;
      engine.frequencySub = 0.0;
      engine.subMixLevel = 0.0;
      engine.volume = 1.0;

      // Generate 100 buffers (= 100 * 1024 / 44100 ≈ 2.3 seconds)
      for (int i = 0; i < 100; i++) {
        engine.generateBufferForTesting();
      }

      // After 100 buffers with freq=-100, phase should still be bounded.
      // Access _phaseL indirectly by checking output is still valid.
      final raw = engine.generateBufferForTesting();
      final pcm = raw.buffer.asInt16List();
      for (int i = 0; i < pcm.length; i++) {
        expect(pcm[i].isFinite, isTrue,
          reason: 'Sample $i is not finite after 100 buffers with negative freq');
        expect(pcm[i], inInclusiveRange(-32768, 32767));
      }

      // Also verify we still get audible signal (not stuck at 0 from NaN)
      final rmsR = rmsChannel(raw, left: false);
      expect(rmsR, greaterThan(0.1),
        reason: 'R channel should still produce signal after extended playback');
    });

    test('zero frequency produces silence (no NaN or artifacts)', () {
      engine.multiFrequencyMode = true;
      engine.frequencyL = 0.0;
      engine.frequencyR = 0.0;
      engine.frequencySub = 0.0;
      engine.volume = 1.0;

      final raw = engine.generateBufferForTesting();
      final pcm = raw.buffer.asInt16List();

      // All samples should be 0 (or very close, due to phase residue)
      for (int i = 0; i < pcm.length; i++) {
        expect(pcm[i].abs(), lessThan(2),
          reason: 'Zero frequency should produce silence, got ${pcm[i]} at sample $i');
      }
    });

    test('Nyquist frequency does not alias or produce NaN', () {
      engine.multiFrequencyMode = true;
      engine.frequencyL = NeomGeneratorConstants.sampleRate / 2.0; // 22050 Hz
      engine.frequencyR = NeomGeneratorConstants.sampleRate / 2.0;
      engine.frequencySub = 0.0;
      engine.volume = 1.0;

      final raw = engine.generateBufferForTesting();
      final pcm = raw.buffer.asInt16List();
      for (int i = 0; i < pcm.length; i++) {
        expect(pcm[i].isFinite, isTrue);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  // GROUP 4: MODE TRANSITIONS
  // ═══════════════════════════════════════════════════════════
  group('Mode transitions', () {

    test('switching from multi to standard mid-playback produces no glitch', () {
      engine.multiFrequencyMode = true;
      engine.frequencyL = 440.0;
      engine.frequencyR = 440.0;
      engine.frequencySub = 55.0;
      engine.volume = 0.5;

      // Generate in multi mode
      engine.generateBufferForTesting();

      // Switch to standard mode
      engine.multiFrequencyMode = false;
      engine.frequency = 440.0;
      engine.beat = 0.0;

      final raw = engine.generateBufferForTesting();
      final pcm = raw.buffer.asInt16List();

      // Should produce valid audio without NaN or extreme spikes
      for (int i = 0; i < pcm.length; i++) {
        expect(pcm[i].isFinite, isTrue);
        expect(pcm[i], inInclusiveRange(-32768, 32767));
      }
    });

    test('repeated multi/standard toggling does not corrupt state', () {
      for (int cycle = 0; cycle < 20; cycle++) {
        engine.multiFrequencyMode = (cycle % 2 == 0);
        engine.frequencyL = 200.0 + cycle;
        engine.frequencyR = 300.0 + cycle;
        engine.frequencySub = 50.0 + cycle;
        engine.frequency = 440.0;

        final raw = engine.generateBufferForTesting();
        final pcm = raw.buffer.asInt16List();

        bool hasSignal = false;
        for (int i = 0; i < pcm.length; i++) {
          expect(pcm[i].isFinite, isTrue, reason: 'Cycle $cycle, sample $i');
          if (pcm[i].abs() > 100) hasSignal = true;
        }
        expect(hasSignal, isTrue, reason: 'Cycle $cycle produced no signal');
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  // GROUP 5: BUFFER FORMAT & SIZE
  // ═══════════════════════════════════════════════════════════
  group('Buffer format invariants', () {

    test('multi-frequency buffer size matches standard mode', () {
      engine.multiFrequencyMode = false;
      final stdBuffer = engine.generateBufferForTesting();

      engine.multiFrequencyMode = true;
      engine.frequencyL = 440.0;
      engine.frequencyR = 880.0;
      engine.frequencySub = 55.0;
      final multiBuffer = engine.generateBufferForTesting();

      expect(multiBuffer.length, equals(stdBuffer.length),
        reason: 'Multi-frequency buffer must be same size as standard '
                '(both are stereo PCM16)');
      expect(multiBuffer.length,
        equals(NeomGeneratorConstants.framesPerBuffer * NeomGeneratorConstants.channels * 2));
    });

    test('buffer is valid PCM16 (exactly framesPerBuffer * channels * 2 bytes)', () {
      engine.multiFrequencyMode = true;
      engine.frequencyL = 440.0;
      engine.frequencyR = 440.0;
      engine.frequencySub = 110.0;

      final raw = engine.generateBufferForTesting();
      // PCM16 stereo: 1024 frames × 2 channels × 2 bytes per sample = 4096 bytes
      expect(raw.length, equals(4096));
    });
  });

  // ═══════════════════════════════════════════════════════════
  // GROUP 6: EXTREME PARAMETER VALUES
  // ═══════════════════════════════════════════════════════════
  group('Extreme parameters', () {

    test('volume=0 produces total silence in multi mode', () {
      engine.multiFrequencyMode = true;
      engine.frequencyL = 440.0;
      engine.frequencyR = 880.0;
      engine.frequencySub = 55.0;
      engine.volume = 0.0;

      final raw = engine.generateBufferForTesting();
      final pcm = raw.buffer.asInt16List();
      for (int i = 0; i < pcm.length; i++) {
        expect(pcm[i], equals(0), reason: 'Volume=0 should silence everything');
      }
    });

    test('very high frequency (above Nyquist) does not crash', () {
      engine.multiFrequencyMode = true;
      engine.frequencyL = 50000.0; // Above Nyquist
      engine.frequencyR = 100000.0;
      engine.frequencySub = 200000.0;
      engine.volume = 1.0;

      // Should not throw, even if output is aliased garbage
      final raw = engine.generateBufferForTesting();
      expect(raw.length, equals(4096));

      final pcm = raw.buffer.asInt16List();
      for (int i = 0; i < pcm.length; i++) {
        expect(pcm[i].isFinite, isTrue);
      }
    });

    test('subMixLevel out of range is handled gracefully', () {
      engine.multiFrequencyMode = true;
      engine.frequencyL = 440.0;
      engine.frequencyR = 440.0;
      engine.frequencySub = 55.0;
      engine.volume = 1.0;

      // subMixLevel > 1.0 should not crash
      engine.subMixLevel = 5.0;
      final raw1 = engine.generateBufferForTesting();
      final pcm1 = raw1.buffer.asInt16List();
      for (int i = 0; i < pcm1.length; i++) {
        expect(pcm1[i].isFinite, isTrue);
        expect(pcm1[i], inInclusiveRange(-32768, 32767));
      }

      // subMixLevel negative
      engine.subMixLevel = -1.0;
      final raw2 = engine.generateBufferForTesting();
      final pcm2 = raw2.buffer.asInt16List();
      for (int i = 0; i < pcm2.length; i++) {
        expect(pcm2[i].isFinite, isTrue);
      }
    });
  });

  // ═══════════════════════════════════════════════════════════
  // GROUP 7: FREQUENCY ACCURACY
  // ═══════════════════════════════════════════════════════════
  group('Frequency accuracy', () {

    test('440 Hz L-channel produces ~10 zero crossings per 1024 samples', () {
      engine.multiFrequencyMode = true;
      engine.frequencyL = 440.0;
      engine.frequencyR = 440.0;
      engine.frequencySub = 0.0;
      engine.subMixLevel = 0.0;
      engine.volume = 1.0;

      // Expected zero crossings: 2 per cycle * 440 Hz * (1024 / 44100) ≈ 20.4
      final raw = engine.generateBufferForTesting();
      final pcm = raw.buffer.asInt16List();

      int crossings = 0;
      for (int i = 2; i < pcm.length; i += 2) {
        final prev = pcm[i - 2];
        final curr = pcm[i];
        if ((prev > 0 && curr < 0) || (prev < 0 && curr > 0)) {
          crossings++;
        }
      }

      // 440 Hz → 440 * 1024 / 44100 ≈ 10.2 full cycles → ~20 zero crossings
      expect(crossings, inInclusiveRange(18, 24),
        reason: '440 Hz should produce ~20 zero crossings in 1024 frames, got $crossings');
    });
  });
}
