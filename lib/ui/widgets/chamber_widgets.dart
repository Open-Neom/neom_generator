import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:neom_commons/app_flavour.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/ui/widgets/images/handled_cached_network_image.dart';
import 'package:neom_commons/ui/widgets/rating_heart_bar.dart';
import 'package:neom_commons/utils/app_alerts.dart';
import 'package:neom_commons/utils/constants/app_constants.dart';
import 'package:neom_commons/utils/constants/translations/app_translation_constants.dart';
import 'package:neom_commons/utils/constants/translations/common_translation_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/app_properties.dart';
import 'package:neom_core/domain/model/neom/chamber.dart';
import 'package:neom_core/domain/model/neom/chamber_preset.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:neom_core/utils/core_utilities.dart';
import 'package:neom_core/utils/enums/app_in_use.dart';
import 'package:neom_core/utils/enums/app_item_state.dart';
import 'package:neom_core/utils/enums/chamber_preset_state.dart';
import 'package:neom_core/utils/enums/profile_type.dart';
import 'package:rflutter_alert/rflutter_alert.dart';

import '../chamber/chamber_controller.dart';
import '../chamber/chamber_preset_controller.dart';

Widget buildChamberList(BuildContext context, ChamberController chamberController) {
  return ListView.separated(
    separatorBuilder: (context, index) => const Divider(),
    itemCount: chamberController.chambers.length,
    shrinkWrap: true,
    itemBuilder: (context, index) {
      Chamber chamber = chamberController.chambers.values.elementAt(index);
      return ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 10),
        leading: SizedBox(
            width: 50,
            child: HandledCachedNetworkImage(chamber.imgUrl.isNotEmpty ? chamber.imgUrl : AppProperties.getAppLogoUrl())
        ),
        title: Row(
            children: <Widget>[
              Text(chamber.name.length > AppConstants.maxItemlistNameLength
                  ? "${chamber.name.substring(0, AppConstants.maxItemlistNameLength).capitalizeFirst}..."
                  : chamber.name.capitalizeFirst),
              ///DEPRECATE .isFav ? const Icon(Icons.favorite, size: 10,) : SizedBox.shrink()
            ]),
        subtitle: chamber.description.isNotEmpty ? Text(chamber.description.capitalizeFirst, maxLines: 3, overflow: TextOverflow.ellipsis,) : null,
        trailing: ActionChip(
          labelPadding: EdgeInsets.zero,
          backgroundColor: AppColor.main25,
          avatar: CircleAvatar(
            backgroundColor: AppColor.white80,
            child: Text(((chamber.chamberPresets?.length ?? 0)).toString(),
                style: const TextStyle(color: Colors.black87),
            ),
          ),
          label: Icon(AppFlavour.getAppItemIcon(), color: AppColor.white80),
          onPressed: () async {
            await chamberController.gotoChamberPresets(chamber);
            ///ADD CHAMBERPRESET SEARCH HERE
            // if(!chamber.isModifiable) {
            //   await chamberController.gotoChamberPresets(chamber);
            // } else {
            //   Get.toNamed(AppRouteConstants.itemSearch,
            //       arguments: [SpotifySearchType.song, chamber]
            //   );
            // }
          },
        ),
        onTap: () async {
          await chamberController.gotoChamberPresets(chamber);
        },
        onLongPress: () async {
          (await showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
            backgroundColor: AppColor.main75,
            title: Text(CommonTranslationConstants.itemlistName.tr,),
            content: SizedBox(
              height: AppTheme.fullHeight(context)*0.25,
              child: Obx(()=> chamberController.isLoading.value ? const Center(child: CircularProgressIndicator())
                : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    TextField(
                      controller: chamberController.newChamberNameController,
                      decoration: InputDecoration(
                        labelText: '${AppTranslationConstants.changeName.tr}: ',
                        hintText: chamber.name,
                      ),
                    ),
                    TextField(
                      controller: chamberController.newChamberDescController,
                      minLines: 2,
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: '${AppTranslationConstants.changeDesc.tr}: ',
                        hintText: chamber.description,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            actions: <Widget>[
              DialogButton(
                color: AppColor.bondiBlue75,
                onPressed: () async {
                  await chamberController.updateChamber(chamber.id, chamber);
                  Navigator.pop(ctx);
                },
                child: Text(AppTranslationConstants.update.tr,
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              DialogButton(
                color: AppColor.bondiBlue75,
                child: Text(AppTranslationConstants.remove.tr,
                  style: const TextStyle(fontSize: 14),
                ),
                onPressed: () async {
                  if(chamberController.chambers.length == 1) {
                    AppAlerts.showAlert(context,
                        title: CommonTranslationConstants.itemlistPrefs.tr,
                        message: CommonTranslationConstants.cantRemoveMainItemlist.tr);
                  } else {
                    await chamberController.deleteChamber(chamber);
                    Navigator.pop(ctx);
                  }
                },
              ),
            ],
          ),
          )) ?? false;
        },
      );
    },
  );
}

Widget buildPresetsList(BuildContext context, ChamberPresetController presetController) {
  return ListView.separated(
    separatorBuilder: (context, index) => const Divider(),
    itemCount: presetController.chamberPresets.length,
    itemBuilder: (context, index) {
      ChamberPreset chamberPreset = presetController.chamberPresets.values.elementAt(index);
      return ListTile(
          leading: HandledCachedNetworkImage(chamberPreset.imgUrl.isNotEmpty
              ? chamberPreset.imgUrl : presetController.chamber.imgUrl, enableFullScreen: false,
            width: 40,
          ),
          title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(chamberPreset.name.isEmpty ? ""
                    : chamberPreset.name.length > AppConstants.maxAppItemNameLength
                    ? "${chamberPreset.name.substring(0,AppConstants.maxAppItemNameLength)}..."
                    : chamberPreset.name),
                const SizedBox(width:5),
                (AppConfig.instance.appInUse == AppInUse.c || (presetController.userServiceImpl.profile.type == ProfileType.appArtist && !presetController.isFixed)) ?
                RatingHeartBar(state: chamberPreset.state.toDouble()) : const SizedBox.shrink(),
              ]
          ),
          subtitle: Text(chamberPreset.description, textAlign: TextAlign.justify,),
          trailing: IconButton(
              icon: const Icon(
                  Icons.arrow_forward_ios
              ),
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
              onPressed: () {
                ChamberPreset preset = presetController.chamber.chamberPresets!.firstWhere((element) => element.id == chamberPreset.id);
                Get.toNamed(AppRouteConstants.generator,  arguments: [preset.clone()]);
              }
          ),
          onTap: () {
            if(!presetController.isFixed) {
              presetController.getChamberPresetDetails(chamberPreset);
            } else {
              ChamberPreset preset = presetController.chamber.chamberPresets!.firstWhere((element) => element.id == chamberPreset.id);
              Get.toNamed(AppRouteConstants.generator,  arguments: [preset.clone()]);
            }
          },
          onLongPress: () => presetController.chamber.isModifiable && (AppConfig.instance.appInUse != AppInUse.c || !presetController.isFixed) ? Alert(
              context: context,
              title: CommonTranslationConstants.appItemPrefs.tr,
              style: AlertStyle(
                  backgroundColor: AppColor.main50,
                  titleStyle: const TextStyle(color: Colors.white)
              ),
              content: Column(
                children: <Widget>[
                  Obx(() =>
                      DropdownButton<String>(
                        items: AppItemState.values.map((AppItemState appItemState) {
                          return DropdownMenuItem<String>(
                              value: appItemState.name,
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(appItemState.name.tr),
                                  appItemState.value == 0 ? const SizedBox.shrink() : const Text(" - "),
                                  appItemState.value == 0 ? const SizedBox.shrink() :
                                  RatingHeartBar(state: appItemState.value.toDouble(),),
                                ],
                              )
                          );
                        }).toList(),
                        onChanged: (String? newItemState) {
                          presetController.setChamberPresetState(EnumToString.fromString(ChamberPresetState.values, newItemState!) ?? ChamberPresetState.noState);
                        },
                        value: CoreUtilities.getItemState(presetController.itemState.value).name,
                        icon: const Icon(Icons.arrow_downward),
                        iconSize: 15,
                        elevation: 15,
                        style: const TextStyle(color: Colors.white),
                        dropdownColor: AppColor.getMain(),
                        underline: Container(
                          height: 1,
                          color: Colors.grey,
                        ),
                      ),
                  ),
                ],
              ),
              buttons: [
                DialogButton(
                  color: AppColor.bondiBlue75,
                  child: Text(AppTranslationConstants.update.tr,
                    style: const TextStyle(fontSize: 15),
                  ),
                  onPressed: () => {
                    presetController.updateChamberPreset(chamberPreset)
                  },
                ),
                DialogButton(
                  color: AppColor.bondiBlue75,
                  child: Text(AppTranslationConstants.remove.tr,
                    style: const TextStyle(fontSize: 15),
                  ),
                  onPressed: () async => {
                    await presetController.removePresetFromChamber(chamberPreset)
                  },
                ),
              ]
          ).show() : {}
      );
    },
  );

}
