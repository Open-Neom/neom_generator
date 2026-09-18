import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_core/domain/model/neom/neom_chamber_preset.dart';
import 'package:neom_core/domain/model/neom/neom_neuro_state.dart';
import 'package:neom_generator/data/implementations/incienso_tracker.dart';
import 'package:neom_generator/data/translations/generator_es_translations.dart';
import 'package:neom_generator/domain/models/incienso.dart';
import 'package:neom_generator/engine/neom_breath_engine.dart';
import 'package:neom_generator/engine/neom_frequency_painter_engine.dart';
import 'package:neom_generator/engine/neom_modulator_engine.dart';
import 'package:neom_generator/ui/neom_generator_controller.dart';
import 'package:neom_generator/ui/web/neom_generator_web_page.dart';
import 'package:neom_generator/ui/widgets/chamber_controls.dart';
import 'package:neom_generator/utils/enums/neom_numeric_target.dart';
import 'package:neom_generator/utils/enums/neom_spatial_mode.dart';
import 'package:sint/sint.dart';

/// Supplies real UI observables without starting audio, a mic or Firebase.
class _WebController extends SintController implements NeomGeneratorController {
  final fields = <Symbol, dynamic>{
    #currentFreq: 178.0.obs,
    #currentBeat: 0.0.obs,
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
    #detectedFrequency: 178.0.obs,
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

  @override
  Future<List<Incienso>> recordedSessions() async => [];
  @override
  bool isFavorite(String id) => false;
  @override
  double get effectiveFrequency => fields[#currentFreq].value;
  @override
  Future<void> startRecording() async => fields[#isRecording].value = true;
  bool? lastApplyDetectedFrequency;
  @override
  Future<void> stopRecording({bool applyDetectedFrequency = true}) async {
    lastApplyDetectedFrequency = applyDetectedFrequency;
    fields[#isRecording].value = false;
  }

  @override
  void setFocusMode(bool value) => fields[#focusMode].value = value;
  @override
  Future<void> playStopPreview({bool stop = false}) async {
    fields[#playbackRequested].value =
        !stop && !fields[#playbackRequested].value;
    fields[#isPlaying].value = fields[#playbackRequested].value;
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
  Future<_WebController> mount(
    WidgetTester tester,
    Size size, {
    double textScale = 1,
    bool recording = false,
  }) async {
    final controller = _WebController();
    controller.fields[#isRecording].value = recording;
    Bind.put<NeomGeneratorController>(controller);
    Sint.addTranslations({'es': GeneratorEsTranslations.values});
    Sint.locale = const Locale('es');
    await tester.binding.setSurfaceSize(size);
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
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: NeomGeneratorWebPage(controller: controller),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 1));
    return controller;
  }

  for (final size in [
    const Size(1440, 900),
    const Size(1366, 768),
    const Size(1280, 720),
  ]) {
    for (final recording in [false, true]) {
      testWidgets(
        'voice, playback and complete scope fit $size recording=$recording',
        (tester) async {
          await mount(tester, size, recording: recording);
          expect(tester.takeException(), isNull);
          final voice = find.byKey(const ValueKey('chamber-web-voice'));
          final scope = find.byKey(const ValueKey('chamber-web-oscilloscope'));
          final play = find.byType(ChamberPlaybackButton);
          final dial = find.byKey(const ValueKey('chamber-web-dial'));
          expect(voice.hitTestable(), findsOneWidget);
          expect(play.hitTestable(), findsOneWidget);
          expect(tester.getRect(voice).top, lessThan(130));
          expect(tester.getRect(scope).bottom, lessThan(size.height - 12));
          expect(
            tester.getRect(scope).top,
            greaterThan(tester.getRect(voice).bottom),
          );
          expect(tester.getSize(play).shortestSide, greaterThanOrEqualTo(48));
          expect(tester.getSize(dial).height, lessThanOrEqualTo(220));
          expect(
            tester
                .widgetList<ChamberFrequencyControl>(
                  find.byType(ChamberFrequencyControl),
                )
                .every((control) => control.compact),
            isTrue,
          );
          // All exact octave choices remain available through the dropdown.
          expect(find.byType(ChamberOctaveControl), findsOneWidget);
          await tester.pumpWidget(const SizedBox.shrink());
        },
      );
    }
  }

  testWidgets(
    'large text remains scrollable without overflow or lost controls',
    (tester) async {
      await mount(tester, const Size(1100, 800), textScale: 2);
      expect(tester.takeException(), isNull);
      final scope = find.byKey(const ValueKey('chamber-web-oscilloscope'));
      await tester.ensureVisible(scope);
      await tester.pump();
      expect(tester.takeException(), isNull);
      final options = find.byKey(const ValueKey('chamber-practice-options'));
      await tester.ensureVisible(options);
      expect(options.hitTestable(), findsOneWidget);
      expect(find.byType(ChamberPlaybackButton), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('top voice action starts and stops detection without scrolling', (
    tester,
  ) async {
    final controller = await mount(tester, const Size(1280, 720));
    final voice = find.byKey(const ValueKey('chamber-web-voice'));
    await tester.tap(voice);
    await tester.pump();
    expect(controller.isRecording.value, isTrue);
    expect(voice.hitTestable(), findsOneWidget);
    await tester.tap(voice);
    await tester.pump();
    expect(controller.isRecording.value, isFalse);
    expect(controller.lastApplyDetectedFrequency, isFalse);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
