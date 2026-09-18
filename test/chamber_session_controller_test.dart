import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_core/domain/model/app_profile.dart';
import 'package:neom_core/domain/model/app_user.dart';
import 'package:neom_core/domain/model/incienso_practice_draft.dart';
import 'package:neom_core/domain/model/neom/neom_chamber_preset.dart';
import 'package:neom_core/domain/model/neom/neom_frequency.dart';
import 'package:neom_core/domain/model/neom/neom_parameter.dart';
import 'package:neom_core/domain/repository/chamber_repository.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_generator/data/firestore/incienso_firestore.dart';
import 'package:neom_generator/data/implementations/chamber_practice_store.dart';
import 'package:neom_generator/data/implementations/incienso_draft_store.dart';
import 'package:neom_generator/data/implementations/incienso_portable_file.dart';
import 'package:neom_generator/data/implementations/incienso_recorder.dart';
import 'package:neom_generator/domain/models/incienso.dart';
import 'package:neom_generator/domain/models/incienso_audio_state.dart';
import 'package:neom_generator/engine/audio/neom_pcm_backend.dart';
import 'package:neom_generator/engine/audio/neom_voice_capture.dart';
import 'package:neom_generator/engine/neom_sine_engine.dart';
import 'package:neom_generator/ui/neom_generator_controller.dart';
import 'package:sint/sint.dart';

