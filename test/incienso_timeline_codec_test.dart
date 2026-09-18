import 'dart:convert';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/domain/models/incienso.dart';
import 'package:neom_generator/domain/models/incienso_audio_state.dart';
import 'package:neom_generator/domain/models/incienso_timeline_codec.dart';
import 'package:neom_generator/engine/audio/neom_pcm_backend.dart';
import 'package:neom_generator/engine/incienso_synthesis_state.dart';
import 'package:neom_generator/engine/neom_sine_engine.dart';

class _NoOutput implements NeomPcmBackend {
  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw StateError('No platform audio allowed');
}

NeomSineEngine _engine() => NeomSineEngine.withBackend(_NoOutput());

Incienso _recording(List<InciensoKeyframe> timeline, {int version = 2}) =>
    Incienso(
      id: 'codec-only',
      names: const {'es': 'Sesión sin audio'},
      leftFrequencyHz: 432,
      rightFrequencyHz: 442,
      suggestedDuration: const Duration(minutes: 30),
      recordingVersion: version,
      timeline: timeline,
    );

List<InciensoKeyframe> _ramp(int minutes) {
  final template = _engine().captureAudioState();
  final count = (minutes * 60 * 44100 / 1024).ceil();
  var leftPhase = 0.0;
  var rightPhase = 0.0;
  return List.generate(count, (index) {
    final beat = 12 - 8 * index / count;
    final state = InciensoAudioState(
      parameters: {
        ...template.parameters,
        'carrierHz': 432.0,
        'baseHz': 432.0,
        'beatHz': beat,
      },
      phases: {...template.phases, 'left': leftPhase, 'right': rightPhase},
    );
    // Same deterministic oscillator recurrence used for a standard ramp;
    // no PCM is generated/retained by this duration/size fixture.
    leftPhase = (leftPhase + 2 * pi * 432 * 1024 / 44100) % (2 * pi);
    rightPhase = (rightPhase + 2 * pi * (432 + beat) * 1024 / 44100) % (2 * pi);
    return InciensoKeyframe(
      timestampMs: index * 1024 * 1000 / 44100,
      sampleFrame: index * 1024,
      leftHz: 432,
      rightHz: 432 + beat,
      audioState: state,
    );
  });
}

