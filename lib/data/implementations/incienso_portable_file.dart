import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';

/// Portable reference, NOT a copy of a person's parameters or recording.
/// The controller resolves the ID and checks visibility before loading it.
class InciensoPortableFile {
  static const maxBytes = 4096;

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
    if (value is! Map ||
        value['format'] != 'neom.incienso-reference' ||
        value['version'] != 1 ||
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
        id.trim() != id ||
        id.contains('/') ||
        id == '.' ||
        id == '..' ||
        id.runes.any((r) => r < 32 || r == 127)) {
      throw const FormatException('Invalid Incienso ID');
    }
  }

  Future<Uint8List?> pick() async {
    final result = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['incienso', 'json'],
      withData: false,
      withReadStream: true,
    );
    if (result == null) return null;
    final file = result.files.single;
    if (file.size > maxBytes ||
        (file.bytes == null && file.readStream == null)) {
      throw const FormatException('Invalid Incienso reference size');
    }
    if (file.bytes != null) return file.bytes;
    final bytes = BytesBuilder(copy: false);
    await for (final chunk in file.readStream!) {
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
      type: FileType.custom,
      allowedExtensions: ['incienso'],
      bytes: encode(inciensoId),
    );
  }
}
