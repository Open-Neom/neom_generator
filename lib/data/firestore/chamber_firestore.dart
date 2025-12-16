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

class ChamberFirestore implements ChamberRepository {
  
  final chamberReference = FirebaseFirestore.instance.collection(AppFirestoreCollectionConstants.chambers);
  final profileReference = FirebaseFirestore.instance.collectionGroup(AppFirestoreCollectionConstants.profiles);

  @override
  Future<String> insert(NeomChamber chamber) async {
    AppConfig.logger.d("Creating chamber for Profile ${chamber.ownerId}");
    String chamberId = "";

    try {
      if(chamber.id.isEmpty) {
        DocumentReference? documentReference = await chamberReference
            .add(chamber.toJSON());
        chamberId = documentReference.id;
      } else {
        await chamberReference.doc(chamber.id).set(chamber.toJSON());
        chamberId = chamber.id;
      }

      AppConfig.logger.d("Public NeomChamber $chamberId inserted");
    } catch (e) {
      AppConfig.logger.e(e.toString());
    }

    return chamberId;
  }

  @override
  Future<NeomChamber> retrieve(String chamberId) async {
    AppConfig.logger.t("Retrieving NeomChamber by ID: $chamberId");
    NeomChamber chamber = NeomChamber();

    try {
      DocumentSnapshot documentSnapshot = await chamberReference.doc(chamberId).get();
      if (documentSnapshot.exists) {
        AppConfig.logger.t("Snapshot is not empty");
        chamber = NeomChamber.fromJSON(documentSnapshot.data());
        chamber.id = documentSnapshot.id;
        AppConfig.logger.t(chamber.toString());
      }
    } catch (e) {
      AppConfig.logger.e(e.toString());
    }


    return chamber;
  }

  @override
  Future<Map<String, NeomChamber>> fetchAll({bool onlyPublic = false, bool excludeMyFavorites = true, int minItems = 0,
    int maxLength = 100, String ownerId = '', String excludeFromProfileId = '', OwnerType ownerType = OwnerType.profile}) async {
    AppConfig.logger.t("Retrieving Chambers from firestore");
    Map<String, NeomChamber> chambers = {};

    try {
      await chamberReference.limit(maxLength).get().then((querySnapshot) {
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
    } catch (e) {
      AppConfig.logger.e(e.toString());
    }

    AppConfig.logger.d("${chambers .length} chambers found in total.");
    return chambers;
  }


  @override
  Future<bool> delete(chamberId) async {
    AppConfig.logger.d("Removing public chamber $chamberId");
    try {

      await chamberReference.doc(chamberId).delete();
      AppConfig.logger.d("NeomChamber $chamberId removed");
      return true;

    } catch (e) {
      AppConfig.logger.e(e.toString());
      return false;
    }
  }

  @override
  Future<bool> update(NeomChamber chamber) async {
    AppConfig.logger.d("Updating NeomChamber for user ${chamber.id}");

    try {

      DocumentReference documentReference = chamberReference.doc(chamber.id);
      await documentReference.update({
        AppFirestoreConstants.name: chamber.name,
        AppFirestoreConstants.description: chamber.description,
      });

      AppConfig.logger.d("NeomChamber ${chamber.id} was updated");
      return true;
    } catch (e) {
      AppConfig.logger.e(e.toString());
    }

    AppConfig.logger.d("NeomChamber ${chamber.id} was not updated");
    return false;
  }

  @override
  Future<bool> addPreset(String chamberId, NeomChamberPreset preset) async {
    AppConfig.logger.d("Adding preset to chamber $chamberId");
    bool addedItem = false;

    try {
      DocumentReference documentReference = chamberReference.doc(chamberId);
      await documentReference.update({
        AppFirestoreConstants.chamberPresets: FieldValue.arrayUnion([preset.toJSON()])
      });
      addedItem = true;
    } catch (e) {
      AppConfig.logger.e(e.toString());
    }

    addedItem ? AppConfig.logger.d("Preset was added to chamber $chamberId") :
    AppConfig.logger.d("Preset was not added to chamber $chamberId");
    return addedItem;
  }


  @override
  Future<bool> deletePreset(String chamberId, NeomChamberPreset preset) async {
    AppConfig.logger.d("Removing preset from chamber $chamberId");

    try {
      DocumentReference documentReference = chamberReference.doc(chamberId);
      await documentReference.update({
        AppFirestoreConstants.chamberPresets: FieldValue.arrayRemove([preset.toJSON()])
      });


      AppConfig.logger.d("Preset was removed from chamber $chamberId");
      return true;
    } catch (e) {
      AppConfig.logger.e(e.toString());
    }

    AppConfig.logger.d("Preset was not  removed from chamber $chamberId");
    return false;
  }

  @override
  Future<bool> updatePreset(String chamberId, NeomChamberPreset preset) async {
    AppConfig.logger.d("Updating preset for profile $chamberId");

    try {
      DocumentReference documentReference = chamberReference.doc(chamberId);
      await documentReference.update({
        AppFirestoreConstants.chamberPresets: FieldValue.arrayUnion([preset.toJSON()])
      });

      AppConfig.logger.d("Preset ${preset.name} was updated to ${preset.state}");
      return true;
    } catch (e) {
      AppConfig.logger.e(e.toString());
    }

    AppConfig.logger.d("Preset ${preset.name} was not updated");
    return false;
  }

}
