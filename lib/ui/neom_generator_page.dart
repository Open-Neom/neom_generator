// Necesario para calcular la nota musical

import 'dart:async';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_color.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:neom_commons/ui/widgets/read_more_container.dart';
import 'package:neom_commons/utils/auth_guard.dart';
import 'package:neom_commons/utils/constants/app_page_id_constants.dart';
import 'package:neom_commons/utils/constants/translations/app_translation_constants.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:sint/sint.dart';
import 'package:sleek_circular_slider/sleek_circular_slider.dart';

import '../engine/neom_frequency_painter_engine.dart';
import '../utils/constants/generator_translation_constants.dart';
import '../utils/constants/neom_generator_constants.dart';
import '../utils/constants/neom_slider_constants.dart';
import '../utils/enums/neom_numeric_target.dart';
import 'neom_generator_controller.dart';
import 'painters/lissajous_painter.dart';
import 'painters/mic_waveform_painter.dart';
import 'painters/oscilloscope_painter.dart';
import 'panels/neom_breath_control_panel.dart';
import 'panels/neom_modulation_control_panel.dart';
import 'panels/neom_neuro_state_control_panel.dart';
import 'panels/neom_spatial_control_panel.dart';
import 'web/neom_generator_web_page.dart';
import 'widgets/camara_neom_tutorial.dart';
import 'widgets/chamber_controls.dart';
import 'widgets/chamber_practice_tools.dart';
import 'widgets/generator_widgets.dart';
import 'widgets/incienso_review_modal.dart';
import 'widgets/signal_paint.dart';
import 'widgets/visual_animation.dart';

class NeomGeneratorPage extends StatelessWidget {
  final bool showAppBar;

  const NeomGeneratorPage({super.key, this.showAppBar = true});

