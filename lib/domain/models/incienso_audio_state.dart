import 'package:flutter/foundation.dart';

/// Complete, versioned synthesis snapshot. No audio or microphone data.
///
/// Parameters are separate from oscillator phases so a recorder can detect
/// actual control changes without writing a frame for every audio sample.
@immutable
class InciensoAudioState {
  static const currentEngineVersion = 1;
  final int engineVersion;
  final Map<String, Object> parameters;
  final Map<String, double> phases;

  static const Set<String> _forbiddenKeys = <String>{
    '__proto__',
    'constructor',
    'prototype',
  };

  InciensoAudioState({
    this.engineVersion = currentEngineVersion,
    required Map<String, Object> parameters,
    Map<String, double> phases = const {},
  }) : parameters = Map.unmodifiable({
         for (final entry in parameters.entries)
           if (!_forbiddenKeys.contains(entry.key)) entry.key: entry.value,
       }),
       phases = Map.unmodifiable({
         for (final entry in phases.entries)
           if (!_forbiddenKeys.contains(entry.key) && entry.value.isFinite)
             entry.key: entry.value,
       });

  double number(String key, double fallback) {
    final value = parameters[key];
    return value is num && value.isFinite ? value.toDouble() : fallback;
  }

  bool flag(String key, bool fallback) =>
      parameters[key] is bool ? parameters[key] as bool : fallback;

  String text(String key, String fallback) =>
      parameters[key] is String ? parameters[key] as String : fallback;

  bool sameParameters(InciensoAudioState other) =>
      engineVersion == other.engineVersion &&
      mapEquals(parameters, other.parameters);

  Map<String, dynamic> toJson() => {
    'engineVersion': engineVersion,
    'parameters': parameters,
    'phases': phases,
  };

  factory InciensoAudioState.fromJson(Map<String, dynamic> json) {
    final rawEngineVersion = json['engineVersion'];
    final safeEngineVersion =
        rawEngineVersion is num && rawEngineVersion.isFinite
        ? rawEngineVersion.toInt()
        : 1;
    final rawParameters = json['parameters'];
    final rawPhases = json['phases'];
    return InciensoAudioState(
      engineVersion: safeEngineVersion,
      parameters: {
        if (rawParameters is Map)
          for (final entry in rawParameters.entries)
            if (entry.key is String &&
                !_forbiddenKeys.contains(entry.key) &&
                (entry.value is bool ||
                    entry.value is String ||
                    (entry.value is num && (entry.value as num).isFinite)))
              entry.key as String: entry.value as Object,
      },
      phases: {
        if (rawPhases is Map)
          for (final entry in rawPhases.entries)
            if (entry.key is String &&
                !_forbiddenKeys.contains(entry.key) &&
                entry.value is num &&
                (entry.value as num).isFinite)
              entry.key as String: (entry.value as num).toDouble(),
      },
    );
  }
}
