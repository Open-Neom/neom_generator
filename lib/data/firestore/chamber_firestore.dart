import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_collection_constants.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_constants.dart';
import 'package:neom_core/domain/model/neom/neom_chamber.dart';
import 'package:neom_core/domain/model/neom/neom_chamber_preset.dart';
import 'package:neom_core/domain/repository/chamber_repository.dart';
import 'package:neom_core/utils/constants/core_constants.dart';
import 'package:neom_core/utils/enums/owner_type.dart';
import 'package:neom_core/utils/neom_error_logger.dart';

class ChamberFirestore implements ChamberRepository {
  final FirebaseFirestore? _firestoreOverride;

  ChamberFirestore({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  FirebaseFirestore get _fs => _firestoreOverride ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get chamberReference =>
      _fs.collection(AppFirestoreCollectionConstants.chambers);
  Query<Map<String, dynamic>> get profileReference =>
      _fs.collectionGroup(AppFirestoreCollectionConstants.profiles);

  static const Set<String> _forbiddenKeys = <String>{
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
  static final RegExp _gemmaThoughtOrPromptBlocks = RegExp(
    r'<\|(?:channel|turn)>thought[\s\S]*?(?:<(?:channel|turn)\|>|$)'
    r'|<(?:think|thought|memory_recall|auto_memory|system_context)\b[^>]*>[\s\S]*?(?:</(?:think|thought|memory_recall|auto_memory|system_context)>|$)'
    r'|</?(?:think|thought|memory_recall|auto_memory|system_context)\b[^>]*>'
    r'|<(?:channel|turn)\|>'
    r'|\[(?:BIOCHIP|MEMORY_RECALL|AUTO_MEMORY|SYSTEM_CONTEXT)\b[^\]]*\][\s\S]*?(?:\[/(?:BIOCHIP|MEMORY_RECALL|AUTO_MEMORY|SYSTEM_CONTEXT)\]|$)',
    caseSensitive: false,
  );
  static final RegExp _contentBreakoutCloseTag = RegExp(
    r'<\s*/\s*content\s*>',
    caseSensitive: false,
  );
  static final Object _dropSentinel = Object();

  static bool isValidChamberId(String id) {
    if (id.isEmpty || id.length > 128) return false;
    if (_controlOrBidiPattern.hasMatch(id)) return false;
    if (id.trim() != id) return false;
    if (id == '.' ||
        id == '..' ||
        id.contains('/') ||
        id.contains(r'\') ||
        _encodedTraversalPattern.hasMatch(id)) {
      return false;
    }
    if (_forbiddenKeys.contains(id.toLowerCase()) ||
        (id.startsWith('__') && id.endsWith('__'))) {
      return false;
    }
    return true;
  }

  static bool _isValidId(String id) => isValidChamberId(id);

  static String _sanitizeText(String raw, {int maxChars = 160}) {
    if (!maxChars.toDouble().isFinite || maxChars <= 0) return '';
    final cleaned = raw
        .replaceAll(_gemmaThoughtOrPromptBlocks, '')
        .replaceAll(_contentBreakoutCloseTag, '[content_end]')
        .replaceAll(_controlOrBidiPattern, '')
        .trim();
    if (cleaned.length <= maxChars) return cleaned;
    var cut = maxChars;
    final lastUnit = cleaned.codeUnitAt(cut - 1);
    if (lastUnit >= 0xD800 && lastUnit <= 0xDBFF) {
      cut -= 1;
    }
    return cut <= 0 ? '' : cleaned.substring(0, cut).trimRight();
  }

  static bool _isForbiddenFieldKey(String key) =>
      key.isEmpty ||
      key.length > 128 ||
      _controlOrBidiPattern.hasMatch(key) ||
      _forbiddenKeys.contains(key.toLowerCase()) ||
      (key.startsWith('__') && key.endsWith('__'));

  static Map<String, dynamic> _sanitizeMap(Map<String, dynamic> raw) {
    final sanitized = _sanitizeValue(raw, depth: 0, active: <int>{});
    return sanitized is Map<String, dynamic> ? sanitized : <String, dynamic>{};
  }

  static Object? _sanitizeValue(
    Object? value, {
    required int depth,
    required Set<int> active,
  }) {
    if (value == null) return null;
    if (value is num) {
      return value.toDouble().isFinite ? value : _dropSentinel;
    }
    if (value is Map) {
      if (depth > 16) return const <String, dynamic>{};
      final id = identityHashCode(value);
      if (!active.add(id)) return const <String, dynamic>{};
      try {
        final nested = <String, dynamic>{};
        for (final entry in value.entries) {
          if (entry.key is! String) continue;
          final key = (entry.key as String).trim();
          if (_isForbiddenFieldKey(key)) continue;
          final sanitized = _sanitizeValue(
            entry.value,
            depth: depth + 1,
            active: active,
          );
          if (identical(sanitized, _dropSentinel)) continue;
          nested[key] = sanitized;
        }
        return nested;
      } finally {
        active.remove(id);
      }
    }
    if (value is List) {
      if (depth > 16) return const <dynamic>[];
      final id = identityHashCode(value);
      if (!active.add(id)) return const <dynamic>[];
      try {
        final out = <dynamic>[];
        for (final item in value) {
          final sanitized = _sanitizeValue(
            item,
            depth: depth + 1,
            active: active,
          );
          if (identical(sanitized, _dropSentinel)) continue;
          out.add(sanitized);
        }
        return out;
      } finally {
        active.remove(id);
      }
    }
    return value;
  }

  @override
  Future<String> insert(NeomChamber chamber) async {
    AppConfig.logger.d("Creating chamber for Profile ${chamber.ownerId}");
    String chamberId = "";

    try {
      final payload = _sanitizeMap(chamber.toJSON());
      if (chamber.id.isEmpty) {
        DocumentReference? documentReference = await chamberReference
            .add(payload);
        chamberId = documentReference.id;
      } else {
        if (!_isValidId(chamber.id)) return "";
        await chamberReference.doc(chamber.id).set(payload);
        chamberId = chamber.id;
      }

      AppConfig.logger.d("Public NeomChamber $chamberId inserted");
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'insert');
    }

    return chamberId;
  }

  @override
  Future<NeomChamber> retrieve(String chamberId) async {
    AppConfig.logger.t("Retrieving NeomChamber by ID: $chamberId");
    NeomChamber chamber = NeomChamber();
    if (!_isValidId(chamberId)) return chamber;

    try {
      DocumentSnapshot documentSnapshot = await chamberReference.doc(chamberId).get();
      if (documentSnapshot.exists) {
        AppConfig.logger.t("Snapshot is not empty");
        chamber = NeomChamber.fromJSON(documentSnapshot.data());
        chamber.id = documentSnapshot.id;
        AppConfig.logger.t(chamber.toString());
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'retrieve');
    }


    return chamber;
  }

  @override
  Future<Map<String, NeomChamber>> fetchAll({bool onlyPublic = false, bool excludeMyFavorites = true, int minItems = 0,
    int maxLength = 100, String ownerId = '', String excludeFromProfileId = '', OwnerType ownerType = OwnerType.profile}) async {
    AppConfig.logger.t("Retrieving Chambers from firestore");
    Map<String, NeomChamber> chambers = {};
    final int safeLimit = (maxLength.toDouble().isFinite && maxLength > 0)
        ? maxLength.clamp(1, 500)
        : 100;

    try {
      await chamberReference.limit(safeLimit).get().then((querySnapshot) {
        for (var document in querySnapshot.docs) {
          NeomChamber chamber = NeomChamber.fromJSON(document.data());
          chamber.id = document.id;
          if((chamber.chamberPresets?.length ?? 0) >= minItems && (!onlyPublic || chamber.public)
              && (!excludeMyFavorites || chamber.id != CoreConstants.myFavorites)
              && (ownerId.isEmpty || chamber.ownerId == ownerId)
              && (excludeFromProfileId.isEmpty || chamber.ownerId != excludeFromProfileId)
              && (chamber.ownerType == ownerType)
          ) {
            chambers[chamber.id] = chamber;
          }
        }
      });
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'fetchAll');
    }

    AppConfig.logger.d("${chambers .length} chambers found in total.");
    return chambers;
  }


  @override
  Future<bool> delete(chamberId) async {
    if (!_isValidId(chamberId)) return false;
    AppConfig.logger.d("Removing public chamber $chamberId");
    try {

      await chamberReference.doc(chamberId).delete();
      AppConfig.logger.d("NeomChamber $chamberId removed");
      return true;

    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'delete');
      return false;
    }
  }

  @override
  Future<bool> update(NeomChamber chamber) async {
    if (!_isValidId(chamber.id)) return false;
    AppConfig.logger.d("Updating NeomChamber for user ${chamber.id}");

    try {

      DocumentReference documentReference = chamberReference.doc(chamber.id);
      await documentReference.update({
        AppFirestoreConstants.name: _sanitizeText(chamber.name, maxChars: 160),
        AppFirestoreConstants.description: _sanitizeText(chamber.description, maxChars: 2000),
      });

      AppConfig.logger.d("NeomChamber ${chamber.id} was updated");
      return true;
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'update');
    }

    AppConfig.logger.d("NeomChamber ${chamber.id} was not updated");
    return false;
  }

