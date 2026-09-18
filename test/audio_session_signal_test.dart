import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:neom_core/domain/use_cases/neom_audio_visual_signal.dart';
import 'package:neom_generator/engine/neom_breath_engine.dart';
import 'package:neom_generator/engine/neom_frequency_painter_engine.dart';
import 'package:neom_generator/engine/neom_modulator_engine.dart';
import 'package:neom_generator/engine/neom_sine_engine.dart';

import 'sine_engine_lifecycle_test.dart' show FakePcmBackend, settle;

class _Output extends FakePcmBackend {
  int cursor = 0;
  final pcm = <Uint8List>[];
  @override
  int get playedFrames => cursor;
  @override
  Future<void> write(Uint8List buffer) async {
    pcm.add(Uint8List.fromList(buffer));
    await super.write(buffer);
  }
}

void main() {
  late _Output output;
  late NeomSineEngine engine;
  late NeomFrequencyPainterEngine painter;

  setUp(() {
    output = _Output();
    engine = NeomSineEngine.withBackend(output);
    painter = NeomFrequencyPainterEngine()
      ..frameDrivenVisuals = true
      ..visualUpdatesEnabled = false;
    engine.painterEngine = painter;
  });
  tearDown(() async {
    engine.painterEngine = null;
    painter.dispose();
    await engine.dispose();
  });

  Future<void> render() async {
    output.allowOneWrite();
    await settle();
  }

  test('bridge is optional and silent before audio starts', () {
    expect(painter, isA<NeomAudioVisualSignal>());
    expect(painter, isA<NeomAudioSessionSignal>());
    expect(painter.audioSession.isPlaying, isFalse);
    expect(painter.audioSession.level, 0);
  });

  test(
    'uses actual L/R Hz and PCM RMS even with all UI tickers hidden',
    () async {
      engine
        ..frequency = 220
        ..beat = 7
        ..volume = 0.4;
      var notifications = 0;
      painter.addListener(() => notifications++);
      await engine.start();
      await render();
      final signal = painter.audioSession;
      expect(signal.isPlaying, isTrue);
      expect(signal.leftHz, closeTo(220, 1e-8));
      expect(signal.rightHz, closeTo(227, 1e-8));
      expect(signal.beatHz, closeTo(7, 1e-8));
      expect(signal.subHz, 0);
      final samples = output.pcm.single.buffer.asInt16List();
      final squares = samples.fold<double>(
        0,
        (sum, value) => sum + pow(value / 32768, 2),
      );
      expect(signal.level, closeTo(sqrt(squares / samples.length), 1e-12));
      expect(
        notifications,
        1,
        reason: 'only Start, never a per-sample repaint',
      );
    },
  );

  test(
    'switches frequency sets at output playhead, not queued generation',
    () async {
      engine
        ..frequency = 220
        ..beat = 7;
      await engine.start();
      await render();
      engine
        ..multiFrequencyMode = true
        ..frequencyL = 310
        ..frequencyR = 317
        ..frequencySub = 62
        ..subMixLevel = 0.5;
      await render();
      expect(engine.generatedFrames, 2048);
      expect(painter.audioSession.leftHz, closeTo(220, 1e-8));
      output.cursor = 1024;
      final signal = painter.audioSession;
      expect(signal.multiFrequency, isTrue);
      expect(signal.leftHz, closeTo(310, 1e-8));
      expect(signal.rightHz, closeTo(317, 1e-8));
      expect(signal.subHz, closeTo(62, 1e-8));
      expect(signal.subGain, closeTo(1 / 3, 1e-12));
      expect(signal.playedFrames, 1024);
      expect(signal.elapsedSeconds, closeTo(1024 / 44100, 1e-12));
      engine.subMixLevel = 0;
      await render();
      output.cursor = 2048;
      expect(painter.audioSession.subHz, 0);
      expect(painter.audioSession.subGain, 0);
    },
  );

  test(
    'reports spatial pitch and modulation, not slider-only carrier',
    () async {
      engine
        ..frequency = 200
        ..beat = 10
        ..posZ = 1;
      await engine.start();
      await render();
      expect(painter.audioSession.leftHz, closeTo(204, 1e-8));
      expect(painter.audioSession.rightHz, closeTo(205.8, 1e-8));
      engine.modulator
        ..enabled = true
        ..type = NeomModulationType.fm
        ..depth = 0.5
        ..modFrequency = 0
        ..restorePhase(pi / 2);
      await render();
      output.cursor = 1024;
      expect(painter.audioSession.leftHz, closeTo(306, 1e-8));
      expect(painter.audioSession.rightHz, closeTo(308.7, 1e-8));
    },
  );

  test(
    'real breathing envelope, silence, stop, restart do not retain activity',
    () async {
      engine.volume = 0;
      engine.breathEngine
        ..mode = NeomBreathMode.box
        ..breathsPerMinute = 6;
      await engine.start();
      await render();
      expect(painter.audioSession.level, 0);
      expect(painter.audioSession.breathingEnabled, isTrue);
      expect(painter.audioSession.breathRateHz, 0.1);
      expect(
        painter.audioSession.breathValue,
        closeTo(engine.breathEngine.currentValue, 1e-12),
      );
      output.cursor = 500;
      await engine.stop();
      final stopped = painter.audioSession;
      expect(stopped.isPlaying, isFalse);
      expect(stopped.level, 0);
      expect(stopped.playedFrames, 500);
      output.cursor =
          0; // a backend resetting after stop cannot rewind telemetry
      expect(painter.audioSession.playedFrames, 500);
      await engine.start();
      expect(painter.audioSession.playedFrames, 0);
      expect(painter.audioSession.level, 0);
      expect(painter.audioSession.leftHz, 0);
    },
  );

  test('phase follows output clock and detach releases old producer', () async {
    engine
      ..frequency = 200
      ..beat = 5;
    await engine.start();
    await render();
    output.cursor = 441;
    expect(painter.audioSession.beatPhase, closeTo(2 * pi * 5 * 0.01, 1e-9));
    final replacement = NeomFrequencyPainterEngine();
    engine.painterEngine = replacement;
    expect(painter.audioSession.isPlaying, isFalse);
    expect(replacement.audioSession.isPlaying, isTrue);
    engine.painterEngine = null;
    expect(replacement.audioSession.isPlaying, isFalse);
    replacement.dispose();
  });

  test('zero beat resets previous artistic pulse', () {
    painter.tickBinaural(8, 0.1);
    expect(painter.binauralPhase, greaterThan(0));
    painter.tickBinaural(0, 0.1);
    expect(painter.binauralPhase, 0);
  });
}
