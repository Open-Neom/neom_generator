import 'dart:async';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/utils/auth_guard.dart';
import 'package:neom_commons/utils/constants/translations/app_translation_constants.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:sint/sint.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

import '../../engine/neom_frequency_painter_engine.dart';
import '../../utils/constants/generator_translation_constants.dart';
import '../../utils/constants/neom_generator_constants.dart';
import '../../utils/constants/neom_slider_constants.dart';
import '../../utils/enums/neom_neuro_state.dart';
import '../../utils/enums/neom_numeric_target.dart';
import '../neom_generator_controller.dart';
import '../painters/frequency_painter.dart';
import '../painters/lissajous_3d_painter.dart';
import '../painters/circuit_wave_painter.dart';
import '../painters/perimeter_wave_painter.dart';
import '../painters/lissajous_painter.dart';
import '../painters/mic_waveform_painter.dart';
import '../painters/neom_binaural_beat_painter.dart';
import '../painters/oscilloscope_painter.dart';
import '../panels/neom_breath_control_panel.dart';
import '../panels/neom_modulation_control_panel.dart';
import '../panels/neom_neuro_state_control_panel.dart';
import '../panels/neom_spatial_control_panel.dart';
import '../widgets/generator_widgets.dart';

/// Web dashboard layout for the Neom Chamber (Cámara Neom).
///
/// Replaces the mobile single-column with ExpansionTiles by a
/// multi-panel grid where all controls are visible simultaneously.
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
          icon: const Icon(Icons.home, color: Colors.white),
          onPressed: () {
            Sint.offAllNamed(AppRouteConstants.home);
          },
        ),
        actions: [
                // Compact volume control in AppBar
                Obx(() => SizedBox(
                  width: 140,
                  child: Row(
                    children: [
                      Icon(Icons.volume_down, size: 16,
                          color: controller.currentVol.value > 0 ? Colors.amber : Colors.white24),
                      Expanded(
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                            overlayShape: const RoundSliderOverlayShape(overlayRadius: 8),
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
                      Text('${(controller.currentVol.value * 100).round()}',
                          style: const TextStyle(fontFamily: 'Courier', color: Colors.white54, fontSize: 10)),
                    ],
                  ),
                )),
                const SizedBox(width: 4),
          Obx(() => IconButton(
            onPressed: () => controller.showCircuitWave.toggle(),
            icon: Icon(
              Icons.cable,
              color: controller.showCircuitWave.value ? AppColor.bondiBlue : Colors.white24,
              size: 20,
            ),
            tooltip: 'Circuit Wave',
          )),
          Obx(() => IconButton(
            onPressed: () => controller.showPerimeterWave.toggle(),
            icon: Icon(
              Icons.waves,
              color: controller.showPerimeterWave.value ? Colors.purpleAccent : Colors.white24,
              size: 20,
            ),
            tooltip: 'Perimeter Wave',
          )),
                IconButton(
                  onPressed: () => Sint.toNamed(AppRouteConstants.chamberExperiences),
                  icon: const Icon(Icons.auto_awesome, color: Colors.amber, size: 22),
                  tooltip: GeneratorTranslationConstants.experiences.tr,
                ),
                if (controller.userServiceImpl != null) ...[
                  IconButton(
                    onPressed: () => Sint.toNamed(AppRouteConstants.chamberPresets),
                    icon: const Icon(Icons.library_music_outlined, color: Colors.white70, size: 22),
                    tooltip: 'Presets',
                  ),
                  IconButton(
                    onPressed: () async {
                      AuthGuard.protect(context, () async {
                        if (controller.existsInChamber.value && !controller.isUpdate.value) {
                          await controller.removePreset(context);
                        } else {
                          showSaveDialog(context, controller);
                        }
                      });
                    },
                    icon: const Icon(Icons.save_outlined, color: Colors.white, size: 22),
                  ),
                ],
              ],
      ),
      body: Container(
        decoration: AppTheme.appBoxDecoration,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Obx(() => CircuitWaveOverlay(
            engine: controller.painterEngine,
            isActive: controller.isPlaying.value && controller.showCircuitWave.value,
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
                                helpTooltip: '${GeneratorTranslationConstants.helpModulation.tr}\n\n${GeneratorTranslationConstants.helpSpatiality.tr}',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Lissajous 2D — pinned at bottom, outside CircuitNode
                    Obx(() => PerimeterWaveWidget(
                      isActive: controller.isPlaying.value && controller.showPerimeterWave.value,
                      engine: controller.painterEngine,
                      primaryColor: AppColor.bondiBlue,
                      secondaryColor: Colors.purpleAccent,
                      amplitude: 5,
                      strokeWidth: 1.0,
                      child: _buildPanel(
                        'LISSAJOUS',
                        SizedBox(height: 180, child: _buildLissajous(context)),
                        helpTooltip: GeneratorTranslationConstants.helpLissajous.tr,
                      ),
                    )),
                  ],
                ),
              ),

              const SizedBox(width: 12),

              // ═══ CENTER: Sleek + Oscilloscope (protagonist) ═══
              Flexible(
                flex: 2,
                child: Obx(() => PerimeterWaveWidget(
                  isActive: controller.isPlaying.value && controller.showPerimeterWave.value,
                  engine: controller.painterEngine,
                  primaryColor: AppColor.bondiBlue,
                  secondaryColor: Colors.purpleAccent,
                  amplitude: 8,
                  strokeWidth: 1.5,
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // Frequency painter strip
                        _buildFrequencyPainter(),
                        const SizedBox(height: 2),
                        _buildBinauralBeatPainter(),
                        const SizedBox(height: 30),
                        // Circular sliders
                        _buildCircularSliders(context),
                      // Frequency + Beat sliders above their displays
                      _buildFreqBeatSliders(),

                      // Frequency + Beat displays (textboxes with +/-)
                      _buildFrequencyDisplays(context),

                      const SizedBox(height: 8),

                      // Octave multiplier
                      _buildOctaveSelector(),

                      const SizedBox(height: 12),

                      // Oscilloscope — full width under the sliders
                      _buildPanel(
                        GeneratorTranslationConstants.neuroHarmonicOscilloscope.tr,
                        _buildOscilloscope(context),
                        helpTooltip: GeneratorTranslationConstants.helpOscilloscope.tr,
                      ),

                      const SizedBox(height: 8),

                      // ═══ INCIENSO Status + Session Timer ═══
                      _buildSessionStatus(),

                      // ═══ Voice detection + Mic waveform ═══
                      _buildVoiceAndChamberRow(),
                      Obx(() => controller.isRecording.value
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Container(
                                height: 48,
                                width: double.infinity,
                                decoration: BoxDecoration(
                                  color: Colors.black.withAlpha(60),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.red.withAlpha(40)),
                                ),
                                child: Obx(() => CustomPaint(
                                  painter: MicWaveformPainter(
                                    bars: controller.micWaveform.toList(),
                                    color: Colors.red.withAlpha(200),
                                  ),
                                )),
                              ),
                            )
                          : const SizedBox.shrink()),

                    ],
                  ),
                ),
              )),  // PerimeterWaveWidget + Obx
              ),  // Flexible

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
                                helpTooltip: '${GeneratorTranslationConstants.helpBreathing.tr}\n\n${GeneratorTranslationConstants.helpNeuroState.tr}',
                              ),
                            ),
                            const SizedBox(height: 12),
                            CircuitNode(
                              child: _buildPanel(
                                GeneratorTranslationConstants.coherenceMeter.tr,
                                _buildCoherence(context),
                                helpTooltip: GeneratorTranslationConstants.helpCoherence.tr,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Lissajous 3D — pinned at bottom, outside CircuitNode
                    Obx(() => PerimeterWaveWidget(
                      isActive: controller.isPlaying.value && controller.showPerimeterWave.value,
                      engine: controller.painterEngine,
                      primaryColor: Colors.purpleAccent,
                      secondaryColor: AppColor.bondiBlue,
                      amplitude: 5,
                      strokeWidth: 1.0,
                      child: _buildPanel(
                        GeneratorTranslationConstants.lissajous.tr,
                        SizedBox(
                          height: 180,
                          child: Lissajous3DWidget(
                            engine: controller.painterEngine,
                            baseColor: AppColor.getAccentColor(),
                          ),
                        ),
                        helpTooltip: GeneratorTranslationConstants.helpLissajous.tr,
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ))),  // Row + CircuitWaveOverlay + Obx
        ),
      ),
    );
  }

  SizedBox _buildFrequencyPainter() {
    return SizedBox(
                      height: 6,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: FrequencyPainter(
                          engine: controller.painterEngine,
                          color: AppColor.bondiBlue,
                        ),
                        willChange: true,
                      ),
                    );
  }

  SizedBox _buildBinauralBeatPainter() {
    return SizedBox(
                      height: 6,
                      width: double.infinity,
                      child: CustomPaint(
                        painter: NeomBinauralBeatPainter(
                          engine: controller.painterEngine,
                          beatHz: controller.currentBeat.value,
                          intensity: controller.modulationDepth.value.clamp(0.2, 1.0),
                          color: AppColor.bondiBlue,
                        ),
                      ),
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
                    child: Icon(Icons.info_outline, size: 13, color: Colors.white24),
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

  Widget _buildCircularSliders(BuildContext context) {
    return Obx(() {
      getNoteFromFrequency(controller.currentFreq.value);
      return SleekCircularSlider(
        appearance: NeomSliderConstants.appearance01,
        min: NeomGeneratorConstants.frequencyMin,
        max: controller.isAdmin
            ? NeomGeneratorConstants.frequencyMax
            : NeomGeneratorConstants.frequencyLimit,
        initialValue: controller.chamberPreset.mainFrequency?.frequency.toDouble() ??
            NeomGeneratorConstants.defaultFrequency,
        onChange: (double val) async => await controller.setFrequency(val),
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
                  x: -val, y: controller.posY.value, z: controller.posZ.value);
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
                        x: controller.posX.value, y: val, z: controller.posZ.value);
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
                          innerWidget: (double val) {
                            return Padding(
                              padding: const EdgeInsets.all(25),
                              child: _OmButton(controller: controller),
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
      );
    });
  }

  Widget _buildFrequencyDisplays(BuildContext context) {
    return Obx(() {
      return Row(
        children: [
          // ── Root Frequency (editable + increment buttons) ──
          Expanded(child: _editableFreqBox(
            context: context,
            label: AppTranslationConstants.rootFrequency.tr.toUpperCase(),
            value: controller.currentFreq.value,
            suffix: 'Hz',
            decimals: 0,
            active: controller.activeNumericTarget.value == NeomNumericTarget.rootFrequency,
            onTap: controller.selectRootFrequency,
            onSubmit: (v) => controller.setFrequencyFromText(v),
            onIncrement: () {
              controller.selectRootFrequency();
              controller.increaseSelected();
            },
            onDecrement: () {
              controller.selectRootFrequency();
              controller.decreaseSelected();
            },
            showIncrementButtons: true,
          )),
          const SizedBox(width: 8),
          // ── Binaural Beat (editable + increment buttons) ──
          Expanded(child: _editableFreqBox(
            context: context,
            label: AppTranslationConstants.binauralBeat.tr.toUpperCase(),
            value: controller.currentBeat.value,
            suffix: 'Hz',
            decimals: 1,
            active: controller.activeNumericTarget.value == NeomNumericTarget.binauralBeat,
            onTap: controller.selectBinauralBeat,
            onSubmit: (v) {
              final parsed = double.tryParse(v);
              if (parsed != null) {
                controller.setBinauralBeat(beat: parsed.clamp(0, NeomGeneratorConstants.binauralBeatMax));
              }
            },
            onIncrement: () {
              controller.selectBinauralBeat();
              controller.increaseSelected();
            },
            onDecrement: () {
              controller.selectBinauralBeat();
              controller.decreaseSelected();
            },
            showIncrementButtons: true,
          )),
        ],
      );
    });
  }

  Widget _editableFreqBox({
    required BuildContext context,
    required String label,
    required double value,
    required String suffix,
    required int decimals,
    required bool active,
    required VoidCallback onTap,
    required Function(String) onSubmit,
    VoidCallback? onIncrement,
    VoidCallback? onDecrement,
    bool showIncrementButtons = false,
  }) {
    return _InlineEditableFreqBox(
      label: label,
      value: value,
      suffix: suffix,
      decimals: decimals,
      active: active,
      onTap: onTap,
      onSubmit: onSubmit,
      onIncrement: onIncrement,
      onDecrement: onDecrement,
      showIncrementButtons: showIncrementButtons,
    );
  }


  Widget _buildOscilloscope(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
          width: double.infinity,
          child: Obx(() => CustomPaint(
            painter: OscilloscopePainter(
              engine: controller.painterEngine,
              signalColor: AppColor.bondiBlue,
              gridColor: Colors.white12,
              timeScale: controller.oscTimeScale.value,
            ),
            willChange: true,
          )),
        ),
        Row(
          children: [
            const SizedBox(width: 8),
            Icon(Icons.speed, color: Colors.white24, size: 14),
            const SizedBox(width: 4),
            const Text('TIME', style: TextStyle(color: Colors.white24, fontSize: 9, letterSpacing: 1)),
            SizedBox(
              width: 120,
              child: Obx(() => Slider(
                value: controller.oscTimeScale.value,
                min: 0.15,
                max: 2.0,
                activeColor: AppColor.bondiBlue.withAlpha(100),
                inactiveColor: Colors.white10,
                onChanged: (v) => controller.oscTimeScale.value = v,
              )),
            ),
            Obx(() => Text(
              '${controller.oscTimeScale.value.toStringAsFixed(2)}x',
              style: const TextStyle(fontFamily: 'Courier', color: Colors.white30, fontSize: 9),
            )),
            const Spacer(),
            IconButton(
              icon: const Icon(Icons.fullscreen, color: AppColor.bondiBlue, size: 18),
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
            child: Obx(() => Slider(
              value: controller.currentFreq.value.clamp(
                NeomGeneratorConstants.frequencyMin.toDouble(),
                NeomGeneratorConstants.frequencyLimit.toDouble(),
              ),
              min: NeomGeneratorConstants.frequencyMin.toDouble(),
              max: NeomGeneratorConstants.frequencyLimit.toDouble(),
              activeColor: AppColor.bondiBlue,
              inactiveColor: Colors.white12,
              onChanged: (val) => controller.setFrequency(val),
            )),
          ),
          const SizedBox(width: 8),
          // Binaural Beat slider (reversed: right-to-left, high→low)
          Expanded(
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Obx(() => Slider(
                value: controller.currentBeat.value.clamp(0.0, NeomGeneratorConstants.binauralBeatMax.toDouble()),
                min: 0.0,
                max: NeomGeneratorConstants.binauralBeatMax.toDouble(),
                activeColor: Colors.purpleAccent,
                inactiveColor: Colors.white12,
                onChanged: (val) => controller.setBinauralBeat(beat: val),
              )),
            ),
          ),
        ],
      ),
    );
  }

  /// Octave shift selector — sub-octaves (purple) + super-octaves (blue).
  Widget _buildOctaveSelector() {
    const octaves = [-4, -3, -2, -1, 0, 1, 2, 3, 4];
    const labels = ['/16', '/8', '/4', '/2', '1x', '2x', '4x', '8x', '16x'];

    return Obx(() {
      final isShifted = controller.currentOctave.value != 0;
      final isDown = controller.currentOctave.value < 0;
      final accentColor = isDown ? Colors.purpleAccent : AppColor.bondiBlue;

      return Row(
      children: [
        Icon(Icons.layers_outlined,
          color: isShifted ? accentColor : AppColor.bondiBlue.withAlpha(120), size: 14),
        const SizedBox(width: 6),
        Text(
          GeneratorTranslationConstants.octave.tr.toUpperCase(),
          style: TextStyle(
            color: isShifted ? accentColor.withAlpha(200) : Colors.white38,
            fontSize: 9, letterSpacing: 1.5,
            fontWeight: isShifted ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(octaves.length, (i) {
                final oct = octaves[i];
                final active = controller.currentOctave.value == oct;
                final isDown = oct < 0;
                return Padding(
                  padding: const EdgeInsets.only(right: 3),
                  child: MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => controller.setOctave(oct),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 150),
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                        decoration: BoxDecoration(
                          color: active
                              ? (isDown ? Colors.deepPurple.withAlpha(60) : AppColor.bondiBlue.withAlpha(50))
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(
                            color: active
                                ? (isDown ? Colors.deepPurple.withAlpha(140) : AppColor.bondiBlue.withAlpha(140))
                                : Colors.white.withAlpha(15),
                            width: 0.5,
                          ),
                        ),
                        child: Text(
                          labels[i],
                          style: TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 10,
                            color: active ? Colors.white : (isDown ? Colors.white24 : Colors.white30),
                            fontWeight: active ? FontWeight.bold : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          '${controller.effectiveFrequency.toStringAsFixed(1)} Hz',
          style: TextStyle(
            fontFamily: 'Courier',
            fontSize: isShifted ? 11 : 10,
            fontWeight: isShifted ? FontWeight.bold : FontWeight.normal,
            color: isShifted ? accentColor : AppColor.bondiBlue.withAlpha(160),
          ),
        ),
      ],
    );
    });
  }

  /// INCIENSO session status bar: neuro state, elapsed time, incienso count, coherence.
  Widget _buildSessionStatus() {
    return Obx(() {
      final playing = controller.isPlaying.value;
      final state = controller.neuroState.value;
      final now = DateTime.now();
      final elapsed = playing && controller.sessionStartedAt != null
          ? now.difference(controller.sessionStartedAt!).inSeconds
          : 0;
      final incCount = controller.inciensoCount;
      final coherence = controller.painterEngine.hemisphericCoherence;
      final breathCycles = controller.inciensoTracker.totalCycles;

      final minutes = elapsed ~/ 60;
      final seconds = elapsed % 60;
      final timeStr = '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';

      const stateColors = {
        NeomNeuroState.sleep: Color(0xFF6C63FF),
        NeomNeuroState.calm: Color(0xFF4FC3F7),
        NeomNeuroState.neutral: Color(0xFF00BCD4),
        NeomNeuroState.creativity: Color(0xFFAB47BC),
        NeomNeuroState.focus: Color(0xFF66BB6A),
        NeomNeuroState.integration: Color(0xFFFFB74D),
      };
      final stateColor = playing ? (stateColors[state] ?? AppColor.bondiBlue) : Colors.white24;

      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: playing ? stateColor.withAlpha(10) : Colors.white.withAlpha(3),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: playing ? stateColor.withAlpha(40) : Colors.white.withAlpha(8)),
        ),
        child: Row(
          children: [
            // State indicator dot
            Container(
              width: 8, height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: playing ? stateColor : Colors.white12,
                boxShadow: playing ? [BoxShadow(color: stateColor.withAlpha(80), blurRadius: 6)] : null,
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
              Text('$breathCycles',
                  style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: stateColor.withAlpha(160))),
              const SizedBox(width: 12),
            ],
            // Incienso count
            if (playing && incCount > 0) ...[
              Icon(Icons.local_fire_department, size: 12, color: const Color(0xFFFF6D00).withAlpha(160)),
              const SizedBox(width: 4),
              Text('$incCount',
                  style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: const Color(0xFFFF6D00).withAlpha(160))),
              const SizedBox(width: 12),
            ],
            // Coherence
            if (playing) ...[
              Text('${(coherence * 100).toInt()}%',
                  style: TextStyle(fontFamily: 'Courier', fontSize: 10, color: stateColor.withAlpha(140))),
              const SizedBox(width: 12),
            ],
            // Timer
            Icon(Icons.timer_outlined, size: 14,
                color: playing ? Colors.white54 : Colors.white12),
            const SizedBox(width: 6),
            Text(
              timeStr,
              style: TextStyle(
                fontFamily: 'Courier',
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: playing ? Colors.white : Colors.white24,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
      );
    });
  }


  /// Voice detection button for web.
  Widget _buildVoiceAndChamberRow() {
    return Obx(() => GestureDetector(
      onTap: () {
        if (controller.isRecording.value) {
          controller.stopRecording();
        } else {
          controller.startRecording();
        }
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
        decoration: BoxDecoration(
          color: controller.isRecording.value
              ? Colors.red.withAlpha(30)
              : Colors.white.withAlpha(5),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: controller.isRecording.value ? Colors.red : Colors.white.withAlpha(15),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              FontAwesomeIcons.microphone,
              size: 14,
              color: controller.isRecording.value ? Colors.red : Colors.white54,
            ),
            const SizedBox(width: 8),
            Text(
              controller.isRecording.value
                  ? '${GeneratorTranslationConstants.detecting.tr.toUpperCase()}: ${controller.detectedFrequency.value.toInt()} Hz'
                  : GeneratorTranslationConstants.detectMyVoice.tr.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                color: controller.isRecording.value ? Colors.red : Colors.white54,
                letterSpacing: 1,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    ));
  }

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
      child: AnimatedBuilder(
        animation: controller.painterEngine,
        builder: (_, _) => CustomPaint(
          painter: LissajousPainter(
            engine: controller.painterEngine,
            color: AppColor.bondiBlue,
          ),
        ),
      ),
    );
  }

}

/// Om button with binaural-beat-synced pulsing glow when playing.
class _OmButton extends StatefulWidget {
  final NeomGeneratorController controller;
  const _OmButton({required this.controller});

  @override
  State<_OmButton> createState() => _OmButtonState();
}

class _OmButtonState extends State<_OmButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseCtrl;
  final List<StreamSubscription> _subs = [];

  @override
  void initState() {
    super.initState();
    _pulseCtrl = AnimationController(vsync: this);
    _syncPulseDuration();

    _subs.add(widget.controller.currentBeat.listen((_) => _syncPulseDuration()));
    _subs.add(widget.controller.isPlaying.listen((playing) {
      if (playing) {
        _pulseCtrl.repeat(reverse: true);
      } else {
        _pulseCtrl.stop();
        _pulseCtrl.value = 0;
      }
    }));

    if (widget.controller.isPlaying.value) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  void _syncPulseDuration() {
    final beat = widget.controller.currentBeat.value.clamp(0.5, 50.0);
    final ms = (1000 / beat).round().clamp(100, 2000);
    _pulseCtrl.duration = Duration(milliseconds: ms);
    if (_pulseCtrl.isAnimating) {
      _pulseCtrl.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    for (final sub in _subs) {
      sub.cancel();
    }
    _pulseCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final playing = widget.controller.isPlaying.value;

      return AnimatedBuilder(
        animation: _pulseCtrl,
        builder: (_, _) {
          final pulse = playing ? _pulseCtrl.value : 0.0;
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
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: () async => await widget.controller.playStopPreview(),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Icon(
                  FontAwesomeIcons.om,
                  size: 50,
                  color: playing
                      ? Color.lerp(Colors.white70, AppColor.bondiBlue, pulse)
                      : Colors.white54,
                ),
              ),
            ),
          );
        },
      );
    });
  }
}

