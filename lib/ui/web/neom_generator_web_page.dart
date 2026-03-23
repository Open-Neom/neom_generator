import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:neom_commons/domain/extensions/double_extensions.dart';
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
import '../../utils/enums/neom_frequency_target.dart';
import '../../utils/enums/neom_numeric_target.dart';
import '../neom_generator_controller.dart';
import '../painters/frequency_painter.dart';
import '../painters/lissajous_painter.dart';
import '../painters/neom_binaural_beat_painter.dart';
import '../painters/oscilloscope_painter.dart';
import '../panels/neom_breath_control_panel.dart';
import '../panels/neom_modulation_control_panel.dart';
import '../panels/neom_neuro_state_control_panel.dart';
import '../panels/neom_spatial_control_panel.dart';
import '../widgets/generator_widgets.dart';
import 'package:neom_states/data/state_catalog.dart';
import 'package:neom_states/domain/models/frequency_state.dart';
// import '../widgets/session_time_meter.dart'; // TODO: create web version

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
        actions: controller.userServiceImpl != null
            ? [
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
              ]
            : null,
      ),
      body: Container(
        decoration: AppTheme.appBoxDecoration,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ═══ LEFT: Modulación / Espacialidad + Experiencias ═══
              Flexible(
                flex: 1,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildPanel(
                        '${GeneratorTranslationConstants.modulation.tr} / ${GeneratorTranslationConstants.spatiality.tr}',
                        Column(
                          children: [
                            NeomModulationControlPanel(),
                            const SizedBox(height: 8),
                            NeomSpatialControlPanel(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Immersive experiences
                      _buildPanel(
                        'EXPERIENCIAS',
                        Column(
                          children: [
                            _experienceChip(
                              icon: Icons.blur_on,
                              label: GeneratorTranslationConstants.neuroFlocking.tr,
                              color: Colors.cyan,
                              onTap: () => Sint.toNamed(AppRouteConstants.flockingFullscreen),
                            ),
                            const SizedBox(height: 8),
                            _experienceChip(
                              icon: Icons.self_improvement,
                              label: GeneratorTranslationConstants.neuroBreathing.tr,
                              color: Colors.green,
                              onTap: () => Sint.toNamed(AppRouteConstants.breathingFullscreen),
                            ),
                            const SizedBox(height: 8),
                            _experienceChip(
                              icon: Icons.auto_awesome,
                              label: 'Fractales',
                              color: Colors.purple,
                              onTap: () => Sint.toNamed(AppRouteConstants.fractalFullscreen),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ═══ CENTER: Sleek + Oscilloscope (protagonist) ═══
              Flexible(
                flex: 2,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      // Frequency painter strip
                      SizedBox(
                        height: 6,
                        width: double.infinity,
                        child: CustomPaint(
                          painter: FrequencyPainter(
                            engine: controller.painterEngine,
                            color: AppColor.bondiBlue,
                          ),
                          willChange: true,
                        ),
                      ),
                      const SizedBox(height: 2),
                      SizedBox(
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
                      ),
                      const SizedBox(height: 8),

                      // Circular sliders — the main controller
                      _buildCircularSliders(context),

                      const SizedBox(height: 12),

                      // Frequency + Beat displays
                      _buildFrequencyDisplays(context),

                      const SizedBox(height: 12),

                      // Oscilloscope — full width under the sliders
                      _buildPanel(
                        GeneratorTranslationConstants.neuroHarmonicOscilloscope.tr,
                        _buildOscilloscope(context),
                      ),

                      const SizedBox(height: 12),

                      // Coherence + Lissajous row
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: _buildPanel(
                            GeneratorTranslationConstants.coherenceMeter.tr,
                            _buildCoherence(context),
                          )),
                          const SizedBox(width: 12),
                          Expanded(child: _buildPanel(
                            'LISSAJOUS',
                            _buildLissajous(context),
                          )),
                        ],
                      ),

                    ],
                  ),
                ),
              ),

              const SizedBox(width: 12),

              // ═══ RIGHT: Respiración / Neuroarmonía + States ═══
              Flexible(
                flex: 1,
                child: SingleChildScrollView(
                  child: Column(
                    children: [
                      _buildPanel(
                        '${GeneratorTranslationConstants.breathing.tr} / ${GeneratorTranslationConstants.neuroharmony.tr}',
                        Column(
                          children: [
                            NeomBreathControlPanel(),
                            const SizedBox(height: 8),
                            NeomNeuroStateControlPanel(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Quick-start states
                      _buildPanel(
                        'ESTADOS',
                        _buildStatesQuickStart(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Reusable panel container with title header.
  Widget _buildPanel(String title, Widget content) {
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
          Text(
            title.toUpperCase(),
            style: const TextStyle(
              color: Colors.white54,
              fontSize: 11,
              letterSpacing: 1.2,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          content,
        ],
      ),
    );
  }

  Widget _buildCircularSliders(BuildContext context) {
    return Obx(() {
      String note = getNoteFromFrequency(controller.currentFreq.value);
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
              initialValue: controller.posX.value,
              onChange: (double val) {
                controller.setParameterPosition(
                  x: val, y: controller.posY.value, z: controller.posZ.value);
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
                              child: Ink(
                                decoration: BoxDecoration(
                                  color: controller.isPlaying.value
                                      ? AppColor.deepDarkViolet
                                      : Colors.transparent,
                                  shape: BoxShape.circle,
                                ),
                                child: InkWell(
                                  child: IconButton(
                                    onPressed: () async =>
                                        await controller.playStopPreview(),
                                    icon: const Icon(FontAwesomeIcons.om, size: 50),
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
      );
    });
  }

  Widget _buildFrequencyDisplays(BuildContext context) {
    return Obx(() {
      String note = getNoteFromFrequency(controller.currentFreq.value);
      return Row(
        children: [
          Expanded(child: _freqBox(
            AppTranslationConstants.rootFrequency.tr.toUpperCase(),
            '${controller.currentFreq.value.toStringAsFixed(0)} Hz',
            controller.activeNumericTarget.value == NeomNumericTarget.rootFrequency,
            onTap: controller.selectRootFrequency,
          )),
          const SizedBox(width: 8),
          Expanded(child: _freqBox(
            AppTranslationConstants.binauralBeat.tr.toUpperCase(),
            '${controller.currentBeat.value.toStringAsFixed(1)} Hz',
            controller.activeNumericTarget.value == NeomNumericTarget.binauralBeat,
            onTap: () {
              if (controller.selectedTarget.value == NeomFrequencyTarget.binaural) {
                controller.increaseSelected();
              } else {
                controller.selectBinauralBeat();
                controller.increaseSelected();
              }
            },
          )),
        ],
      );
    });
  }

  Widget _freqBox(String label, String value, bool active, {VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.black.withAlpha(128),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: active ? AppColor.bondiBlue : AppColor.bondiBlue.withAlpha(100),
          ),
        ),
        child: Column(
          children: [
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10, letterSpacing: 1.2)),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(
              fontFamily: 'Courier', fontSize: 22, fontWeight: FontWeight.bold, color: Colors.white)),
          ],
        ),
      ),
    );
  }

  Widget _buildOscilloscope(BuildContext context) {
    return Column(
      children: [
        SizedBox(
          height: 160,
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
        Align(
          alignment: Alignment.centerRight,
          child: IconButton(
            icon: const Icon(Icons.fullscreen, color: AppColor.bondiBlue, size: 18),
            onPressed: () => Sint.toNamed(
              AppRouteConstants.oscilloscopeFullscreen,
              arguments: controller.painterEngine,
            ),
            tooltip: 'Fullscreen',
          ),
        ),
      ],
    );
  }

  Widget _buildCoherence(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: coherenceMeter(controller.painterEngine),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 60,
          width: double.infinity,
          child: CustomPaint(
            painter: FrequencyPainter(
              engine: controller.painterEngine,
              color: AppColor.bondiBlue,
            ),
            willChange: true,
          ),
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
        builder: (_, __) => CustomPaint(
          painter: LissajousPainter(
            engine: controller.painterEngine,
            color: AppColor.bondiBlue,
          ),
        ),
      ),
    );
  }

  /// Quick-start frequency states (right panel).
  Widget _buildStatesQuickStart() {
    final locale = Sint.locale?.languageCode ?? 'es';
    final states = StateCatalog.free;
    return Column(
      children: states.map((state) => _stateChip(state, locale)).toList(),
    );
  }

  Widget _stateChip(FrequencyState state, String locale) {
    final name = state.names[locale] ?? state.names['es'] ?? state.id;
    final beatHz = (state.rightFrequency - state.leftFrequency).abs();
    final minutes = state.duration.inMinutes;
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GestureDetector(
        onTap: () => Sint.toNamed('/x/${state.id}'),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: state.screenColor.withAlpha(15),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: state.screenColor.withAlpha(40)),
            ),
            child: Row(
              children: [
                Icon(state.icon, color: state.screenColor, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(name, style: TextStyle(color: state.screenColor, fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis),
                      Text('${beatHz.toStringAsFixed(0)} Hz · $minutes min',
                          style: TextStyle(color: state.screenColor.withAlpha(120), fontSize: 10)),
                    ],
                  ),
                ),
                Icon(Icons.play_circle_outline, color: state.screenColor.withAlpha(100), size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _experienceChip({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: color.withAlpha(15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withAlpha(50)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: color, size: 18),
              const SizedBox(width: 8),
              Text(label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w500)),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_ios, color: color.withAlpha(100), size: 10),
            ],
          ),
        ),
      ),
    );
  }
}
