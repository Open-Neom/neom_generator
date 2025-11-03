import 'dart:io';

import 'package:enum_to_string/enum_to_string.dart';
import 'package:flutter/material.dart';
import 'package:flutter_rating_bar/flutter_rating_bar.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:get/get.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/ui/widgets/appbar_child.dart';
import 'package:neom_commons/ui/widgets/core_widgets.dart';
import 'package:neom_commons/ui/widgets/read_more_container.dart';
import 'package:neom_commons/utils/app_utilities.dart';
import 'package:neom_commons/utils/constants/app_assets.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_commons/utils/constants/translations/app_translation_constants.dart';
import 'package:neom_commons/utils/constants/translations/common_translation_constants.dart';
import 'package:neom_commons/utils/constants/translations/message_translation_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/utils/core_utilities.dart';
import 'package:neom_core/utils/enums/app_item_state.dart';
import 'package:rflutter_alert/rflutter_alert.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';
import 'package:surround_frequency_generator/surround_frequency_generator.dart';

import '../utils/constants/generator_translation_constants.dart';
import '../utils/constants/neom_generator_constants.dart';
import '../utils/constants/neom_slider_constants.dart';
import 'neom_generator_controller.dart';

class NeomGeneratorPage extends StatelessWidget {
  
  final bool showAppBar;
  
