import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/data/implementations/incienso_portable_file.dart';

void main() {
  test(
    'exchange contains only the public ID and format, not session parameters',
    () {
      final bytes = InciensoPortableFile.encode('public-123');
      expect(jsonDecode(utf8.decode(bytes)), {
        'format': 'neom.incienso-reference',
        'version': 1,
        'inciensoId': 'public-123',
      });
      expect(InciensoPortableFile.decode(bytes), 'public-123');
    },
  );
  test('rejects paths, empty IDs, invalid versions and oversized files', () {
    for (final id in ['', '../users', 'a/b', '.', '..', ' a', 'a\n']) {
      expect(() => InciensoPortableFile.encode(id), throwsFormatException);
    }
    for (final value in [
      {},
      {'format': 'neom.incienso-reference', 'version': 2, 'inciensoId': 'x'},
    ]) {
      expect(
        () => InciensoPortableFile.decode(
          Uint8List.fromList(utf8.encode(jsonEncode(value))),
        ),
        throwsFormatException,
      );
    }
    expect(
      () => InciensoPortableFile.decode(Uint8List(4097)),
      throwsFormatException,
    );
  });
  test('untrusted extra fields cannot instruct playback or publishing', () {
    final bytes = Uint8List.fromList(
      utf8.encode(
        jsonEncode({
          'format': 'neom.incienso-reference',
          'version': 1,
          'inciensoId': 'abc',
          'isPublic': true,
          'autoplay': true,
          'parameters': {'volume': 1},
        }),
      ),
    );
    expect(InciensoPortableFile.decode(bytes), 'abc');
  });
}
