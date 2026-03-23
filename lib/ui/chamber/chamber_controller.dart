import 'package:flutter/cupertino.dart';
import 'package:neom_commons/utils/app_utilities.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_commons/utils/constants/translations/common_translation_constants.dart';
import 'package:neom_commons/utils/constants/translations/message_translation_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/domain/model/app_profile.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:neom_core/domain/model/band.dart';
import 'package:neom_core/domain/model/neom/neom_chamber.dart';
import 'package:neom_core/domain/repository/chamber_repository.dart';
import 'package:neom_core/domain/use_cases/chamber_service.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:neom_core/utils/enums/owner_type.dart';
import 'package:sint/sint.dart';

import '../../data/firestore/chamber_firestore.dart';
import '../../utils/constants/generator_translation_constants.dart';

class ChamberController extends SintController implements ChamberService {

  final userServiceImpl = Sint.find<UserService>();
  final ChamberRepository chamberRepository = ChamberFirestore();

  NeomChamber currentChamber = NeomChamber();

  TextEditingController newChamberNameController = TextEditingController();
  TextEditingController newChamberDescController = TextEditingController();

  final RxMap<String, NeomChamber> chambers = <String, NeomChamber>{}.obs;
  final RxList<NeomChamber> addedChambers = <NeomChamber>[].obs;

  AppProfile profile = AppProfile();
  Band? band;
  String ownerId = '';
  String ownerName = '';
  OwnerType ownerType = OwnerType.profile;

  final RxBool isLoading = true.obs;
  final RxBool isButtonDisabled = false.obs;

  final RxBool isPublicNewChamber = true.obs;
  final RxString errorMsg = "".obs;

  RxString itemName = "".obs;
  RxInt itemNumber = 0.obs;

  // NUEVAS VARIABLES PARA BINAURALES
  TextEditingController baseFreqController = TextEditingController();
  TextEditingController binauralBeatController = TextEditingController();
  // true = Sumar (Base + Beat), false = Restar (Base - Beat)
  final RxBool isBinauralUpper = true.obs;

  // Para mostrar el resultado en tiempo real en la UI (ej: "L: 432Hz | R: 452Hz")
  final RxString binauralPreview = "".obs;

