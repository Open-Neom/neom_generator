// The Cámara Neom's neuro layout lives in its own route (ChamberNeuroPage):
// the standard chamber page must stay exactly as it is, and the EEG-first
// layout is an option the host app links to when it registered a panel.

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:neom_core/domain/model/neom/neom_chamber_preset.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:neom_generator/data/implementations/incienso_tracker.dart';
import 'package:neom_generator/data/translations/generator_es_translations.dart';
import 'package:neom_generator/domain/models/incienso.dart';
import 'package:neom_generator/domain/use_cases/chamber_neuro_panel.dart';
import 'package:neom_generator/engine/neom_breath_engine.dart';
import 'package:neom_generator/engine/neom_frequency_painter_engine.dart';
import 'package:neom_generator/engine/neom_modulator_engine.dart';
import 'package:neom_generator/ui/chamber/chamber_neuro_page.dart';
import 'package:neom_generator/ui/neom_generator_controller.dart';
import 'package:neom_generator/ui/neom_generator_page.dart';
import 'package:neom_generator/ui/widgets/chamber_controls.dart';
import 'package:neom_generator/ui/widgets/chamber_neuro_view.dart';
import 'package:neom_generator/ui/widgets/chamber_practice_tools.dart';
import 'package:neom_generator/utils/enums/neom_numeric_target.dart';
import 'package:neom_generator/utils/enums/neom_spatial_mode.dart';
import 'package:sint/sint.dart';

/// Fake lifecycle/data provider, never constructs the real audio controller.
class _Controller extends SintController
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
    storage = await Directory.systemTemp.createTemp('chamber_neuro_page_');
    Hive.init(storage.path);
    final settings = await Hive.openBox('settings');
    await settings.put('camara_neom_tutorial_seen', true);
  });
  tearDownAll(() async {
    await Hive.close();
    await storage.delete(recursive: true);
  });

  ChamberNeuroPanel stubPanel() => ChamberNeuroPanel(
        id: 'stub',
        icon: Icons.psychology,
        statusLine: () => 'Stub · 5/5',
        builder: (_) => const SizedBox(
          key: ValueKey('stub-neuro-panel'),
          height: 400,
          child: Text('PANEL'),
        ),
      );

  Future<_Controller> pump(
    WidgetTester tester,
    Widget home, {
    required double width,
    bool registerPanel = true,
  }) async {
    final controller = _Controller();
    Bind.put<NeomGeneratorController>(controller);
    if (registerPanel) Sint.put<ChamberNeuroPanel>(stubPanel());
    Sint.addTranslations({'es': GeneratorEsTranslations.values});
    Sint.locale = const Locale('es');
    await tester.binding.setSurfaceSize(Size(width, 820));
    addTearDown(() async {
      await Bind.delete<NeomGeneratorController>(force: true);
      if (Sint.isRegistered<ChamberNeuroPanel>()) {
        Sint.delete<ChamberNeuroPanel>(force: true);
      }
      controller.painterEngine.dispose();
      Sint.clearTranslations();
      Sint.locale = null;
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
      SintMaterialApp(
        theme: ThemeData.dark(),
        home: MediaQuery(
          data: MediaQueryData(size: Size(width, 820)),
          child: home,
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    return controller;
  }

  group('the standard chamber is untouched', () {
    testWidgets('no neuro toggle or view appears in the chamber page',
        (tester) async {
      await pump(tester, const NeomGeneratorPage(), width: 390);
      expect(find.byKey(const ValueKey('chamber-neuro-toggle')), findsNothing);
      expect(find.byType(ChamberNeuroView), findsNothing);
      expect(find.byKey(const ValueKey('chamber-focus-toggle')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('ChamberNeuroPage', () {
    testWidgets('phone: panel on stage, audio controls in a bottom bar',
        (tester) async {
      final controller =
          await pump(tester, const ChamberNeuroPage(), width: 390);
      controller.fields[#playbackRequested].value = true;
      controller.fields[#isPlaying].value = true;
      await tester.pump();

      expect(find.byType(ChamberNeuroView), findsOneWidget);
      expect(find.byKey(const ValueKey('stub-neuro-panel')), findsOneWidget);
      expect(find.text('Modo EEG'), findsWidgets);
      expect(find.text('Stub · 5/5'), findsOneWidget);
      expect(find.byType(ChamberFrequencyControl), findsNothing);
      expect(find.byType(ChamberPlaybackButton), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.text('432.3 Hz'), findsOneWidget);
      expect(find.text('binaural 7.8 Hz'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(ChamberNeuroView),
          matching: find.byType(ChamberPracticeToolbar),
        ),
        findsNothing,
        reason: 'phone rail is a compact bar',
      );
      expect(controller.fields[#playbackRequested].value, isTrue,
          reason: 'entering the page never touches playback');
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('tablet: rail on the left, panel on the right',
        (tester) async {
      await pump(tester, const ChamberNeuroPage(), width: 1024);
      final view = find.byType(ChamberNeuroView);
      expect(view, findsOneWidget);
      final panel =
          tester.getRect(find.byKey(const ValueKey('stub-neuro-panel')));
      final play = tester.getRect(find.byType(ChamberPlaybackButton));
      expect(play.right, lessThan(panel.left));
      expect(
        find.descendant(of: view, matching: find.byType(ChamberPracticeToolbar)),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });

    testWidgets('without a registered panel it explains and offers to leave',
        (tester) async {
      await pump(tester, const ChamberNeuroPage(),
          width: 390, registerPanel: false);
      expect(find.byKey(const ValueKey('stub-neuro-panel')), findsNothing);
      expect(find.textContaining('panel de biosensores'), findsOneWidget);
      expect(find.byKey(const ValueKey('chamber-neuro-exit')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  group('ChamberNeuroView', () {
    testWidgets('exit button calls onExit', (tester) async {
      var exits = 0;
      final controller = _Controller();
      Bind.put<NeomGeneratorController>(controller);
      Sint.put<ChamberNeuroPanel>(stubPanel());
      Sint.addTranslations({'es': GeneratorEsTranslations.values});
      Sint.locale = const Locale('es');
      addTearDown(() async {
        await Bind.delete<NeomGeneratorController>(force: true);
        Sint.delete<ChamberNeuroPanel>(force: true);
        controller.painterEngine.dispose();
        Sint.clearTranslations();
        Sint.locale = null;
      });
      await tester.pumpWidget(
        SintMaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: ChamberNeuroView(
              controller: controller,
              onExit: () => exits++,
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('chamber-neuro-exit')));
      expect(exits, 1);
      // Let the tooltip's tap timers expire before tearing the tree down.
      await tester.pump(const Duration(seconds: 3));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