  @override
  Future<bool> addPreset(String chamberId, NeomChamberPreset preset) async {
    if (!_isValidId(chamberId)) return false;
    AppConfig.logger.d("Adding preset to chamber $chamberId");
    bool addedItem = false;

    try {
      DocumentReference documentReference = chamberReference.doc(chamberId);
      await documentReference.update({
        AppFirestoreConstants.chamberPresets: FieldValue.arrayUnion([_sanitizeMap(preset.toJSON())])
      });
      addedItem = true;
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'addPreset');
    }

    addedItem ? AppConfig.logger.d("Preset was added to chamber $chamberId") :
    AppConfig.logger.d("Preset was not added to chamber $chamberId");
    return addedItem;
  }


  @override
  Future<bool> deletePreset(String chamberId, NeomChamberPreset preset) async {
    if (!_isValidId(chamberId)) return false;
    AppConfig.logger.d("Removing preset from chamber $chamberId");

    try {
      DocumentReference documentReference = chamberReference.doc(chamberId);
      await documentReference.update({
        AppFirestoreConstants.chamberPresets: FieldValue.arrayRemove([_sanitizeMap(preset.toJSON())])
      });


      AppConfig.logger.d("Preset was removed from chamber $chamberId");
      return true;
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'deletePreset');
    }

    AppConfig.logger.d("Preset was not  removed from chamber $chamberId");
    return false;
  }

  @override
  Future<bool> updatePreset(String chamberId, NeomChamberPreset preset) async {
    if (!_isValidId(chamberId)) return false;
    AppConfig.logger.d("Updating preset for profile $chamberId");

    try {
      final DocumentReference<Map<String, dynamic>> documentReference =
          chamberReference.doc(chamberId);
      final sanitizedPreset = _sanitizeMap(preset.toJSON());
      final targetId = _sanitizeText(preset.id);
      final targetName = _sanitizeText(preset.name);

      final updated = await _fs.runTransaction<bool>((transaction) async {
        final snapshot = await transaction.get(documentReference);
        if (!snapshot.exists) return false;

        final data = snapshot.data();
        final rawPresets = data?[AppFirestoreConstants.chamberPresets];
        final updatedPresets = <Map<String, dynamic>>[];
        var replaced = false;

        if (rawPresets is List) {
          for (final entry in rawPresets) {
            if (entry is! Map) continue;
            final map = Map<String, dynamic>.from(entry);
            final entryId = _sanitizeText(map['id']?.toString() ?? '');
            final entryName = _sanitizeText(map['name']?.toString() ?? '');
            final isMatch = targetId.isNotEmpty
                ? entryId == targetId
                : (targetName.isNotEmpty && entryName == targetName);
            if (isMatch) {
              if (!replaced) {
                updatedPresets.add(sanitizedPreset);
                replaced = true;
              }
            } else {
              updatedPresets.add(_sanitizeMap(map));
            }
          }
        }

        if (!replaced) {
          updatedPresets.add(sanitizedPreset);
        }

        transaction.update(documentReference, {
          AppFirestoreConstants.chamberPresets: updatedPresets,
        });
        return true;
      });

      if (updated) {
        AppConfig.logger.d("Preset ${preset.name} was updated to ${preset.state}");
        return true;
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'updatePreset');
    }

    AppConfig.logger.d("Preset ${preset.name} was not updated");
    return false;
  }

}
