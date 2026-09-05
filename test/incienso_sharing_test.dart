import 'package:flutter_test/flutter_test.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:neom_generator/data/implementations/incienso_recorder.dart';
import 'package:neom_generator/domain/models/incienso.dart';

/// A recorded session is meant to be practised by other people, which makes two
/// things load-bearing: it must not be shared unless its creator said so, and
/// sharing must not alter what was recorded.
void main() {
  group('visibility', () {
    test('a session is private by default', () {
      const incienso = Incienso(
        id: 'x', names: {'es': 'Sesión'},
        leftFrequencyHz: 200, rightFrequencyHz: 210,
        suggestedDuration: Duration(minutes: 10),
      );

      expect(incienso.isPublic, isFalse);
    });

    test('an unmarked document deserializes as private', () {
      // Documents written before the field existed must not become public.
      final restored = Incienso.fromJson({
        'id': 'x',
        'names': {'es': 'Sesión'},
        'leftFrequencyHz': 200.0,
        'rightFrequencyHz': 210.0,
        'suggestedDuration': 600,
      });

      expect(restored.isPublic, isFalse);
    });

    test('the choice survives a round trip', () {
      const incienso = Incienso(
        id: 'x', names: {'es': 'Sesión'},
        leftFrequencyHz: 200, rightFrequencyHz: 210,
        suggestedDuration: Duration(minutes: 10),
        isPublic: true,
      );

      expect(Incienso.fromJson(incienso.toJson()).isPublic, isTrue);
    });
  });

  group('copyWithVisibility', () {
    const original = Incienso(
      id: 'rec_1',
      names: {'es': 'Nocturna'},
      descriptions: {'es': 'Una práctica larga'},
      leftFrequencyHz: 196.5,
      rightFrequencyHz: 204.5,
      suggestedDuration: Duration(minutes: 22),
      pulseFrequencyHz: 0.25,
      screenColorValue: 0xFF102030,
      stateId: 'state_x',
      protocolId: 'proto_y',
      creatorId: 'user_1',
      isPro: true,
      iconCodePoint: 0xE800,
      tags: ['noche', 'respiración'],
      practiceCount: 7,
      avgQualityRatio: 0.82,
    );

    test('flips visibility', () {
      expect(original.copyWithVisibility(isPublic: true).isPublic, isTrue);
      expect(original.copyWithVisibility(isPublic: false).isPublic, isFalse);
    });

    test('keeps everything that defines the experience', () {
      // The first version of this dropped 11 fields — including phases,
      // pulseFrequencyHz and the visual — which would have silently changed
      // what a listener practises.
      final shared = original.copyWithVisibility(isPublic: true);

      expect(shared.id, original.id);
      expect(shared.names, original.names);
      expect(shared.descriptions, original.descriptions);
      expect(shared.leftFrequencyHz, original.leftFrequencyHz);
      expect(shared.rightFrequencyHz, original.rightFrequencyHz);
      expect(shared.suggestedDuration, original.suggestedDuration);
      expect(shared.pulseFrequencyHz, original.pulseFrequencyHz);
      expect(shared.screenColorValue, original.screenColorValue);
      expect(shared.stateId, original.stateId);
      expect(shared.protocolId, original.protocolId);
      expect(shared.creatorId, original.creatorId);
      expect(shared.isPro, original.isPro);
      expect(shared.iconCodePoint, original.iconCodePoint);
      expect(shared.tags, original.tags);
      expect(shared.practiceCount, original.practiceCount);
      expect(shared.avgQualityRatio, original.avgQualityRatio);
      expect(shared.defaultVisual, original.defaultVisual);
      expect(shared.source, original.source);
    });

    test('serializes to the same document apart from the flag', () {
      final before = Map<String, dynamic>.from(original.toJson())..remove('isPublic');
      final after = Map<String, dynamic>.from(
          original.copyWithVisibility(isPublic: true).toJson())..remove('isPublic');

      expect(after, before);
    });
  });

  group('recorder guard', () {
    test('nothing recorded cannot be saved', () {
      final recorder = InciensoRecorder();
      expect(recorder.hasEnoughToBuild, isFalse);
    });

    test('too few keyframes cannot be saved', () {
      final recorder = InciensoRecorder()..startRecording();
      for (var i = 0; i < InciensoRecorder.minKeyframes - 1; i++) {
        recorder.captureUserAction(
          leftHz: 200, rightHz: 210, coherence: 0.5, volume: 0.7,
          neuroState: NeomNeuroState.calm, breathPhase: 0.5,
        );
      }

      expect(recorder.hasEnoughToBuild, isFalse);
      expect(recorder.stopAndBuild(name: 'corta'), isNull);
    });

    test('the guard and the builder agree', () {
      // hasEnoughToBuild exists so the UI can offer saving without stopping;
      // if they disagreed, the offer would lead to a null.
      final recorder = InciensoRecorder()..startRecording();
      for (var i = 0; i < InciensoRecorder.minKeyframes + 2; i++) {
        recorder.captureUserAction(
          leftHz: 200, rightHz: 210, coherence: 0.5, volume: 0.7,
          neuroState: NeomNeuroState.calm, breathPhase: 0.5,
        );
      }

      // Still under the minimum duration, so both must refuse.
      expect(recorder.hasEnoughToBuild, isFalse);
      expect(recorder.stopAndBuild(name: 'corta'), isNull);
    });
  });

  group('recorder reset between sessions', () {
    InciensoRecorder recorded({int frames = 6}) {
      final r = InciensoRecorder()..startRecording();
      for (var i = 0; i < frames; i++) {
        r.captureUserAction(
          leftHz: 200, rightHz: 210, coherence: 0.5, volume: 0.7,
          neuroState: NeomNeuroState.calm, breathPhase: 0.5,
        );
      }
      return r;
    }

    test('a new session does not inherit the previous keyframes', () {
      final r = recorded(frames: 6);
      final previous = r.keyframeCount;
      expect(previous, greaterThanOrEqualTo(6));

      r.startRecording();

      // Starting captures one baseline frame, so the count resets to that —
      // what matters is that the previous session is gone.
      expect(r.keyframeCount, lessThan(previous));
      expect(r.keyframeCount, 1);
    });

    test('cancel clears what was recorded', () {
      // Auto-save calls this after storing, so a second stop cannot save the
      // same session twice.
      final r = recorded(frames: 6);
      r.cancel();

      expect(r.keyframeCount, 0);
      expect(r.hasEnoughToBuild, isFalse);
      expect(r.stopAndBuild(name: 'x'), isNull);
    });

    test('building does not clear on its own', () {
      // Pins why the auto-save has to cancel explicitly.
      final r = recorded(frames: 6);
      r.stopAndBuild(name: 'x');

      expect(r.keyframeCount, greaterThanOrEqualTo(6));
    });
  });

  group('evidence level', () {
    test('a new protocol claims nothing by default', () {
      const fresh = Incienso(
        id: 'x', names: {'es': 'Nuevo'},
        leftFrequencyHz: 200, rightFrequencyHz: 210,
        suggestedDuration: Duration(minutes: 10),
      );

      expect(fresh.evidence, InciensoEvidence.experiential);
    });

    test('an unmarked document reads as experiential', () {
      // Documents written before the field existed must not claim support.
      final restored = Incienso.fromJson({
        'id': 'x', 'names': {'es': 'X'},
        'leftFrequencyHz': 200.0, 'rightFrequencyHz': 210.0,
        'suggestedDuration': 600,
      });

      expect(restored.evidence, InciensoEvidence.experiential);
    });

    test('an unknown value degrades to experiential, not a crash', () {
      final restored = Incienso.fromJson({
        'id': 'x', 'names': {'es': 'X'},
        'leftFrequencyHz': 200.0, 'rightFrequencyHz': 210.0,
        'suggestedDuration': 600, 'evidence': 'proven-by-vibes',
      });

      expect(restored.evidence, InciensoEvidence.experiential);
    });

    test('the level survives a round trip', () {
      const claimed = Incienso(
        id: 'x', names: {'es': 'X'},
        leftFrequencyHz: 200, rightFrequencyHz: 210,
        suggestedDuration: Duration(minutes: 10),
        evidence: InciensoEvidence.clinical,
      );

      expect(Incienso.fromJson(claimed.toJson()).evidence,
          InciensoEvidence.clinical);
    });

    test('sharing does not change what a protocol claims', () {
      const claimed = Incienso(
        id: 'x', names: {'es': 'X'},
        leftFrequencyHz: 200, rightFrequencyHz: 210,
        suggestedDuration: Duration(minutes: 10),
        evidence: InciensoEvidence.preliminary,
      );

      expect(claimed.copyWithVisibility(isPublic: true).evidence,
          InciensoEvidence.preliminary);
    });

    test('every level has a translation key', () {
      for (final level in InciensoEvidence.values) {
        expect(level.nameKey, isNotEmpty);
        expect(level.nameKey, startsWith('evidence'));
      }
    });
  });
}
