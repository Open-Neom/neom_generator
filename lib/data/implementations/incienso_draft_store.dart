import 'dart:async';
import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/models/incienso.dart';

/// Private local recovery queue. No Firebase calls. Drafts are removed only
/// after the server acknowledges the same immutable session ID.
class InciensoDraftStore {
  static const int maxEncodedChars = 2 * 1024 * 1024;
  static const Set<String> _forbiddenIds = <String>{
    '__proto__',
    'constructor',
    'prototype',
  };
  static final RegExp _controlOrBidiPattern = RegExp(
    r'[\x00-\x1F\x7F-\x9F\u0085\u061C\u200B-\u200F\u2028-\u202E\u2060\u2066-\u2069\uFEFF]',
  );

  static bool isSafeDraftId(String id) {
    if (id.isEmpty || id.length > 240) return false;
    if (_controlOrBidiPattern.hasMatch(id) || id.trim() != id) return false;
    if (id == '.' || id == '..' || id.contains('/') || id.contains(r'\')) {
      return false;
    }
    if (_forbiddenIds.contains(id) ||
        (id.startsWith('__') && id.endsWith('__'))) {
      return false;
    }
    return true;
  }

  final Map<String, String> _memoryFallback = {};

  Future<Box<String>?> _openSafeBox() async {
    if (Hive.isBoxOpen('neom_incienso_drafts_v2')) {
      return Hive.box<String>('neom_incienso_drafts_v2');
    }
    final completer = Completer<Box<String>?>();
    runZonedGuarded(
      () async {
        try {
          final box = await Hive.openBox<String>('neom_incienso_drafts_v2');
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

  Future<void> save(Incienso recording) async {
    if (!isSafeDraftId(recording.id)) return;
    final encoded = jsonEncode(recording.toJson());
    if (encoded.length > maxEncodedChars) return;
    final box = await _openSafeBox();
    if (box != null) {
      await box.put(recording.id, encoded);
    } else {
      _memoryFallback[recording.id] = encoded;
    }
  }

  Future<List<Incienso>> load() async {
    final box = await _openSafeBox();
    final values = box != null ? box.values : _memoryFallback.values;
    final result = <Incienso>[];
    for (final value in values) {
      if (value.length > maxEncodedChars) continue;
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map) {
          final parsed = Incienso.fromJson(Map<String, dynamic>.from(decoded));
          if (isSafeDraftId(parsed.id)) {
            result.add(parsed);
          }
        }
      } catch (_) {}
    }
    return result;
  }

  Future<void> remove(String id) async {
    if (!isSafeDraftId(id)) return;
    final box = await _openSafeBox();
    if (box != null) {
      await box.delete(id);
    } else {
      _memoryFallback.remove(id);
    }
  }
}
