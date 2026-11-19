import 'dart:async';
import 'dart:convert';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';

/// Device-only favorites, recent choices and imported parameter files.
/// Callers namespace by app AND account; imports never enter the upload queue.
class ChamberPracticeStore {
  static const int maxEncodedChars = 512 * 1024;
  static const Set<String> _forbiddenKeys = <String>{
    '__proto__',
    'constructor',
    'prototype',
  };
  static final RegExp _controlOrBidiPattern = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u0085\u061C\u200B-\u200F\u2028-\u202E\u2060\u2066-\u2069\uFEFF]',
  );

  static bool isSafeScope(String scope) {
    if (scope.isEmpty || scope.length > 200) return false;
    if (_controlOrBidiPattern.hasMatch(scope) || scope.trim() != scope) {
      return false;
    }
    if (scope == '.' ||
        scope == '..' ||
        scope.contains('/') ||
        scope.contains(r'\')) {
      return false;
    }
    if (_forbiddenKeys.contains(scope) ||
        (scope.startsWith('__') && scope.endsWith('__'))) {
      return false;
    }
    return true;
  }

  static Map<String, dynamic> _stripForbiddenKeys(Map raw) {
    final cleaned = <String, dynamic>{};
    for (final entry in raw.entries) {
      if (entry.key is! String) continue;
      final key = entry.key as String;
      if (_forbiddenKeys.contains(key)) continue;
      cleaned[key] = _sanitizeValue(entry.value);
    }
    return cleaned;
  }

  static Object? _sanitizeValue(Object? value) {
    if (value is Map) return _stripForbiddenKeys(value);
    if (value is List) return value.map(_sanitizeValue).toList();
    return value;
  }

  final Map<String, String> _memoryFallback = {};

  Future<Box<String>?> _openSafeBox() async {
    if (Hive.isBoxOpen('neom_chamber_practice_v1')) {
      return Hive.box<String>('neom_chamber_practice_v1');
    }
    final completer = Completer<Box<String>?>();
    runZonedGuarded(
      () async {
        try {
          final box = await Hive.openBox<String>('neom_chamber_practice_v1');
          if (!completer.isCompleted) completer.complete(box);
        } catch (_) {
          if (!completer.isCompleted) completer.complete(null);
        }
      },
      (_, _) {
        if (!completer.isCompleted) completer.complete(null);
      },
    );
    return completer.future;
  }

  Future<Map<String, dynamic>> load(String scope) async {
    if (!isSafeScope(scope)) return <String, dynamic>{};
    final box = await _openSafeBox();
    final value = box != null ? box.get(scope) : _memoryFallback[scope];
    if (value == null || value.length > maxEncodedChars) {
      return <String, dynamic>{};
    }
    try {
      final decoded = jsonDecode(value);
      return decoded is Map ? _stripForbiddenKeys(decoded) : <String, dynamic>{};
    } catch (_) {
      return <String, dynamic>{};
    }
  }

  Future<void> save(String scope, Map<String, dynamic> value) async {
    if (!isSafeScope(scope)) return;
    final encoded = jsonEncode(_stripForbiddenKeys(value)); // Freeze before the first await.
    if (encoded.length > maxEncodedChars) return;
    final box = await _openSafeBox();
    if (box != null) {
      await box.put(scope, encoded);
    } else {
      _memoryFallback[scope] = encoded;
    }
  }
}