  @override
  void onInit() async {
    super.onInit();
    AppConfig.logger.t("onInit NeomChamber Controller");

    try {
      userServiceImpl.itemlistOwnerType = OwnerType.profile;
      profile = userServiceImpl.profile;
      ownerId = profile.id;
      ownerName = profile.name;

      if(Sint.arguments != null) {
        if(Sint.arguments.isNotEmpty && Sint.arguments[0] is Band) {
          band = Sint.arguments[0];
          userServiceImpl.band = band!;
        }

        if(band != null) {
          ownerId = band!.id;
          ownerName = band!.name;
          ownerType = OwnerType.band;
          userServiceImpl.itemlistOwnerType = OwnerType.band;
        }
      }

      // Listeners para actualizar la vista previa cuando el usuario escribe
      baseFreqController.addListener(_updateBinauralPreview);
      binauralBeatController.addListener(_updateBinauralPreview);

    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'onInit');
    }

  }

  @override
  void onReady() async {
    super.onReady();
    AppConfig.logger.t('Chambers being loaded from ${ownerType.name}');
    if(ownerType == OwnerType.profile) {
      chambers.value = profile.chambers ?? {};
    } else if(ownerType == OwnerType.band){
      chambers.value = band?.chambers ?? {};
    }

    if(chambers.isEmpty) {
      chambers.value = await chamberRepository.fetchAll(ownerId: ownerId);
    }
    isLoading.value = false;
    update([AppPageIdConstants.chamber]);
  }

  @override
  void onClose() {
    baseFreqController.dispose();
    binauralBeatController.dispose();
    super.onClose();
  }


  void clear() {
    chambers.value = <String, NeomChamber>{};
    currentChamber = NeomChamber();
  }

  @override
  void clearNewChamber() {
    newChamberNameController.clear();
    newChamberDescController.clear();
    // Limpiar campos binaurales
    baseFreqController.clear();
    binauralBeatController.clear();
    binauralPreview.value = "";
    isBinauralUpper.value = true;
  }


  @override
  Future<void> createChamber() async {
    AppConfig.logger.d("Start ${newChamberNameController.text} and ${newChamberDescController.text}");

    try {
      errorMsg.value = '';
      if((isPublicNewChamber.value && newChamberNameController.text.isNotEmpty && newChamberDescController.text.isNotEmpty)
          || (!isPublicNewChamber.value && newChamberNameController.text.isNotEmpty)) {
        NeomChamber newChamber = NeomChamber.createBasic(newChamberNameController.text, newChamberDescController.text);

        // --- LOGICA BINAURAL ---
        if (baseFreqController.text.isNotEmpty && binauralBeatController.text.isNotEmpty) {
          double base = double.parse(baseFreqController.text);
          double beat = double.parse(binauralBeatController.text);

          // Asumiendo que has agregado estos campos a tu modelo NeomChamber
          // Si no existen en el modelo, deberás agregarlos en domain/model/neom/chamber.dart
          newChamber.chamberPresets?.first.mainFrequency?.frequency = base;
          newChamber.chamberPresets?.first.binauralFrequency?.frequency = beat;

          // newChamber.binauralBeat = beat;
          // newChamber.isBinauralUpper = isBinauralUpper.value;

          // Opcional: Guardar la segunda frecuencia calculada directamente
          // newChamber. = isBinauralUpper.value ? (base + beat) : (base - beat);
        }

        newChamber.ownerId = ownerId;
        newChamber.ownerName = ownerName;
        newChamber.ownerType = ownerType;
        String newItemlistId = "";

        if (profile.position?.latitude != 0.0) {
          newChamber.position = profile.position!;
        }

        newChamber.public = isPublicNewChamber.value;
        newItemlistId = await chamberRepository.insert(newChamber);


        AppConfig.logger.i("Empty NeomChamber created successfully for profile ${newChamber.ownerId}");
        newChamber.id = newItemlistId;

        if(newItemlistId.isNotEmpty){
          chambers[newItemlistId] = newChamber;
          AppConfig.logger.t("Itemlists $chambers");
          clearNewChamber();
          AppUtilities.showSnackBar(
              title: GeneratorTranslationConstants.chamberPrefs.tr,
              message: GeneratorTranslationConstants.chamberCreated.tr
          );
        } else {
          AppConfig.logger.d("Something happens trying to insert chamber");
        }
      } else {
        AppConfig.logger.d(MessageTranslationConstants.pleaseFillItemlistInfo.tr);
        errorMsg.value = newChamberNameController.text.isEmpty ? MessageTranslationConstants.pleaseAddName
            : MessageTranslationConstants.pleaseAddDescription;

        AppUtilities.showSnackBar(
          title: CommonTranslationConstants.addNewItemlist.tr,
          message: MessageTranslationConstants.pleaseFillItemlistInfo.tr,
        );
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'createChamber');
    }

    update([AppPageIdConstants.chamber]);
  }

  @override
  Future<void> deleteChamber(NeomChamber chamber) async {
    AppConfig.logger.d("Removing for $chamber");

    try {
      isLoading.value = true;
      update([AppPageIdConstants.itemlist]);

      if(await chamberRepository.delete(chamber.id)) {
        AppConfig.logger.d("NeomChamber ${chamber.id} removed");

        chambers.remove(chamber.id);
        AppUtilities.showSnackBar(
          title: CommonTranslationConstants.itemlistPrefs.tr,
          message: CommonTranslationConstants.itemlistRemoved.tr
        );
      } else {
        AppUtilities.showSnackBar(
            title: CommonTranslationConstants.itemlistPrefs.tr,
            message: MessageTranslationConstants.itemlistRemovedErrorMsg.tr
        );
        AppConfig.logger.e("Something happens trying to remove itemlist");
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'deleteChamber');
    }

    isLoading.value = false;
    update([AppPageIdConstants.chamber]);
  }


  @override
  Future<void> updateChamber(String itemlistId, NeomChamber itemlist) async {

    AppConfig.logger.d("Updating to $itemlist");

    try {
      isLoading.value = true;
      update([AppPageIdConstants.itemlist]);
      String newName = newChamberNameController.text;
      String newDesc = newChamberDescController.text;

      if((newName.isNotEmpty && newName.toLowerCase() != itemlist.name.toLowerCase())
          || (newDesc.isNotEmpty && newDesc.toLowerCase() != itemlist.description.toLowerCase())) {

        if(newChamberNameController.text.isNotEmpty) {
          itemlist.name = newChamberNameController.text;
        }

        if(newChamberDescController.text.isNotEmpty) {
          itemlist.description = newChamberDescController.text;
        }

        if(await chamberRepository.update(itemlist)){
          AppConfig.logger.d("NeomChamber $itemlistId updated");
          chambers[itemlist.id] = itemlist;
          clearNewChamber();
          AppUtilities.showSnackBar(
              title: CommonTranslationConstants.itemlistPrefs.tr,
              message: CommonTranslationConstants.itemlistUpdated.tr
          );
        } else {
          AppConfig.logger.i("Something happens trying to update itemlist");
          AppUtilities.showSnackBar(
              title: CommonTranslationConstants.itemlistPrefs.tr,
              message: MessageTranslationConstants.itemlistUpdatedErrorMsg.tr
          );
        }
      } else {
        AppUtilities.showSnackBar(
            title: CommonTranslationConstants.itemlistPrefs.tr,
            message: CommonTranslationConstants.itemlistUpdateSameInfo.tr
        );
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'updateChamber');
      AppUtilities.showSnackBar(
          title: CommonTranslationConstants.itemlistPrefs.tr,
          message: MessageTranslationConstants.itemlistUpdatedErrorMsg.tr
      );
    }


    isLoading.value = false;
    update([AppPageIdConstants.chamber]);
  }

  @override
  Future<void> gotoChamberPresets(NeomChamber chamber) async {
    await Sint.toNamed(AppRouteConstants.chamberPresets, arguments: [chamber]);
    update([AppPageIdConstants.chamber]);
  }

  @override
  Future<void> setPrivacyOption() async {
    AppConfig.logger.t('setPrivacyOption for Playlist');
    isPublicNewChamber.value = !isPublicNewChamber.value;
    AppConfig.logger.d("New Itemlist would be ${isPublicNewChamber.value ? 'Public':'Private'}");
    update([AppPageIdConstants.chamber, AppPageIdConstants.chamberPresets]);
  }

  void _updateBinauralPreview() {
    double base = double.tryParse(baseFreqController.text) ?? 0;
    double beat = double.tryParse(binauralBeatController.text) ?? 0;

    if (base > 0 && beat > 0) {
      double secondFreq = isBinauralUpper.value ? (base + beat) : (base - beat);
      binauralPreview.value = "F1: ${base.toStringAsFixed(2)} Hz | F2: ${secondFreq.toStringAsFixed(2)} Hz";
    } else {
      binauralPreview.value = "";
    }
  }

  void toggleBinauralDirection(bool? value) {
    if(value != null) {
      isBinauralUpper.value = value;
      _updateBinauralPreview();
    }
  }


}