/// Controller integration with real synthesis/recording logic, but NO output,
/// microphone, Firebase or Hive. Audio-buffer boundaries are advanced explicitly
/// where noted; these tests are not real-time audio-device measurements.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const permissions = MethodChannel('flutter.baseflow.com/permissions/methods');
  final permissionCalls = <MethodCall>[];
  setUp(() {
    Sint.testMode = true;
    SintTestMode.setTestArguments(null);
    permissionCalls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, (call) async {
          permissionCalls.add(call);
          return <int, int>{};
        });
  });
  tearDown(() {
    SintTestMode.setTestArguments(null);
    Sint.testMode = false;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(permissions, null);
  });

  testWidgets(
    'free session removes replay without changing knobs or starting audio',
    (tester) async {
      final f = _Fixture();
      try {
        await f.controller.loadIncienso(_recording('saved', left: 333));
        await f.controller.startFreeSession();
        f.controller.setFreeSessionMinutes(10);
        expect(f.controller.activeIncienso, isNull);
        expect(f.controller.currentFreq.value, 333);
        expect(f.controller.sessionRemaining, const Duration(minutes: 10));
        expect(f.backend.starts, 0);
        await f.controller.playStopPreview();
        expect(f.engine.frameLimit, 600 * 44100);
      } finally {
        await f.close();
      }
    },
  );

  testWidgets('explicit Stop cancels pending preset autoplay', (tester) async {
    final f = _Fixture();
    try {
      final load = f.controller.loadIncienso(
        _recording('pending'),
        autoStart: true,
      );
      await f.controller.playStopPreview(stop: true);
      await load;
      expect(f.backend.starts, 0);
      expect(f.controller.playbackRequested.value, isFalse);
    } finally {
      await f.close();
    }
  });

  testWidgets('free catalog references resolve without Firebase or autoplay', (
    tester,
  ) async {
    final f = _Fixture();
    try {
      f.portable.input = InciensoPortableFile.encode('incienso-deep-sleep');
      await f.controller.importSession();
      expect(f.controller.activeIncienso!.id, 'incienso-deep-sleep');
      expect(
        f.controller.canShareIncienso(f.controller.activeIncienso!),
        isTrue,
      );
      await f.controller.exportSession(f.controller.activeIncienso!);
      expect(f.portable.exported, ['incienso-deep-sleep']);
      expect(f.backend.starts, 0);
      expect(f.firestore.attempts, isEmpty);
    } finally {
      await f.close();
    }
  });

  testWidgets(
    'free timer follows audio clock, freezes on stop and preserves fades',
    (tester) async {
      final f = _Fixture();
      try {
        f.controller.setFreeSessionMinutes(5);
        expect(f.controller.sessionRemaining, const Duration(minutes: 5));
        f.controller.reflectionBeforeFeeling.value = 'calm';
        await f.controller.playStopPreview();
        expect(f.engine.frameLimit, 300 * 44100);
        expect(f.engine.fadeInSeconds, 2);
        expect(f.engine.fadeOutEndFrame, 300 * 44100);
        f.controller.setFreeSessionMinutes(10);
        expect(f.controller.freeSessionMinutes.value, 5);
        f.emitSeconds([0, 8, 16, 24, 30]);
        expect(f.controller.sessionRemaining, const Duration(seconds: 270));
        await f.controller.playStopPreview(stop: true);
        await tester.pump();
        expect(f.controller.sessionRemaining, const Duration(seconds: 270));
        expect(f.controller.canReflectSession.value, isTrue);
        final saved = f.drafts.saved.single;
        expect(
          saved.timeline.first.audioState!.number('fadeOutEndFrame', 0),
          300 * 44100,
        );
        f.controller.setSoftTransitions(false);
        await f.controller.loadIncienso(saved);
        await f.controller.playStopPreview();
        expect(f.engine.frameLimit, 30 * 44100);
        expect(f.engine.fadeOutEndFrame, 300 * 44100);
        expect(f.engine.fadeInSeconds, 2);
      } finally {
        await f.close();
      }
    },
  );

  testWidgets('reset restores session baseline, focus never starts output', (
    tester,
  ) async {
    final f = _Fixture();
    try {
      await f.controller.setFrequency(333);
      await f.controller.playStopPreview();
      await f.controller.setFrequency(555);
      f.controller.setFocusMode(true);
      expect(f.backend.starts, 1);
      await f.controller.resetSessionSettings();
      expect(f.controller.currentFreq.value, 333);
      expect(f.controller.playbackRequested.value, isFalse);
      expect(f.controller.sessionElapsed, Duration.zero);
      expect(f.backend.starts, 1);
    } finally {
      await f.close();
    }
  });

  testWidgets('favorites and recents are device-only and scoped by account', (
    tester,
  ) async {
    final f = _Fixture();
    try {
      final session = _recording('favorite');
      await f.controller.loadIncienso(session);
      await f.controller.toggleFavorite(session.id);
      expect(f.controller.isFavorite(session.id), isTrue);
      expect((await f.controller.quickSessions()).single.id, session.id);
      expect(f.firestore.attempts, isEmpty);
      expect(f.backend.starts, 0);
      f.controller.userServiceImpl = _User('other');
      expect(await f.controller.quickSessions(), isEmpty);
      expect(f.controller.favoriteSessionIds, isEmpty);
      f.controller.userServiceImpl = null;
      expect((await f.controller.quickSessions()).single.id, session.id);
      expect(f.controller.isFavorite(session.id), isTrue);
    } finally {
      await f.close();
    }
  });

  testWidgets(
    'stereo channel check is isolated, cancelable and never recorded',
    (tester) async {
      final f = _Fixture();
      try {
        await f.controller.setFrequency(528);
        await f.controller.playChannelCheck(true);
        expect(f.checkEngine.frequencyL, 440);
        expect(f.checkEngine.frequencyR, 0);
        expect(f.checkEngine.volume, .08);
        expect(f.checkEngine.frameLimit, 44100);
        expect(f.controller.isInciensoRecording, isFalse);
        expect(f.backend.starts, 0);
        await f.controller.playChannelCheck(false);
        expect(f.checkBackend.starts, 2);
        expect(f.checkEngine.frequencyL, 0);
        expect(f.checkEngine.frequencyR, 440);
        await f.controller.stopChannelCheck();
        expect(f.controller.channelCheckRunning.value, isFalse);
        expect(f.controller.currentFreq.value, 528);
        expect(f.drafts.saved, isEmpty);
        expect(f.firestore.attempts, isEmpty);
      } finally {
        await f.close();
      }
    },
  );

  testWidgets('late public reference cannot override a newer local selection', (
    tester,
  ) async {
    final f = _Fixture();
    try {
      f.firestore.retrieveBarrier = Completer<Incienso?>();
      final old = f.controller.loadRouteArguments([
        const InciensoPracticeReference(
          inciensoName: 'A',
          publicInciensoId: 'public-a',
        ),
      ]);
      await tester.pump();
      await f.controller.loadIncienso(_recording('newer'));
      f.firestore.retrieveBarrier!.complete(
        _recording('public-a').copyWithVisibility(isPublic: true),
      );
      await old;
      expect(f.controller.activeIncienso!.id, 'newer');
      expect(f.backend.starts, 0);
    } finally {
      await f.close();
    }
  });

  testWidgets(
    'opening reference resolves public ID only, never writes/autoplays',
    (tester) async {
      final f = _Fixture();
      try {
        f.portable.input = InciensoPortableFile.encode('public');
        f.firestore.library.add(
          _recording('public').copyWithVisibility(isPublic: true),
        );
        await f.controller.importSession();
        expect(f.controller.activeIncienso!.id, 'public');
        expect(f.backend.starts, 0);
        await f.controller.exportSession(f.controller.activeIncienso!);
        expect(f.portable.exported, ['public']);
        expect(f.firestore.attempts, isEmpty);
        f.portable.input = InciensoPortableFile.encode('private');
        f.firestore.library.add(_recording('private'));
        await f.controller.importSession();
        expect(f.controller.activeIncienso!.id, 'public');
        expect(f.controller.playbackError.value, isNotEmpty);
      } finally {
        await f.close();
      }
    },
  );

  testWidgets(
    'initialization and stale detection completion do not start audio',
    (tester) async {
      final f = _Fixture();
      try {
        await tester.pump();
        expect(f.backend.activations, 0);
        expect(f.backend.starts, 0);
        expect(f.controller.isRecording.value, isFalse);
        expect(f.controller.isPlaying.value, isFalse);
        expect(permissionCalls, isEmpty);
        // A stale completion without an explicit capture is not permission to
        // modify the root or start output.
        final originalFrequency = f.controller.currentFreq.value;
        f.controller.detectedPitches.addAll([220, 220, 220]);
        await f.controller.stopRecording();
        expect(f.controller.currentFreq.value, originalFrequency);
        expect(f.backend.activations, 0);
        expect(f.controller.playbackRequested.value, isFalse);
        expect(permissionCalls, isEmpty);
      } finally {
        await f.close();
      }
    },
  );

  testWidgets('Stop wins while Play is awaiting output startup', (
    tester,
  ) async {
    final f = _Fixture();
    f.backend.startBarrier = Completer<void>();
    try {
      final play = f.controller.playStopPreview();
      await tester.pump();
      expect(f.backend.starts, 1);
      expect(f.controller.playbackRequested.value, isTrue);
      final stop = f.controller.playStopPreview(stop: true);
      expect(f.controller.playbackRequested.value, isFalse);
      expect(f.controller.isInciensoRecording, isFalse);
      f.backend.startBarrier!.complete();
      await Future.wait([play, stop]);
      expect(f.controller.isPlaying.value, isFalse);
      expect(f.engine.isPlaying, isFalse);
      expect(f.controller.isPlaybackTransitioning.value, isFalse);
      expect(f.backend.writes, 0);
    } finally {
      await f.close();
    }
  });

  testWidgets(
    'rapid Play Stop Play honors last request and records one fresh session',
    (tester) async {
      final f = _Fixture();
      f.backend.startBarrier = Completer<void>();
      try {
        final first = f.controller.playStopPreview();
        await tester.pump();
        final stop = f.controller.playStopPreview(stop: true);
        final last = f.controller.playStopPreview();
        f.backend.startBarrier!.complete();
        await Future.wait([first, stop, last]);
        expect(f.controller.playbackRequested.value, isTrue);
        expect(f.controller.isPlaying.value, isTrue);
        expect(f.controller.isPlaybackTransitioning.value, isFalse);
        expect(f.controller.isInciensoRecording, isTrue);
        expect(f.controller.inciensoRecorder.keyframeCount, 1);
        expect(f.backend.writes, 0);
      } finally {
        await f.close();
      }
    },
  );

  testWidgets(
    'Stop freezes the audible endpoint before delayed save or new controls',
    (tester) async {
      final f = _Fixture();
      try {
        await f.controller.setFrequency(432);
        f.controller.setBinauralBeat(beat: 10);
        await f.controller.playStopPreview();
        f.emitSeconds([0, 8, 16, 24, 30]);
        await f.controller.setFrequency(555);
        f.controller.setVolume(0.23);
        f.emitFrame(31 * 44100);
        // Generated audio can be slightly ahead of the audible output clock.
        f.backend.audibleFrame = 30 * 44100 + 22050;
        expect(
          f.controller.sessionElapsed,
          const Duration(milliseconds: 30500),
        );
        await f.controller.playStopPreview(stop: true);
        await tester.pump();
        expect(f.drafts.saved.length, 1);
        final frozen = f.drafts.saved.single;
        expect(frozen.recordingVersion, 2);
        expect(frozen.timeline.first.leftHz, 432);
        expect(frozen.timeline.first.rightHz, 442);
        expect(frozen.effectiveDuration, const Duration(milliseconds: 30500));
        expect(frozen.timeline.last.sampleFrame, 30 * 44100 + 22050);
        expect(
          frozen.timeline.last.leftHz,
          432,
          reason:
              'A generated-but-not-yet-heard parameter change must be trimmed.',
        );
        await f.controller.setFrequency(999);
        f.engine.beforeBuffer?.call(32 * 44100);
        f.engine.afterBuffer?.call(32 * 44100);
        expect(frozen.timeline.first.leftHz, 432);
        expect(frozen.timeline.last.leftHz, 432);
        expect(f.controller.pendingRecordingCount, 1);
        expect(
          f.firestore.attempts,
          isEmpty,
          reason: 'Guest recordings stay local without fabricated ownership.',
        );
      } finally {
        await f.close();
      }
    },
  );

  testWidgets(
    'loaded timeline updates the real engine and restarts from its initial state',
    (tester) async {
      final f = _Fixture();
      try {
        final recording = _recording('first', left: 300, changedLeft: 480);
        await f.controller.loadIncienso(recording, autoStart: false);
        expect(f.controller.activeIncienso, same(recording));
        expect(f.engine.frequency, 300);
        expect(f.backend.activations, 0);
        await f.controller.playStopPreview();
        f.emitFrame(44100);
        expect(f.controller.currentFreq.value, 480);
        expect(f.engine.frequency, 480);
        expect(f.engine.volume, 0.2);
        await f.controller.playStopPreview(stop: true);
        expect(
          f.drafts.saved,
          isEmpty,
          reason: 'Replay must not save a duplicate recording.',
        );
        await f.controller.playStopPreview();
        expect(f.controller.currentFreq.value, 300);
        expect(f.engine.frequency, 300);
        expect(f.engine.volume, 0.6);
        f.emitFrame(44100);
        expect(f.engine.frequency, 480);
      } finally {
        await f.close();
      }
    },
  );

  testWidgets(
    'background visual suspension does not stop audio-clock recording',
    (tester) async {
      final f = _Fixture();
      try {
        await f.controller.playStopPreview();
        f.controller.didChangeAppLifecycleState(AppLifecycleState.paused);
        expect(f.controller.painterEngine.visualUpdatesEnabled, isFalse);
        expect(f.engine.isPlaying, isTrue);
        // No Flutter frames or wall-clock duration are advanced here. The
        // controller must still capture transitions on synthesis callbacks.
        f.emitSeconds([0, 8, 16, 24]);
        await f.controller.setFrequency(517);
        f.emitSeconds([30, 31]);
        expect(
          f.controller.inciensoRecorder.recordingDuration,
          const Duration(seconds: 31),
        );
        await f.controller.playStopPreview(stop: true);
        await tester.pump();
        final recorded = f.drafts.saved.single;
        expect(recorded.effectiveDuration, const Duration(seconds: 31));
        expect(recorded.timeline.last.leftHz, 517);
        expect(
          recorded.timeline
              .where((frame) => frame.audioState != null)
              .last
              .audioState!
              .number('carrierHz', 0),
          517,
        );
        f.controller.didChangeAppLifecycleState(AppLifecycleState.resumed);
        expect(f.controller.painterEngine.visualUpdatesEnabled, isTrue);
        expect(f.controller.isPlaying.value, isFalse);
      } finally {
        await f.close();
      }
    },
  );

  testWidgets(
    'new selection replaces a loaded session on the same controller',
    (tester) async {
      final f = _Fixture();
      try {
        await f.controller.loadRouteArguments([_recording('old', left: 250)]);
        await f.controller.playStopPreview();
        final next = _recording('new', left: 610, changedLeft: 720);
        await f.controller.loadRouteArguments(next);
        expect(f.controller.activeIncienso?.id, 'new');
        expect(f.controller.isPlaying.value, isFalse);
        expect(f.engine.frequency, 610);
        await f.controller.playStopPreview();
        f.emitFrame(44100);
        expect(f.engine.frequency, 720);
      } finally {
        await f.close();
      }
    },
  );

  testWidgets(
    'failed server save retains immutable draft; acknowledged retry removes it',
    (tester) async {
      final f = _Fixture();
      f.controller.userServiceImpl = _User('owner');
      f.controller.profile = f.controller.userServiceImpl!.profile;
      f.firestore.fail = true;
      try {
        await f.controller.playStopPreview();
        f.emitSeconds([0, 8, 16, 24, 31]);
        await f.controller.playStopPreview(stop: true);
        await tester.pump();
        expect(f.controller.pendingRecordingCount, 1);
        expect(f.drafts.byId.length, 1);
        expect(f.controller.recordingSaveError.value, isNotEmpty);
        final id = f.drafts.byId.keys.single;
        expect(f.firestore.attempts, isNotEmpty);
        expect(
          f.firestore.attempts.map((attempt) => attempt.id),
          everyElement(id),
        );
        expect(f.drafts.removed, isEmpty);
        f.firestore.fail = false;
        await f.controller.retryPendingRecordings();
        expect(f.firestore.attempts.last.id, id);
        expect(f.controller.pendingRecordingCount, 0);
        expect(f.drafts.byId, isEmpty);
        expect(f.drafts.removed, [id]);
        expect(f.controller.recordingSaveError.value, isEmpty);
      } finally {
        await f.close();
      }
    },
  );

  testWidgets(
    'completion of a previous save cannot cancel a newly started recording',
    (tester) async {
      final f = _Fixture();
      f.controller.userServiceImpl = _User('owner');
      f.firestore.insertBarrier = Completer<String>();
      try {
        await f.controller.playStopPreview();
        f.emitSeconds([0, 8, 16, 24, 31]);
        await f.controller.playStopPreview(stop: true);
        await tester.pump();
        expect(f.firestore.attempts.length, 1);
        final savedId = f.firestore.attempts.single.id;
        await f.controller.playStopPreview();
        expect(f.controller.isInciensoRecording, isTrue);
        f.firestore.insertBarrier!.complete(savedId);
        await tester.pump();
        expect(f.controller.pendingRecordingCount, 0);
        expect(f.controller.isInciensoRecording, isTrue);
        expect(f.controller.inciensoRecorder.keyframeCount, 1);
        f.emitFrame(44100);
        expect(
          f.controller.inciensoRecorder.recordingDuration,
          const Duration(seconds: 1),
        );
      } finally {
        await f.close();
      }
    },
  );

  testWidgets(
    'onReady restores drafts without uploading a different owner session',
    (tester) async {
      final f = _Fixture();
      f.controller.userServiceImpl = _User('current-owner');
      final draft = _recording('recovery', creatorId: 'old-owner');
      f.drafts.byId[draft.id] = draft;
      try {
        f.controller.onReady();
        await tester.pump();
        expect(f.controller.pendingRecordingCount, 1);
        expect(f.firestore.attempts, isEmpty);
        expect(f.drafts.byId[draft.id], same(draft));
        expect(f.backend.activations, 0);
      } finally {
        await f.close();
      }
    },
  );

  testWidgets('an acknowledged save removes its draft without manual retry', (
    tester,
  ) async {
    final f = _Fixture();
    f.controller.userServiceImpl = _User('owner');
    try {
      await f.controller.playStopPreview();
      f.emitSeconds([0, 8, 16, 24, 31]);
      await f.controller.playStopPreview(stop: true);
      await tester.pump();
      expect(f.firestore.attempts, hasLength(1));
      final saved = f.firestore.attempts.single;
      expect(saved.creatorId, 'owner');
      expect(f.drafts.removed, [saved.id]);
      expect(f.controller.pendingRecordingCount, 0);
      expect(f.drafts.byId, isEmpty);
    } finally {
      await f.close();
    }
  });

  testWidgets(
    'session library isolates owners and guests while merging duplicate IDs',
    (tester) async {
      final f = _Fixture();
      final ownCloud = _recording('same-id', creatorId: 'owner');
      final ownLocal = _recording('same-id', left: 620, creatorId: 'owner');
      final other = _recording('other', creatorId: 'other-owner');
      final guest = _recording('guest');
      f.firestore.library.addAll([ownCloud, other]);
      f.drafts.byId.addAll({
        ownLocal.id: ownLocal,
        other.id: other,
        guest.id: guest,
      });
      try {
        f.controller.userServiceImpl = _User('owner');
        final ownSessions = await f.controller.recordedSessions();
        expect(ownSessions, [same(ownLocal)]);
        expect(f.firestore.queriedOwners, ['owner']);
        f.controller.userServiceImpl = _User('other-owner');
        expect(await f.controller.recordedSessions(), [same(other)]);
        f.controller.userServiceImpl = null;
        expect(await f.controller.recordedSessions(), [same(guest)]);
        expect(f.firestore.queriedOwners, ['owner', 'other-owner']);
        expect(f.firestore.attempts, isEmpty);
        expect(f.drafts.removed, isEmpty);
      } finally {
        await f.close();
      }
    },
  );

  testWidgets('cancelling pending microphone permission ignores late PCM', (
    tester,
  ) async {
    final voice = _VoiceCapture()..startBarrier = Completer<int>();
    final f = _Fixture(voiceCapture: voice);
    try {
      final start = f.controller.startRecording();
      expect(voice.starts, 1);
      expect(f.controller.isRecording.value, isTrue);
      await f.controller.stopRecording(applyDetectedFrequency: false);
      expect(f.controller.isRecording.value, isFalse);
      voice.emit(_monoTone()); // Simulates a browser callback racing shutdown.
      voice.startBarrier!.complete(48000);
      await start;
      await tester.pump(const Duration(seconds: 4));
      expect(f.controller.isRecording.value, isFalse);
      expect(f.controller.detectedPitches, isEmpty);
      expect(f.controller.micWaveform, isEmpty);
      expect(voice.isActive, isFalse);
      expect(voice.stops, 2, reason: 'Late activation is explicitly stopped.');
      expect(f.backend.starts, 0);
      expect(permissionCalls, isEmpty);
    } finally {
      await f.close();
    }
  });

  testWidgets('cancelled voice timer cannot stop a newer capture', (
    tester,
  ) async {
    final voice = _VoiceCapture();
    final f = _Fixture(voiceCapture: voice);
    try {
      await f.controller.startRecording();
      await tester.pump(const Duration(seconds: 1));
      await f.controller.stopRecording(applyDetectedFrequency: false);
      await f.controller.startRecording();
      // The first session's deadline has passed; the second still has 999 ms.
      await tester.pump(const Duration(milliseconds: 2001));
      expect(f.controller.isRecording.value, isTrue);
      expect(voice.isActive, isTrue);
      expect(voice.stops, 1);
      await f.controller.stopRecording(applyDetectedFrequency: false);
      await tester.pump(const Duration(seconds: 4));
      expect(voice.stops, 2, reason: 'The second timer was cancelled as well.');
      expect(f.controller.isRecording.value, isFalse);
      expect(permissionCalls, isEmpty);
    } finally {
      await f.close();
    }
  });

  testWidgets(
    'voice capture uses 48 kHz mono and starts detected sound after release',
    (tester) async {
      final voice = _VoiceCapture();
      final f = _Fixture(voiceCapture: voice);
      try {
        await f.controller.playStopPreview();
        expect(f.engine.isPlaying, isTrue);
        final capture = f.controller.startRecording();
        expect(f.controller.playbackRequested.value, isFalse);
        expect(
          voice.starts,
          1,
          reason: 'Activation stays inside the user gesture.',
        );
        await capture;
        expect(f.engine.isPlaying, isFalse);
        for (var i = 0; i < 3; i++) {
          voice.emit(_monoTone());
          await tester.pump();
        }
        expect(f.controller.detectedPitches, hasLength(3));
        expect(f.controller.detectedPitches, everyElement(closeTo(440, 1)));
        expect(f.controller.micWaveform.length, 3);
        await tester.pump(const Duration(milliseconds: 2999));
        expect(f.controller.isRecording.value, isTrue);
        await tester.pump(const Duration(milliseconds: 1));
        expect(f.controller.isRecording.value, isFalse);
        expect(voice.isActive, isFalse);
        expect(f.controller.currentFreq.value, closeTo(440, 1));
        final pitches = List<double>.of(f.controller.detectedPitches);
        voice.emit(_monoTone(frequency: 880));
        await tester.pump();
        expect(f.controller.detectedPitches, pitches);
        expect(f.controller.playbackRequested.value, isTrue);
        expect(f.engine.isPlaying, isTrue);
        expect(f.backend.activations, 3);
        expect(f.backend.starts, 2);
        expect(permissionCalls, isEmpty);
      } finally {
        await f.close();
      }
    },
  );

  testWidgets('44.1 kHz controller pitch uses signed PCM and ignores silence', (
    tester,
  ) async {
    final voice = _VoiceCapture()..sampleRate = 44100;
    final f = _Fixture(voiceCapture: voice);
    try {
      await f.controller.startRecording();
      voice.emit(Uint8List(4096));
      await tester.pump();
      expect(f.controller.detectedPitches, isEmpty);
      final samples = ByteData(4096);
      for (var index = 0; index < 2048; index++) {
        samples.setInt16(
          index * 2,
          (math.sin(2 * math.pi * 220 * index / 44100) * 8000).round(),
          Endian.little,
        );
      }
      voice.emit(samples.buffer.asUint8List());
      await tester.pump();
      expect(f.controller.detectedPitches, [closeTo(220, 1)]);
      await f.controller.stopRecording();
      expect(f.controller.currentFreq.value, closeTo(220, 1));
      expect(f.backend.starts, 1);
    } finally {
      await f.close();
    }
  });

  testWidgets('voice prepares output in the gesture without starting sound', (
    tester,
  ) async {
    final voice = _VoiceCapture()..startBarrier = Completer<int>();
    final f = _Fixture(voiceCapture: voice);
    try {
      final capture = f.controller.startRecording();
      expect(f.backend.activations, 1);
      expect(f.backend.starts, 0);
      expect(f.controller.playbackRequested.value, isFalse);
      expect(f.controller.inciensoRecorder.isRecording, isFalse);
      await f.controller.stopRecording(applyDetectedFrequency: false);
      voice.startBarrier!.complete(48000);
      await capture;
      expect(f.backend.starts, 0);
    } finally {
      await f.close();
    }
  });

  testWidgets('detected root resets octave and leaves replay/multi output', (
    tester,
  ) async {
    final voice = _VoiceCapture();
    final f = _Fixture(voiceCapture: voice);
    try {
      await f.controller.loadIncienso(_recording('old', left: 333));
      f.controller.setOctave(3);
      f.controller.setMultiFrequency(subHz: 80, leftHz: 400, rightHz: 408);
      await f.controller.startRecording();
      f.controller.detectedPitches.addAll([178, 178, 179]);
      await f.controller.stopRecording();
      expect(f.controller.currentFreq.value, 178);
      expect(f.controller.effectiveFrequency, 178);
      expect(f.controller.currentOctave.value, 0);
      expect(f.controller.activeIncienso, isNull);
      expect(f.engine.multiFrequencyMode, isFalse);
      expect(f.engine.frequency, 178);
      expect(f.engine.isPlaying, isTrue);
      f.emitSeconds([0, 1]);
      expect(f.engine.frequency, 178, reason: 'Old keyframes cannot replay.');
    } finally {
      await f.close();
    }
  });

  testWidgets('microphone shutdown must finish before automatic playback', (
    tester,
  ) async {
    final voice = _VoiceCapture()..stopBarrier = Completer<void>();
    final f = _Fixture(voiceCapture: voice);
    try {
      await f.controller.startRecording();
      f.controller.detectedPitches.addAll([220, 220]);
      f.backend.onStart = () => expect(voice.isActive, isFalse);
      final completion = f.controller.stopRecording();
      expect(f.backend.starts, 0);
      expect(voice.isActive, isTrue);
      // An impatient new capture cannot reuse a microphone still stopping.
      await f.controller.startRecording();
      expect(voice.starts, 1);
      voice.stopBarrier!.complete();
      await completion;
      expect(f.backend.starts, 1);
      expect(f.engine.frequency, 220);
    } finally {
      await f.close();
    }
  });

  testWidgets('explicit cancellation discards a valid measured frequency', (
    tester,
  ) async {
    final voice = _VoiceCapture();
    final f = _Fixture(voiceCapture: voice);
    try {
      final original = f.controller.currentFreq.value;
      await f.controller.startRecording();
      f.controller.detectedPitches.addAll([220, 220]);
      await f.controller.stopRecording(applyDetectedFrequency: false);
      await tester.pump(const Duration(seconds: 4));
      expect(f.controller.currentFreq.value, original);
      expect(f.backend.starts, 0);
      expect(voice.isActive, isFalse);
    } finally {
      await f.close();
    }
  });

  for (final invalid in [
    null,
    0.0,
    40.0,
    1500.0,
    double.nan,
    double.infinity,
  ]) {
    testWidgets('no playback on empty or invalid voice pitch: $invalid', (
      tester,
    ) async {
      final f = _Fixture(voiceCapture: _VoiceCapture());
      try {
        f.controller.isAdmin = false;
        final original = f.controller.currentFreq.value;
        await f.controller.startRecording();
        if (invalid != null) f.controller.detectedPitches.add(invalid);
        await f.controller.stopRecording();
        expect(f.controller.currentFreq.value, original);
        expect(f.backend.starts, 0);
        expect(f.engine.isPlaying, isFalse);
      } finally {
        await f.close();
      }
    });
  }

  testWidgets('a second cancellation wins while successful capture closes', (
    tester,
  ) async {
    final voice = _VoiceCapture()..stopBarrier = Completer<void>();
    final f = _Fixture(voiceCapture: voice);
    try {
      await f.controller.startRecording();
      f.controller.detectedPitches.add(220);
      final completion = f.controller.stopRecording();
      await f.controller.stopRecording(applyDetectedFrequency: false);
      voice.stopBarrier!.complete();
      await completion;
      expect(f.backend.starts, 0);
      expect(voice.stops, 1);
    } finally {
      await f.close();
    }
  });

  testWidgets('explicit Stop prevents late voice completion from starting', (
    tester,
  ) async {
    final voice = _VoiceCapture()..stopBarrier = Completer<void>();
    final f = _Fixture(voiceCapture: voice);
    try {
      await f.controller.startRecording();
      f.controller.detectedPitches.add(220);
      final completion = f.controller.stopRecording();
      await f.controller.playStopPreview(stop: true);
      voice.stopBarrier!.complete();
      await completion;
      expect(f.backend.starts, 0);
    } finally {
      await f.close();
    }
  });

  testWidgets('Play during microphone shutdown cannot bypass capture release', (
    tester,
  ) async {
    final voice = _VoiceCapture()..stopBarrier = Completer<void>();
    final f = _Fixture(voiceCapture: voice);
    try {
      await f.controller.startRecording();
      f.controller.detectedPitches.add(220);
      final completion = f.controller.stopRecording();
      await f.controller.playStopPreview();
      expect(f.backend.starts, 0);
      voice.stopBarrier!.complete();
      await completion;
      expect(f.backend.starts, 1);
      expect(f.engine.isPlaying, isTrue);
    } finally {
      await f.close();
    }
  });

  testWidgets('Stop during measurement prevents timer-driven autoplay', (
    tester,
  ) async {
    final f = _Fixture(voiceCapture: _VoiceCapture());
    try {
      await f.controller.startRecording();
      f.controller.detectedPitches.add(220);
      await f.controller.playStopPreview(stop: true);
      await tester.pump(const Duration(seconds: 4));
      expect(f.backend.starts, 0);
      expect(f.controller.isRecording.value, isFalse);
    } finally {
      await f.close();
    }
  });

  testWidgets(
    'disposal cancels a valid completion awaiting microphone release',
    (tester) async {
      final voice = _VoiceCapture()..stopBarrier = Completer<void>();
      final f = _Fixture(voiceCapture: voice);
      await f.controller.startRecording();
      f.controller.detectedPitches.add(220);
      final completion = f.controller.stopRecording();
      await f.close();
      voice.stopBarrier!.complete();
      await completion;
      expect(f.backend.starts, 0);
      expect(voice.isActive, isFalse);
    },
  );

  testWidgets('capture start failure cannot auto-start even with late PCM', (
    tester,
  ) async {
    final voice = _VoiceCapture()..failStart = true;
    final f = _Fixture(voiceCapture: voice);
    try {
      await f.controller.startRecording();
      voice.emit(_monoTone());
      await tester.pump(const Duration(seconds: 4));
      await f.controller.stopRecording();
      expect(f.controller.isRecording.value, isFalse);
      expect(f.controller.detectedPitches, isEmpty);
      expect(f.controller.playbackError.value, isNotEmpty);
      expect(f.backend.starts, 0);
    } finally {
      await f.close();
    }
  });

  testWidgets('output preparation failure releases the microphone', (
    tester,
  ) async {
    final voice = _VoiceCapture();
    final f = _Fixture(voiceCapture: voice);
    f.backend.failActivation = true;
    try {
      await f.controller.startRecording();
      expect(f.controller.isRecording.value, isFalse);
      expect(voice.isActive, isFalse);
      expect(f.backend.starts, 0);
      expect(f.controller.playbackError.value, isNotEmpty);
    } finally {
      await f.close();
    }
  });

  testWidgets('failed microphone shutdown never starts output', (tester) async {
    final voice = _VoiceCapture();
    final f = _Fixture(voiceCapture: voice);
    try {
      await f.controller.startRecording();
      f.controller.detectedPitches.add(220);
      voice.failStop = true;
      await f.controller.stopRecording();
      expect(f.backend.starts, 0);
      expect(f.controller.playbackError.value, isNotEmpty);
    } finally {
      voice.failStop = false;
      await f.close();
    }
  });

  testWidgets('controller disposal releases capture and cancels its timer', (
    tester,
  ) async {
    final voice = _VoiceCapture();
    final f = _Fixture(voiceCapture: voice);
    await f.controller.startRecording();
    await f.close();
    await tester.pump();
    expect(voice.disposals, 1);
    expect(voice.isActive, isFalse);
    final stops = voice.stops;
    voice.emit(_monoTone());
    await tester.pump(const Duration(seconds: 4));
    expect(f.controller.detectedPitches, isEmpty);
    expect(voice.stops, stops);
    expect(permissionCalls, isEmpty);
  });

  testWidgets('a session keeps its starting owner after an account switch', (
    tester,
  ) async {
    final f = _Fixture();
    try {
      f.controller.userServiceImpl = _User('owner-a');
      await f.controller.playStopPreview();
      f.emitSeconds([0, 8, 16, 24, 31]);
      f.controller.userServiceImpl = _User('owner-b');
      await f.controller.playStopPreview(stop: true);
      await tester.pump();
      expect(f.drafts.saved.single.creatorId, 'owner-a');
      expect(f.controller.pendingRecordingCount, 1);
      expect(f.firestore.attempts, isEmpty);
      expect(await f.controller.recordedSessions(), isEmpty);
      f.controller.userServiceImpl = _User('owner-a');
      await f.controller.retryPendingRecordings();
      expect(f.firestore.attempts.single.creatorId, 'owner-a');
      expect(f.controller.pendingRecordingCount, 0);
    } finally {
      await f.close();
    }
  });

  testWidgets('loading a chamber preset restores all spatial coordinates', (
    tester,
  ) async {
    final f = _Fixture();
    final preset = NeomChamberPreset(
      mainFrequency: NeomFrequency(frequency: 321.5),
      binauralFrequency: NeomFrequency(frequency: 328.75),
      neomParameter: NeomParameter(x: .25, y: -.5, z: .75, volume: .35),
    );
    try {
      await f.controller.loadRouteArguments(preset);
      expect(f.engine.frequency, 321.5);
      expect(f.engine.beat, 7.25);
      expect(f.engine.volume, .35);
      expect([f.engine.posX, f.engine.posY, f.engine.posZ], [.25, -.5, .75]);
      expect(
        [
          f.controller.posX.value,
          f.controller.posY.value,
          f.controller.posZ.value,
        ],
        [.25, -.5, .75],
      );
      expect(f.backend.starts, 0);
      await f.controller.playStopPreview();
      expect([f.engine.posX, f.engine.posY, f.engine.posZ], [.25, -.5, .75]);
    } finally {
      await f.close();
    }
  });

  testWidgets('failed first draft does not block a later successful save', (
    tester,
  ) async {
    final f = _Fixture();
    f.controller.userServiceImpl = _User('owner');
    f.firestore.failedIds.add('failed');
    f.drafts.byId.addAll({
      'failed': _recording('failed', creatorId: 'owner'),
      'success': _recording('success', creatorId: 'owner'),
    });
    try {
      f.controller.onReady();
      await tester.pump();
      expect(f.firestore.attempts.map((session) => session.id), [
        'failed',
        'success',
      ]);
      expect(f.drafts.removed, ['success']);
      expect(f.drafts.byId.keys, ['failed']);
      expect(f.controller.pendingRecordingCount, 1);
      expect(f.controller.recordingSaveError.value, isNotEmpty);
      f.firestore.failedIds.clear();
      await f.controller.retryPendingRecordings();
      expect(f.controller.pendingRecordingCount, 0);
      expect(f.controller.recordingSaveError.value, isEmpty);
      expect(f.drafts.removed, ['success', 'failed']);
    } finally {
      await f.close();
    }
  });
}

