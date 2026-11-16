import 'dart:async';
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_collection_constants.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:sint/sint.dart';

import '../../domain/models/incienso.dart';
import '../../domain/models/incienso_review.dart';

class InciensoFirestore {
  final FirebaseFirestore? _firestoreOverride;

  InciensoFirestore({FirebaseFirestore? firestore})
      : _firestoreOverride = firestore;

  CollectionReference<Map<String, dynamic>> get _inciensoReference =>
      (_firestoreOverride ?? FirebaseFirestore.instance)
          .collection(AppFirestoreCollectionConstants.inciensos);

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
  static final Object _dropSentinel = Object();

  static bool isValidInciensoId(String id) {
    if (id.isEmpty || id.length > 240) return false;
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

  static bool _isValidId(String id) => isValidInciensoId(id);

  static bool _isForbiddenFieldKey(String key) =>
      key.isEmpty ||
      key.length > 128 ||
      _controlOrBidiPattern.hasMatch(key) ||
      _forbiddenKeys.contains(key.toLowerCase()) ||
      (key.startsWith('__') && key.endsWith('__'));

  static Map<String, dynamic> _sanitizePayload(Map<String, dynamic> raw) {
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

  String _resolveCallerProfileId(String? callerCreatorId) {
    if (callerCreatorId != null && callerCreatorId.trim().isNotEmpty) {
      final candidate = callerCreatorId.trim();
      return _isValidId(candidate) ? candidate : '';
    }
    if (Sint.isRegistered<UserService>()) {
      try {
        final profileId = Sint.find<UserService>().profile.id.trim();
        if (_isValidId(profileId)) return profileId;
      } catch (_) {}
    }
    return '';
  }

  /// Insert or update an Incienso preset in Firestore.
  Future<String> insert(Incienso incienso) async {
    AppConfig.logger.d("Saving Incienso ${incienso.id} to Firestore");
    String id = incienso.id;
    if (id.isNotEmpty && !_isValidId(id)) return '';

    try {
      final data = _sanitizePayload(incienso.toJson());
      // Conservative application budget leaves room for Firestore field/path
      // overhead. Oversized sessions remain available in the local draft store.
      if (utf8.encode(jsonEncode(data)).length > 900 * 1024) {
        throw StateError('Incienso exceeds the single-document upload budget');
      }
      if (id.isEmpty) {
        final docRef = await _inciensoReference.add(data);
        id = docRef.id;
      } else {
        final existing = await _inciensoReference.doc(id).get();
        if (existing.exists && existing.data() != null) {
          final existingCreator =
              (existing.data()!['creatorId'] as String?)?.trim() ?? '';
          final incomingCreator = (incienso.creatorId ?? '').trim();
          if (existingCreator.isNotEmpty &&
              existingCreator != incomingCreator) {
            throw StateError(
              'Refusing to overwrite Incienso $id owned by another creator',
            );
          }
        }
        await _inciensoReference.doc(id).set(data, SetOptions(merge: true));
      }
      AppConfig.logger.d("Incienso $id saved successfully");
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'InciensoFirestore.insert',
      );
      return ''; // An existing ID is not evidence that persistence succeeded.
    }

    return id;
  }

  /// Retrieve a specific Incienso by ID.
  Future<Incienso?> retrieve(String inciensoId) async {
    if (!_isValidId(inciensoId)) return null;
    AppConfig.logger.t("Retrieving Incienso: $inciensoId");
    try {
      final doc = await _inciensoReference.doc(inciensoId).get();
      if (doc.exists && doc.data() != null) {
        final data = Map<String, dynamic>.from(doc.data()!);
        // Ensure the ID matches the document ID in Firestore if it was auto-assigned
        if (data['id'] is! String || (data['id'] as String).isEmpty) {
          data['id'] = doc.id;
        }
        return Incienso.fromJson(data);
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'InciensoFirestore.retrieve',
      );
    }
    return null;
  }

  /// Fetch all public Inciensos from the community, ordered by practiceCount descending.
  Future<List<Incienso>> fetchPublic({int limit = 50}) async {
    AppConfig.logger.t("Fetching public Inciensos from Firestore");
    final List<Incienso> list = [];
    final safeLimit = (limit.toDouble().isFinite && limit > 0)
        ? limit.clamp(1, 200)
        : 50;

    try {
      // Only what its creator chose to share. This used to read the whole
      // collection, which would have exposed every recorded session the moment
      // publishing was wired up.
      final querySnapshot = await _inciensoReference
          .where('isPublic', isEqualTo: true)
          .orderBy('practiceCount', descending: true)
          .limit(safeLimit)
          .get();

      for (final doc in querySnapshot.docs) {
        final raw = doc.data();
        final data = Map<String, dynamic>.from(raw);
        if (data['id'] is! String || (data['id'] as String).isEmpty) {
          data['id'] = doc.id;
        }
        list.add(Incienso.fromJson(data));
      }
      AppConfig.logger.d("${list.length} public Inciensos loaded");
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'InciensoFirestore.fetchPublic',
      );
    }

    return list;
  }

