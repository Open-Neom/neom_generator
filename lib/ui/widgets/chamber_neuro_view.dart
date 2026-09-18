import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:sint/sint.dart';

import '../../domain/use_cases/chamber_neuro_panel.dart';
import '../../engine/neom_frequency_painter_engine.dart';
import '../../utils/constants/generator_translation_constants.dart';
import '../neom_generator_controller.dart';
import '../painters/lissajous_painter.dart';
import 'chamber_controls.dart';
import 'chamber_practice_tools.dart';
import 'signal_paint.dart';

/// Cámara Neom with the biosignal in the centre.
///
/// The host's [ChamberNeuroPanel] (EEG today) takes the stage; the audio
/// side of the chamber shrinks to a rail with what a session needs while
/// watching the signal — play/stop, volume, frequency, the practice clock
/// and the Lissajous figure. Wide screens put the rail on the left; phones
/// stack it under the panel as a bottom bar.
class ChamberNeuroView extends StatelessWidget {
  final NeomGeneratorController controller;

  /// Leaves the neuro layout. [ChamberNeuroPage] pops the route; a host
  /// embedding the view elsewhere decides what "exit" means.
  final VoidCallback onExit;

  const ChamberNeuroView({
    super.key,
    required this.controller,
    required this.onExit,
  });

  static const _railWidth = 300.0;
  static const _wideBreakpoint = 900.0;

  @override
  Widget build(BuildContext context) {
    final panel = ChamberNeuroPanel.registered;
    if (panel == null) {
      return _NoPanel(onExit: onExit);
    }

    return Container(
      decoration: AppTheme.appBoxDecoration,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final wide = constraints.maxWidth >= _wideBreakpoint;
          final stage = _Stage(panel: panel, controller: controller, onExit: onExit);

          if (wide) {
            return Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  width: _railWidth,
                  child: _Rail(controller: controller, panel: panel, vertical: true),
                ),
                const VerticalDivider(width: 1, color: Colors.white12),
                Expanded(child: stage),
              ],
            );
          }

          return Column(
            children: [
              Expanded(child: stage),
              const Divider(height: 1, color: Colors.white12),
              _Rail(controller: controller, panel: panel, vertical: false),
            ],
          );
        },
      ),
    );
  }
}

/// The centre: the host panel in a scroll view with a slim title bar.
class _Stage extends StatelessWidget {
  final ChamberNeuroPanel panel;
  final NeomGeneratorController controller;
  final VoidCallback onExit;

  const _Stage({
    required this.panel,
    required this.controller,
    required this.onExit,
  });

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 8, 4),
            child: Row(
              children: [
                Icon(panel.icon, size: 18, color: Colors.white70),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    GeneratorTranslationConstants.neuroMode.tr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (panel.statusLine != null)
                  Obx(() {
                    // Reading isPlaying keeps Obx satisfied even when the
                    // host's statusLine touches no Rx; when it does (the
                    // EEG panel reads the connection controller) those are
                    // tracked too, so the line updates on connect/disconnect.
                    controller.isPlaying.value;
                    final line = panel.statusLine!();
                    return line == null
                        ? const SizedBox.shrink()
                        : Text(
                            line,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 11,
                            ),
                          );
                  }),
                IconButton(
                  key: const ValueKey('chamber-neuro-exit'),
                  tooltip: GeneratorTranslationConstants.neuroModeExit.tr,
                  icon: const Icon(Icons.close_fullscreen),
                  onPressed: onExit,
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              key: const ValueKey('chamber-neuro-stage-scroll'),
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 1100),
                  child: panel.builder(context),
                ),
              ),
            ),
          ),
        ],
      );
}

/// The audio side of the chamber, reduced to what a session needs.
class _Rail extends StatelessWidget {
  final NeomGeneratorController controller;
  final ChamberNeuroPanel panel;
  final bool vertical;

  const _Rail({
    required this.controller,
    required this.panel,
    required this.vertical,
  });