Uint8List _monoTone({double frequency = 440}) {
  final samples = ByteData(2048 * 2);
  for (var i = 0; i < 2048; i++) {
    samples.setInt16(
      i * 2,
      (math.sin(2 * math.pi * frequency * i / 48000) * 16000).round(),
      Endian.little,
    );
  }
  return samples.buffer.asUint8List();
}

Incienso _recording(
  String id, {
  double left = 300,
  double changedLeft = 480,
  String? creatorId,
}) => Incienso(
  id: id,
  names: {'es': id},
  leftFrequencyHz: left,
  rightFrequencyHz: left + 8,
  suggestedDuration: const Duration(seconds: 2),
  creatorId: creatorId,
  recordingVersion: 2,
  timeline: [
    InciensoKeyframe(
      timestampMs: 0,
      sampleFrame: 0,
      leftHz: left,
      rightHz: left + 8,
      volume: 0.6,
      audioState: InciensoAudioState(
        parameters: {
          'carrierHz': left,
          'baseHz': left,
          'beatHz': 8.0,
          'volume': 0.6,
        },
      ),
    ),
    InciensoKeyframe(
      timestampMs: 1000,
      sampleFrame: 44100,
      leftHz: changedLeft,
      rightHz: changedLeft + 5,
      volume: 0.2,
      audioState: InciensoAudioState(
        parameters: {
          'carrierHz': changedLeft,
          'baseHz': changedLeft,
          'beatHz': 5.0,
          'volume': 0.2,
        },
      ),
    ),
    InciensoKeyframe(
      timestampMs: 2000,
      sampleFrame: 88200,
      leftHz: changedLeft,
      rightHz: changedLeft + 5,
      volume: 0.2,
    ),
  ],
);