  /// Stores how a session felt, under the incienso it was practised with.
  ///
  /// Kept as a subcollection so a preset carries its own feedback: the explore
  /// list can show how others experienced it without a second query per card.
  Future<String> insertReview(InciensoReview review) async {
    final inciensoId = review.inciensoId;
    if (inciensoId == null || !_isValidId(inciensoId)) return '';

    try {
      final doc = await _inciensoReference
          .doc(inciensoId)
          .collection(AppFirestoreCollectionConstants.reviews)
          .add(_sanitizePayload(review.toJson()));
      AppConfig.logger.d("Incienso review stored: ${doc.id}");
      return doc.id;
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'InciensoFirestore.insertReview',
      );
    }
    return '';
  }

  /// Every session recorded by [creatorId], shared or not, newest first.
  Future<List<Incienso>> fetchByCreator(
    String creatorId, {
    int limit = 50,
  }) async {
    if (!_isValidId(creatorId)) return [];
    final List<Incienso> list = [];
    final safeLimit = (limit.toDouble().isFinite && limit > 0)
        ? limit.clamp(1, 200)
        : 50;

    try {
      final querySnapshot = await _inciensoReference
          .where('creatorId', isEqualTo: creatorId)
          .limit(safeLimit)
          .get();

      for (final doc in querySnapshot.docs) {
        final data = Map<String, dynamic>.from(doc.data());
        if (data['id'] is! String || (data['id'] as String).isEmpty) {
          data['id'] = doc.id;
        }
        list.add(Incienso.fromJson(data));
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'InciensoFirestore.fetchByCreator',
      );
    }

    return list;
  }

  /// Shares or unshares a session. Only its creator may change this.
  Future<bool> setPublic(
    String inciensoId,
    bool isPublic, {
    String? callerCreatorId,
  }) async {
    if (!_isValidId(inciensoId)) return false;
    final caller = _resolveCallerProfileId(callerCreatorId);
    if (!_isValidId(caller)) return false;
    try {
      final snap = await _inciensoReference.doc(inciensoId).get();
      if (!snap.exists || snap.data() == null) return false;
      final existingCreator =
          (snap.data()!['creatorId'] as String?)?.trim() ?? '';
      if (existingCreator.isEmpty || existingCreator != caller) {
        AppConfig.logger.w(
          'Refusing unauthorized setPublic on Incienso $inciensoId by $caller',
        );
        return false;
      }
      await _inciensoReference.doc(inciensoId).update({'isPublic': isPublic});
      return true;
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'InciensoFirestore.setPublic',
      );
      return false;
    }
  }

  /// Atomically increment the practice count of an Incienso preset.
  Future<void> incrementPracticeCount(String inciensoId) async {
    if (!_isValidId(inciensoId)) return;
    AppConfig.logger.d("Incrementing practice count for Incienso: $inciensoId");
    try {
      await _inciensoReference.doc(inciensoId).update({
        'practiceCount': FieldValue.increment(1),
      });
      AppConfig.logger.t(
        "Practice count incremented for Incienso: $inciensoId",
      );
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'InciensoFirestore.incrementPracticeCount',
      );
    }
  }
}
