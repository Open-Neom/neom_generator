import 'package:neom_commons/app_flavour.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/data/api_services/push_notification/firebase_messaging_calls.dart';
import 'package:neom_core/domain/model/collective.dart';
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
  final UserService? userServiceImpl;
  final ChamberRepository chamberRepository;

  ChamberPresetController({
    UserService? userService,
    ChamberRepository? chamberRepository,
  }) : userServiceImpl =
           userService ??
           (Sint.isRegistered<UserService>() ? Sint.find<UserService>() : null),
       chamberRepository = chamberRepository ?? ChamberFirestore();

  static Object? _safeRouteArguments() {
    try {
      return Sint.arguments;
    } catch (_) {
      return null;
    }
  }

  NeomChamberPreset chamberPreset = NeomChamberPreset();
  NeomChamber chamber = NeomChamber();

  final RxInt itemState = 0.obs;
  final RxMap<String, NeomChamberPreset> chamberPresets = <String, NeomChamberPreset>{}.obs;
  final RxBool isLoading = true.obs;

  bool isFixed = false;

  String profileId = "";
  String chamberId = "";
  Collective collective = Collective();
  int _prevItemState = 0;
  OwnerType chamberOwner = OwnerType.profile;


  @override
  void onInit() async {
    super.onInit();
    AppConfig.logger.d("ItemlistItem Controller init");
    try {
      final userSvc = userServiceImpl;
      if (userSvc != null) {
        profileId = userSvc.profile.id;
        collective = userSvc.collective;
        chamberOwner = userSvc.itemlistOwnerType;
      }

      final rawArgs = _safeRouteArguments();
      if (rawArgs is List && rawArgs.isNotEmpty) {
        if (rawArgs[0] is NeomChamber) {
          chamber = rawArgs[0] as NeomChamber;
        } else if (rawArgs[0] is String) {
          chamberId = rawArgs[0] as String;
          chamber = await chamberRepository.retrieve(chamberId);
        }

        if (rawArgs.length > 1 && rawArgs[1] is bool) {
          isFixed = rawArgs[1] as bool;
        }
      } else if (rawArgs is NeomChamber) {
        chamber = rawArgs;
      } else if (rawArgs is String && rawArgs.isNotEmpty) {
        chamberId = rawArgs;
        chamber = await chamberRepository.retrieve(chamberId);
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

  @override
  void onClose() {
    itemState.close();
    chamberPresets.close();
    isLoading.close();
    super.onClose();
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
          chamberPresets[updatedPreset.id] = updatedPreset;
          final profileChamber = userServiceImpl?.profile.chambers?[chamber.id];
          if (profileChamber != null) {
            (profileChamber.chamberPresets ??= []).add(updatedPreset);
          }
          updatedPreset.state = _prevItemState;
          profileChamber?.chamberPresets?.remove(updatedPreset);
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
        final userSvc = userServiceImpl;
        if (chamberOwner == OwnerType.profile) {
          final targetChamber = userSvc?.profile.chambers?[chamberId];
          if (targetChamber != null) {
            AppConfig.logger.d("Adding item to global itemlist from userController");
            (targetChamber.chamberPresets ??= []).add(chamberPreset);
            chamber = targetChamber;
            loadPresetsFromChamber();
          }

          if (userSvc != null) {
            FirebaseMessagingCalls.sendPublicPushNotification(
                fromProfile: userSvc.profile,
                notificationType: PushNotificationType.chamberPresetAdded,
                toProfileId: '',
                title: GeneratorTranslationConstants.chamberPresetAdded,
                referenceId: chamberPreset.id,
                imgUrl: chamberPreset.imgUrl
            );
          }

          return true;
        } else if (chamberOwner == OwnerType.collective) {
          final targetChamber = userSvc?.collective.chambers?[chamberId];
          if (targetChamber != null) {
            AppConfig.logger.d("Adding item to global itemlist from userController");
            (targetChamber.chamberPresets ??= []).add(chamberPreset);
            chamber = targetChamber;
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
        final userSvc = userServiceImpl;
        if (userSvc != null) {
          userSvc.profile.chambers = await chamberRepository.fetchAll(ownerId: userSvc.profile.id);
        }
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

    NeomChamberPreset chamberPreset =
        chamber.chamberPresets?.firstWhere(
          (element) => element.name == appMediaItem.name,
          orElse: () => NeomChamberPreset(),
        ) ??
        NeomChamberPreset();
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
