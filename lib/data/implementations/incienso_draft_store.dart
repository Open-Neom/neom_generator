import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';
import '../../domain/models/incienso.dart';

/// Private local recovery queue. No Firebase calls. Drafts are removed only
/// after the server acknowledges the same immutable session ID.
class InciensoDraftStore {
  Future<Box<String>> _box() => Hive.openBox<String>('neom_incienso_drafts_v2');

  Future<void> save(Incienso recording) async {
    await (await _box()).put(recording.id, jsonEncode(recording.toJson()));
  }

  Future<List<Incienso>> load() async {
    final box = await _box();
    return [
      for (final value in box.values)
        Incienso.fromJson(Map<String, dynamic>.from(jsonDecode(value) as Map)),
    ];
  }

  Future<void> remove(String id) async => (await _box()).delete(id);
}
