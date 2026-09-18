import 'dart:async';

import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/utils/auth_guard.dart';
import 'package:neom_commons/utils/constants/translations/app_translation_constants.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:sint/sint.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

import '../../engine/neom_frequency_painter_engine.dart';
import '../../utils/constants/generator_translation_constants.dart';
import '../../utils/constants/neom_generator_constants.dart';
import '../../utils/constants/neom_slider_constants.dart';
import '../../utils/enums/neom_numeric_target.dart';
import '../neom_generator_controller.dart';
import '../painters/circuit_wave_painter.dart';
import '../painters/frequency_painter.dart';
import '../painters/lissajous_3d_painter.dart';
import '../painters/lissajous_painter.dart';
import '../painters/mic_waveform_painter.dart';
import '../painters/neom_binaural_beat_painter.dart';
import '../painters/oscilloscope_painter.dart';
import '../painters/perimeter_wave_painter.dart';
import '../panels/neom_breath_control_panel.dart';
import '../panels/neom_modulation_control_panel.dart';
import '../panels/neom_neuro_state_control_panel.dart';
import '../panels/neom_spatial_control_panel.dart';
import '../widgets/camara_neom_tutorial.dart';
import '../widgets/chamber_controls.dart';
import '../widgets/chamber_practice_tools.dart';
import '../widgets/generator_widgets.dart';
import '../widgets/signal_paint.dart';
import '../widgets/visual_animation.dart';

/// Web dashboard layout for the Neom Chamber (Cámara Neom).
///
/// Keeps voice, playback and the oscilloscope in the first viewport. Secondary
/// controls remain available in independently scrollable dashboard columns.
class NeomGeneratorWebPage extends StatelessWidget {
  final NeomGeneratorController controller;