class _Fixture {
  final NeomVoiceCapture? voiceCapture;
  final backend = _SilentBackend();
  final drafts = _Drafts();
  final firestore = _Firestore();
  final practiceStore = _PracticeStore();
  final portable = _PortableFile();
  final checkBackend = _SilentBackend();
  late final checkEngine = NeomSineEngine.withBackend(checkBackend);
  late final engine = NeomSineEngine.withBackend(backend);
  late final controller = NeomGeneratorController(
    sineEngine: engine,
    chamberRepository: _Chambers(),
    inciensoFirestore: firestore,
    draftStore: drafts,
    inciensoRecorder: InciensoRecorder(),
    voiceCapture: voiceCapture,
    practiceStore: practiceStore,
    portableFile: portable,
    channelCheckEngine: checkEngine,
  )..onInit();

  _Fixture({this.voiceCapture}) {
    controller;
  }

  /// Simulates synthesis/output-clock callbacks without generating PCM or
  /// waiting 30 real seconds. Backend capacity stays blocked throughout.
  void emitFrame(int frame) {
    engine.beforeBuffer!.call(frame);
    engine.generatedFrames = frame;
    engine.afterBuffer!.call(frame);
    backend.audibleFrame = frame;
  }

  void emitSeconds(List<int> seconds) {
    for (final second in seconds) {
      emitFrame(second * 44100);
    }
  }

