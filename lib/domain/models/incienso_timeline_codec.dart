import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';

import 'incienso.dart';

/// Lossless storage of synthesis parameters, never recorded audio.
///
/// Long ramps change at every PCM boundary. Column dictionaries, byte-plane
/// XOR and gzip retain every IEEE-754 bit without repeating JSON field names.
/// Small/legacy sessions keep their original JSON representation. This storage
/// version is independent of the recording/playback engine version.
abstract final class InciensoTimelineCodec {
  static const encoding = 'columns-f64-xor-gzip-v1';
  static const compressionThreshold = 128;
  static const maxFrames = 200000;
  static const maxColumns = 128;
  static const maxExpandedCells = 8 * 1000 * 1000;
  static const maxInflatedBytes = 64 * 1024 * 1024;
  static const maxCompressedBytes = 8 * 1024 * 1024;
  static const _maxHeaderBytes = 1024 * 1024;

  static Map<String, dynamic> encode(
    List<InciensoKeyframe> frames, {
    required int recordingVersion,
  }) {
    if (recordingVersion < 2 || frames.length < compressionThreshold) {
      return {'timeline': frames.map((frame) => frame.toJson()).toList()};
    }
    if (frames.length > maxFrames) {
      throw const FormatException('Incienso timeline has too many frames');
    }
    final keys = <String>{
      'm:t',
      'm:l',
      'm:r',
      'm:c',
      'm:v',
      'm:s',
      'm:b',
      'm:x',
      'm:a',
      'm:f',
    };
    for (final frame in frames) {
      if (frame.audioState case final state?) {
        keys.add('e');
        keys.addAll(state.parameters.keys.map((key) => 'p:$key'));
        keys.addAll(state.phases.keys.map((key) => 'h:$key'));
      }
    }
    if (keys.length > maxColumns ||
        frames.length * keys.length > maxExpandedCells) {
      throw const FormatException('Incienso timeline has too many cells');
    }
    final strings = <String>[];
    final stringIndexes = <String, int>{};
    final columns = <Uint8List>[];
    final descriptors = <List<Object>>[];
    var rawLength = 0;
    for (final key in keys) {
      final first = _value(frames.first, key);
      final constant = frames.every(
        (frame) => _sameScalar(_value(frame, key), first),
      );
      final count = constant ? 1 : frames.length;
      final bytes = Uint8List(count * 9);
      final scalar = ByteData(8);
      final previous = Uint8List(8);
      for (var row = 0; row < count; row++) {
        final value = _value(frames[row], key);
        double number = 0;
        final int type;
        if (value == null) {
          type = 0;
        } else if (value is bool) {
          type = value ? 4 : 3;
        } else if (value is String) {
          type = 5;
          number = stringIndexes.putIfAbsent(value, () {
            strings.add(value);
            return strings.length - 1;
          }).toDouble();
        } else if (value is num && value.isFinite) {
          type = value is int ? 2 : 1;
          number = value.toDouble();
          if (value is int && number.toInt() != value) {
            throw const FormatException('Incienso integer cannot roundtrip');
          }
        } else {
          throw const FormatException('Invalid Incienso scalar');
        }
        bytes[row] = type;
        scalar.setFloat64(0, number, Endian.little);
        for (var plane = 0; plane < 8; plane++) {
          final current = scalar.getUint8(plane);
          bytes[count + plane * count + row] = current ^ previous[plane];
          previous[plane] = current;
        }
      }
      rawLength += bytes.length;
      if (rawLength > maxInflatedBytes) {
        throw const FormatException('Incienso timeline is too large');
      }
      descriptors.add([key, constant]);
      columns.add(bytes);
    }
    final header = utf8.encode(
      jsonEncode({
        'rows': frames.length,
        'columns': descriptors,
        'strings': strings,
      }),
    );
    if (header.length > _maxHeaderBytes ||
        rawLength + header.length + 4 > maxInflatedBytes) {
      throw const FormatException('Incienso timeline header is too large');
    }
    final raw = Uint8List(4 + header.length + rawLength);
    ByteData.sublistView(raw).setUint32(0, header.length, Endian.little);
    raw.setRange(4, 4 + header.length, header);
    var offset = 4 + header.length;
    for (final column in columns) {
      raw.setRange(offset, offset + column.length, column);
      offset += column.length;
    }
    final compressed = const GZipEncoder().encode(raw);
    if (compressed.length > maxCompressedBytes) {
      throw const FormatException('Compressed Incienso timeline is too large');
    }
    return {
      'timelineEncoding': encoding,
      'timelineBytes': raw.length,
      'timelineCrc32': getCrc32(raw),
      'timelineData': base64Encode(compressed),
    };
  }

  static bool _sameScalar(Object? a, Object? b) =>
      a.runtimeType == b.runtimeType &&
      a == b &&
      (a is! double || a != 0 || a.isNegative == (b as double).isNegative);

  // Read columns directly instead of cloning tens of thousands of complete
  // snapshot maps while the immutable recording is already resident in memory.
  static Object? _value(InciensoKeyframe frame, String key) => switch (key) {
    'm:t' => frame.timestampMs,
    'm:l' => frame.leftHz,
    'm:r' => frame.rightHz,
    'm:c' => frame.coherence,
    'm:v' => frame.volume,
    'm:s' => frame.neuroState,
    'm:b' => frame.breathPhase,
    'm:x' => frame.visualExperience,
    'm:a' => frame.isUserAction ? true : null,
    'm:f' => frame.sampleFrame,
    'e' => frame.audioState?.engineVersion,
    _ when key.startsWith('p:') =>
      frame.audioState?.parameters[key.substring(2)],
    _ when key.startsWith('h:') => frame.audioState?.phases[key.substring(2)],
    _ => null,
  };