  @override
  Widget build(BuildContext context) {
    final sessionName = controller.activeIncienso?.getName(
          Sint.locale?.languageCode ?? 'en',
        ) ??
        GeneratorTranslationConstants.practiceFreeSession.tr;

    final play = Obx(
      () => ChamberPlaybackButton(
        requested: controller.playbackRequested.value,
        transitioning: controller.isPlaybackTransitioning.value,
        onPressed: () => controller.playStopPreview(),
      ),
    );

    final frequency = Obx(
      () => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment:
            vertical ? CrossAxisAlignment.center : CrossAxisAlignment.start,
        children: [
          Text(
            '${controller.currentFreq.value.toStringAsFixed(1)} Hz',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
              fontFamily: 'monospace',
            ),
          ),
          if (controller.currentBeat.value > 0)
            Text(
              'binaural ${controller.currentBeat.value.toStringAsFixed(1)} Hz',
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
        ],
      ),
    );

    final volume = Obx(
      () => Row(
        children: [
          const Icon(Icons.volume_down, size: 16, color: Colors.white54),
          Expanded(
            child: Slider(
              value: controller.currentVol.value.clamp(0, 1),
              label: '${(controller.currentVol.value * 100).round()}%',
              semanticFormatterCallback: (v) => '${(v * 100).round()}%',
              onChanged: controller.setVolume,
            ),
          ),
          SizedBox(
            width: 36,
            child: Text(
              '${(controller.currentVol.value * 100).round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(color: Colors.white54, fontSize: 11),
            ),
          ),
        ],
      ),
    );

    final lissajous = Obx(
      () => SizedBox(
        height: vertical ? 150 : 56,
        width: vertical ? 200 : 72,
        child: SignalPaint(
          active: controller.isPlaying.value,
          builder: (repaint) => LissajousPainter(
            engine: controller.painterEngine,
            color: Colors.cyanAccent,
            repaint: repaint,
          ),
        ),
      ),
    );

    if (!vertical) {
      // Phone: one compact bar under the stage.
      return SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  lissajous,
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sessionName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                        frequency,
                        // The compact clock is a Wrap; it needs a bounded
                        // width, which this column provides.
                        ChamberPracticeClock(controller: controller, compact: true),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  play,
                ],
              ),
              volume,
            ],
          ),
        ),
      );
    }

    // Desktop / tablet: vertical rail on the left.
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ChamberPracticeToolbar(controller: controller, compact: true),
          Obx(
            () => ChamberFeedback(
              playbackError: controller.playbackError.value,
              saveError: controller.recordingSaveError.value,
              onRetrySave: controller.retryPendingRecordings,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            sessionName,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Center(child: lissajous),
          const SizedBox(height: 8),
          ChamberPracticeClock(controller: controller),
          const SizedBox(height: 12),
          Center(child: play),
          const SizedBox(height: 12),
          frequency,
          const SizedBox(height: 8),
          volume,
          const SizedBox(height: 12),
          coherenceMeter(controller.painterEngine),
          const SizedBox(height: 12),
          Text(
            GeneratorTranslationConstants.neuroModeHint.tr,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white38, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Shown when the host registered no [ChamberNeuroPanel]: the route exists
/// in every app, the sensor module only in some.
class _NoPanel extends StatelessWidget {
  final VoidCallback onExit;
  const _NoPanel({required this.onExit});

  @override
  Widget build(BuildContext context) => Container(
        decoration: AppTheme.appBoxDecoration,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.sensors_off, size: 40, color: Colors.white24),
            const SizedBox(height: 12),
            Text(
              GeneratorTranslationConstants.neuroModeUnavailable.tr,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white54),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              key: const ValueKey('chamber-neuro-exit'),
              onPressed: onExit,
              child: Text(GeneratorTranslationConstants.neuroModeExit.tr),
            ),
          ],
        ),
      );
}
