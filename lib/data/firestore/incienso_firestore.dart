import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/firestore/constants/app_firestore_collection_constants.dart';
import 'package:neom_core/utils/neom_error_logger.dart';

import '../../domain/models/incienso.dart';

class InciensoFirestore {
  final CollectionReference _inciensoReference =
      FirebaseFirestore.instance.collection(AppFirestoreCollectionConstants.inciensos);

  /// Insert or update an Incienso preset in Firestore.
  Future<String> insert(Incienso incienso) async {
    AppConfig.logger.d("Saving Incienso ${incienso.id} to Firestore");
    String id = incienso.id;

    try {
      if (id.isEmpty) {
        final docRef = await _inciensoReference.add(incienso.toJson());
        id = docRef.id;
      } else {
        await _inciensoReference.doc(id).set(incienso.toJson(), SetOptions(merge: true));
      }
      AppConfig.logger.d("Incienso $id saved successfully");
    } catch (e, st) {
      NeomErrorLogger.recordError(
        e,
        st,
        module: 'neom_generator',
        operation: 'InciensoFirestore.insert',
      );
    }

    return id;
  }

  /// Retrieve a specific Incienso by ID.
  Future<Incienso?> retrieve(String inciensoId) async {
    AppConfig.logger.t("Retrieving Incienso: $inciensoId");
    try {
      final doc = await _inciensoReference.doc(inciensoId).get();
      if (doc.exists && doc.data() != null) {
        final data = doc.data() as Map<String, dynamic>;
        // Ensure the ID matches the document ID in Firestore if it was auto-assigned
        if (data['id'] == null || (data['id'] as String).isEmpty) {
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

    try {
      // Fetch only those created by users or shared (source != predefined / protocol)
      // or simply fetch all that have creatorId != null and are public.
      // For general purposes, we fetch everything in 'inciensos' collection sorted by popularity.
      final querySnapshot = await _inciensoReference
          .orderBy('practiceCount', descending: true)
          .limit(limit)
          .get();

      for (final doc in querySnapshot.docs) {
        if (doc.data() != null) {
          final data = doc.data() as Map<String, dynamic>;
          if (data['id'] == null || (data['id'] as String).isEmpty) {
            data['id'] = doc.id;
          }
          list.add(Incienso.fromJson(data));
        }
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

  /// Atomically increment the practice count of an Incienso preset.
  Future<void> incrementPracticeCount(String inciensoId) async {
    AppConfig.logger.d("Incrementing practice count for Incienso: $inciensoId");
    try {
      await _inciensoReference.doc(inciensoId).update({
        'practiceCount': FieldValue.increment(1),
      });
      AppConfig.logger.t("Practice count incremented for Incienso: $inciensoId");
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