  Widget _sectionTitle(String title, String tooltip) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Tooltip(
          message: tooltip,
          preferBelow: true,
          showDuration: const Duration(seconds: 8),
          child: const Padding(
            padding: EdgeInsets.only(left: 8),
            child: Icon(Icons.info_outline, size: 14, color: Colors.white24),
          ),
        ),
      ],
    );
  }

  void _navigateHome(NeomGeneratorController controller) {
    // Keep the persistent engine running; the home mini player owns Stop.
    unawaited(controller.stopRecording(applyDetectedFrequency: false));
    Sint.offAllNamed(AppRouteConstants.home);
  }

  Widget _mobileControls(
    BuildContext context,
    NeomGeneratorController controller,
  ) => SafeArea(
    top: false,
    child: Container(
      decoration: AppTheme.appBoxDecoration,
      child: SingleChildScrollView(
        key: const ValueKey('chamber-mobile-scroll'),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 760),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Obx(
                  () => ChamberFeedback(
                    playbackError: controller.playbackError.value,
                    saveError: controller.recordingSaveError.value,
                    onRetrySave: controller.retryPendingRecordings,
                  ),
                ),
                _voiceControl(controller),
                ChamberPracticeClock(controller: controller, compact: true),
                const SizedBox(height: 4),
                LayoutBuilder(
                  builder: (context, constraints) => Center(
                    child: _dial(
                      context,
                      controller,
                      constraints.maxWidth.clamp(180.0, 236.0),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                _frequencyControls(controller),
                const SizedBox(height: 10),
                _oscilloscope(controller),
                const SizedBox(height: 8),
                Obx(
                  () => ChamberOctaveControl(
                    compact: true,
                    octave: controller.currentOctave.value,
                    effectiveFrequency: controller.effectiveFrequency,
                    onChanged: controller.setOctave,
                  ),
                ),
                const SizedBox(height: 8),
                _volumeControl(controller),
                ChamberPracticeToolbar(controller: controller, compact: true),
                const SizedBox(height: 4),
                _experiences(controller),
                ExpansionTile(
                  key: const PageStorageKey('chamber-mobile-modulation'),
                  title: _sectionTitle(
                    "${GeneratorTranslationConstants.modulation.tr} / ${GeneratorTranslationConstants.spatiality.tr}",
                    '${GeneratorTranslationConstants.helpModulation.tr}\n\n${GeneratorTranslationConstants.helpSpatiality.tr}',
                  ),
                  children: const [
                    NeomModulationControlPanel(),
                    SizedBox(height: 8),
                    NeomSpatialControlPanel(),
                  ],
                ),
                ExpansionTile(
                  key: const PageStorageKey('chamber-mobile-breathing'),
                  title: _sectionTitle(
                    "${GeneratorTranslationConstants.breathing.tr} / ${GeneratorTranslationConstants.neuroharmony.tr}",
                    '${GeneratorTranslationConstants.helpBreathing.tr}\n\n${GeneratorTranslationConstants.helpNeuroState.tr}',
                  ),
                  children: const [
                    NeomBreathControlPanel(),
                    SizedBox(height: 8),
                    NeomNeuroStateControlPanel(),
                  ],
                ),
                _signalDetails(controller),
                Obx(
                  () => controller.frequencyDescription.isEmpty
                      ? const SizedBox.shrink()
                      : Padding(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          child: ReadMoreContainer(
                            text: controller.frequencyDescription.value,
                            fontSize: 13,
                            trimLines: 3,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _voiceControl(NeomGeneratorController controller) => Obx(() {
    final recording = controller.isRecording.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton.tonalIcon(
          key: const ValueKey('chamber-mobile-detect-voice'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          ),
          onPressed: () => recording
              ? controller.stopRecording(applyDetectedFrequency: false)
              : controller.startRecording(),
          icon: Icon(
            recording ? Icons.stop : Icons.mic,
            color: recording ? Colors.redAccent : null,
          ),
          label: Text(
            recording
                ? '${GeneratorTranslationConstants.stopVoiceDetection.tr} · ${controller.detectedFrequency.value.toStringAsFixed(1)} Hz'
                : GeneratorTranslationConstants.detectMyVoice.tr,
            textAlign: TextAlign.center,
          ),
        ),
        if (recording)
          Container(
            key: const ValueKey('chamber-mobile-mic-wave'),
            height: 40,
            margin: const EdgeInsets.only(top: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: .3),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red.withValues(alpha: .3)),
            ),
            child: Obx(
              () => CustomPaint(
                painter: MicWaveformPainter(
                  bars: controller.micWaveform.toList(),
                  color: Colors.red.withValues(alpha: .8),
                ),
                size: Size.infinite,
              ),
            ),
          ),
      ],
    );
  });

  Widget _dial(
    BuildContext context,
    NeomGeneratorController controller,
    double diameter,
  ) => Obx(() {
    // Capture configuration before the nested slider builders run later.
    final posX = controller.posX.value;
    final posY = controller.posY.value;
    final posZ = controller.posZ.value;
    CircularSliderAppearance appearance(
      double fraction,
      double start,
      double range,
      CustomSliderWidths widths,
      CustomSliderColors colors,
    ) => CircularSliderAppearance(
      size: diameter * fraction,
      startAngle: start,
      angleRange: range,
      customWidths: widths,
      customColors: colors,
      animationEnabled: false,
    );
    return SizedBox(
      key: const ValueKey('chamber-mobile-dial'),
      width: diameter,
      height: diameter,
      child: SleekCircularSlider(
        appearance: appearance(
          1,
          180,
          360,
          NeomSliderConstants.customWidth01,
          NeomSliderConstants.customColors01,
        ),
        min: NeomGeneratorConstants.frequencyMin,
        max: controller.isAdmin
            ? NeomGeneratorConstants.frequencyMax
            : NeomGeneratorConstants.frequencyLimit,
        initialValue: controller.currentFreq.value,
        onChange: controller.setFrequency,
        innerWidget: (_) => Center(
          child: SleekCircularSlider(
            appearance: appearance(
              .82,
              360,
              180,
              NeomSliderConstants.customWidth02,
              NeomSliderConstants.customColors02,
            ),
            min: NeomGeneratorConstants.positionMin,
            max: NeomGeneratorConstants.positionMax,
            initialValue: -posX,
            onChange: (value) => controller.setParameterPosition(
              x: -value,
              y: controller.posY.value,
              z: controller.posZ.value,
            ),
            innerWidget: (_) => Center(
              child: SleekCircularSlider(
                appearance: appearance(
                  .59,
                  90,
                  270,
                  NeomSliderConstants.customWidth03,
                  NeomSliderConstants.customColors03,
                ),
                min: NeomGeneratorConstants.positionMin,
                max: NeomGeneratorConstants.positionMax,
                initialValue: posY,
                onChange: (value) => controller.setParameterPosition(
                  x: controller.posX.value,
                  y: value,
                  z: controller.posZ.value,
                ),
                innerWidget: (_) => Center(
                  child: SleekCircularSlider(
                    appearance: appearance(
                      .40,
                      270,
                      270,
                      NeomSliderConstants.customWidth04,
                      NeomSliderConstants.customColors04,
                    ),
                    min: NeomGeneratorConstants.positionMin,
                    max: NeomGeneratorConstants.positionMax,
                    initialValue: posZ,
                    onChange: (value) => controller.setParameterPosition(
                      x: controller.posX.value,
                      y: controller.posY.value,
                      z: value,
                    ),
                    innerWidget: (_) => Center(
                      // The slider builds its center lazily; observe playback
                      // here so Stop remains reactive without a frequency edit.
                      child: Obx(
                        () => ChamberPlaybackButton(
                          requested: controller.playbackRequested.value,
                          transitioning:
                              controller.isPlaybackTransitioning.value,
                          onPressed: () async {
                            final wasPlaying = controller.isPlaying.value;
                            await controller.playStopPreview();
                            if (wasPlaying &&
                                !controller.playbackRequested.value &&
                                context.mounted) {
                              await _askForReview(context, controller);
                            }
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  });

  Widget _frequencyControls(
    NeomGeneratorController controller,
  ) => LayoutBuilder(
    builder: (context, constraints) => Obx(() {
      final cards = [
        ChamberFrequencyControl(
          key: const ValueKey('chamber-mobile-root'),
          compact: true,
          label: AppTranslationConstants.rootFrequency.tr,
          value: controller.currentFreq.value,
          selected:
              controller.activeNumericTarget.value ==
              NeomNumericTarget.rootFrequency,
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
          key: const ValueKey('chamber-mobile-beat'),
          compact: true,
          label: AppTranslationConstants.binauralBeat.tr,
          value: controller.currentBeat.value,
          selected:
              controller.activeNumericTarget.value ==
              NeomNumericTarget.binauralBeat,
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
      final stacked =
          constraints.maxWidth < 328 ||
          MediaQuery.textScalerOf(context).scale(12) > 18;
      return stacked
          ? Column(children: [cards[0], const SizedBox(height: 8), cards[1]])
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: cards[0]),
                const SizedBox(width: 8),
                Expanded(child: cards[1]),
              ],
            );
    }),
  );

  Widget _oscilloscope(NeomGeneratorController controller) => Container(
    key: const ValueKey('chamber-mobile-oscilloscope'),
    padding: const EdgeInsets.fromLTRB(10, 8, 10, 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: .2),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white12),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _sectionTitle(
          GeneratorTranslationConstants.neuroHarmonicOscilloscope.tr,
          GeneratorTranslationConstants.helpOscilloscope.tr,
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            SizedBox(
              height: 112,
              width: double.infinity,
              child: Obx(
                () => SignalPaint(
                  active: controller.isPlaying.value,
                  builder: (repaint) => OscilloscopePainter(
                    engine: controller.painterEngine,
                    signalColor: AppColor.bondiBlue,
                    gridColor: Colors.white12,
                    repaint: repaint,
                  ),
                ),
              ),
            ),
            Positioned(
              right: 0,
              bottom: 0,
              child: IconButton(
                tooltip:
                    GeneratorTranslationConstants.neuroHarmonicOscilloscope.tr,
                style: IconButton.styleFrom(
                  backgroundColor: Colors.black54,
                  minimumSize: const Size(48, 48),
                ),
                icon: const Icon(Icons.fullscreen, color: AppColor.bondiBlue),
                onPressed: () => Sint.toNamed(
                  AppRouteConstants.oscilloscopeFullscreen,
                  arguments: controller.painterEngine,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Widget _volumeControl(NeomGeneratorController controller) => Obx(
    () => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(child: Text(AppTranslationConstants.volume.tr)),
            Text('${(controller.currentVol.value * 100).round()}%'),
          ],
        ),
        Slider(
          value: controller.currentVol.value,
          min: NeomGeneratorConstants.volumeMin,
          max: NeomGeneratorConstants.volumeMax,
          semanticFormatterCallback: (value) =>
              '${AppTranslationConstants.volume.tr}: ${(value * 100).round()}%',
          onChanged: controller.setVolume,
        ),
      ],
    ),
  );

  Widget _experiences(NeomGeneratorController controller) => ExpansionTile(
    key: const PageStorageKey('chamber-mobile-experiences'),
    title: Text(GeneratorTranslationConstants.experiences.tr),
    leading: const Icon(Icons.auto_awesome),
    childrenPadding: const EdgeInsets.only(bottom: 8),
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final experiences = [
            (
              Icons.scatter_plot,
              AppTranslationConstants.attention.tr,
              AppRouteConstants.flockingFullscreen,
            ),
            (
              Icons.vrpano,
              GeneratorTranslationConstants.spatiality.tr,
              AppRouteConstants.spatial360Fullscreen,
            ),
            (
              Icons.air,
              GeneratorTranslationConstants.breathing.tr,
              AppRouteConstants.breathingFullscreen,
            ),
            (
              Icons.view_in_ar,
              AppTranslationConstants.virtualReality.tr,
              AppRouteConstants.vr360StereoFullscreen,
            ),
            (
              Icons.grain,
              GeneratorTranslationConstants.fractalVisualization.tr,
              AppRouteConstants.fractalFullscreen,
            ),
            (
              Icons.grid_on,
              GeneratorTranslationConstants.neomatics.tr,
              AppRouteConstants.neomaticsFullscreen,
            ),
            (
              Icons.blur_circular,
              GeneratorTranslationConstants.neuroMandala.tr,
              AppRouteConstants.neuromandalaFullscreen,
            ),
          ];
          final columns = MediaQuery.textScalerOf(context).scale(12) > 18
              ? 1
              : (constraints.maxWidth >= 600 ? 3 : 2);
          final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
          return Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final experience in experiences)
                SizedBox(
                  width: width,
                  child: OutlinedButton(
                    key: ValueKey('chamber-mobile-experience-${experience.$3}'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 64),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    onPressed: () => Sint.toNamed(
                      experience.$3,
                      arguments:
                          experience.$3 == AppRouteConstants.fractalFullscreen
                          ? [controller.painterEngine]
                          : controller.painterEngine,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(experience.$1, size: 20),
                        const SizedBox(height: 4),
                        Text(experience.$2, textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    ],
  );

  Widget _signalDetails(NeomGeneratorController controller) => ExpansionTile(
    key: const PageStorageKey('chamber-mobile-signal-details'),
    title: _sectionTitle(
      GeneratorTranslationConstants.coherenceMeter.tr,
      GeneratorTranslationConstants.helpCoherence.tr,
    ),
    children: [
      Obx(
        () => Column(
          children: [
            ChamberParameterLabel(
              GeneratorTranslationConstants.surroundSound.tr,
              'X ${controller.posX.value.toStringAsFixed(2)} · Y ${controller.posY.value.toStringAsFixed(2)} · Z ${controller.posZ.value.toStringAsFixed(2)}',
            ),
            ChamberParameterLabel(
              AppTranslationConstants.musicalNote.tr,
              getNoteFromFrequency(controller.currentFreq.value),
            ),
            ChamberParameterLabel(
              GeneratorTranslationConstants.waveLength.tr,
              controller.currentFreq.value > 0
                  ? '${((343 / controller.currentFreq.value) * 100).toStringAsFixed(2)} cm'
                  : '—',
            ),
          ],
        ),
      ),
      coherenceMeter(controller.painterEngine),
      SizedBox(
        height: 140,
        width: double.infinity,
        child: Obx(
          () => SignalPaint(
            active: controller.isPlaying.value,
            builder: (repaint) => LissajousPainter(
              engine: controller.painterEngine,
              color: controller.painterEngine.eegColor,
              useEngineColor: true,
              repaint: repaint,
            ),
            size: Size.infinite,
          ),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return VisualActivityScope(
      child: _PageWithTutorial(
        child: SintBuilder<NeomGeneratorController>(
          id: AppPageIdConstants.generator,
          init: Sint.isRegistered<NeomGeneratorController>()
              ? null
              : NeomGeneratorController(),
          builder: (controller) => PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, result) async {
              if (!didPop) {
                _navigateHome(controller);
              }
            },
            child: kIsWeb && MediaQuery.of(context).size.width > 900
                ? NeomGeneratorWebPage(controller: controller)
                : Scaffold(
                    appBar: showAppBar
                        ? SintAppBar(
                            title: GeneratorTranslationConstants.neomChamber.tr,
                            centerTitle: true,
                            leading: IconButton(
                              tooltip: GeneratorTranslationConstants
                                  .homeKeepAudio
                                  .tr,
                              icon: const Icon(
                                Icons.arrow_back_ios_new,
                                color: Colors.white,
                              ),
                              onPressed: () => _navigateHome(controller),
                            ),
                            actions: [
                              IconButton(
                                tooltip: GeneratorTranslationConstants
                                    .chamberGuide
                                    .tr,
                                icon: const Icon(Icons.help_outline),
                                onPressed: () => showDialog<void>(
                                  context: context,
                                  builder: (context) => CamaraNeomTutorial(
                                    onComplete: () =>
                                        Navigator.of(context).pop(),
                                  ),
                                ),
                              ),
                              if (controller.userServiceImpl != null)
                                SizedBox(
                                  child: IconButton(
                                    onPressed: () async {
                                      AuthGuard.protect(context, () async {
                                        if (controller.existsInChamber.value &&
                                            !controller.isUpdate.value) {
                                          await controller.removePreset(
                                            context,
                                          );
                                        } else {
                                          showSaveDialog(context, controller);
                                        }
                                      });
                                    },
                                    icon: Icon(
                                      Icons.save_outlined,
                                      color: Colors.white,
                                      size: 25,
                                    ),
                                  ),
                                ),
                            ],
                          )
                        : null,
                    body: Obx(
                      () => controller.focusMode.value
                          ? ChamberFocusView(controller: controller)
                          : _mobileControls(context, controller),
                    ),

                    ///TODO EXPERIMENTAL FEATURES TO MOVE NEOM CHAMBER 2D TO A 3D VERSION TO USE IT WITH SMARTPHONE VR
                    // floatingActionButton: Row(
                    //   mainAxisAlignment: MainAxisAlignment.end,
                    //   children: [
                    //   FloatingActionButton(
                    //     heroTag: "",
                    //     backgroundColor: Colors.white12,
                    //     mini: true,
                    //     child: FaIcon(FontAwesomeIcons.vrCardboard, size: 12,color: Colors.white,),
                    //     onPressed: ()=>{
                    //       // Sint.to(() => PanoramaView())
                    //     },
                    //   ),
                    //   FloatingActionButton(
                    //     heroTag: " ",
                    //     backgroundColor: Colors.white12,
                    //     mini: true,
                    //     child: FaIcon(FontAwesomeIcons.globe, size: 12,color: Colors.white,),
                    //     onPressed: ()=> {
                    //       // Sint.to(() => VideoSection())
                    //     },
                    //   ),
                    //     FloatingActionButton(
                    //       heroTag: " _",
                    //       backgroundColor: Colors.white12,
                    //       mini: true,
                    //       child: FaIcon(FontAwesomeIcons.chrome, size: 12,color: Colors.white,),
                    //       onPressed: ()=> {
                    //         generatorController.neom360viewerController.launchChromeVRView(context, url: 'https://larkintuckerllc.github.io/hello-react-360/')
                    //       },
                    //     )
                    // ],
                    // )
                  ),
          ),
        ),
      ),
    );
  }
}

/// Uses the same first-visit guide on phones and desktop.
class _PageWithTutorial extends StatefulWidget {
  final Widget child;
  const _PageWithTutorial({required this.child});

  @override
  State<_PageWithTutorial> createState() => _PageWithTutorialState();
}

class _PageWithTutorialState extends State<_PageWithTutorial> {
  bool _showTutorial = false;

  @override
  void initState() {
    super.initState();
    _checkTutorial();
  }

  Future<void> _checkTutorial() async {
    final shouldShow = await CamaraNeomTutorial.shouldShow();
    if (shouldShow && mounted) {
      setState(() => _showTutorial = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_showTutorial)
          CamaraNeomTutorial(
            onComplete: () => setState(() => _showTutorial = false),
          ),
      ],
    );
  }
}

/// Offers the post-session review once the practice ends.
///
/// The session is already saved by then; this only records how it felt, and
/// the user can dismiss it. Skipped when nothing was tracked.
Future<void> _askForReview(
  BuildContext context,
  NeomGeneratorController controller,
) async {
  final summary = controller.pendingSessionSummary();
  if (summary == null) return;

  final review = await InciensoReviewModal.show(
    context,
    sessionSummary: summary,
  );
  if (review != null) await controller.saveSessionReview(review);
}
