import 'dart:math' as math; // Necesario para calcular la nota musical

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:neom_commons/app_flavour.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/ui/widgets/images/handled_cached_network_image.dart';
import 'package:neom_commons/ui/widgets/rating_heart_bar.dart';
import 'package:neom_commons/utils/app_alerts.dart';
import 'package:neom_commons/utils/app_utilities.dart';
import 'package:neom_commons/utils/constants/app_assets.dart';
import 'package:neom_commons/utils/constants/app_constants.dart';
import 'package:neom_commons/utils/constants/translations/app_translation_constants.dart';
import 'package:neom_commons/utils/constants/translations/common_translation_constants.dart';
import 'package:neom_commons/utils/constants/translations/message_translation_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/app_properties.dart';
import 'package:neom_core/domain/model/neom/neom_chamber.dart';
import 'package:neom_core/domain/model/neom/neom_chamber_preset.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:neom_core/utils/core_utilities.dart';
import 'package:neom_core/utils/enums/app_in_use.dart';
import 'package:neom_core/utils/enums/app_item_state.dart';
import 'package:neom_core/utils/enums/chamber_preset_state.dart';
import 'package:neom_core/utils/enums/profile_type.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:sint/sint.dart';

import '../../utils/constants/generator_translation_constants.dart';
import '../../utils/constants/neom_generator_constants.dart';
import '../chamber/chamber_controller.dart';
import '../chamber/chamber_preset_controller.dart';
import '../neom_generator_controller.dart';

Widget buildChamberList(BuildContext context, ChamberController chamberController) {
  return ListView.separated(
    separatorBuilder: (context, index) => const Divider(),
    itemCount: chamberController.chambers.length,
    shrinkWrap: true,
    itemBuilder: (context, index) {
      NeomChamber chamber = chamberController.chambers.values.elementAt(index);
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
          backgroundColor: AppColor.surfaceDim,
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
            //   Sint.toNamed(AppRouteConstants.itemSearch,
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
            backgroundColor: AppColor.surfaceElevated,
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
      NeomChamberPreset chamberPreset = presetController.chamberPresets.values.elementAt(index);
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
                NeomChamberPreset preset = presetController.chamber.chamberPresets!.firstWhere((element) => element.id == chamberPreset.id);
                Sint.toNamed(AppRouteConstants.generator,  arguments: [preset.clone()]);
              }
          ),
          onTap: () {
            if(!presetController.isFixed) {
              presetController.getChamberPresetDetails(chamberPreset);
            } else {
              NeomChamberPreset preset = presetController.chamber.chamberPresets!.firstWhere((element) => element.id == chamberPreset.id);
              Sint.toNamed(AppRouteConstants.generator,  arguments: [preset.clone()]);
            }
          },
          onLongPress: () => presetController.chamber.isModifiable && (AppConfig.instance.appInUse != AppInUse.c || !presetController.isFixed) ? Alert(
              context: context,
              title: CommonTranslationConstants.appItemPrefs.tr,
              style: AlertStyle(
                  backgroundColor: AppColor.scaffold,
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

// --- WIDGETS AUXILIARES PARA EL DISEÑO CIENTÍFICO ---
Widget buildScienceParamCard({required String title, required String value, required double percent, required Color color, bool isProgress = true}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: TextStyle(color: Colors.white54, fontSize: 10, fontWeight: FontWeight.bold)),
      const SizedBox(height: 4),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(value, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold, fontFamily: 'Courier')),
        ],
      ),
      if(isProgress) ...[
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: percent,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 4,
          ),
        ),
      ]
    ],
  );
}

Widget buildAxisIndicator(String label, double value, Color color) {
  // Normalizar valor de -1.0 a 1.0 para visualización (0.0 a 1.0)
  // El slider va de -10 a 10 normalmente, ajusta según NeomGeneratorConstants
  double normalized = (value - NeomGeneratorConstants.positionMin) / (NeomGeneratorConstants.positionMax - NeomGeneratorConstants.positionMin);
  // Clamp por seguridad
  normalized = normalized.clamp(0.0, 1.0);

  return Container(
    width: 100,
    padding: const EdgeInsets.all(10),
    decoration: BoxDecoration(
        color: Colors.black26,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10)
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
            Text(value.toString(), style: const TextStyle(color: Colors.white70, fontSize: 12, fontFamily: 'Courier')),
          ],
        ),
        const SizedBox(height: 5),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: normalized,
            backgroundColor: Colors.white10,
            valueColor: AlwaysStoppedAnimation<Color>(color.withValues(alpha: 0.7)),
            minHeight: 5,
          ),
        )
      ],
    ),
  );
}

