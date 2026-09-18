import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:neom_core/domain/model/neom/neom_chamber_preset.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:neom_generator/data/implementations/incienso_tracker.dart';
import 'package:neom_generator/data/translations/generator_de_translations.dart';
import 'package:neom_generator/data/translations/generator_en_translations.dart';
import 'package:neom_generator/data/translations/generator_es_translations.dart';
import 'package:neom_generator/data/translations/generator_fr_translations.dart';
import 'package:neom_generator/domain/models/incienso.dart';
import 'package:neom_generator/engine/neom_breath_engine.dart';
import 'package:neom_generator/engine/neom_frequency_painter_engine.dart';
import 'package:neom_generator/engine/neom_modulator_engine.dart';
import 'package:neom_generator/ui/neom_generator_controller.dart';
import 'package:neom_generator/ui/neom_generator_page.dart';
import 'package:neom_generator/ui/web/neom_generator_web_page.dart';
import 'package:neom_generator/ui/widgets/chamber_controls.dart';
import 'package:neom_generator/ui/widgets/chamber_practice_tools.dart';
import 'package:neom_generator/utils/constants/generator_translation_constants.dart';
import 'package:neom_generator/utils/enums/neom_numeric_target.dart';
import 'package:neom_generator/utils/enums/neom_spatial_mode.dart';
import 'package:sint/sint.dart';