  const NeomGeneratorPage({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return GetBuilder<NeomGeneratorController>(
      id: AppPageIdConstants.generator,
      init: NeomGeneratorController(),
      builder: (controller) => WillPopScope(
        onWillPop: () async {
          try {
            if(controller.isPlaying.value) {
              await controller.playStopPreview(stopPreview: true);
            }
            controller.soundController.removeListener(() { });
            controller.soundController.dispose();
            controller.soundController = SoundController();
            if(Platform.isAndroid) {
              await controller.webViewAndroidController.clearCache(); // Clear the WebView cache (optional)
              await controller.webViewAndroidController.goBack();    // Dispose of the WebView
            } else {
              await controller.webViewIosController.clearCache();
              await controller.webViewIosController.goBack();
            }
            controller.isPlaying.value = false;
          } catch (e) {
            AppConfig.logger.e(e.toString());
          }
          return true;
        },
    child: Scaffold(
      appBar: showAppBar ? AppBarChild(title: GeneratorTranslationConstants.neomChamber.tr) : null,
        body: Container(
        height: AppTheme.fullHeight(context),
        width: AppTheme.fullWidth(context),
        decoration: AppTheme.appBoxDecoration,
        child: SingleChildScrollView(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          SoundWidget(soundController: controller.soundController,
            webViewAndroidController: controller.webViewAndroidController,
            webViewIosController: controller.webViewIosController,
            backgroundColor: AppColor.getMain(),
          ),
          AppTheme.heightSpace40,
          ValueListenableBuilder<AudioParam>(
            valueListenable: controller.soundController,
            builder: (context, AudioParam freqValue, __) {
              AudioParam freqValue = controller.getAudioParam();
              return Column(
                children: <Widget>[
                  SleekCircularSlider(
                    appearance: NeomSliderConstants.appearance01,
                    min: NeomGeneratorConstants.frequencyMin,
                    max: NeomGeneratorConstants.frequencyMax,
                    initialValue: controller.chamberPreset.neomFrequency!.frequency,
                    onChange: (double val) async {
                      await controller.setFrequency(val);
                    },
                    innerWidget: (double value) {
                      return Align(
                        alignment: Alignment.center,
                        child: SleekCircularSlider(
                          appearance: NeomSliderConstants.appearance02,
                          min: NeomGeneratorConstants.positionMin,
                          max: NeomGeneratorConstants.positionMax,
                          initialValue: freqValue.x,
                          onChange: (double val) {
                            controller.setParameterPosition(x: val, y: freqValue.y, z: freqValue.z);
                          },
                          innerWidget: (double v) {
                            return Align(
                              alignment: Alignment.center,
                              child: SleekCircularSlider(
                                appearance: NeomSliderConstants.appearance03,
                                min: NeomGeneratorConstants.positionMin,
                                max: NeomGeneratorConstants.positionMax,
                                initialValue: freqValue.y,
                                onChange: (double val) {
                                  controller.setParameterPosition(x: freqValue.x, y: val, z: freqValue.z);
                                },
                                innerWidget: (double v) {
                                  return Align(
                                    alignment: Alignment.center,
                                    child: SleekCircularSlider(
                                      appearance: NeomSliderConstants.appearance04,
                                      min: NeomGeneratorConstants.positionMin,
                                      max: NeomGeneratorConstants.positionMax,
                                      initialValue: freqValue.z,
                                      onChange: (double val) {
                                        controller.setParameterPosition(x: freqValue.x, y: freqValue.y, z: val);
                                      },
                                      innerWidget: (double val) {
                                        return Padding(
                                          padding: const EdgeInsets.all(25),
                                          child: Ink(
                                            decoration: BoxDecoration(
                                              color: controller.isPlaying.value ? AppColor.deepDarkViolet : Colors.transparent,
                                              shape: BoxShape.circle,
                                            ),
                                            child: InkWell(
                                              child: IconButton(
                                                  onPressed: ()  async {
                                                    await controller.playStopPreview();
                                                  },
                                                  icon: const Icon(FontAwesomeIcons.om, size: 60)
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      );
                    },
                  ),
                  Slider(
                    value: freqValue.volume,
                    min: NeomGeneratorConstants.volumeMin,
                    max: NeomGeneratorConstants.volumeMax,
                    onChanged: (val) {
                      controller.setVolume(val);
                    },
                  ),
                  AppTheme.heightSpace10,

                  Text("${controller.soundController.value.freq.round()} Hz",
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 30,
                    ),
                  ),
                  AppTheme.heightSpace20,
                  Text(
                    AppTranslationConstants.parameters.tr.capitalizeFirst,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 20,
                    ),
                  ),
                  AppTheme.heightSpace10,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("${AppTranslationConstants.volume.tr}: ${(controller.soundController.value.volume*100).round()}"),
                      Text(
                          "${GeneratorTranslationConstants.waveLength.tr}: ${controller.soundController.value.freq > 0 ? ((343 / controller.soundController.value.freq) * 100).toStringAsFixed(2) : 'N/A'} cm"
                      ),
                    ],
                  ),
                  AppTheme.heightSpace10,
                  Text(
                    GeneratorTranslationConstants.surroundSound.tr.capitalizeFirst,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 15,
                    ),
                  ),
                  AppTheme.heightSpace10,
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      Text("${GeneratorTranslationConstants.xAxis.tr}: ${controller.soundController.value.x.toPrecision(2)}"),
                      Text("${GeneratorTranslationConstants.yAxis.tr}: ${controller.soundController.value.y.toPrecision(2)}"),
                      Text("${GeneratorTranslationConstants.zAxis.tr}: ${controller.soundController.value.z.toPrecision(2)}"),
                    ],
                  ),
                  AppTheme.heightSpace20,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: controller.existsInChamber.value && !controller.isUpdate.value ? const SizedBox.shrink() : Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        GestureDetector(
                          child: buildIconActionChip(icon: const Icon(Icons.remove), controllerFunction: () async {await controller.decreaseFrequency();}),
                          onLongPress: () {
                            controller.longPressed.value = true;
                            controller.timerDuration.value = NeomGeneratorConstants.recursiveCallTimerDuration;
                            controller.decreaseOnLongPress();
                          },
                          onLongPressUp: () => controller.longPressed.value = false,
                        ),
                        if(controller.userServiceImpl != null) TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
                            backgroundColor: AppColor.bondiBlue,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(40)),),
                          child: Text(controller.isUpdate.value ? GeneratorTranslationConstants.savePreset.tr : controller.existsInChamber.value ? GeneratorTranslationConstants.removePreset.tr : GeneratorTranslationConstants.savePreset.tr,
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 18.0,
                                  fontWeight: FontWeight.bold
                              )
                          ),
                          onPressed: () async {
                            if(controller.existsInChamber.value && !controller.isUpdate.value) {
                              await controller.removePreset(context);
                            } else {
                              await Alert(
                                context: context,
                                style: AlertStyle(
                                    backgroundColor: AppColor.main50,
                                    titleStyle: const TextStyle(color: Colors.white)
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
                                                    itemState.value == 0 ? const SizedBox.shrink() : const Text(" - "),
                                                    itemState.value == 0 ? const SizedBox.shrink() :
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
                                                      onRatingUpdate: (rating) {
                                                        AppConfig.logger.i("New Rating set to $rating");
                                                      },
                                                    ),
                                                  ],
                                                )
                                            );
                                          }).toList(),
                                          onChanged: (String? newItemState) {
                                            controller.setFrequencyState(EnumToString.fromString(AppItemState.values, newItemState!) ?? AppItemState.noState);
                                          },
                                          value: CoreUtilities.getItemState(controller.frequencyState.value).name,
                                          alignment: Alignment.center,
                                          icon: const Icon(Icons.arrow_downward),
                                          iconSize: 15,
                                          elevation: 15,
                                          style: const TextStyle(color: Colors.white),
                                          dropdownColor: AppColor.main75,
                                          underline: Container(
                                            height: 1,
                                            color: Colors.grey,
                                          ),
                                        )
                                    ),
                                  ],
                                ),
                                buttons: [
                                  DialogButton(
                                    color: AppColor.bondiBlue75,
                                    child: Obx(()=>controller.isLoading.value ? const Center(child: CircularProgressIndicator())
                                        : Text(AppTranslationConstants.add.tr,
                                    )),
                                    onPressed: () async {
                                      if(controller.frequencyState > 0) {
                                        await controller.addPreset(context, frequencyPracticeState: controller.frequencyState.value);
                                        Navigator.pop(context);
                                      } else {
                                        Get.snackbar(
                                            CommonTranslationConstants.appItemPrefs.tr,
                                            MessageTranslationConstants.selectItemStateMsg.tr,
                                            snackPosition: SnackPosition.bottom
                                        );
                                      }
                                    },
                                  )],
                              ).show();
                            }
                            Navigator.pop(context);
                          },
                        ),
                        GestureDetector(
                          child: buildIconActionChip(icon: const Icon(Icons.add), controllerFunction: () async { await controller.increaseFrequency();}),
                          onLongPress: () {
                            controller.longPressed.value = true;
                            controller.timerDuration.value = NeomGeneratorConstants.recursiveCallTimerDuration;
                            controller.increaseOnLongPress();
                          },
                          onLongPressUp: () => controller.longPressed.value = false,
                        ),
                      ],
                    ),
                  ),
                  AppTheme.heightSpace10,
                  InkWell(
                    child: Container(
                      width: 60,
                      height: 60,
                      decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: controller.isRecording ? Colors.grey.shade800 : Colors.grey.shade900,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black12,
                          blurRadius: 4,
                          offset: Offset(2, 2),
                        ),
                      ],),
                      child: Stack(
                      alignment: Alignment.center,
                      children: [
                        if (controller.isRecording)
                          const SizedBox(
                            width: 60,
                            height: 60,
                            child: CircularProgressIndicator(),
                          ),
                        IconButton(
                          onPressed: () => controller.isRecording ? controller.stopRecording() : controller.startRecording(),
                          icon: Icon(FontAwesomeIcons.microphone, size: 40, color: controller.isRecording ? Colors.red : null),
                        ),
                      ],
                    ),),
                    onTap: () => controller.isRecording ? controller.stopRecording() : controller.startRecording(),
                    onLongPress: () => controller.isRecording ? controller.stopRecording() : controller.startRecording(),
                  ),
                  AppTheme.heightSpace10,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: controller.isRecording || controller.frequencyDescription.isEmpty ? Text(
                      controller.isRecording ? "${AppTranslationConstants.frequency.tr}: ${controller.detectedFrequency.toInt()} Hz"
                  : controller.detectedFrequency == 0 ? GeneratorTranslationConstants.findsYourVoiceFrequency.tr : '',
                      style: TextStyle(fontSize: controller.isRecording ? 18 : 15,),
                      textAlign: TextAlign.justify,
                    ) : ReadMoreContainer(
                      text: controller.frequencyDescription.value,
                      fontSize: 12,
                      trimLines: 5,
                    )
                  ),
                  AppTheme.heightSpace20,
                ],
              );
            },
          ),
        ],
      ),
        ),
        ),
      //TODO EXPERIMENTAL FEATURES TO MOVE NEOM CHAMBER 2D TO A 3D VERSION TO USE IT WITH SMARTPHONE VR
      // floatingActionButton: Row(
      //   mainAxisAlignment: MainAxisAlignment.end,
      //   children: [
      //   FloatingActionButton(
      //     heroTag: "",
      //     backgroundColor: Colors.white12,
      //     mini: true,
      //     child: Icon(FontAwesomeIcons.vrCardboard, size: 12,color: Colors.white,),
      //     onPressed: ()=>{
      //       // Get.to(() => PanoramaView())
      //     },
      //   ),
      //   FloatingActionButton(
      //     heroTag: " ",
      //     backgroundColor: Colors.white12,
      //     mini: true,
      //     child: Icon(FontAwesomeIcons.globe, size: 12,color: Colors.white,),
      //     onPressed: ()=> {
      //       // Get.to(() => VideoSection())
      //     },
      //   ),
      //     FloatingActionButton(
      //       heroTag: " _",
      //       backgroundColor: Colors.white12,
      //       mini: true,
      //       child: Icon(FontAwesomeIcons.chrome, size: 12,color: Colors.white,),
      //       onPressed: ()=> {
      //         generatorController.neom360viewerController.launchChromeVRView(context, url: 'https://larkintuckerllc.github.io/hello-react-360/')
      //       },
      //     )
      // ],
      // )
    ),),
    );
  }
}
