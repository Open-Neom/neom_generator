import 'package:neom_commons/app_flavour.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/api_services/push_notification/firebase_messaging_calls.dart';
import 'package:neom_core/domain/model/band.dart';
import 'package:neom_core/domain/model/neom/neom_chamber.dart';
import 'package:neom_core/domain/model/neom/neom_chamber_preset.dart';
import 'package:neom_core/domain/repository/chamber_repository.dart';
import 'package:neom_core/domain/use_cases/user_service.dart';
import 'package:neom_core/utils/enums/app_in_use.dart';
import 'package:neom_core/utils/enums/chamber_preset_state.dart';
import 'package:neom_core/utils/enums/owner_type.dart';
import 'package:neom_core/utils/enums/push_notification_type.dart';
import 'package:neom_core/utils/neom_error_logger.dart';
import 'package:sint/sint.dart';

import '../../data/firestore/chamber_firestore.dart';
import '../../domain/use_cases/chamber_preset_service.dart';
import '../../utils/constants/generator_translation_constants.dart';

class ChamberPresetController extends SintController implements ChamberPresetService {

  final userServiceImpl = Sint.find<UserService>();
  final ChamberRepository chamberRepository = ChamberFirestore();

  NeomChamberPreset chamberPreset = NeomChamberPreset();
  NeomChamber chamber = NeomChamber();

  final RxInt itemState = 0.obs;
  final RxMap<String, NeomChamberPreset> chamberPresets = <String, NeomChamberPreset>{}.obs;
  final RxBool isLoading = true.obs;

  bool isFixed = false;

  String profileId = "";
  String chamberId = "";
  Band band = Band();
  int _prevItemState = 0;
  OwnerType chamberOwner = OwnerType.profile;


  @override
  void onInit() async {
    super.onInit();
    AppConfig.logger.d("ItemlistItem Controller init");
    try {
      profileId = userServiceImpl.profile.id;
      band = userServiceImpl.band;
      chamberOwner = userServiceImpl.itemlistOwnerType;

      if(Sint.arguments != null) {
        List<dynamic> arguments = Sint.arguments;
        if(arguments[0] is NeomChamber) {
          chamber =  arguments[0];
        } else if(arguments[0] is String) {
          chamberId = arguments[0];
          chamber = await chamberRepository.retrieve(chamberId);
        }

        if(arguments.length > 1) {
          isFixed = arguments[1];
        }
      }

      if(chamber.id.isNotEmpty) {
        AppConfig.logger.i("AppMediaItemController for NeomChamber: ${chamber.id} ${chamber.name} ");
        AppConfig.logger.d("${chamber.chamberPresets?.length ?? 0} presets in chamber");
        loadPresetsFromChamber();
      } else {
        AppConfig.logger.i("ChamberPresetController Init ready loco with no chamber");
      }

      if(AppConfig.instance.appInUse == AppInUse.c) {
        isFixed = true;
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'onInit');
    }

  }


  @override
  void onReady() {
    super.onReady();
    isLoading.value = false;
    update([AppPageIdConstants.chamberPresets]);
  }

  void clear() {
    chamberPresets.value = <String, NeomChamberPreset>{};
  }