/// Fake lifecycle/data provider, never constructs the real audio controller.
class _PageController extends SintController
    implements NeomGeneratorController {
  final fields = <Symbol, dynamic>{
    #currentFreq: 432.25.obs,
    #currentBeat: 7.83.obs,
    #currentVol: .5.obs,
    #currentOctave: 0.obs,
    #posX: 0.0.obs,
    #posY: 0.0.obs,
    #posZ: 0.0.obs,
    #activeNumericTarget: NeomNumericTarget.rootFrequency.obs,
    #modulationDepth: .3.obs,
    #isPlaying: false.obs,
    #playbackRequested: false.obs,
    #isPlaybackTransitioning: false.obs,
    #playbackError: ''.obs,
    #recordingSaveError: ''.obs,
    #isRecording: false.obs,
    #detectedFrequency: 0.0.obs,
    #micWaveform: <double>[].obs,
    #chamberPreset: NeomChamberPreset(),
    #isAdmin: false,
    #existsInChamber: false.obs,
    #isUpdate: false.obs,
    #frequencyDescription: ''.obs,
    #oscTimeScale: 1.0.obs,
    #showCircuitWave: true.obs,
    #showPerimeterWave: true.obs,
    #neuroState: NeomNeuroState.neutral.obs,
    #inciensoCount: 0,
    #inciensoTracker: InciensoTracker(),
    #sessionElapsed: Duration.zero,
    #isIsochronicEnabled: false.obs,
    #isochronicFreq: 4.0.obs,
    #isochronicDuty: .5.obs,
    #isModulationEnabled: true.obs,
    #modulationType: NeomModulationType.none.obs,
    #spatialMode: NeomSpatialMode.orbit.obs,
    #spatialIntensity: .5.obs,
    #orbitSpeed: .15.obs,
    #orbitDirection: 1.obs,
    #breathMode: NeomBreathMode.off.obs,
    #breathRate: 6.0.obs,
    #breathDepth: .5.obs,
    #painterEngine: NeomFrequencyPainterEngine(),
    #freeSessionMinutes: 0.obs,
    #focusMode: false.obs,
    #softTransitions: true.obs,
    #channelCheckRunning: false.obs,
    #favoriteSessionIds: <String>[].obs,
    #reflectionBeforeFeeling: ''.obs,
    #canReflectSession: false.obs,
    #sessionRemaining: null,
    #activeIncienso: null,
  };
  int resets = 0;
  int checks = 0;
  int imports = 0;
  int reflections = 0;
  int freeSessions = 0;
  Incienso? exported;
  @override
  bool canShareIncienso(Incienso value) => value.isPublic;
  @override
  Future<void> startFreeSession() async {
    freeSessions++;
    fields[#activeIncienso] = null;
  }

  @override
  Future<void> toggleFavorite(String id) async {
    final ids = fields[#favoriteSessionIds] as RxList<String>;
    if (ids.contains(id)) {
      ids.remove(id);
    } else {
      ids.add(id);
    }
  }

  @override
  Future<void> exportSession(Incienso value) async => exported = value;
  @override
  Future<List<Incienso>> quickSessions() async => [];
  @override
  Future<List<Incienso>> recordedSessions() async => [];
  @override
  bool isFavorite(String id) => fields[#favoriteSessionIds].contains(id);
  @override
  void setFocusMode(bool value) => fields[#focusMode].value = value;
  @override
  void setFreeSessionMinutes(int value) =>
      fields[#freeSessionMinutes].value = value;
  @override
  void setSoftTransitions(bool value) => fields[#softTransitions].value = value;
  @override
  Future<void> resetSessionSettings() async {
    resets++;
  }

  @override
  Future<void> playChannelCheck(bool left) async {
    checks++;
  }

  @override
  Future<void> stopChannelCheck() async {
    fields[#channelCheckRunning].value = false;
  }

  @override
  Future<void> importSession() async {
    imports++;
  }

  @override
  Future<void> openSessionReflection() async {
    reflections++;
  }

  @override
  Future<void> playStopPreview({bool stop = false}) async {
    fields[#playbackRequested].value =
        !stop && !fields[#playbackRequested].value;
    fields[#isPlaying].value = fields[#playbackRequested].value;
  }

  @override
  void setVolume(double value, {bool? rightOrLeft}) =>
      fields[#currentVol].value = value;
  @override
  double get effectiveFrequency => fields[#currentFreq].value;
  @override
  void selectBinauralBeat() =>
      fields[#activeNumericTarget].value = NeomNumericTarget.binauralBeat;
  @override
  void selectRootFrequency() =>
      fields[#activeNumericTarget].value = NeomNumericTarget.rootFrequency;
  @override
  Future<void> stopRecording({bool applyDetectedFrequency = true}) async {}
  @override
  dynamic noSuchMethod(Invocation invocation) {
    if (invocation.isGetter && fields.containsKey(invocation.memberName)) {
      return fields[invocation.memberName];
    }
    if (invocation.memberName == #userServiceImpl) return null;
    return super.noSuchMethod(invocation);
  }
}

void main() {
  late Directory storage;
  setUpAll(() async {
    storage = await Directory.systemTemp.createTemp('chamber_ui_smoke_');
    Hive.init(storage.path);
    final settings = await Hive.openBox('settings');
    await settings.put('camara_neom_tutorial_seen', true);
  });
  tearDownAll(() async {
    await Hive.close();
    await storage.delete(recursive: true);
  });
  testWidgets(
    'active public Incienso can be favorited and linked without playback',
    (tester) async {
      final controller = _PageController();
      final active = Incienso(
        id: 'public-incienso',
        names: const {'es': 'Mi Incienso público'},
        leftFrequencyHz: 432,
        rightFrequencyHz: 440,
        suggestedDuration: const Duration(minutes: 10),
        isPublic: true,
      );
      controller.fields[#activeIncienso] = active;
      Sint.addTranslations({'es': GeneratorEsTranslations.values});
      Sint.locale = const Locale('es');
      addTearDown(() {
        controller.painterEngine.dispose();
        Sint.clearTranslations();
        Sint.locale = null;
      });
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(body: ChamberPracticeSettings(controller: controller)),
        ),
      );
      final favorite = find.text(
        GeneratorTranslationConstants.practiceFavorite.tr,
      );
      await tester.ensureVisible(favorite);
      await tester.tap(favorite);
      await tester.pump();
      expect(controller.isFavorite(active.id), isTrue);
      final share = find.text(GeneratorTranslationConstants.practiceExport.tr);
      await tester.ensureVisible(share);
      await tester.tap(share);
      await tester.pump();
      expect(controller.exported, same(active));
      expect(controller.fields[#playbackRequested].value, isFalse);
      final timer = tester.widget<ChoiceChip>(
        find.widgetWithText(ChoiceChip, '10 min'),
      );
      expect(timer.onSelected, isNull);
      controller.fields[#playbackError].value = 'Visible export failure';
      await tester.pump();
      expect(find.text('Visible export failure').hitTestable(), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets('free-session action leaves a loaded preset without autoplay', (
    tester,
  ) async {
    final controller = _PageController();
    controller.fields[#activeIncienso] = Incienso(
      id: 'loaded',
      names: const {'es': 'Sesión cargada'},
      leftFrequencyHz: 432,
      rightFrequencyHz: 440,
      suggestedDuration: const Duration(minutes: 10),
    );
    addTearDown(controller.painterEngine.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                builder: (_) => ChamberPracticeSettings(controller: controller),
              ),
              child: const Text('Options'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Options'));
    await tester.pumpAndSettle();
    final free = find.byKey(const ValueKey('chamber-free-session'));
    expect(free, findsOneWidget);
    controller.fields[#playbackRequested].value = true;
    await tester.pump();
    expect(tester.widget<OutlinedButton>(free).onPressed, isNull);
    controller.fields[#playbackRequested].value = false;
    await tester.pump();
    await tester.ensureVisible(free);
    await tester.tap(free);
    await tester.pumpAndSettle();
    expect(controller.freeSessions, 1);
    expect(controller.fields[#activeIncienso], isNull);
    expect(controller.fields[#playbackRequested].value, isFalse);
    expect(controller.fields[#currentFreq].value, 432.25);
    expect(find.byType(ChamberPracticeSettings), findsNothing);
  });
  for (final language in ['es', 'en', 'fr', 'de']) {
    testWidgets(
      'session options wrap at 320px in $language and apply without starting playback',
      (tester) async {
        final controller = _PageController();
        Sint.addTranslations({
          'es': GeneratorEsTranslations.values,
          'en': GeneratorEnTranslations.values,
          'fr': GeneratorFrTranslations.values,
          'de': GeneratorDeTranslations.values,
        });
        Sint.locale = Locale(language);
        await tester.binding.setSurfaceSize(const Size(320, 800));
        addTearDown(() async {
          controller.painterEngine.dispose();
          Sint.clearTranslations();
          Sint.locale = null;
          await tester.binding.setSurfaceSize(null);
        });
        await tester.pumpWidget(
          MaterialApp(
            theme: ThemeData.dark(),
            home: Scaffold(
              body: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 800),
                  textScaler: TextScaler.linear(1.3),
                ),
                child: ChamberPracticeSettings(controller: controller),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('10 min'));
        await tester.pump();
        expect(controller.fields[#freeSessionMinutes].value, 10);
        final calm = find.text(
          GeneratorTranslationConstants.practiceFeelingCalm.tr,
        );
        await tester.ensureVisible(calm);
        await tester.tap(calm);
        await tester.pump();
        expect(controller.fields[#reflectionBeforeFeeling].value, 'calm');
        final soft = find.byType(SwitchListTile);
        await tester.ensureVisible(soft);
        await tester.tap(soft);
        await tester.pump();
        expect(controller.fields[#softTransitions].value, isFalse);
        final left = find.text(GeneratorTranslationConstants.practiceLeft.tr);
        await tester.ensureVisible(left);
        await tester.tap(left);
        await tester.pump();
        expect(controller.checks, 1);
        expect(controller.fields[#playbackRequested].value, isFalse);
        controller.fields[#channelCheckRunning].value = true;
        await tester.pump();
        final stop = find.text(
          GeneratorTranslationConstants.practiceStopCheck.tr,
        );
        await tester.ensureVisible(stop);
        await tester.tap(stop);
        await tester.pump();
        expect(controller.fields[#channelCheckRunning].value, isFalse);
        controller.fields[#playbackRequested].value = true;
        await tester.pump();
        final timer = tester.widget<ChoiceChip>(
          find.widgetWithText(ChoiceChip, '10 min'),
        );
        expect(timer.onSelected, isNull);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
  for (final width in [320.0, 1100.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets('chamber layout $width with text scale $scale', (
        tester,
      ) async {
        final controller = _PageController();
        Bind.put<NeomGeneratorController>(controller);
        Sint.addTranslations({'es': GeneratorEsTranslations.values});
        Sint.locale = const Locale('es');
        await tester.binding.setSurfaceSize(Size(width, 800));
        addTearDown(() async {
          await Bind.delete<NeomGeneratorController>(force: true);
          controller.painterEngine.dispose();
          Sint.clearTranslations();
          Sint.locale = null;
          await tester.binding.setSurfaceSize(null);
        });
        await tester.pumpWidget(
          SintMaterialApp(
            theme: ThemeData.dark(),
            home: MediaQuery(
              data: MediaQueryData(
                size: Size(width, 800),
                textScaler: TextScaler.linear(scale),
              ),
              child: width < 900
                  ? const NeomGeneratorPage()
                  : NeomGeneratorWebPage(controller: controller),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 1));
        expect(tester.takeException(), isNull);
        final frequencyCards = find.byType(ChamberFrequencyControl);
        expect(frequencyCards, findsNWidgets(2));
        if (width < 900) {
          final experiences = find.byKey(
            const PageStorageKey('chamber-mobile-experiences'),
          );
          await tester.ensureVisible(experiences);
          await tester.tap(
            find.text(GeneratorTranslationConstants.experiences.tr),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 1));
          expect(
            find.widgetWithText(OutlinedButton, 'Neomatics'),
            findsOneWidget,
          );
          expect(
            find.widgetWithText(OutlinedButton, 'NeuroMandala'),
            findsOneWidget,
          );
        }
        controller.fields[#currentBeat].value = 8.25;
        await tester.pump();
        expect(find.text('8.25 Hz'), findsOneWidget);
        controller.fields[#playbackRequested].value = true;
        controller.fields[#isPlaybackTransitioning].value = true;
        await tester.pump();
        expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.ensureVisible(
          find.byKey(const ValueKey('chamber-focus-toggle')),
        );
        await tester.tap(find.byKey(const ValueKey('chamber-focus-toggle')));
        await tester.pump();
        expect(find.byType(ChamberFocusView), findsOneWidget);
        expect(find.byType(ChamberFrequencyControl), findsNothing);
        expect(controller.fields[#playbackRequested].value, isTrue);
        expect(find.byIcon(Icons.stop_rounded), findsOneWidget);
        expect(tester.takeException(), isNull);
        final stopControl = find.byType(ChamberPlaybackButton);
        if (scale == 1.0) {
          final bounds = tester.getRect(stopControl);
          expect(bounds.top, greaterThanOrEqualTo(0));
          expect(bounds.bottom, lessThanOrEqualTo(800));
        }
        await tester.ensureVisible(stopControl);
        expect(stopControl.hitTestable(), findsOneWidget);
        await tester.tap(stopControl);
        await tester.pump();
        expect(controller.fields[#playbackRequested].value, isFalse);
        expect(controller.fields[#currentBeat].value, 8.25);
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(milliseconds: 1));
      });
    }
  }
}
