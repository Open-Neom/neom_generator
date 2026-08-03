import 'package:flutter/material.dart';

/// Tree-shake-safe resolver for Incienso icons.
///
/// Web release builds tree-shake the MaterialIcons font and reject
/// non-constant `IconData(...)` constructor calls. The catalog stores
/// icons as raw codePoints, so this const map resolves them back to
/// constant [IconData] instances the tree-shaker can analyze, keeping
/// release builds working without `--no-tree-shake-icons`.
class InciensoIcons {

  InciensoIcons._();

  static const IconData fallback = Icons.local_fire_department;

  static const Map<int, IconData> _byCodePoint = {
    0xe03e: IconData(0xe03e, fontFamily: 'MaterialIcons'), // auto_fix_high
    0xe153: IconData(0xe153, fontFamily: 'MaterialIcons'), // flight_land
    0xe1b1: IconData(0xe1b1, fontFamily: 'MaterialIcons'), // bolt
    0xe3a5: IconData(0xe3a5, fontFamily: 'MaterialIcons'), // bolt
    0xe3ae: IconData(0xe3ae, fontFamily: 'MaterialIcons'), // brush
    0xe3e7: IconData(0xe3e7, fontFamily: 'MaterialIcons'), // center_focus_strong
    0xe3f3: IconData(0xe3f3, fontFamily: 'MaterialIcons'), // healing
    0xe405: IconData(0xe405, fontFamily: 'MaterialIcons'), // music_note
    0xe40a: IconData(0xe40a, fontFamily: 'MaterialIcons'), // lightbulb
    0xe425: IconData(0xe425, fontFamily: 'MaterialIcons'), // snooze
    0xe4be: IconData(0xe4be, fontFamily: 'MaterialIcons'), // healing
    0xe50a: IconData(0xe50a, fontFamily: 'MaterialIcons'), // bedtime
    0xe51a: IconData(0xe51a, fontFamily: 'MaterialIcons'), // nights_stay
    0xe51c: IconData(0xe51c, fontFamily: 'MaterialIcons'), // visibility
    0xe53a: IconData(0xe53a, fontFamily: 'MaterialIcons'), // nightlight_round
    0xe572: IconData(0xe572, fontFamily: 'MaterialIcons'), // spa
    0xe813: IconData(0xe813, fontFamily: 'MaterialIcons'), // bedtime
    0xe84e: IconData(0xe84e, fontFamily: 'MaterialIcons'), // shield
    0xe865: IconData(0xe865, fontFamily: 'MaterialIcons'), // school
    0xe87d: IconData(0xe87d, fontFamily: 'MaterialIcons'), // favorite
    0xe88e: IconData(0xe88e, fontFamily: 'MaterialIcons'), // psychology
    0xe894: IconData(0xe894, fontFamily: 'MaterialIcons'), // public
    0xe8b8: IconData(0xe8b8, fontFamily: 'MaterialIcons'), // psychology
    0xe8f9: IconData(0xe8f9, fontFamily: 'MaterialIcons'), // terminal
    0xea63: IconData(0xea63, fontFamily: 'MaterialIcons'), // accessibility_new
    0xeb43: IconData(0xeb43, fontFamily: 'MaterialIcons'), // fitness_center
    0xeb44: IconData(0xeb44, fontFamily: 'MaterialIcons'), // sports_score
    0xeb45: IconData(0xeb45, fontFamily: 'MaterialIcons'), // sports
    0xee6c: IconData(0xee6c, fontFamily: 'MaterialIcons'), // weekend
    0xef3d: IconData(0xef3d, fontFamily: 'MaterialIcons'), // self_improvement
    0xef65: IconData(0xef65, fontFamily: 'MaterialIcons'), // local_fire_department
    0xf0117: IconData(0xf0117, fontFamily: 'MaterialIcons'), // accessibility
    0xf0542: IconData(0xf0542, fontFamily: 'MaterialIcons'), // spa_outlined
    0xf06bb: IconData(0xf06bb, fontFamily: 'MaterialIcons'), // self_improvement
    0xf0875: IconData(0xf0875, fontFamily: 'MaterialIcons'), // air
  };

  /// Resolves a stored Material Icons [codePoint] to a const [IconData].
  ///
  /// Null or unknown codePoints return [orElse] (defaults to [fallback]).
  /// All codePoints used by `InciensoCatalog` are covered by the map.
  static IconData resolve(int? codePoint, {IconData orElse = fallback}) {
    if (codePoint == null) return orElse;
    return _byCodePoint[codePoint] ?? orElse;
  }

}