  Future<void> close() async {
    final barrier = backend.startBarrier;
    if (barrier != null && !barrier.isCompleted) barrier.complete();
    await controller.playStopPreview(stop: true);
    controller.onClose();
    await engine.dispose();
  }
}

class _SilentBackend implements NeomPcmBackend {
  Completer<void>? startBarrier;
  Completer<void> _cancelled = Completer<void>();
  int activations = 0;
  int starts = 0;
  int writes = 0;
  int audibleFrame = 0;
  bool failActivation = false;
  VoidCallback? onStart;
  @override
  int get playedFrames => audibleFrame;
  @override
  Future<void> init() async {}
  @override
  Future<void> activate() async {
    activations++;
    if (failActivation) throw StateError('Output activation failed');
  }

  @override
  Future<void> start({
    required int sampleRate,
    required int channels,
    required int framesPerBuffer,
  }) async {
    starts++;
    onStart?.call();
    await startBarrier?.future;
    audibleFrame = 0;
    _cancelled = Completer<void>();
  }

  @override
  Future<void> waitForCapacity(int frames) => _cancelled.future;
  @override
  Future<void> write(Uint8List pcm) async {
    writes++;
  }

  @override
  Future<void> drain() async {}
  @override
  void interrupt() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  @override
  Future<void> stop() async {
    interrupt();
  }