  static List<InciensoKeyframe> decode(Map<String, dynamic> json) {
    if (!json.containsKey('timelineEncoding')) {
      final timeline = json['timeline'] as List? ?? const [];
      if (timeline.length > maxFrames) {
        throw const FormatException('Incienso timeline has too many frames');
      }
      return timeline
          .map(
            (row) => InciensoKeyframe.fromJson(
              Map<String, dynamic>.from(row as Map),
            ),
          )
          .toList();
    }
    if (json['timelineEncoding'] != encoding || json.containsKey('timeline')) {
      throw const FormatException(
        'Unsupported or ambiguous Incienso timeline encoding',
      );
    }
    final length = json['timelineBytes'];
    final data = json['timelineData'];
    if (length is! int ||
        length < 4 ||
        length > maxInflatedBytes ||
        data is! String ||
        data.length > ((maxCompressedBytes + 2) ~/ 3) * 4) {
      throw const FormatException('Invalid Incienso timeline envelope');
    }
    final compressed = base64Decode(data);
    if (compressed.length < 18 ||
        compressed.length > maxCompressedBytes ||
        compressed[0] != 0x1f ||
        compressed[1] != 0x8b) {
      throw const FormatException('Invalid Incienso gzip data');
    }
    // Always use the streaming Dart decoder: native decodeBytes allocates the
    // entire output before callers can reject a malicious expansion bomb.
    final output = _BoundedOutput(length);
    const GZipDecoderWeb().decodeStream(InputMemoryStream(compressed), output);
    final raw = output.getBytes();
    if (raw.length != length || getCrc32(raw) != json['timelineCrc32']) {
      throw const FormatException('Corrupt Incienso timeline');
    }
    final headerLength = ByteData.sublistView(raw).getUint32(0, Endian.little);
    if (headerLength > _maxHeaderBytes || headerLength > raw.length - 4) {
      throw const FormatException('Invalid Incienso timeline header');
    }
    final header =
        jsonDecode(utf8.decode(raw.sublist(4, 4 + headerLength))) as Map;
    final count = header['rows'];
    final columns = header['columns'];
    final strings = header['strings'];
    if (count is! int ||
        count < 1 ||
        count > maxFrames ||
        columns is! List ||
        columns.isEmpty ||
        columns.length > maxColumns ||
        count * columns.length > maxExpandedCells ||
        strings is! List ||
        strings.any((value) => value is! String)) {
      throw const FormatException('Invalid Incienso timeline dimensions');
    }
    final rows = List.generate(count, (_) => <String, dynamic>{});
    var offset = 4 + headerLength;
    final seen = <String>{};
    for (final descriptor in columns) {
      if (descriptor is! List ||
          descriptor.length != 2 ||
          descriptor[0] is! String ||
          descriptor[1] is! bool) {
        throw const FormatException('Invalid Incienso column');
      }
      final key = descriptor[0] as String;
      if (!seen.add(key) ||
          !(key == 'e' ||
              key.startsWith('m:') ||
              key.startsWith('p:') ||
              key.startsWith('h:'))) {
        throw const FormatException('Invalid Incienso column key');
      }
      final cells = descriptor[1] == true ? 1 : count;
      if (cells * 9 > raw.length - offset) {
        throw const FormatException('Truncated Incienso timeline');
      }
      final previous = Uint8List(8);
      final scalar = ByteData.sublistView(previous);
      Object? last;
      for (var index = 0; index < count; index++) {
        if (index < cells) {
          for (var plane = 0; plane < 8; plane++) {
            previous[plane] ^= raw[offset + cells + plane * cells + index];
          }
          final number = scalar.getFloat64(0, Endian.little);
          if (!number.isFinite) {
            throw const FormatException('Invalid Incienso number');
          }
          final type = raw[offset + index];
          last = switch (type) {
            0 => null,
            1 => number,
            2 when number == number.truncateToDouble() => number.toInt(),
            3 => false,
            4 => true,
            5
                when number >= 0 &&
                    number < strings.length &&
                    number == number.truncateToDouble() =>
              strings[number.toInt()] as String,
            _ => throw const FormatException('Invalid Incienso scalar tag'),
          };
        }
        if (last == null) continue;
        final row = rows[index];
        if (key.startsWith('m:')) {
          row[key.substring(2)] = last;
        } else {
          final audio =
              row.putIfAbsent('p', () => <String, dynamic>{})
                  as Map<String, dynamic>;
          if (key == 'e') {
            audio['engineVersion'] = last;
          } else {
            final map =
                audio.putIfAbsent(
                      key.startsWith('h:') ? 'phases' : 'parameters',
                      () => <String, dynamic>{},
                    )
                    as Map<String, dynamic>;
            map[key.substring(2)] = last;
          }
        }
      }
      offset += cells * 9;
    }
    if (offset != raw.length) {
      throw const FormatException('Trailing Incienso data');
    }
    return rows.map(InciensoKeyframe.fromJson).toList();
  }
}

class _BoundedOutput extends OutputMemoryStream {
  final int limit;
  _BoundedOutput(this.limit);

  void _check(int count) {
    if (count < 0 || length + count > limit) {
      throw const FormatException('Incienso decompression limit exceeded');
    }
  }

  @override
  void writeByte(int value) {
    _check(1);
    super.writeByte(value);
  }

  @override
  void writeBytes(List<int> bytes, {int? length}) {
    _check(length ?? bytes.length);
    super.writeBytes(bytes, length: length);
  }

  @override
  void writeStream(InputStream stream) {
    _check(stream.length);
    super.writeStream(stream);
  }
}
