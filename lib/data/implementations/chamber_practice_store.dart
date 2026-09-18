import 'dart:convert';
import 'package:hive_flutter/hive_flutter.dart';

/// Device-only favorites, recent choices and imported parameter files.
/// Callers namespace by app AND account; imports never enter the upload queue.
class ChamberPracticeStore {
  Future<Map<String, dynamic>> load(String scope) async {
    final box = await Hive.openBox<String>('neom_chamber_practice_v1');
    final value = box.get(scope);
    return value == null
        ? <String, dynamic>{}
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Future<void> save(String scope, Map<String, dynamic> value) async {
    final encoded = jsonEncode(value); // Freeze before the first await.
    final box = await Hive.openBox<String>('neom_chamber_practice_v1');
    await box.put(scope, encoded);
  }
}