  @override
  Future<void> dispose() async {
    interrupt();
  }
}

class _PracticeStore extends ChamberPracticeStore {
  final values = <String, Map<String, dynamic>>{};
  @override
  Future<Map<String, dynamic>> load(String scope) async => values[scope] ?? {};
  @override
  Future<void> save(String scope, Map<String, dynamic> value) async {
    values[scope] = value;
  }
}

class _PortableFile extends InciensoPortableFile {
  Uint8List? input;
  final exported = <String>[];
  @override
  Future<Uint8List?> pick() async => input;
  @override
  Future<void> export(String id) async {
    exported.add(id);
  }
}

class _Drafts implements InciensoDraftStore {
  final byId = <String, Incienso>{};
  final saved = <Incienso>[];
  final removed = <String>[];
  @override
  Future<void> save(Incienso recording) async {
    saved.add(recording);
    byId[recording.id] = recording;
  }

  @override
  Future<List<Incienso>> load() async => byId.values.toList();
  @override
  Future<void> remove(String id) async {
    removed.add(id);
    byId.remove(id);
  }
}

class _Firestore implements InciensoFirestore {
  Completer<Incienso?>? retrieveBarrier;
  @override
  Future<Incienso?> retrieve(String id) async => retrieveBarrier != null
      ? retrieveBarrier!.future
      : library.where((s) => s.id == id).firstOrNull;
  bool fail = false;
  final failedIds = <String>{};
  Completer<String>? insertBarrier;
  final attempts = <Incienso>[];
  final library = <Incienso>[];
  final queriedOwners = <String>[];
  @override
  Future<List<Incienso>> fetchByCreator(
    String creatorId, {
    int limit = 50,
  }) async {
    queriedOwners.add(creatorId);
    // Return the deliberately mixed fixture to verify controller-side scoping,
    // independent of server filtering.
    return library.take(limit).toList();
  }

