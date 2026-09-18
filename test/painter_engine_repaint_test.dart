import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/engine/neom_frequency_painter_engine.dart';

/// The engine sits between a 44.1 kHz audio loop and a 60 Hz screen. These pin
/// the two things that has to get right: not waking the UI per audio sample,
/// and still letting a painter tell that the reused buffer moved.
void main() {
  const sampleRate = 44100.0;

  group('notification rate', () {
    void updateVisuals(
      NeomFrequencyPainterEngine engine, {
      bool frame = false,
    }) {
      engine.updateFromAudio(
        phase: 0.5,
        amplitude: 0.5,
        pan: 0,
        breath: 0.5,
        modulation: 0,
        neuro: 0,
        frequency: 432,
        isVisualFrame: frame,
      );
    }

    test('standalone engines preserve automatic visual notifications', () {
      final engine = NeomFrequencyPainterEngine();
      addTearDown(engine.dispose);
      var notifications = 0;
      engine.addListener(() => notifications++);

      updateVisuals(engine);

      expect(notifications, 1);
    });

    test('frame-driven mode ignores audio-buffer visual dispatch', () {
      final engine = NeomFrequencyPainterEngine()..frameDrivenVisuals = true;
      addTearDown(engine.dispose);
      var notifications = 0;
      engine.addListener(() => notifications++);

      for (var i = 0; i < 100; i++) {
        updateVisuals(engine);
      }
      expect(notifications, 0);
      updateVisuals(engine, frame: true);
      expect(notifications, 1);
    });

    test('hidden visuals leave audio samples and binaural state active', () {
      final engine = NeomFrequencyPainterEngine()
        ..frameDrivenVisuals = true
        ..visualUpdatesEnabled = false;
      addTearDown(engine.dispose);
      var notifications = 0;
      engine.addListener(() => notifications++);

      updateVisuals(engine);
      updateVisuals(engine, frame: true);
      engine.notifyVisualUpdate();
      engine.pushSample(0.5);
      engine.updatePhases(phaseL: 0.25, phaseR: 0.75);
      engine.tickBinaural(4, 0.1);

      expect(notifications, 0);
      expect(engine.sampleRevision, 1);
      expect(engine.phaseL, 0.25);
      expect(engine.phaseR, 0.75);
      expect(engine.binauralPhase, greaterThan(0));
      engine.visualUpdatesEnabled = true;
      updateVisuals(engine, frame: true);
      expect(notifications, 1);
    });

    test('writing samples never notifies', () {
      // pushSample runs once per audio sample; a listener here would be woken
      // 44 100 times a second for a screen that draws 60.
      final engine = NeomFrequencyPainterEngine();
      var notifications = 0;
      engine.addListener(() => notifications++);

      for (var i = 0; i < 1024; i++) {
        engine.pushSample(i / 1024);
      }

      expect(notifications, 0);
    });

    test('the binaural tick never notifies', () {
      final engine = NeomFrequencyPainterEngine();
      var notifications = 0;
      engine.addListener(() => notifications++);

      // One audio buffer's worth.
      for (var i = 0; i < 1024; i++) {
        engine.tickBinaural(10, 1 / sampleRate);
      }

      expect(notifications, 0);
    });

    test('a full second of audio wakes the UI zero times', () {
      final engine = NeomFrequencyPainterEngine();
      var notifications = 0;
      engine.addListener(() => notifications++);

      for (var i = 0; i < sampleRate.toInt(); i++) {
        engine.pushSample(0.5);
        engine.updatePhases(phaseL: 0.1, phaseR: 0.2);
        engine.tickBinaural(10, 1 / sampleRate);
      }

      expect(
        notifications,
        0,
        reason: 'the frame Ticker drives repaints, not the audio loop',
      );
    });

    test('the tick still advances its state', () {
      // Silent, not inert.
      final engine = NeomFrequencyPainterEngine();
      final before = engine.binauralPhase;

      for (var i = 0; i < 4410; i++) {
        engine.tickBinaural(10, 1 / sampleRate);
      }

      expect(engine.binauralPhase, isNot(before));
    });
  });

  group('sample revision', () {
    test('the buffer identity never changes', () {
      // Which is why shouldRepaint could not compare it.
      final engine = NeomFrequencyPainterEngine();
      final first = engine.samples;
      engine.pushSample(0.9);

      expect(identical(engine.samples, first), isTrue);
    });

    test('the revision does change, once per sample', () {
      final engine = NeomFrequencyPainterEngine();
      final before = engine.sampleRevision;

      for (var i = 0; i < 10; i++) {
        engine.pushSample(0.1);
      }

      expect(engine.sampleRevision, before + 10);
    });

    test('it keeps moving past a full buffer wrap', () {
      // The write index wraps; the revision must not.
      final engine = NeomFrequencyPainterEngine();
      final before = engine.sampleRevision;

      for (var i = 0; i < NeomFrequencyPainterEngine.bufferSize * 2; i++) {
        engine.pushSample(0.1);
      }

      expect(
        engine.sampleRevision,
        before + NeomFrequencyPainterEngine.bufferSize * 2,
      );
    });
  });
}
