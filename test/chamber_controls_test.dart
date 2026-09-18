import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/data/translations/generator_de_translations.dart';
import 'package:neom_generator/data/translations/generator_en_translations.dart';
import 'package:neom_generator/data/translations/generator_es_translations.dart';
import 'package:neom_generator/data/translations/generator_fr_translations.dart';
import 'package:neom_generator/ui/widgets/camara_neom_tutorial.dart';
import 'package:neom_generator/ui/widgets/chamber_controls.dart';
import 'package:neom_generator/utils/constants/generator_translation_constants.dart';
import 'package:sint/sint.dart';

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

  testWidgets(
    'numeric card selects without changing beat and preserves decimals',
    (tester) async {
      var selects = 0;
      var increases = 0;
      String? submitted;
      await tester.pumpWidget(
        _host(
          ChamberFrequencyControl(
            label: 'Beat',
            value: 7.83,
            selected: false,
            onSelect: () => selects++,
            onSubmit: (value) => submitted = value,
            onIncrease: () => increases++,
            onDecrease: () {},
          ),
          width: 240,
          scale: 2,
        ),
      );
      expect(find.text('7.83 Hz'), findsOneWidget);
      await tester.tap(find.text('Beat'));
      await tester.pump();
      expect(selects, 1);
      expect(increases, 0);
      await tester.tap(find.byIcon(Icons.edit_outlined));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '7.83',
      );
      await tester.enterText(find.byType(TextField), '8.25');
      await tester.tap(
        find.text(GeneratorTranslationConstants.applyControl.tr),
      );
      await tester.pumpAndSettle();
      expect(submitted, '8.25');
      expect(increases, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'play/stop stays cancellable during startup and supports keyboard',
    (tester) async {
      var presses = 0;
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          ChamberPlaybackButton(
            requested: true,
            transitioning: true,
            onPressed: () => presses++,
          ),
        ),
      );
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        find.byTooltip(GeneratorTranslationConstants.stopChamber.tr),
        findsWidgets,
      );
      await tester.tap(find.byIcon(Icons.stop_rounded));
      await tester.pump();
      expect(presses, 1);
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(presses, 2);
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('octaves wrap and retain selected state with large text', (
    tester,
  ) async {
    int? changed;
    await tester.pumpWidget(
      _host(
        ChamberOctaveControl(
          octave: 0,
          effectiveFrequency: 432.25,
          onChanged: (value) => changed = value,
        ),
        width: 240,
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    final choices = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .toList();
    expect(choices.length, 9);
    expect(choices[4].selected, isTrue);
    await tester.ensureVisible(find.text('2x'));
    await tester.tap(find.text('2x'));
    await tester.pump();
    expect(changed, 1);
  });

  testWidgets(
    'tutorial scrolls on a small landscape viewport with large text',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 240));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: CamaraNeomTutorial(onComplete: () {}),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(
        find.text(GeneratorTranslationConstants.guideNext.tr),
      );
      await tester.tap(find.text(GeneratorTranslationConstants.guideNext.tr));
      await tester.pump();
      expect(find.text('2 / 5'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('frequency formatting avoids integer truncation', () {
    expect(formatChamberFrequency(432.25), '432.25');
    expect(formatChamberFrequency(7.83), '7.83');
    expect(formatChamberFrequency(0), '0');
    expect(formatChamberFrequency(10), '10');
    expect(formatChamberFrequency(double.nan), '0');
  });

  testWidgets('compact Hz row edits directly with accessible step targets', (
    tester,
  ) async {
    var increases = 0;
    var decreases = 0;
    String? submitted;
    await tester.pumpWidget(
      _host(
        ChamberFrequencyControl(
          compact: true,
          label: 'Raíz',
          value: 178.25,
          selected: true,
          onSelect: () {},
          onSubmit: (value) => submitted = value,
          onIncrease: () => increases++,
          onDecrease: () => decreases++,
        ),
        width: 220,
      ),
    );
    expect(
      tester.getSize(find.byType(ChamberFrequencyControl)).height,
      lessThan(100),
    );
    for (final icon in [Icons.remove, Icons.add]) {
      final target = find.ancestor(
        of: find.byIcon(icon),
        matching: find.byType(IconButton),
      );
      expect(tester.getSize(target).width, greaterThanOrEqualTo(48));
      expect(tester.getSize(target).height, greaterThanOrEqualTo(48));
      await tester.tap(target);
    }
    expect(increases, 1);
    expect(decreases, 1);
    await tester.tap(find.text('178.25 Hz'));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '178.25',
    );
    await tester.enterText(find.byType(TextField), '182,75');
    await tester.tap(find.text(GeneratorTranslationConstants.applyControl.tr));
    await tester.pumpAndSettle();
    expect(submitted, '182.75');
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact Hz control reflows in narrow large-text cards', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        ChamberFrequencyControl(
          compact: true,
          label: 'Frecuencia Raíz',
          value: 1234.5,
          selected: false,
          onSelect: () {},
          onSubmit: (_) {},
          onIncrease: () {},
          onDecrease: () {},
        ),
        width: 144,
        scale: 2,
      ),
    );
    expect(find.text('1234.5 Hz'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact octave selector retains all octave choices', (
    tester,
  ) async {
    int? changed;
    await tester.pumpWidget(
      _host(
        ChamberOctaveControl(
          compact: true,
          octave: 0,
          effectiveFrequency: 178,
          onChanged: (value) => changed = value,
        ),
        width: 240,
        scale: 2,
      ),
    );
    expect(tester.takeException(), isNull);
    expect(
      tester
          .widget<DropdownButton<int>>(find.byType(DropdownButton<int>))
          .items!
          .length,
      9,
    );
    await tester.tap(find.byType(DropdownButton<int>));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('2x').last);
    await tester.tap(find.text('2x').last);
    await tester.pumpAndSettle();
    expect(changed, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('failed session save is visible and retry cannot overlap', (
    tester,
  ) async {
    final completion = Completer<void>();
    var calls = 0;
    await tester.pumpWidget(
      _host(
        ChamberFeedback(
          playbackError: 'Audio failed',
          saveError: 'Save failed',
          onRetrySave: () {
            calls++;
            return completion.future;
          },
        ),
        width: 240,
        scale: 2,
      ),
    );
    expect(find.text('Audio failed'), findsOneWidget);
    expect(find.text('Save failed'), findsOneWidget);
    await tester.tap(find.byType(OutlinedButton));
    await tester.pump();
    await tester.tap(find.byType(OutlinedButton));
    expect(calls, 1);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    completion.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing rejects NaN and accepts a decimal comma', (
    tester,
  ) async {
    String? submitted;
    await tester.pumpWidget(
      _host(
        ChamberFrequencyControl(
          label: 'Frequency',
          value: 432.123,
          selected: true,
          onSelect: () {},
          onSubmit: (value) => submitted = value,
          onIncrease: () {},
          onDecrease: () {},
        ),
      ),
    );
    await tester.tap(find.byIcon(Icons.edit_outlined));
    await tester.pumpAndSettle();
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      '432.123',
    );
    await tester.enterText(find.byType(TextField), 'NaN');
    await tester.tap(find.text(GeneratorTranslationConstants.applyControl.tr));
    await tester.pump();
    expect(
      find.text(GeneratorTranslationConstants.invalidFrequencyControl.tr),
      findsOneWidget,
    );
    expect(submitted, isNull);
    await tester.enterText(find.byType(TextField), '432,25');
    await tester.tap(find.text(GeneratorTranslationConstants.applyControl.tr));
    await tester.pumpAndSettle();
    expect(submitted, '432.25');
  });
}
