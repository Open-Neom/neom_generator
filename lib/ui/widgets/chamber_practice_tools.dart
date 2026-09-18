import 'package:flutter/material.dart';
import 'package:neom_commons/ui/theme/app_theme.dart';
import 'package:sint/sint.dart';

import '../../domain/models/incienso.dart';
import '../../utils/constants/generator_translation_constants.dart';
import '../neom_generator_controller.dart';
import '../painters/lissajous_painter.dart';
import 'chamber_controls.dart';
import 'chamber_sessions_button.dart';
import 'signal_paint.dart';
import 'visual_animation.dart';

/// The same compact entry points are available in the studio and practice view.
class ChamberPracticeToolbar extends StatefulWidget {
  final NeomGeneratorController controller;
  final bool compact;

  const ChamberPracticeToolbar({
    super.key,
    required this.controller,
    this.compact = false,
  });

  @override
  State<ChamberPracticeToolbar> createState() => _ChamberPracticeToolbarState();
}

class _ChamberPracticeToolbarState extends State<ChamberPracticeToolbar> {
  late Future<List<Incienso>> _quickSessions;

  @override
  void initState() {
    super.initState();
    _quickSessions = widget.compact
        ? Future.value(const <Incienso>[])
        : Future.sync(widget.controller.quickSessions);
  }

  void _refresh() {
    if (mounted && !widget.compact) {
      setState(() {
        _quickSessions = Future.sync(widget.controller.quickSessions);
      });
    }
  }

