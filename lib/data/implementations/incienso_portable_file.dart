import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Portable reference, NOT a copy of a person's parameters or recording.
/// The controller resolves the ID and checks visibility before loading it.
class InciensoPortableFile {
  static const maxBytes = 4096;
  static const Set<String> _forbiddenIds = <String>{
    '__proto__',
    'constructor',
    'prototype',
  };
  static final RegExp _controlOrBidiPattern = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u0085\u061C\u200B-\u200F\u2028-\u202E\u2060\u2066-\u2069\uFEFF]',
  );
  static final RegExp _encodedTraversalPattern = RegExp(
    r'(%00|%2e|%2f|%5c)',
    caseSensitive: false,
  );

  static Uint8List encode(String inciensoId) {
    _validateId(inciensoId);
    return Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'neom.incienso-reference',
          'version': 1,
          'inciensoId': inciensoId,
        }),
      ),
    );
  }

  static String decode(Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxBytes) {
      throw const FormatException('Invalid Incienso reference size');
    }
    final value = jsonDecode(utf8.decode(bytes));
    if (value is! Map) {
      throw const FormatException('Unsupported Incienso reference');
    }
    final rawVersion = value['version'];
    if (value['format'] != 'neom.incienso-reference' ||
        rawVersion is! int ||
        !rawVersion.isFinite ||
        rawVersion != 1 ||
        value['inciensoId'] is! String) {
      throw const FormatException('Unsupported Incienso reference');
    }
    final id = value['inciensoId'] as String;
    _validateId(id);
    return id;
  }

  static void _validateId(String id) {
    if (id.isEmpty ||
        id.length > 240 ||
        _controlOrBidiPattern.hasMatch(id) ||
        id.trim() != id ||
        id.contains('/') ||
        id.contains(r'\') ||
        id == '.' ||
        id == '..' ||
        id.contains('..') ||
        _encodedTraversalPattern.hasMatch(id) ||
        _forbiddenIds.contains(id) ||
        (id.startsWith('__') && id.endsWith('__'))) {
      throw const FormatException('Invalid Incienso ID');
    }
  }

  Future<Uint8List?> pick() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['incienso', 'json'],
    );
    if (file == null) return null;
    final knownSize = file.lengthSync() ?? await file.length();
    if (knownSize != null && (knownSize < 0 || knownSize > maxBytes)) {
      throw const FormatException('Invalid Incienso reference size');
    }
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readAsByteStream()) {
      if (bytes.length + chunk.length > maxBytes) {
        throw const FormatException('Invalid Incienso reference size');
      }
      bytes.add(chunk);
    }
    return bytes.takeBytes();
  }

  Future<void> export(String inciensoId) async {
    await FilePicker.saveFile(
      fileName: 'reference.incienso',
      bytes: encode(inciensoId),
    );
  }
}