/// Inline-editable frequency box. Double-click toggles between
/// display mode and a text field inside the same container.
class _InlineEditableFreqBox extends StatefulWidget {
  final String label;
  final double value;
  final String suffix;
  final int decimals;
  final bool active;
  final VoidCallback onTap;
  final Function(String) onSubmit;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final bool showIncrementButtons;

  const _InlineEditableFreqBox({
    required this.label,
    required this.value,
    required this.suffix,
    required this.decimals,
    required this.active,
    required this.onTap,
    required this.onSubmit,
    this.onIncrement,
    this.onDecrement,
    this.showIncrementButtons = false,
  });

  @override
  State<_InlineEditableFreqBox> createState() => _InlineEditableFreqBoxState();
}

class _InlineEditableFreqBoxState extends State<_InlineEditableFreqBox> {
  bool _editing = false;
  late final TextEditingController _textCtrl;
  late final FocusNode _focusNode;

  /// Format value avoiding "-0.0" display.
  static String _formatValue(double value, int decimals) {
    // Avoid displaying "-0.0" or "-0"
    if (value.abs() < 0.05 && decimals <= 1) return (0.0).toStringAsFixed(decimals);
    return value.toStringAsFixed(decimals);
  }

  @override
  void initState() {
    super.initState();
    _textCtrl = TextEditingController();
    _focusNode = FocusNode();
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) {
        _finishEdit();
      }
    });
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _startEdit() {
    setState(() {
      _editing = true;
      _textCtrl.text = _formatValue(widget.value, widget.decimals);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
      _textCtrl.selection = TextSelection(
        baseOffset: 0,
        extentOffset: _textCtrl.text.length,
      );
    });
  }

  void _finishEdit() {
    if (!_editing) return;
    widget.onSubmit(_textCtrl.text);
    setState(() => _editing = false);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(128),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: widget.active
                ? AppColor.bondiBlue
                : AppColor.bondiBlue.withAlpha(100),
          ),
        ),
        child: Column(
          children: [
            Text(
              widget.label,
              style: const TextStyle(
                color: Colors.white70, fontSize: 10, letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.showIncrementButtons)
                  _buildIncrementBtn(Icons.remove, widget.onDecrement),
                Expanded(
                  child: GestureDetector(
                    onDoubleTap: _startEdit,
                    child: _editing
                      ? TextField(
                          controller: _textCtrl,
                          focusNode: _focusNode,
                          textAlign: TextAlign.center,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                          decoration: InputDecoration(
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                            suffixText: widget.suffix,
                            suffixStyle: const TextStyle(
                              color: Colors.white54, fontSize: 14,
                            ),
                            border: InputBorder.none,
                          ),
                          onSubmitted: (_) => _finishEdit(),
                        )
                      : Text(
                          '${_formatValue(widget.value, widget.decimals)} ${widget.suffix}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontFamily: 'Courier',
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                  ),
                ),
                if (widget.showIncrementButtons)
                  _buildIncrementBtn(Icons.add, widget.onIncrement),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildIncrementBtn(IconData icon, VoidCallback? onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white24),
          ),
          child: Icon(icon, size: 16, color: Colors.white70),
        ),
      ),
    );
  }
}