  @override
  Future<String> insert(Incienso recording) async {
    attempts.add(recording);
    if (insertBarrier != null) return insertBarrier!.future;
    return fail || failedIds.contains(recording.id) ? '' : recording.id;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected Firestore operation: ${invocation.memberName}',
  );
}

class _VoiceCapture implements NeomVoiceCapture {
  Completer<int>? startBarrier;
  Completer<void>? stopBarrier;
  bool failStart = false;
  bool failStop = false;
  void Function(Uint8List)? _callback;
  int starts = 0;
  int stops = 0;
  int disposals = 0;
  @override
  bool isActive = false;
  @override
  int sampleRate = 48000;

  @override
  Future<int> start(void Function(Uint8List) onMonoPcm16) async {
    starts++;
    _callback = onMonoPcm16;
    if (startBarrier != null) await startBarrier!.future;
    if (failStart) throw StateError('Microphone permission denied');
    isActive = true;
    return sampleRate;
  }

  // Intentionally emits after stop/disposal as well, to exercise the
  // controller's own invalidation rather than rely on an ideal adapter.
  void emit(Uint8List samples) => _callback?.call(samples);

  @override
  Future<void> stop() async {
    stops++;
    await stopBarrier?.future;
    if (failStop) throw StateError('Microphone shutdown failed');
    isActive = false;
  }

  @override
  Future<void> dispose() async {
    disposals++;
    await stop();
  }
}

class _Chambers implements ChamberRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected chamber operation: ${invocation.memberName}',
  );
}

class _User implements UserService {
  _User(String id) : profile = AppProfile(id: id);
  @override
  AppProfile profile;
  @override
  AppUser user = AppUser();
  @override
  dynamic noSuchMethod(Invocation invocation) => throw UnsupportedError(
    'Unexpected user operation: ${invocation.memberName}',
  );
}