void main() {
  test('legacy and short v2 sessions keep the readable timeline contract', () {
    final frames = _ramp(1).take(3).toList();
    for (final version in [1, 2]) {
      final encoded = _recording(frames, version: version).toJson();
      expect(encoded['timeline'], isList);
      expect(encoded.containsKey('timelineData'), isFalse);
      final decoded = Incienso.fromJson(encoded);
      expect(
        decoded.timeline.map((frame) => frame.toJson()),
        frames.map((frame) => frame.toJson()),
      );
    }
  });

  for (final minutes in [5, 30]) {
    test('$minutes minute per-buffer ramp is lossless below 900 KiB', () {
      final frames = _ramp(minutes);
      final encoded = _recording(frames).toJson();
      final size = utf8.encode(jsonEncode(encoded)).length;
      debugPrint(
        'Incienso lossless $minutes min: ${frames.length} snapshots, $size bytes',
      );
      // Include base64 + all document metadata, not only compressed bytes.
      expect(
        size,
        lessThan(900 * 1024),
        reason: '$minutes minute payload: $size bytes',
      );
      expect(encoded['timelineEncoding'], InciensoTimelineCodec.encoding);
      expect(encoded.containsKey('timeline'), isFalse);
      final decoded = Incienso.fromJson(
        jsonDecode(jsonEncode(encoded)) as Map<String, dynamic>,
      );
      expect(decoded.timeline.length, frames.length);
      for (var index = 0; index < frames.length; index++) {
        expect(
          decoded.timeline[index].toJson(),
          frames[index].toJson(),
          reason: 'snapshot $index',
        );
      }
    });
  }

  test(
    'compressed snapshots reproduce identical PCM and preserve sparse states',
    () {
      final original = _engine();
      final frames = <InciensoKeyframe>[];
      final pcm = <Uint8List>[];
      for (var index = 0; index < 160; index++) {
        original.beat = 7 + index / 1000;
        if (index == 71) original.volume = .39;
        frames.add(
          InciensoKeyframe(
            timestampMs: index * 1024 * 1000 / 44100,
            sampleFrame: index * 1024,
            leftHz: original.frequency,
            rightHz: original.frequency + original.beat,
            visualExperience: index % 3 == 0 ? 'fractals' : null,
            isUserAction: index == 71,
            audioState: original.captureAudioState(),
          ),
        );
        pcm.add(original.generateBufferForTesting());
      }
      // A final metadata-only endpoint must stay metadata-only after decoding.
      frames.add(
        InciensoKeyframe(timestampMs: 4000, leftHz: 432, rightHz: 439),
      );
      final decoded = Incienso.fromJson(_recording(frames).toJson());
      expect(decoded.timeline.last.audioState, isNull);
      final replay = _engine();
      for (var index = 0; index < pcm.length; index++) {
        expect(decoded.timeline[index].toJson(), frames[index].toJson());
        replay.applyAudioState(decoded.timeline[index].audioState!);
        expect(replay.generateBufferForTesting(), pcm[index]);
      }
    },
  );

  test(
    'unknown parameters, disappearing keys, type changes and negative zero survive',
    () {
      final frames = List.generate(
        130,
        (index) => InciensoKeyframe(
          timestampMs: index.toDouble(),
          leftHz: 1,
          rightHz: 2,
          audioState: InciensoAudioState(
            parameters: {
              'negZero': -0.0,
              'variable': index.isEven ? index : 'value $index',
              if (index % 3 == 0) 'optional': true,
            },
            phases: const {'left': -0.0},
          ),
        ),
      );
      final decoded = Incienso.fromJson(_recording(frames).toJson());
      for (var index = 0; index < frames.length; index++) {
        expect(decoded.timeline[index].toJson(), frames[index].toJson());
        expect(
          (decoded.timeline[index].audioState!.parameters['negZero'] as double)
              .isNegative,
          isTrue,
        );
        expect(
          decoded.timeline[index].audioState!.phases['left']!.isNegative,
          isTrue,
        );
      }
    },
  );

  test(
    'rejects unknown versions, corrupt data, oversized claims and expansion bombs',
    () {
      final encoded = _recording(_ramp(1).take(130).toList()).toJson();
      for (final invalid in [
        {...encoded, 'timelineEncoding': 'future-format'},
        {...encoded, 'timeline': []},
        {
          ...encoded,
          'timelineBytes': InciensoTimelineCodec.maxInflatedBytes + 1,
        },
        {...encoded, 'timelineCrc32': -1},
        {...encoded, 'timelineData': 'not a base64 string'},
        {
          ...encoded,
          'timelineBytes': 4,
          'timelineData': base64Encode(
            const GZipEncoder().encode(Uint8List(1024 * 1024)),
          ),
        },
      ]) {
        expect(() => Incienso.fromJson(invalid), throwsFormatException);
      }
    },
  );

  test(
    'tiny constant-column payload cannot expand into millions of map cells',
    () {
      final header = utf8.encode(
        jsonEncode({
          'rows': InciensoTimelineCodec.maxFrames,
          'columns': List.generate(
            InciensoTimelineCodec.maxColumns,
            (index) => ['p:key$index', true],
          ),
          'strings': <String>[],
        }),
      );
      final raw = Uint8List(
        4 + header.length + InciensoTimelineCodec.maxColumns * 9,
      );
      ByteData.sublistView(raw).setUint32(0, header.length, Endian.little);
      raw.setRange(4, 4 + header.length, header);
      for (var index = 0; index < InciensoTimelineCodec.maxColumns; index++) {
        raw[4 + header.length + index * 9] = 1; // Present constant double 0.
      }
      expect(
        () => InciensoTimelineCodec.decode({
          'timelineEncoding': InciensoTimelineCodec.encoding,
          'timelineBytes': raw.length,
          'timelineCrc32': getCrc32(raw),
          'timelineData': base64Encode(const GZipEncoder().encode(raw)),
        }),
        throwsFormatException,
      );
    },
  );
}