// --- LÓGICA MATEMÁTICA PARA NOTAS ---
String getNoteFromFrequency(double frequency) {
  if (frequency <= 0) return "--";
  // Fórmula: n = 12 * log2(f / 440) + 69
  // 69 es el número MIDI de A4 (440Hz)
  final n = 12 * (math.log(frequency / 440) / math.log(2)) + 69;
  final midiNumber = n.round();

  final notes = ['C', 'C#', 'D', 'D#', 'E', 'F', 'F#', 'G', 'G#', 'A', 'A#', 'B'];
  final octave = (midiNumber ~/ 12) - 1;
  final noteIndex = midiNumber % 12;

  if (midiNumber < 0 || noteIndex < 0) return "?";

  return "${notes[noteIndex]}$octave";
}

Widget buildCompactStat(String label, String value, Color color) {
  return Row(
    children: [
      Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 20)),
      const SizedBox(width: 5),
      Text(value, style: const TextStyle(color: Colors.white70, fontFamily: 'Courier', fontSize: 20)),
    ],
  );
}

Widget buildCircleBtn({required IconData icon, required Color color, required Function() onTap, Function()? onLongPress, Function()? onLongPressUp}) {
  return GestureDetector(
    onTap: onTap,
    onLongPress: onLongPress,
    onLongPressUp: onLongPressUp,
    child: Container(
      width: 50, height: 50,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    ),
  );
}

void showSaveDialog(BuildContext context, NeomGeneratorController controller) {
  Alert(
    context: context,
    style: AlertStyle(
        backgroundColor: AppColor.surfaceElevated,
        titleStyle: const TextStyle(color: Colors.white),
        descStyle: const TextStyle(color: Colors.white70)
    ),
    title: GeneratorTranslationConstants.chamberPrefs.tr,
    content: Column(
      children: <Widget>[
        Obx(()=>
            DropdownButton<String>(
              items: AppItemState.values.map((AppItemState itemState) {
                return DropdownMenuItem<String>(
                    value: itemState.name,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Text(itemState.name.tr),
                        if(itemState.value != 0) ...[
                          const SizedBox(width: 10),
                          RatingBar(
                            initialRating: itemState.value.toDouble(),
                            minRating: 1,
                            ignoreGestures: true,
                            direction: Axis.horizontal,
                            allowHalfRating: false,
                            itemCount: 5,
                            ratingWidget: RatingWidget(
                              full: AppUtilities.ratingImage(AppAssets.heart),
                              half: AppUtilities.ratingImage(AppAssets.heartHalf),
                              empty: AppUtilities.ratingImage(AppAssets.heartBorder),
                            ),
                            itemPadding: const EdgeInsets.symmetric(horizontal: 1.0),
                            itemSize: 10,
                            onRatingUpdate: (rating) {},
                          ),
                        ]
                      ],
                    )
                );
              }).toList(),
              onChanged: (String? newItemState) {
                controller.setFrequencyState(EnumToString.fromString(AppItemState.values, newItemState!) ?? AppItemState.noState);
              },
              value: CoreUtilities.getItemState(controller.frequencyState.value).name,
              isExpanded: true,
              dropdownColor: AppColor.surfaceElevated,
              style: const TextStyle(color: Colors.white),
              underline: Container(height: 1, color: AppColor.bondiBlue),
            )
        ),
      ],
    ),
    buttons: [
      DialogButton(
        color: AppColor.bondiBlue,
        child: Obx(()=>controller.isLoading.value ? const Center(child: CircularProgressIndicator(color: Colors.white))
            : Text(AppTranslationConstants.add.tr, style: const TextStyle(color: Colors.white, fontSize: 16),
        )),
        onPressed: () async {
          if(controller.frequencyState > 0) {
            await controller.addPreset(context, frequencyPracticeState: controller.frequencyState.value);
            Sint.back();
          } else {
            Sint.snackbar(
                CommonTranslationConstants.appItemPrefs.tr,
                MessageTranslationConstants.selectItemStateMsg.tr,
                snackPosition: SnackPosition.bottom,
                backgroundColor: AppColor.scaffold,
                colorText: Colors.white
            );
          }
        },
      )],
  ).show();
}