  Future<void> _load(Incienso session) async {
    await widget.controller.loadIncienso(session, autoStart: false);
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final controller = widget.controller;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 0 : 12,
        vertical: widget.compact ? 2 : 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: [
              ChamberSessionsButton(
                loadSessions: controller.recordedSessions,
                onSelected: _load,
                isFavorite: controller.isFavorite,
                onToggleFavorite: (id) async {
                  await controller.toggleFavorite(id);
                  _refresh();
                },
                onExport: controller.exportSession,
                errorMessage: () => controller.playbackError.value,
              ),
              Obx(
                () => widget.compact
                    ? IconButton(
                        key: const ValueKey('chamber-focus-toggle'),
                        tooltip:
                            (controller.focusMode.value
                                    ? GeneratorTranslationConstants
                                          .practiceControls
                                    : GeneratorTranslationConstants
                                          .practiceFocus)
                                .tr,
                        onPressed: () => controller.setFocusMode(
                          !controller.focusMode.value,
                        ),
                        icon: Icon(
                          controller.focusMode.value
                              ? Icons.tune
                              : Icons.self_improvement,
                        ),
                      )
                    : OutlinedButton.icon(
                        key: const ValueKey('chamber-focus-toggle'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        onPressed: () => controller.setFocusMode(
                          !controller.focusMode.value,
                        ),
                        icon: Icon(
                          controller.focusMode.value
                              ? Icons.tune
                              : Icons.self_improvement,
                        ),
                        label: Text(
                          (controller.focusMode.value
                                  ? GeneratorTranslationConstants
                                        .practiceControls
                                  : GeneratorTranslationConstants.practiceFocus)
                              .tr,
                        ),
                      ),
              ),
              if (widget.compact)
                IconButton(
                  key: const ValueKey('chamber-practice-options'),
                  tooltip: GeneratorTranslationConstants.practiceOptions.tr,
                  icon: const Icon(Icons.more_horiz),
                  onPressed: () => _showSettings(context),
                )
              else
                OutlinedButton.icon(
                  key: const ValueKey('chamber-practice-options'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                  ),
                  icon: const Icon(Icons.more_horiz),
                  label: Text(GeneratorTranslationConstants.practiceOptions.tr),
                  onPressed: () => _showSettings(context),
                ),
            ],
          ),
          FutureBuilder<List<Incienso>>(
            future: _quickSessions,
            builder: (context, snapshot) {
              final sessions = snapshot.data ?? const <Incienso>[];
              if (sessions.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Column(
                  children: [
                    Text(
                      GeneratorTranslationConstants.practiceQuickAccess.tr,
                      style: Theme.of(context).textTheme.labelSmall,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: sessions
                          .take(3)
                          .map(
                            (session) => Obx(() {
                              // Reading the IDs keeps existing quick links in sync.
                              final favorite = controller.favoriteSessionIds
                                  .contains(session.id);
                              return ActionChip(
                                avatar: Icon(
                                  favorite ? Icons.star : Icons.history,
                                  size: 18,
                                ),
                                tooltip: GeneratorTranslationConstants
                                    .selectSession
                                    .tr,
                                label: ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxWidth: 170,
                                  ),
                                  child: Text(
                                    session.getName(
                                      Sint.locale?.languageCode ?? 'en',
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                onPressed: () => _load(session),
                              );
                            }),
                          )
                          .toList(),
                    ),
                  ],
                ),
              );
            },
          ),
          Obx(
            () => controller.canReflectSession.value
                ? TextButton.icon(
                    icon: const Icon(Icons.edit_note),
                    label: Text(
                      GeneratorTranslationConstants.practiceReflection.tr,
                    ),
                    onPressed: controller.openSessionReflection,
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Future<void> _showSettings(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      constraints: const BoxConstraints(maxWidth: 620),
      builder: (_) => ChamberPracticeSettings(controller: widget.controller),
    );
    _refresh();
  }
}

class ChamberPracticeSettings extends StatelessWidget {
  final NeomGeneratorController controller;
  const ChamberPracticeSettings({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * .88,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: Obx(() {
              final playing = controller.playbackRequested.value;
              final activeSession = controller.activeIncienso;
              final loaded = activeSession != null;
              final checking = controller.channelCheckRunning.value;
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          GeneratorTranslationConstants.practiceOptions.tr,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ),
                      IconButton(
                        tooltip: GeneratorTranslationConstants.cancelControl.tr,
                        onPressed: () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    GeneratorTranslationConstants.practiceTimer.tr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    (loaded
                            ? GeneratorTranslationConstants.practicePresetTimer
                            : GeneratorTranslationConstants.practiceTimerHint)
                        .tr,
                  ),
                  if (loaded) ...[
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      key: const ValueKey('chamber-free-session'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: const Icon(Icons.tune),
                      label: Text(
                        GeneratorTranslationConstants.practiceFreeSession.tr,
                      ),
                      onPressed: playing || checking
                          ? null
                          : () async {
                              await controller.startFreeSession();
                              if (context.mounted) Navigator.of(context).pop();
                            },
                    ),
                  ],
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final minutes in const [0, 5, 10, 20, 30])
                        ChoiceChip(
                          label: Text(
                            minutes == 0
                                ? GeneratorTranslationConstants
                                      .practiceNoLimit
                                      .tr
                                : '$minutes min',
                          ),
                          selected:
                              controller.freeSessionMinutes.value == minutes,
                          onSelected: playing || loaded || checking
                              ? null
                              : (_) =>
                                    controller.setFreeSessionMinutes(minutes),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    GeneratorTranslationConstants.practiceFeelingBefore.tr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    children: [
                      for (final feeling in const [
                        'neutral',
                        'calm',
                        'tense',
                        'tired',
                        'energized',
                      ])
                        ChoiceChip(
                          label: Text(chamberFeelingLabel(feeling).tr),
                          selected:
                              controller.reflectionBeforeFeeling.value ==
                              feeling,
                          onSelected: playing || checking
                              ? null
                              : (selected) {
                                  controller.reflectionBeforeFeeling.value =
                                      selected ? feeling : '';
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      GeneratorTranslationConstants.practiceSoftTransitions.tr,
                    ),
                    subtitle: Text(
                      GeneratorTranslationConstants
                          .practiceSoftTransitionsHint
                          .tr,
                    ),
                    value: controller.softTransitions.value,
                    onChanged: playing || checking
                        ? null
                        : controller.setSoftTransitions,
                  ),
                  const Divider(),
                  Text(
                    GeneratorTranslationConstants.practiceStereo.tr,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 4),
                  Text(GeneratorTranslationConstants.practiceStereoHint.tr),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final left in [true, false])
                        OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(48, 48),
                          ),
                          icon: Icon(
                            left ? Icons.headphones : Icons.headphones_outlined,
                          ),
                          label: Text(
                            (left
                                    ? GeneratorTranslationConstants.practiceLeft
                                    : GeneratorTranslationConstants
                                          .practiceRight)
                                .tr,
                          ),
                          onPressed:
                              playing ||
                                  checking ||
                                  controller.isRecording.value
                              ? null
                              : () => controller.playChannelCheck(left),
                        ),
                    ],
                  ),
                  if (checking)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            GeneratorTranslationConstants.practiceChecking.tr,
                          ),
                          TextButton.icon(
                            onPressed: controller.stopChannelCheck,
                            icon: const Icon(Icons.stop_rounded),
                            label: Text(
                              GeneratorTranslationConstants
                                  .practiceStopCheck
                                  .tr,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const Divider(height: 28),
                  if (activeSession != null) ...[
                    Text(
                      activeSession.getName(Sint.locale?.languageCode ?? 'en'),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(48, 48),
                      ),
                      icon: Icon(
                        controller.isFavorite(activeSession.id)
                            ? Icons.star
                            : Icons.star_border,
                      ),
                      label: Text(
                        (controller.isFavorite(activeSession.id)
                                ? GeneratorTranslationConstants
                                      .practiceUnfavorite
                                : GeneratorTranslationConstants
                                      .practiceFavorite)
                            .tr,
                      ),
                      onPressed: () =>
                          controller.toggleFavorite(activeSession.id),
                    ),
                    if (controller.canShareIncienso(activeSession)) ...[
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(48, 48),
                        ),
                        icon: const Icon(Icons.ios_share),
                        label: Text(
                          GeneratorTranslationConstants.practiceExport.tr,
                        ),
                        onPressed: () =>
                            controller.exportSession(activeSession),
                      ),
                    ],
                    const SizedBox(height: 8),
                  ],
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.settings_backup_restore),
                    label: Text(GeneratorTranslationConstants.practiceReset.tr),
                    onPressed: checking
                        ? null
                        : () async {
                            await controller.resetSessionSettings();
                            if (context.mounted) Navigator.of(context).pop();
                          },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(48, 48),
                    ),
                    icon: const Icon(Icons.file_open_outlined),
                    label: Text(
                      GeneratorTranslationConstants.practiceImport.tr,
                    ),
                    onPressed: playing || checking
                        ? null
                        : () async {
                            Navigator.of(context).pop();
                            await controller.importSession();
                          },
                  ),
                  const SizedBox(height: 8),
                  Text(
                    GeneratorTranslationConstants.practiceSharePublicOnly.tr,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              );
            }),
          ),
        ),
        Obx(() {
          final error = controller.playbackError.value;
          return error.isEmpty
              ? const SizedBox.shrink()
              : Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(
                      error,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                );
        }),
      ],
    ),
  );
}

