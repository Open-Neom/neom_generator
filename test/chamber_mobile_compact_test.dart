import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:neom_core/domain/model/neom/neom_chamber_preset.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:neom_generator/data/implementations/incienso_tracker.dart';
import 'package:neom_generator/data/translations/generator_es_translations.dart';
import 'package:neom_generator/domain/models/incienso.dart';
import 'package:neom_generator/engine/neom_breath_engine.dart';
import 'package:neom_generator/engine/neom_frequency_painter_engine.dart';
import 'package:neom_generator/engine/neom_modulator_engine.dart';
import 'package:neom_generator/ui/neom_generator_controller.dart';
import 'package:neom_generator/ui/neom_generator_page.dart';
import 'package:neom_generator/ui/widgets/chamber_controls.dart';
import 'package:neom_generator/ui/widgets/chamber_practice_tools.dart';
import 'package:neom_generator/utils/constants/generator_translation_constants.dart';
import 'package:neom_generator/utils/enums/neom_numeric_target.dart';
import 'package:neom_generator/utils/enums/neom_spatial_mode.dart';
import 'package:sint/sint.dart';

/// Fake lifecycle/data provider, never constructs the real audio controller.
class _MobileController extends SintController
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
  int voiceStarts = 0;
  int voiceStops = 0;
  bool? lastStopAppliedFrequency;
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
  Future<void> startRecording() async {
    voiceStarts++;
    fields[#isRecording].value = true;
  }

  @override
  Future<void> stopRecording({bool applyDetectedFrequency = true}) async {
    voiceStops++;
    lastStopAppliedFrequency = applyDetectedFrequency;
    fields[#isRecording].value = false;
  }

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
    storage = await Directory.systemTemp.createTemp('chamber_mobile_compact_');
    Hive.init(storage.path);
    final settings = await Hive.openBox('settings');
    await settings.put('camara_neom_tutorial_seen', true);
  });
  tearDownAll(() async {
    await Hive.close();
    await storage.delete(recursive: true);
  });

  Future<_MobileController> pumpPage(
    WidgetTester tester,
    double width,
    double scale,
  ) async {
    final controller = _MobileController();
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
          child: const NeomGeneratorPage(),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    return controller;
  }

  for (final width in [320.0, 360.0, 390.0, 430.0, 768.0]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'mobile $width scale $scale keeps voice first and scope before advanced controls',
        (tester) async {
          final controller = await pumpPage(tester, width, scale);
          expect(tester.takeException(), isNull);
          final voice = find.byKey(
            const ValueKey('chamber-mobile-detect-voice'),
          );
          final root = find.byKey(const ValueKey('chamber-mobile-root'));
          final beat = find.byKey(const ValueKey('chamber-mobile-beat'));
          final scope = find.byKey(
            const ValueKey('chamber-mobile-oscilloscope'),
          );
          final experiences = find.byKey(
            const PageStorageKey('chamber-mobile-experiences'),
          );
          expect(voice.hitTestable(), findsOneWidget);
          expect(tester.getRect(voice).top, lessThan(100));
          expect(tester.getSize(voice).height, greaterThanOrEqualTo(48));
          expect(
            tester.getRect(voice).bottom,
            lessThan(tester.getRect(root).top),
          );
          expect(tester.widget<ChamberFrequencyControl>(root).compact, isTrue);
          expect(tester.widget<ChamberFrequencyControl>(beat).compact, isTrue);
          if (width >= 360 && scale == 1) {
            expect(tester.getRect(root).top, tester.getRect(beat).top);
            expect(
              tester.getRect(root).right,
              lessThan(tester.getRect(beat).left),
            );
          } else {
            expect(
              tester.getRect(root).bottom,
              lessThan(tester.getRect(beat).top),
            );
          }
          expect(
            tester.getRect(scope).bottom,
            lessThan(tester.getRect(experiences).top),
          );
          if (scale == 1) {
            expect(tester.getRect(scope).bottom, lessThanOrEqualTo(800));
          }
          expect(find.byType(ChamberOctaveControl), findsOneWidget);
          expect(
            tester
                .widget<ChamberOctaveControl>(find.byType(ChamberOctaveControl))
                .compact,
            isTrue,
          );

          await tester.tap(voice);
          await tester.pump();
          expect(controller.voiceStarts, 1);
          expect(
            find.byKey(const ValueKey('chamber-mobile-mic-wave')),
            findsOneWidget,
          );
          expect(voice.hitTestable(), findsOneWidget);
          await tester.tap(voice);
          await tester.pump();
          expect(controller.voiceStops, 1);
          expect(controller.lastStopAppliedFrequency, isFalse);

          await tester.ensureVisible(experiences);
          await tester.tap(
            find.text(GeneratorTranslationConstants.experiences.tr),
          );
          await tester.pump(const Duration(milliseconds: 300));
          await tester.pump(const Duration(milliseconds: 1));
          final tiles = find.descendant(
            of: experiences,
            matching: find.byType(OutlinedButton),
          );
          expect(tiles, findsNWidgets(7));
          for (final element in tiles.evaluate()) {
            final rect = tester.getRect(find.byWidget(element.widget));
            expect(rect.width, greaterThanOrEqualTo(48));
            expect(rect.height, greaterThanOrEqualTo(48));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(width));
          }
          final first = tester.getRect(tiles.at(0));
          final second = tester.getRect(tiles.at(1));
          if (scale == 1) {
            expect(first.top, second.top);
            expect(first.right, lessThan(second.left));
          } else {
            expect(first.bottom, lessThan(second.top));
          }
          expect(tester.takeException(), isNull);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'compact mobile toolbar enters and exits focus without stopping audio',
    (tester) async {
      final controller = await pumpPage(tester, 390, 1);
      controller.fields[#playbackRequested].value = true;
      controller.fields[#isPlaying].value = true;
      await tester.pump();
      final focus = find.byKey(const ValueKey('chamber-focus-toggle'));
      await tester.ensureVisible(focus);
      await tester.tap(focus);
      await tester.pump();
      expect(find.byType(ChamberFocusView), findsOneWidget);
      expect(find.byType(ChamberFrequencyControl), findsNothing);
      expect(controller.fields[#playbackRequested].value, isTrue);
      await tester.tap(focus);
      await tester.pump();
      expect(find.byType(ChamberFocusView), findsNothing);
      expect(find.byType(ChamberFrequencyControl), findsNWidgets(2));
      expect(controller.fields[#playbackRequested].value, isTrue);
      expect(
        find.byKey(const ValueKey('chamber-mobile-detect-voice')).hitTestable(),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
