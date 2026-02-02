// Necesario para calcular la nota musical

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:neom_commons/domain/extensions/double_extensions.dart';
import 'package:sint/sint.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/ui/widgets/appbar_child.dart';
import 'package:neom_commons/ui/widgets/read_more_container.dart';
import 'package:neom_commons/utils/auth_guard.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_commons/utils/constants/translations/app_translation_constants.dart';
import 'package:neom_core/app_config.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

import '../engine/neom_frequency_painter_engine.dart';
import '../utils/constants/generator_translation_constants.dart';
import '../utils/constants/neom_generator_constants.dart';
import '../utils/constants/neom_slider_constants.dart';
import '../utils/enums/neom_frequency_target.dart';
import '../utils/enums/neom_numeric_target.dart';
import 'neom_generator_controller.dart';
import 'painters/frequency_painter.dart';
import 'painters/lissajous_painter.dart';
import 'painters/neom_binaural_beat_painter.dart';
import 'painters/oscilloscope_painter.dart';
import 'panels/neom_breath_control_panel.dart';
import 'panels/neom_modulation_control_panel.dart';
import 'panels/neom_neuro_state_control_panel.dart';
import 'panels/neom_spatial_control_panel.dart';
import 'widgets/generator_widgets.dart';
import 'widgets/session_time_meter.dart';

class NeomGeneratorPage extends StatelessWidget {

  final bool showAppBar;

  const NeomGeneratorPage({super.key, this.showAppBar = true});