  const NeomGeneratorWebPage({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: SintAppBar(
        title: GeneratorTranslationConstants.neomChamber.tr,
        centerTitle: true,
        leading: IconButton(
          tooltip: GeneratorTranslationConstants.homeKeepAudio.tr,
          icon: const Icon(Icons.home, color: Colors.white),
          onPressed: () {
            unawaited(controller.stopRecording(applyDetectedFrequency: false));
            Sint.offAllNamed(AppRouteConstants.home);
          },
        ),
        actions: [
          IconButton(
            tooltip: GeneratorTranslationConstants.chamberGuide.tr,
            icon: const Icon(Icons.help_outline),
            onPressed: () => showDialog<void>(
              context: context,
              builder: (context) => CamaraNeomTutorial(
                onComplete: () => Navigator.of(context).pop(),
              ),
            ),
          ),
          // Compact volume control in AppBar
          Obx(
            () => controller.focusMode.value
                ? const SizedBox.shrink()
                : SizedBox(
                    width: 140,
                    child: Row(
                      children: [
                        Icon(
                          Icons.volume_down,
                          size: 16,
                          color: controller.currentVol.value > 0
                              ? Colors.amber
                              : Colors.white24,
                        ),
                        Expanded(
                          child: SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 2,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 5,
                              ),
                              overlayShape: const RoundSliderOverlayShape(
                                overlayRadius: 8,
                              ),
                              activeTrackColor: Colors.amber,
                              inactiveTrackColor: Colors.white12,
                              thumbColor: Colors.amber,
                            ),
                            child: Slider(
                              value: controller.currentVol.value,
                              min: 0.0,
                              max: 1.0,
                              onChanged: (val) => controller.setVolume(val),
                            ),
                          ),
                        ),
                        Text(
                          '${(controller.currentVol.value * 100).round()}',
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            color: Colors.white54,
                            fontSize: 10,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          const SizedBox(width: 4),
          Obx(
            () => controller.focusMode.value
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: () => controller.showCircuitWave.toggle(),
                    icon: Icon(
                      Icons.cable,
                      color: controller.showCircuitWave.value
                          ? AppColor.bondiBlue
                          : Colors.white24,
                      size: 20,
                    ),
                    tooltip: 'Circuit Wave',
                  ),
          ),
          Obx(
            () => controller.focusMode.value
                ? const SizedBox.shrink()
                : IconButton(
                    onPressed: () => controller.showPerimeterWave.toggle(),
                    icon: Icon(
                      Icons.waves,
                      color: controller.showPerimeterWave.value
                          ? Colors.purpleAccent
                          : Colors.white24,
                      size: 20,
                    ),
                    tooltip: 'Perimeter Wave',
                  ),
          ),
          IconButton(
            onPressed: () => Sint.toNamed(AppRouteConstants.chamberExperiences),
            icon: const Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
            tooltip: GeneratorTranslationConstants.experiences.tr,
          ),
          if (controller.userServiceImpl != null) ...[
            IconButton(
              onPressed: () => Sint.toNamed(AppRouteConstants.chamberPresets),
              icon: const Icon(
                Icons.library_music_outlined,
                color: Colors.white70,
                size: 22,
              ),
              tooltip: 'Presets',
            ),
            IconButton(
              onPressed: () async {
                AuthGuard.protect(context, () async {
                  if (controller.existsInChamber.value &&
                      !controller.isUpdate.value) {
                    await controller.removePreset(context);
                  } else {
                    showSaveDialog(context, controller);
                  }
                });
              },
              icon: const Icon(
                Icons.save_outlined,
                color: Colors.white,
                size: 22,
              ),
            ),
          ],
        ],
      ),
      body: Obx(
        () => controller.focusMode.value
            ? ChamberFocusView(controller: controller)
            : Container(
                decoration: AppTheme.appBoxDecoration,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                  child: Obx(
                    () => CircuitWaveOverlay(
                      engine: controller.painterEngine,
                      isActive:
                          controller.isPlaying.value &&
                          controller.showCircuitWave.value,
                      primaryColor: AppColor.bondiBlue,
                      secondaryColor: Colors.purpleAccent,
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // ═══ LEFT: Modulación / Espacialidad + Lissajous 2D ═══
                          Flexible(
                            flex: 1,
                            child: Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        CircuitNode(
                                          child: _buildPanel(
                                            '${GeneratorTranslationConstants.modulation.tr} / ${GeneratorTranslationConstants.spatiality.tr}',
                                            Column(
                                              children: [
                                                NeomModulationControlPanel(),
                                                const SizedBox(height: 8),
                                                NeomSpatialControlPanel(),
                                              ],
                                            ),
                                            helpTooltip:
                                                '${GeneratorTranslationConstants.helpModulation.tr}\n\n${GeneratorTranslationConstants.helpSpatiality.tr}',
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Lissajous 2D — pinned at bottom, outside CircuitNode
                                Obx(
                                  () => PerimeterWaveWidget(
                                    isActive:
                                        controller.isPlaying.value &&
                                        controller.showPerimeterWave.value,
                                    engine: controller.painterEngine,
                                    primaryColor: AppColor.bondiBlue,
                                    secondaryColor: Colors.purpleAccent,
                                    amplitude: 5,
                                    strokeWidth: 1.0,
                                    child: _buildPanel(
                                      'LISSAJOUS',
                                      SizedBox(
                                        height: 180,
                                        child: _buildLissajous(context),
                                      ),
                                      helpTooltip: GeneratorTranslationConstants
                                          .helpLissajous
                                          .tr,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(width: 12),

                          // ═══ CENTER: Sleek + Oscilloscope (protagonist) ═══
                          Flexible(
                            flex: 2,
                            child: Obx(
                              () => PerimeterWaveWidget(
                                isActive:
                                    controller.isPlaying.value &&
                                    controller.showPerimeterWave.value,
                                engine: controller.painterEngine,
                                primaryColor: AppColor.bondiBlue,
                                secondaryColor: Colors.purpleAccent,
                                amplitude: 8,
                                strokeWidth: 1.5,
                                child: _buildPrimaryDashboard(context),
                              ),
                            ), // PerimeterWaveWidget + Obx
                          ), // Flexible

                          const SizedBox(width: 12),

                          // ═══ RIGHT: Respiración / Neuroarmonía + Lissajous 3D ═══
                          Flexible(
                            flex: 1,
                            child: Column(
                              children: [
                                Expanded(
                                  child: SingleChildScrollView(
                                    child: Column(
                                      children: [
                                        CircuitNode(
                                          child: _buildPanel(
                                            '${GeneratorTranslationConstants.breathing.tr} / ${GeneratorTranslationConstants.neuroharmony.tr}',
                                            Column(
                                              children: [
                                                NeomBreathControlPanel(),
                                                const SizedBox(height: 8),
                                                NeomNeuroStateControlPanel(),
                                              ],
                                            ),
                                            helpTooltip:
                                                '${GeneratorTranslationConstants.helpBreathing.tr}\n\n${GeneratorTranslationConstants.helpNeuroState.tr}',
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        CircuitNode(
                                          child: _buildPanel(
                                            GeneratorTranslationConstants
                                                .coherenceMeter
                                                .tr,
                                            _buildCoherence(context),
                                            helpTooltip:
                                                GeneratorTranslationConstants
                                                    .helpCoherence
                                                    .tr,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                // Lissajous 3D — pinned at bottom, outside CircuitNode
                                Obx(
                                  () => PerimeterWaveWidget(
                                    isActive:
                                        controller.isPlaying.value &&
                                        controller.showPerimeterWave.value,
                                    engine: controller.painterEngine,
                                    primaryColor: Colors.purpleAccent,
                                    secondaryColor: AppColor.bondiBlue,
                                    amplitude: 5,
                                    strokeWidth: 1.0,
                                    child: _buildPanel(
                                      GeneratorTranslationConstants
                                          .lissajous
                                          .tr,
                                      SizedBox(
                                        height: 180,
                                        child: Lissajous3DWidget(
                                          engine: controller.painterEngine,
                                          baseColor: AppColor.getAccentColor(),
                                        ),
                                      ),
                                      helpTooltip: GeneratorTranslationConstants
                                          .helpLissajous
                                          .tr,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ), // Row + CircuitWaveOverlay + Obx
                ),
              ),
      ),
    );
  }

  Widget _buildPrimaryDashboard(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Reserve room for the scope instead of sizing the dial from the page
        // width. At enlarged text sizes the column can scroll naturally.
        final dialSize = (constraints.maxHeight * .28).clamp(160.0, 220.0);
        final scopeHeight = (constraints.maxHeight * .21).clamp(120.0, 160.0);
        final largeText = MediaQuery.textScalerOf(context).scale(14) > 21;
        return SingleChildScrollView(
          key: const ValueKey('chamber-web-primary-scroll'),
          padding: const EdgeInsets.all(12),
          child: Column(
            children: [
              Wrap(
                key: const ValueKey('chamber-web-primary-actions'),
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 12,
                runSpacing: 4,
                children: [
                  _buildVoiceAndChamberRow(),
                  ChamberPracticeClock(controller: controller, compact: true),
                ],
              ),
              _buildMicWaveform(),
              ChamberFeedback(
                playbackError: controller.playbackError.value,
                saveError: controller.recordingSaveError.value,
                onRetrySave: controller.retryPendingRecordings,
              ),
              const SizedBox(height: 8),
              if (largeText || constraints.maxWidth < 430)
                Column(
                  children: [
                    _buildCircularSliders(context, size: dialSize),
                    const SizedBox(height: 8),
                    _buildFrequencyDisplays(context),
                  ],
                )
              else
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    _buildCircularSliders(context, size: dialSize),
                    const SizedBox(width: 12),
                    Expanded(child: _buildFrequencyDisplays(context)),
                  ],
                ),
              const SizedBox(height: 8),
              _buildFrequencyPainter(),
              _buildBinauralBeatPainter(),
              const SizedBox(height: 4),
              KeyedSubtree(
                key: const ValueKey('chamber-web-oscilloscope'),
                child: _buildPanel(
                  GeneratorTranslationConstants.neuroHarmonicOscilloscope.tr,
                  _buildOscilloscope(context, height: scopeHeight),
                  helpTooltip:
                      GeneratorTranslationConstants.helpOscilloscope.tr,
                ),
              ),
              const SizedBox(height: 8),
              _buildFreqBeatSliders(),
              _buildOctaveSelector(),
              const SizedBox(height: 4),
              ChamberPracticeToolbar(controller: controller, compact: true),
              _buildSessionStatus(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMicWaveform() => Obx(
    () => controller.isRecording.value
        ? Container(
            margin: const EdgeInsets.only(top: 4),
            height: 32,
            width: double.infinity,
            decoration: BoxDecoration(
              color: Colors.black.withAlpha(60),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withAlpha(40)),
            ),
            child: Obx(
              () => CustomPaint(
                painter: MicWaveformPainter(
                  bars: controller.micWaveform.toList(),
                  color: Colors.red.withAlpha(200),
                ),
              ),
            ),
          )
        : const SizedBox.shrink(),
  );

  SizedBox _buildFrequencyPainter() {
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: Obx(
        () => SignalPaint(
          active: controller.isPlaying.value,
          builder: (repaint) => FrequencyPainter(
            engine: controller.painterEngine,
            repaint: repaint,
            color: AppColor.bondiBlue,
          ),
        ),
      ),
    );
  }

  SizedBox _buildBinauralBeatPainter() {
    return SizedBox(
      height: 6,
      width: double.infinity,
      child: Obx(() {
        final playing = controller.isPlaying.value;
        final beat = controller.currentBeat.value;
        final intensity = controller.modulationDepth.value.clamp(0.2, 1.0);
        return SignalPaint(
          active: playing,
          builder: (repaint) => NeomBinauralBeatPainter(
            engine: controller.painterEngine,
            repaint: repaint,
            beatHz: beat,
            intensity: intensity,
            color: AppColor.bondiBlue,
          ),
        );
      }),
    );
  }

  /// Reusable panel container with title header.
  Widget _buildPanel(String title, Widget content, {String? helpTooltip}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.black.withAlpha(80),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColor.bondiBlue.withAlpha(40)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: const TextStyle(
                    color: Colors.white54,
                    fontSize: 11,
                    letterSpacing: 1.2,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (helpTooltip != null)
                Tooltip(
                  message: helpTooltip,
                  preferBelow: true,
                  showDuration: const Duration(seconds: 8),
                  child: const Padding(
                    padding: EdgeInsets.only(left: 6),
                    child: Icon(
                      Icons.info_outline,
                      size: 13,
                      color: Colors.white24,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildCircularSliders(BuildContext context, {required double size}) {
    return Obx(() {
      getNoteFromFrequency(controller.currentFreq.value);
      return SizedBox.square(
        key: const ValueKey('chamber-web-dial'),
        dimension: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: SleekCircularSlider(
                appearance: NeomSliderConstants.appearance01,
                min: NeomGeneratorConstants.frequencyMin,
                max: controller.isAdmin
                    ? NeomGeneratorConstants.frequencyMax
                    : NeomGeneratorConstants.frequencyLimit,
                initialValue:
                    controller.chamberPreset.mainFrequency?.frequency
                        .toDouble() ??
                    NeomGeneratorConstants.defaultFrequency,
                onChange: (double val) async =>
                    await controller.setFrequency(val),
                innerWidget: (double value) {
                  return Align(
                    alignment: Alignment.center,
                    child: SleekCircularSlider(
                      appearance: NeomSliderConstants.appearance02,
                      min: NeomGeneratorConstants.positionMin,
                      max: NeomGeneratorConstants.positionMax,
                      initialValue: -controller.posX.value,
                      onChange: (double val) {
                        controller.setParameterPosition(
                          x: -val,
                          y: controller.posY.value,
                          z: controller.posZ.value,
                        );
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
                                z: controller.posZ.value,
                              );
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
                                      z: val,
                                    );
                                  },
                                  innerWidget: (_) => const SizedBox.shrink(),
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
            ),
            // Keep a real 48px target even when the decorative dial is scaled.
            SizedBox.square(
              dimension: 48,
              child: _OmButton(controller: controller),
            ),
          ],
        ),
      );
    });
  }

  Widget _buildFrequencyDisplays(BuildContext context) => Obx(() {
    final rootFrequency = controller.currentFreq.value;
    final beatFrequency = controller.currentBeat.value;
    final selectedTarget = controller.activeNumericTarget.value;
    return LayoutBuilder(
      builder: (context, constraints) {
        final cards = [
          ChamberFrequencyControl(
            compact: true,
            label: AppTranslationConstants.rootFrequency.tr,
            value: rootFrequency,
            selected: selectedTarget == NeomNumericTarget.rootFrequency,
            onSelect: controller.selectRootFrequency,
            onSubmit: controller.setFrequencyFromText,
            onIncrease: () {
              controller.selectRootFrequency();
              controller.increaseSelected();
            },
            onDecrease: () {
              controller.selectRootFrequency();
              controller.decreaseSelected();
            },
          ),
          ChamberFrequencyControl(
            compact: true,
            label: AppTranslationConstants.binauralBeat.tr,
            value: beatFrequency,
            selected: selectedTarget == NeomNumericTarget.binauralBeat,
            onSelect: controller.selectBinauralBeat,
            onSubmit: (text) {
              final value = double.tryParse(text.replaceAll(',', '.'));
              if (value != null && value.isFinite) {
                controller.setBinauralBeat(
                  beat: value.clamp(0, NeomGeneratorConstants.binauralBeatMax),
                );
              }
            },
            onIncrease: () {
              controller.selectBinauralBeat();
              controller.increaseSelected();
            },
            onDecrease: () {
              controller.selectBinauralBeat();
              controller.decreaseSelected();
            },
          ),
        ];
        return constraints.maxWidth < 400 ||
                MediaQuery.textScalerOf(context).scale(12) > 18
            ? Column(children: [cards[0], const SizedBox(height: 12), cards[1]])
            : Row(
                children: [
                  Expanded(child: cards[0]),
                  const SizedBox(width: 12),
                  Expanded(child: cards[1]),
                ],
              );
      },
    );
  });

  Widget _buildOscilloscope(BuildContext context, {required double height}) {
    return Column(
      children: [
        SizedBox(
          height: height,
          width: double.infinity,
          child: Obx(() {
            final playing = controller.isPlaying.value;
            final timeScale = controller.oscTimeScale.value;
            return SignalPaint(
              active: playing,
              builder: (repaint) => OscilloscopePainter(
                engine: controller.painterEngine,
                repaint: repaint,
                signalColor: AppColor.bondiBlue,
                gridColor: Colors.white12,
                timeScale: timeScale,
              ),
            );
          }),
        ),
        Row(
          children: [
            const SizedBox(width: 8),
            Icon(Icons.speed, color: Colors.white24, size: 14),
            const SizedBox(width: 4),
            const Text(
              'TIME',
              style: TextStyle(
                color: Colors.white24,
                fontSize: 9,
                letterSpacing: 1,
              ),
            ),
            SizedBox(
              width: 120,
              child: Obx(
                () => Slider(
                  value: controller.oscTimeScale.value,
                  min: 0.15,
                  max: 2.0,
                  activeColor: AppColor.bondiBlue.withAlpha(100),
                  inactiveColor: Colors.white10,
                  onChanged: (v) => controller.oscTimeScale.value = v,
                ),
              ),
            ),
            Obx(
              () => Text(
                '${controller.oscTimeScale.value.toStringAsFixed(2)}x',
                style: const TextStyle(
                  fontFamily: 'Courier',
                  color: Colors.white30,
                  fontSize: 9,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              icon: const Icon(
                Icons.fullscreen,
                color: AppColor.bondiBlue,
                size: 18,
              ),
              onPressed: () => Sint.toNamed(
                AppRouteConstants.oscilloscopeFullscreen,
                arguments: controller.painterEngine,
              ),
              tooltip: 'Fullscreen',
            ),
          ],
        ),
      ],
    );
  }

  /// Frequency + Binaural Beat sliders above their textboxes.
  Widget _buildFreqBeatSliders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          // Frequency slider
          Expanded(
            child: Obx(
              () => Slider(
                value: controller.currentFreq.value.clamp(
                  NeomGeneratorConstants.frequencyMin.toDouble(),
                  NeomGeneratorConstants.frequencyLimit.toDouble(),
                ),
                min: NeomGeneratorConstants.frequencyMin.toDouble(),
                max: NeomGeneratorConstants.frequencyLimit.toDouble(),
                activeColor: AppColor.bondiBlue,
                inactiveColor: Colors.white12,
                onChanged: (val) => controller.setFrequency(val),
              ),
            ),
          ),
          const SizedBox(width: 8),
          // Binaural Beat slider (reversed: right-to-left, high→low)
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Obx(
                () => Slider(
                  value: controller.currentBeat.value.clamp(
                    0.0,
                    NeomGeneratorConstants.binauralBeatMax.toDouble(),
                  ),
                  min: 0.0,
                  max: NeomGeneratorConstants.binauralBeatMax.toDouble(),
                  activeColor: Colors.purpleAccent,
                  inactiveColor: Colors.white12,
                  onChanged: (val) => controller.setBinauralBeat(beat: val),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOctaveSelector() => Obx(
    () => ChamberOctaveControl(
      compact: true,
      octave: controller.currentOctave.value,
      effectiveFrequency: controller.effectiveFrequency,
      onChanged: controller.setOctave,
    ),
  );

  /// INCIENSO session status bar: neuro state, incienso count and coherence.
  Widget _buildSessionStatus() {
    return Obx(
      () => VisualAnimation(
        active: controller.isPlaying.value,
        respectReducedMotion: false,
        frameInterval: const Duration(seconds: 1),
        builder: (context, clock, child) => AnimatedBuilder(
          animation: clock,
          builder: (_, _) => _buildSessionStatusBody(),
        ),
      ),
    );
  }

  Widget _buildSessionStatusBody() {
    return Obx(() {
      final playing = controller.isPlaying.value;
      final state = controller.neuroState.value;
      final incCount = controller.inciensoCount;
      final coherence = controller.painterEngine.hemisphericCoherence;
      final breathCycles = controller.inciensoTracker.totalCycles;

      const stateColors = {
        NeomNeuroState.sleep: Color(0xFF6C63FF),
        NeomNeuroState.calm: Color(0xFF4FC3F7),
        NeomNeuroState.neutral: Color(0xFF00BCD4),
        NeomNeuroState.creativity: Color(0xFFAB47BC),
        NeomNeuroState.focus: Color(0xFF66BB6A),
        NeomNeuroState.integration: Color(0xFFFFB74D),
      };
      final stateColor = playing
          ? (stateColors[state] ?? AppColor.bondiBlue)
          : Colors.white24;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: playing ? stateColor.withAlpha(10) : Colors.white.withAlpha(3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: playing
                ? stateColor.withAlpha(40)
                : Colors.white.withAlpha(8),
          ),
        ),
        child: Row(
          children: [
            // State indicator dot
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: playing ? stateColor : Colors.white12,
                boxShadow: playing
                    ? [
                        BoxShadow(
                          color: stateColor.withAlpha(80),
                          blurRadius: 6,
                        ),
                      ]
                    : null,
              ),
            ),
            const SizedBox(width: 10),
            // State name
            Text(
              playing ? state.nameKey.tr.toUpperCase() : '—',
              style: TextStyle(
                color: playing ? stateColor : Colors.white24,
                fontFamily: 'Courier',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 1,
              ),
            ),
            const Spacer(),
            // Breath cycles
            if (playing && breathCycles > 0) ...[
              Icon(Icons.air, size: 12, color: stateColor.withAlpha(120)),
              const SizedBox(width: 4),
              Text(
                '$breathCycles',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 10,
                  color: stateColor.withAlpha(160),
                ),
              ),
              const SizedBox(width: 12),
            ],
            // Incienso count
            if (playing && incCount > 0) ...[
              Icon(
                Icons.local_fire_department,
                size: 12,
                color: const Color(0xFFFF6D00).withAlpha(160),
              ),
              const SizedBox(width: 4),
              Text(
                '$incCount',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 10,
                  color: const Color(0xFFFF6D00).withAlpha(160),
                ),
              ),
              const SizedBox(width: 12),
            ],
            // Coherence
            if (playing) ...[
              Text(
                '${(coherence * 100).toInt()}%',
                style: TextStyle(
                  fontFamily: 'Courier',
                  fontSize: 10,
                  color: stateColor.withAlpha(140),
                ),
              ),
              const SizedBox(width: 12),
            ],
          ],
        ),
      );
    });
  }

  /// Voice detection button for web.
  Widget _buildVoiceAndChamberRow() => Obx(
    () => OutlinedButton.icon(
      key: const ValueKey('chamber-web-voice'),
      style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
      onPressed: () => controller.isRecording.value
          ? controller.stopRecording(applyDetectedFrequency: false)
          : controller.startRecording(),
      icon: Icon(
        controller.isRecording.value ? Icons.stop : Icons.mic,
        color: controller.isRecording.value ? Colors.redAccent : Colors.white70,
      ),
      label: Text(
        controller.isRecording.value
            ? '${GeneratorTranslationConstants.stopVoiceDetection.tr} · ${controller.detectedFrequency.value.toStringAsFixed(1)} Hz'
            : GeneratorTranslationConstants.detectMyVoice.tr,
        textAlign: TextAlign.center,
      ),
    ),
  );

  Widget _buildCoherence(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: coherenceMeter(controller.painterEngine),
        ),
      ],
    );
  }

  Widget _buildLissajous(BuildContext context) {
    return SizedBox(
      height: 140,
      width: double.infinity,
      child: Obx(
        () => SignalPaint(
          active: controller.isPlaying.value,
          builder: (repaint) => LissajousPainter(
            engine: controller.painterEngine,
            repaint: repaint,
            color: AppColor.bondiBlue,
          ),
        ),
      ),
    );
  }
}

/// Om button with binaural-beat-synced pulsing glow when playing.
class _OmButton extends StatelessWidget {
  final NeomGeneratorController controller;
  const _OmButton({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final playing = controller.isPlaying.value;
      final beat = controller.currentBeat.value.clamp(0.5, 50.0);
      final halfCycleMs = (1000 / beat).round().clamp(100, 2000);
      return VisualAnimation(
        active: playing,
        duration: Duration(milliseconds: halfCycleMs * 2),
        child: ChamberPlaybackButton(
          requested: controller.playbackRequested.value,
          transitioning: controller.isPlaybackTransitioning.value,
          onPressed: () => controller.playStopPreview(),
        ),
        builder: (_, clock, child) => AnimatedBuilder(
          animation: clock,
          child: child,
          builder: (_, stableControl) {
            final pulse = playing ? 1 - (2 * clock.value - 1).abs() : 0.0;
            final glowAlpha = (pulse * 120).round();
            final bgAlpha = playing ? (80 + pulse * 80).round() : 0;

            return Container(
              decoration: BoxDecoration(
                color: Color.fromARGB(bgAlpha, 75, 0, 130),
                shape: BoxShape.circle,
                boxShadow: playing
                    ? [
                        BoxShadow(
                          color: AppColor.bondiBlue.withAlpha(glowAlpha),
                          blurRadius: 16 + pulse * 20,
                          spreadRadius: pulse * 6,
                        ),
                      ]
                    : null,
              ),
              child: stableControl,
            );
          },
        ),
      );
    });
  }
}

/// Inline-editable frequency box. Double-click toggles between
/// display mode and a text field inside the same container.
