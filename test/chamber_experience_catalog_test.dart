import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_core/utils/constants/app_route_constants.dart';
import 'package:neom_generator/data/translations/generator_de_translations.dart';
import 'package:neom_generator/data/translations/generator_en_translations.dart';
import 'package:neom_generator/data/translations/generator_es_translations.dart';
import 'package:neom_generator/data/translations/generator_fr_translations.dart';
import 'package:neom_generator/ui/experiences/neom_experiences_page.dart';
import 'package:neom_generator/utils/constants/generator_translation_constants.dart';
import 'package:sint/sint.dart';

void main() {
  test('both added experience names exist in every Generator locale', () {
    for (final translations in [
      GeneratorEsTranslations.values,
      GeneratorEnTranslations.values,
      GeneratorFrTranslations.values,
      GeneratorDeTranslations.values,
    ]) {
      expect(
        translations[GeneratorTranslationConstants.neomatics],
        'Neomatics',
      );
      expect(
        translations[GeneratorTranslationConstants.neuroMandala],
        'NeuroMandala',
      );
    }
  });

  testWidgets('catalog opens all five visual routes at narrow width', (
    tester,
  ) async {
    const destinations = {
      GeneratorTranslationConstants.neuroFlocking:
          AppRouteConstants.flockingFullscreen,
      GeneratorTranslationConstants.neuroBreathing:
          AppRouteConstants.breathingFullscreen,
      GeneratorTranslationConstants.fractalVisualization:
          AppRouteConstants.fractalFullscreen,
      GeneratorTranslationConstants.neomatics:
          AppRouteConstants.neomaticsFullscreen,
      GeneratorTranslationConstants.neuroMandala:
          AppRouteConstants.neuromandalaFullscreen,
    };
    Sint.addTranslations({'es': GeneratorEsTranslations.values});
    Sint.locale = const Locale('es');
    await tester.binding.setSurfaceSize(const Size(320, 800));
    addTearDown(() async {
      Sint.clearTranslations();
      Sint.locale = null;
      await tester.binding.setSurfaceSize(null);
    });
    await tester.pumpWidget(
        SintMaterialApp(
          theme: ThemeData.dark(),
          initialRoute: AppRouteConstants.chamberExperiences,
          // Route-only stand-ins: no audio, platform sensors, or remote services.
          sintPages: [
            SintPage(
              name: AppRouteConstants.chamberExperiences,
              page: () => const MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2)),
                child: NeomExperiencesPage(),
              ),
            ),
          for (final route in destinations.values)
            SintPage(
              name: route,
              page: () => Scaffold(body: Text(route)),
            ),
        ],
      ),
    );
    await tester.pumpAndSettle();
    for (final destination in destinations.entries) {
      final label = find.text(destination.key.tr);
      await tester.scrollUntilVisible(
        label,
        160,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(label);
      await tester.pumpAndSettle();
      expect(find.text(destination.value), findsOneWidget);
      expect(tester.takeException(), isNull);
      Sint.back();
      await tester.pumpAndSettle();
    }
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pumpAndSettle();
  });
}