  @override
  Widget build(BuildContext context) {
    return SintBuilder<NeomGeneratorController>(
      id: AppPageIdConstants.generator,
      init: NeomGeneratorController(),
      builder: (controller) => WillPopScope(
        onWillPop: () async {
          try {
            if(controller.isPlaying.value) {
              await controller.playStopPreview(stop: true);
            }
            // controller.soloud.disposeAllSources();
            controller.isPlaying.value = false;
          } catch (e) {
            AppConfig.logger.e(e.toString());
          }
          return true;
        },
    child: Scaffold(
      appBar: showAppBar ? AppBarChild(title: GeneratorTranslationConstants.neomChamber.tr,
      centerTitle: true,
      actionWidgets: controller.userServiceImpl != null ? [
          SizedBox(
            child: IconButton(
              onPressed: () async {
                AuthGuard.protect(context, () async {
                  if(controller.existsInChamber.value && !controller.isUpdate.value) {
                    await controller.removePreset(context);
                  } else {
                    showSaveDialog(context, controller);
                  }
                });
              },
              icon: Icon(Icons.save_outlined, color: Colors.white, size: 25),
            ),
          ),
      ] : null) : null,
        body: Container(
        height: AppTheme.fullHeight(context),
        width: AppTheme.fullWidth(context),
        decoration: AppTheme.appBoxDecoration,
        alignment: Alignment.center,
        child: SingleChildScrollView(
          child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          AppTheme.heightSpace20,
          // --- SLIDERS PRINCIPALES ---
          SizedBox(
            height: AppTheme.fullHeight(context) * 0.01,
            width: double.infinity,
            child: CustomPaint(
              painter: FrequencyPainter(
                  engine: controller.painterEngine,
                  color: AppColor.bondiBlue
              ),
              willChange: true,
            ),
          ),
          AppTheme.heightSpace5,
          SizedBox(
            height: AppTheme.fullHeight(context) * 0.01,
            width: double.infinity,
            child: CustomPaint(
              painter: NeomBinauralBeatPainter(
                engine: controller.painterEngine,
                beatHz: controller.currentBeat.value,
                intensity: controller.modulationDepth.value.clamp(0.2, 1.0),
                color: AppColor.bondiBlue,
              ),
            ),
          ),
          AppTheme.heightSpace30,
          Obx(() {
              // AudioParam currentParam = controller.getAudioParam();
              String note = getNoteFromFrequency(controller.currentFreq.value);
              return Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: <Widget>[
                  SleekCircularSlider(
                    appearance: NeomSliderConstants.appearance01,
                    min: NeomGeneratorConstants.frequencyMin,
                    max: controller.isAdmin ? NeomGeneratorConstants.frequencyMax : NeomGeneratorConstants.frequencyLimit,
                    initialValue: controller.chamberPreset.mainFrequency?.frequency.toDouble() ?? NeomGeneratorConstants.defaultFrequency,
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
                          initialValue: controller.posX.value,
                          onChange: (double val) {
                            controller.setParameterPosition(
                                x: val,
                                y: controller.posY.value,
                                z: controller.posZ.value);
                          },
                          innerWidget: (double v) {
                            return Align(
                              alignment: Alignment.center,
                              child: SleekCircularSlider(
                                appearance: NeomSliderConstants.appearance03,
                                min: NeomGeneratorConstants.positionMin,
                                max: NeomGeneratorConstants.positionMax,
                                initialValue: controller.posY.value,
                                onChange: (double val) {
                                  controller.setParameterPosition(
                                      x: controller.posX.value,
                                      y: val,
                                      z: controller.posZ.value);
                                },
                                innerWidget: (double v) {
                                  return Align(
                                    alignment: Alignment.center,
                                    child: SleekCircularSlider(
                                      appearance: NeomSliderConstants.appearance04,
                                      min: NeomGeneratorConstants.positionMin,
                                      max: NeomGeneratorConstants.positionMax,
                                      initialValue: controller.posZ.value,
                                      onChange: (double val) {
                                        controller.setParameterPosition(
                                            x: controller.posX.value,
                                            y: controller.posY.value,
                                            z: val
                                        );
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
                  AppTheme.heightSpace20,
                  // 1. Display Digital de Frecuencia Principal
                  Row(
                    children: [
                      GestureDetector(
                        onTap: controller.selectRootFrequency,
                        onDoubleTap: controller.startEditFrequency,
                        child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        width: AppTheme.fullWidth(context)/2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: controller.activeNumericTarget.value ==
                                    NeomNumericTarget.rootFrequency
                                    ? AppColor.bondiBlue
                                    : AppColor.bondiBlue.withOpacity(0.4),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColor.bondiBlue.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 1
                                )
                              ]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(AppTranslationConstants.rootFrequency.tr.toUpperCase(), style: TextStyle(color: AppColor.white, fontSize: 12, letterSpacing: 1.2)),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Obx(() {
                                    if (controller.isEditingFrequency.value) {
                                      return SizedBox(
                                        width: 90,
                                        child: TextField(
                                          controller: controller.frequencyEditCtrl,
                                          autofocus: true,
                                          keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: 'Courier',
                                            fontSize: 30,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            border: InputBorder.none,
                                          ),
                                          onSubmitted: (_) => controller.finishEditFrequency(),
                                          onEditingComplete: controller.finishEditFrequency,
                                        ),
                                      );
                                    }

                                    return GestureDetector(
                                      onTap: controller.startEditFrequency,
                                      child: Text(
                                        controller.currentFreq.value.toStringAsFixed(0),
                                        style: const TextStyle(
                                          fontFamily: 'Courier',
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  }),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8, left: 5),
                                    child: Text("Hz", style: TextStyle(fontSize: 15, color: Colors.white54)),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      ),),
                      GestureDetector(
                        onTap: () {
                          if(controller.selectedTarget.value ==
                              NeomFrequencyTarget.binaural) {
                            controller.increaseSelected();
                          } else {
                          controller.selectBinauralBeat();
                          controller.increaseSelected();
                          }
                        },
                        onDoubleTap: controller.startEditBeat,
                        child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        width: AppTheme.fullWidth(context)/2,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
                          decoration: BoxDecoration(
                              color: Colors.black.withOpacity(0.5),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: controller.activeNumericTarget.value ==
                                    NeomNumericTarget.binauralBeat
                                    ? AppColor.bondiBlue
                                    : AppColor.bondiBlue.withOpacity(0.4),
                                width: 1,
                              ),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColor.bondiBlue.withOpacity(0.1),
                                    blurRadius: 10,
                                    spreadRadius: 1
                                )
                              ]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Text(AppTranslationConstants.binauralBeat.tr.toUpperCase(), style: TextStyle(color: AppColor.white, fontSize: 12, letterSpacing: 1.2)),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Obx(() {
                                    if (controller.isEditingBeat.value) {
                                      return SizedBox(
                                        width: 80,
                                        child: TextField(
                                          controller: controller.beatEditCtrl,
                                          autofocus: true,
                                          keyboardType:
                                          const TextInputType.numberWithOptions(decimal: true),
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: 'Courier',
                                            fontSize: 30,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                          decoration: const InputDecoration(
                                            isDense: true,
                                            border: InputBorder.none,
                                          ),
                                          onSubmitted: (_) => controller.finishEditBeat(),
                                          onEditingComplete: controller.finishEditBeat,
                                        ),
                                      );
                                    }

                                    return GestureDetector(
                                      onDoubleTap: controller.startEditBeat,
                                      child: Text(
                                        controller.currentBeat.value.toStringAsFixed(0),
                                        style: const TextStyle(
                                          fontFamily: 'Courier',
                                          fontSize: 30,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    );
                                  }),
                                  const Padding(
                                    padding: EdgeInsets.only(bottom: 8, left: 5),
                                    child: Text("Hz", style: TextStyle(fontSize: 15, color: Colors.white54)),
                                  )
                                ],
                              )
                            ],
                          ),
                        ),
                      ),),
                    ],
                  ),
                  AppTheme.heightSpace20,
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: <Widget>[
                        // Botón Menos
                        buildCircleBtn(
                          icon: Icons.remove,
                          color: Colors.white24,
                          onTap: () async {
                            controller.decreaseSelected();
                          },
                          onLongPress: () {
                            controller.longPressed.value = true;
                            controller.timerDuration.value =
                                NeomGeneratorConstants.recursiveCallTimerDuration;
                            controller.decreaseOnLongPress();
                          },
                          onLongPressUp: () => controller.longPressed.value = false,
                        ),
                        InkWell(
                          onTap: () => controller.isRecording ? controller.stopRecording() : controller.startRecording(),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            padding: const EdgeInsets.all(15),
                            decoration: BoxDecoration(
                                color: controller.isRecording ? Colors.red.withOpacity(0.2) : Colors.transparent,
                                border: Border.all(color: controller.isRecording ? Colors.red : Colors.white12),
                                borderRadius: BorderRadius.circular(30)
                            ),
                            child: Row(
                              children: [
                                Icon(FontAwesomeIcons.microphone, size: 15, color: controller.isRecording ? Colors.red : Colors.white54),
                                const SizedBox(width: 8),
                                Text(
                                  controller.isRecording
                                      ? "${GeneratorTranslationConstants.detecting.tr.toUpperCase()}: ${controller.detectedFrequency.toInt()} Hz"
                                      : GeneratorTranslationConstants.detectMyVoice.tr.toUpperCase(),
                                  style: TextStyle(                                      fontSize: 15,
                                      color: controller.isRecording ? Colors.red : Colors.white54,
                                      letterSpacing: 1
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        // Botón Más
                        buildCircleBtn(
                          icon: Icons.add,
                          color: Colors.white24,
                          onTap: () async {
                            controller.increaseSelected();
                          },
                          onLongPress: () {
                            controller.longPressed.value = true;
                            controller.timerDuration.value =
                                NeomGeneratorConstants.recursiveCallTimerDuration;
                            controller.increaseOnLongPress();
                          },
                          onLongPressUp: () => controller.longPressed.value = false,
                        ),
                      ],
                    ),
                  ),
                  AppTheme.heightSpace20,
                  // Botones de visualización inmersiva
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Botón Flocking
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Sint.toNamed(
                                AppRouteConstants.flockingFullscreen,
                                arguments: controller.painterEngine,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    AppColor.bondiBlue.withOpacity(0.2),
                                    Colors.purple.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: AppColor.bondiBlue.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.scatter_plot, color: AppColor.bondiBlue, size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      AppTranslationConstants.attention.tr.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        letterSpacing: 1,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Botón VR 360
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Sint.toNamed(
                                AppRouteConstants.spatial360Fullscreen,
                                arguments: controller.painterEngine,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.indigo.withOpacity(0.2),
                                    Colors.deepPurple.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.vrpano, color: Colors.indigo.shade300, size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      GeneratorTranslationConstants.spatiality.tr.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        letterSpacing: 1,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppTheme.heightSpace10,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        // Botón Flocking
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Sint.toNamed(
                                AppRouteConstants.breathingFullscreen,
                                arguments: controller.painterEngine,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.teal.withOpacity(0.2),
                                    Colors.cyan.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.teal.withOpacity(0.4)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.air, color: Colors.teal.shade300, size: 22),
                                  const SizedBox(width: 10),
                                  Text(
                                    GeneratorTranslationConstants.breathing.tr.toUpperCase(),
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 12,
                                      letterSpacing: 1.5,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Botón VR 360
                        Expanded(
                          child: GestureDetector(
                            onTap: () {
                              Sint.toNamed(
                                AppRouteConstants.vr360StereoFullscreen,
                                arguments: controller.painterEngine,
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [
                                    Colors.indigo.withOpacity(0.2),
                                    Colors.deepPurple.withOpacity(0.2),
                                  ],
                                ),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: Colors.indigo.withOpacity(0.3)),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(FontAwesomeIcons.vrCardboard, color: Colors.indigo.shade300, size: 20),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      AppTranslationConstants.virtualReality.tr.toUpperCase(),
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        letterSpacing: 1,
                                        fontWeight: FontWeight.w500,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  AppTheme.heightSpace10,
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.volume_up, size: 18, color: Colors.white70),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 20,
                              child: SliderTheme(
                                data: SliderTheme.of(context).copyWith(
                                  activeTrackColor: AppColor.bondiBlue,
                                  inactiveTrackColor: Colors.white12,
                                  thumbColor: Colors.white,
                                  thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                  trackHeight: 2.0,
                                  overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                ),
                                child: Slider(
                                  value: controller.currentVol.value,
                                  min: NeomGeneratorConstants.volumeMin,
                                  max: NeomGeneratorConstants.volumeMax,
                                  onChanged: (val) {
                                    controller.setVolume(val);
                                  },
                                ),
                              ),
                            ),
                          ),
                          Text(
                            "${(controller.currentVol.value * 100).round()}%",
                            style: const TextStyle(color: Colors.white, fontFamily: 'Courier', fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppTheme.heightSpace30,
                  SizedBox(
                    height: AppTheme.fullHeight(context) * 0.01,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: FrequencyPainter(
                          engine: controller.painterEngine,
                          color: AppColor.bondiBlue
                      ),
                      willChange: true,
                    ),
                  ),
                  AppTheme.heightSpace5,
                  SizedBox(
                    height: AppTheme.fullHeight(context) * 0.01,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: NeomBinauralBeatPainter(
                        engine: controller.painterEngine,
                        beatHz: controller.currentBeat.value,
                        intensity: controller.modulationDepth.value.clamp(0.2, 1.0),
                        color: AppColor.bondiBlue,
                      ),
                    ),
                  ),
                  AppTheme.heightSpace10,
                  //TODO Add visual mode
                  // const NeomVisualModeControlPanel(),
                  // AppTheme.heightSpace10,
                  // --- VISUALIZADOR DE SONIDO ---
                  ExpansionTile(
                      title: Text(GeneratorTranslationConstants.neuroHarmonicOscilloscope.tr,
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      children: [
                        Stack(
                          children: [
                            SizedBox(
                              height: AppTheme.fullHeight(context) * 0.20,
                              width: double.infinity,
                              child: CustomPaint(
                                painter: OscilloscopePainter(
                                  engine: controller.painterEngine,
                                  signalColor: AppColor.bondiBlue,
                                  gridColor: Colors.white12,
                                ),
                                willChange: true,
                              ),
                            ),
                            // Botón fullscreen
                            Positioned(
                              right: 10,
                              bottom: 10,
                              child: GestureDetector(
                                onTap: () {
                                  Sint.toNamed(
                                    AppRouteConstants.oscilloscopeFullscreen,
                                    arguments: controller.painterEngine,
                                  );
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.black54,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: AppColor.bondiBlue.withOpacity(0.5)),
                                  ),
                                  child: const Icon(
                                    Icons.fullscreen,
                                    color: AppColor.bondiBlue,
                                    size: 20,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ]
                  ),
                  AppTheme.heightSpace10,
                  // 2. Dashboard de Parámetros (Grilla)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        children: [
                          // Fila 1: Control de Volumen (Compacto)
                          Row(
                            children: [
                              const Icon(Icons.volume_up, size: 18, color: Colors.white70),
                              const SizedBox(width: 10),
                              Expanded(
                                child: SizedBox(
                                  height: 20,
                                  child: SliderTheme(
                                    data: SliderTheme.of(context).copyWith(
                                      activeTrackColor: AppColor.bondiBlue,
                                      inactiveTrackColor: Colors.white12,
                                      thumbColor: Colors.white,
                                      thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                                      trackHeight: 2.0,
                                      overlayShape: const RoundSliderOverlayShape(overlayRadius: 10),
                                    ),
                                    child: Slider(
                                      value: controller.currentVol.value,
                                      min: NeomGeneratorConstants.volumeMin,
                                      max: NeomGeneratorConstants.volumeMax,
                                      onChanged: (val) {
                                        controller.setVolume(val);
                                      },
                                    ),
                                  ),
                                ),
                              ),
                              Text(
                                "${(controller.currentVol.value * 100).round()}%",
                                style: const TextStyle(color: Colors.white, fontFamily: 'Courier', fontSize: 12),
                              ),
                            ],
                          ),
                          AppTheme.heightSpace10,
                          const Divider(color: Colors.white12, height: 15),
                          AppTheme.heightSpace10,
                          // Fila 1: Ejes X, Y, Z
                          Column(
                            children: [
                              Text(
                                GeneratorTranslationConstants.surroundSound.tr.toUpperCase(),
                                style: TextStyle(
                                    color: Colors.white.withOpacity(0.5),
                                    fontSize: 10, letterSpacing: 1.5
                                ),
                              ),
                              AppTheme.heightSpace10,
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  buildAxisIndicator("X", controller.posX.value.toPrecision(2), Colors.redAccent),
                                  buildAxisIndicator("Y", controller.posY.value.toPrecision(2), Colors.greenAccent),
                                  buildAxisIndicator("Z", controller.posZ.value.toPrecision(2), Colors.blueAccent),
                                ],
                              ),
                            ],
                          ),
                          AppTheme.heightSpace10,
                          const Divider(color: Colors.white12, height: 1),
                          AppTheme.heightSpace10,
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(AppTranslationConstants.musicalNote.tr.toUpperCase(),
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 10, letterSpacing: 1.5
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.music_note, size: 20),
                                      const SizedBox(width: 5),
                                      Text(
                                        note,
                                        style: const TextStyle(fontFamily: 'Courier', fontSize: 20, fontWeight: FontWeight.bold, color: Colors.white),
                                      )
                                    ],
                                  )

                                ],
                              ),
                              Container(width: 1, height: 20, color: Colors.white12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  Text(GeneratorTranslationConstants.waveLength.tr.toUpperCase(),
                                    style: TextStyle(
                                        color: Colors.white.withOpacity(0.5),
                                        fontSize: 10,
                                        letterSpacing: 1.5
                                    ),
                                  ),
                                  buildCompactStat(
                                      "λ",
                                      controller.currentFreq.value > 0
                                          ? "${((343 / controller.currentFreq.value) * 100).toStringAsFixed(2)}cm"
                                          : '--',
                                      Colors.orangeAccent
                                  ),
                                ],
                              )
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  AppTheme.heightSpace10,
                  ExpansionTile(
                      title: Text("${GeneratorTranslationConstants.modulation.tr.toUpperCase()} / ${GeneratorTranslationConstants.spatiality.tr.toUpperCase()}",
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      children: [
                        NeomModulationControlPanel(),
                        AppTheme.heightSpace10,
                        NeomSpatialControlPanel()
                      ]
                  ),
                  ExpansionTile(
                      title: Text("${GeneratorTranslationConstants.breathing.tr.toUpperCase()} / ${GeneratorTranslationConstants.neuroharmony.tr.toUpperCase()}",
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      children: [
                        NeomBreathControlPanel(),
                        AppTheme.heightSpace10,
                        NeomNeuroStateControlPanel()
                      ]
                  ),
                  ExpansionTile(
                      title: Text(GeneratorTranslationConstants.coherenceMeter.tr.toUpperCase(),
                          style: TextStyle(color: Colors.white70, fontSize: 12)),
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: coherenceMeter(controller.painterEngine),
                        ),
                        SizedBox(
                          height: AppTheme.fullHeight(context) * 0.05,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: FrequencyPainter(
                              engine: controller.painterEngine,
                              color: AppColor.bondiBlue,
                            ),
                            willChange: true,
                          ),
                        ),
                        SizedBox(
                          height: AppTheme.fullHeight(context) * 0.15,
                          width: double.infinity,
                          child: AnimatedBuilder(
                            animation: controller.painterEngine,
                            builder: (_, __) => CustomPaint(
                              painter: LissajousPainter(
                                engine: controller.painterEngine,
                                color: controller.painterEngine.eegColor,
                              ),
                              size: Size.infinite,
                            ),
                          ),
                        ),
                        SizedBox(
                          height: AppTheme.fullHeight(context) * 0.05,
                          width: double.infinity,
                          child: CustomPaint(
                            painter: FrequencyPainter(
                              engine: controller.painterEngine,
                              color: AppColor.bondiBlue,
                            ),
                            willChange: true,
                          ),
                        ),
                      ]
                  ),
                  AppTheme.heightSpace10,
                  Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: controller.frequencyDescription.isEmpty ? Text(
                        controller.detectedFrequency == 0 ? GeneratorTranslationConstants.findsYourVoiceFrequency.tr : '',
                        style: TextStyle(
                            fontSize: controller.isRecording ? 18 : 14,
                            fontFamily: 'Courier',
                            color: Colors.white70
                        ),
                        textAlign: TextAlign.center,
                      ) : Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            border: Border(left: BorderSide(color: AppColor.bondiBlue, width: 3))
                        ),
                        child: ReadMoreContainer(
                          text: controller.frequencyDescription.value,
                          fontSize: 13,
                          trimLines: 3,
                        ),
                      )
                  ),
                  AppTheme.heightSpace10,
                  SizedBox(
                    height: AppTheme.fullHeight(context) * 0.03,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: FrequencyPainter(
                        engine: controller.painterEngine,
                        color: AppColor.bondiBlue,
                      ),
                      willChange: true,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: SessionChamberTimeMeter(
                      referenceId: controller.chamberPreset.id,
                      showTitle: false
                    ),
                  ),
                  SizedBox(
                    height: AppTheme.fullHeight(context) * 0.03,
                    width: double.infinity,
                    child: CustomPaint(
                      painter: FrequencyPainter(
                        engine: controller.painterEngine,
                        color: AppColor.bondiBlue,
                      ),
                      willChange: true,
                    ),
                  ),
                  AppTheme.heightSpace20,
                ],
              );
            },
          ),
        ],),
        ),
        ),
      ///TODO EXPERIMENTAL FEATURES TO MOVE NEOM CHAMBER 2D TO A 3D VERSION TO USE IT WITH SMARTPHONE VR
      // floatingActionButton: Row(
      //   mainAxisAlignment: MainAxisAlignment.end,
      //   children: [
      //   FloatingActionButton(
      //     heroTag: "",
      //     backgroundColor: Colors.white12,
      //     mini: true,
      //     child: Icon(FontAwesomeIcons.vrCardboard, size: 12,color: Colors.white,),
      //     onPressed: ()=>{
      //       // Sint.to(() => PanoramaView())
      //     },
      //   ),
      //   FloatingActionButton(
      //     heroTag: " ",
      //     backgroundColor: Colors.white12,
      //     mini: true,
      //     child: Icon(FontAwesomeIcons.globe, size: 12,color: Colors.white,),
      //     onPressed: ()=> {
      //       // Sint.to(() => VideoSection())
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