String chamberFeelingLabel(String feeling) => switch (feeling) {
  'calm' => GeneratorTranslationConstants.practiceFeelingCalm,
  'tense' => GeneratorTranslationConstants.practiceFeelingTense,
  'tired' => GeneratorTranslationConstants.practiceFeelingTired,
  'energized' => GeneratorTranslationConstants.practiceFeelingEnergized,
  _ => GeneratorTranslationConstants.practiceFeelingNeutral,
};

/// Reads the controller's audio clock; rebuilding the view never advances time.
class ChamberPracticeClock extends StatelessWidget {
  final NeomGeneratorController controller;
  final bool compact;
  const ChamberPracticeClock({
    super.key,
    required this.controller,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) => VisualAnimation(
    respectReducedMotion: false,
    frameInterval: const Duration(seconds: 1),
    builder: (_, clock, child) => AnimatedBuilder(
      animation: clock,
      builder: (context, child) {
        final remaining = controller.sessionRemaining;
        final duration = remaining ?? controller.sessionElapsed;
        final seconds = duration.inSeconds.clamp(0, 86400 * 7);
        if (compact) {
          return Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            children: [
              Text(
                (remaining == null
                        ? GeneratorTranslationConstants.sessionTime
                        : GeneratorTranslationConstants.practiceRemaining)
                    .tr,
                style: const TextStyle(fontSize: 12, color: Colors.white70),
              ),
              Text(
                '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
                style: const TextStyle(fontSize: 20, fontFamily: 'Courier'),
              ),
            ],
          );
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (remaining == null
                      ? GeneratorTranslationConstants.sessionTime
                      : GeneratorTranslationConstants.practiceRemaining)
                  .tr,
            ),
            Text(
              '${(seconds ~/ 60).toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}',
              style: const TextStyle(fontSize: 36, fontFamily: 'Courier'),
            ),
          ],
        );
      },
    ),
  );
}

class ChamberFocusView extends StatelessWidget {
  final NeomGeneratorController controller;
  const ChamberFocusView({super.key, required this.controller});

  @override
  Widget build(BuildContext context) => Container(
    decoration: AppTheme.appBoxDecoration,
    alignment: Alignment.center,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            ChamberPracticeToolbar(controller: controller, compact: true),
            Obx(
              () => ChamberFeedback(
                playbackError: controller.playbackError.value,
                saveError: controller.recordingSaveError.value,
                onRetrySave: controller.retryPendingRecordings,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Text(
                controller.activeIncienso?.getName(
                      Sint.locale?.languageCode ?? 'en',
                    ) ??
                    GeneratorTranslationConstants.practiceFreeSession.tr,
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
            ),
            Obx(
              () => SizedBox(
                height: 180,
                width: 240,
                child: SignalPaint(
                  active: controller.isPlaying.value,
                  builder: (repaint) => LissajousPainter(
                    engine: controller.painterEngine,
                    color: Colors.cyanAccent,
                    repaint: repaint,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            ChamberPracticeClock(controller: controller),
            const SizedBox(height: 20),
            Obx(
              () => ChamberPlaybackButton(
                requested: controller.playbackRequested.value,
                transitioning: controller.isPlaybackTransitioning.value,
                onPressed: () => controller.playStopPreview(),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Obx(
                () => Column(
                  children: [
                    Text(
                      '${GeneratorTranslationConstants.practiceVolume.tr} · ${(controller.currentVol.value * 100).round()}%',
                    ),
                    Slider(
                      value: controller.currentVol.value.clamp(0, 1),
                      label: '${(controller.currentVol.value * 100).round()}%',
                      semanticFormatterCallback: (value) =>
                          '${(value * 100).round()}%',
                      onChanged: controller.setVolume,
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
