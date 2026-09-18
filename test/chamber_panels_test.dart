import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/data/translations/generator_de_translations.dart';
import 'package:neom_generator/data/translations/generator_en_translations.dart';
import 'package:neom_generator/data/translations/generator_es_translations.dart';
import 'package:neom_generator/data/translations/generator_fr_translations.dart';
import 'package:neom_generator/engine/neom_breath_engine.dart';
import 'package:neom_generator/engine/neom_modulator_engine.dart';
import 'package:neom_generator/ui/neom_generator_controller.dart';
import 'package:neom_generator/ui/panels/neom_breath_control_panel.dart';
import 'package:neom_generator/ui/panels/neom_modulation_control_panel.dart';
import 'package:neom_generator/ui/panels/neom_spatial_control_panel.dart';
import 'package:neom_generator/utils/enums/neom_spatial_mode.dart';
import 'package:sint/sint.dart';

/// Implements data only: no engine, recorder, microphone or Firebase is created.
class _PanelController implements NeomGeneratorController {
  @override
  final breathMode = NeomBreathMode.fourSevenEight.obs;
  @override
  final breathRate = 6.0.obs;
  @override
  final breathDepth = .5.obs;
  @override
  final isIsochronicEnabled = false.obs;
  @override
  final isochronicFreq = 4.0.obs;
  @override
  final isochronicDuty = .5.obs;
  @override
  final isModulationEnabled = true.obs;
  @override
  final modulationType = NeomModulationType.fm.obs;
  @override
  final modulationDepth = .4.obs;
  @override
  final spatialMode = NeomSpatialMode.orbit.obs;
  @override
  final spatialIntensity = .5.obs;
  @override
  final orbitSpeed = .15.obs;
  @override
  final orbitDirection = 1.obs;
  @override
  void setOrbitDirection(int value) => orbitDirection.value = value;
  @override
  void setModulationEnabled(bool value) => isModulationEnabled.value = value;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Widget _host(Widget child, {double width = 320, double scale = 1}) =>
    MaterialApp(
      theme: ThemeData.dark(),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Center(
            child: SizedBox(
              width: width,
              child: SingleChildScrollView(child: child),
            ),
          ),
        ),
      ),
    );

void main() {
  setUp(() {
    Sint.addTranslations({
      'es': GeneratorEsTranslations.values,
      'en': GeneratorEnTranslations.values,
      'fr': GeneratorFrTranslations.values,
      'de': GeneratorDeTranslations.values,
    });
    Sint.locale = const Locale('es');
  });
  tearDown(() {
    Sint.clearTranslations();
    Sint.locale = null;
  });

  for (final language in ['es', 'en', 'fr', 'de']) {
    for (final width in [240.0, 320.0, 600.0]) {
      testWidgets('panels wrap at $width with 2x text ($language)', (
        tester,
      ) async {
        Sint.locale = Locale(language);
        final controller = _PanelController();
        await tester.pumpWidget(
          _host(
            Column(
              children: [
                NeomModulationControlPanel(controller: controller),
                NeomBreathControlPanel(controller: controller),
                NeomSpatialControlPanel(controller: controller),
              ],
            ),
            width: width,
            scale: 2,
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      });
    }
  }
}