  @override
  Future<void> updateChamberPreset(NeomChamberPreset updatedPreset) async {
    AppConfig.logger.d("Preview state ${updatedPreset.state}");
    if(updatedPreset.state == itemState.value) {
      AppConfig.logger.d("Trying to set same status");
    } else {
      _prevItemState = updatedPreset.state;
      updatedPreset.state = itemState.value;
      AppConfig.logger.d("updating itemlistItem ${updatedPreset.toString()}");
      try {

        if (await chamberRepository.updatePreset(chamber.id, updatedPreset)) {
          chamberPresets.update(updatedPreset.id, (preset) => preset);
          userServiceImpl.profile.chambers![chamber.id]!
              .chamberPresets!.add(updatedPreset);
          updatedPreset.state = _prevItemState;
          userServiceImpl.profile.chambers![chamber.id]!
              .chamberPresets!.remove(updatedPreset);
          if(await chamberRepository.deletePreset(chamber.id, updatedPreset)) {
            AppConfig.logger.d("NeomChamberPreset was updated and old version deleted.");
          } else {
            AppConfig.logger.d("NeomChamberPreset was updated but old version remains.");
          }
          updatedPreset.state = itemState.value;
        } else {
          AppConfig.logger.e("NeomChamberPreset not updated");
        }
      } catch (e, st) {
        NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'updateChamberPreset');
      }

      Sint.back();
      update([AppPageIdConstants.chamberPresets]);
    }
  }

  @override
  Future<bool> addPresetToChamber(NeomChamberPreset chamberPreset, String chamberId) async {

    AppConfig.logger.d("Item ${chamberPreset.name} would be added as $itemState for Itemlist $chamberId");

    try {
      if(await chamberRepository.addPreset(chamberId, chamberPreset)) {
        if (chamberOwner == OwnerType.profile) {
          if (userServiceImpl.profile.itemlists!.isNotEmpty) {
            AppConfig.logger.d("Adding item to global itemlist from userController");
            userServiceImpl.profile.chambers![chamberId]!.chamberPresets!.add(chamberPreset);
            chamber = userServiceImpl.profile.chambers![chamberId]!;
            loadPresetsFromChamber();
          }

          FirebaseMessagingCalls.sendPublicPushNotification(
              fromProfile: userServiceImpl.profile,
              notificationType: PushNotificationType.chamberPresetAdded,
              toProfileId: '',
              title: GeneratorTranslationConstants.chamberPresetAdded,
              referenceId: chamberPreset.id,
              imgUrl: chamberPreset.imgUrl
          );

          return true;
        } else if (chamberOwner == OwnerType.band) {
          if (userServiceImpl.band.itemlists!.isNotEmpty) {
            AppConfig.logger.d("Adding item to global itemlist from userController");
            userServiceImpl.band.chambers![chamberId]!.chamberPresets!.add(chamberPreset);
            chamber = userServiceImpl.band.chambers![chamberId]!;
            loadPresetsFromChamber();
          }
          return true;
        }
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'addPresetToChamber');
    }

    update([AppPageIdConstants.chamberPresets, AppPageIdConstants.chamber, AppPageIdConstants.chamberPresetDetails]);
    return false;
  }

  @override
  Future<bool> removePresetFromChamber(NeomChamberPreset chamberPreset) async {
    AppConfig.logger.d("removing itemlistItem ${chamberPreset.toString()}");

    try {
      if(await chamberRepository.deletePreset(chamber.id, chamberPreset)) {
        AppConfig.logger.d("Removing item from global itemlist from userController");
        userServiceImpl.profile.chambers = await chamberRepository.fetchAll(ownerId: userServiceImpl.profile.id);
        chamberPresets.remove(chamberPreset.id);

      } else {
        AppConfig.logger.d("NeomChamberPreset not removed");
        return false;
      }
    } catch (e, st) {
      NeomErrorLogger.recordError(e, st, module: 'neom_generator', operation: 'removePresetFromChamber');
      return false;
    }

    Sint.back();
    update([AppPageIdConstants.chamberPresets, AppPageIdConstants.chamber]);
    return true;
  }


  @override
  void setChamberPresetState(ChamberPresetState newState){
    AppConfig.logger.d("Setting new chamberPresetState $newState");
    itemState.value = newState.value;
    update([AppPageIdConstants.itemlistItem, AppPageIdConstants.appItem]);
  }

  @override
  Future<void> getChamberPresetDetails(NeomChamberPreset appMediaItem) async {
    AppConfig.logger.d("getChamberPresetDetails ${appMediaItem.name}");

    if(appMediaItem.imgUrl.isEmpty && chamber.imgUrl.isNotEmpty) appMediaItem.imgUrl = chamber.imgUrl;

    NeomChamberPreset chamberPreset = chamber.chamberPresets?.firstWhere((element) => element.name == appMediaItem.name) ?? NeomChamberPreset();
    if(chamberPreset.name.isNotEmpty) {
      Sint.toNamed(AppFlavour.getMainItemDetailsRoute(chamberPreset.id), arguments: [chamberPreset.clone()]
      );
    }

    update([AppPageIdConstants.chamberPresets]);
  }

  @override
  void loadPresetsFromChamber(){
    Map<String, NeomChamberPreset> presets = {};

    if(chamber.chamberPresets?.isNotEmpty ?? false) {
      chamber.chamberPresets?.forEach((preset) {
        AppConfig.logger.d(preset.name);
        presets[preset.id] = preset;
      });
    }

    chamberPresets.value = presets;
    update([AppPageIdConstants.chamberPresets]);
  }

}
