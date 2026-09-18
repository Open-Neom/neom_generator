import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:neom_generator/data/translations/generator_es_translations.dart';
import 'package:neom_generator/domain/models/incienso.dart';
import 'package:neom_generator/ui/widgets/chamber_sessions_button.dart';
import 'package:neom_generator/utils/constants/generator_translation_constants.dart';
import 'package:sint/sint.dart';

void main() {
  setUp(() {
    Sint.addTranslations({'es': GeneratorEsTranslations.values});
    Sint.locale = const Locale('es');
  });
  tearDown(() {
    Sint.clearTranslations();
    Sint.locale = null;
  });
  testWidgets(
    'my sessions loads on demand and selects without producing audio',
    (tester) async {
      final pending = Completer<List<Incienso>>();
      var loads = 0;
      Incienso? selected;
      final session = Incienso(
        id: 'local-test',
        names: const {'es': 'Mi sesión'},
        leftFrequencyHz: 432,
        rightFrequencyHz: 439.83,
        suggestedDuration: const Duration(minutes: 5),
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChamberSessionsButton(
              loadSessions: () {
                loads++;
                return pending.future;
              },
              onSelected: (value) async => selected = value,
            ),
          ),
        ),
      );
      expect(loads, 0);
      await tester.tap(find.text(GeneratorTranslationConstants.mySessions.tr));
      await tester.pump();
      expect(loads, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      pending.complete([session]);
      await tester.pumpAndSettle();
      expect(find.text('Mi sesión'), findsOneWidget);
      expect(
        find.text(GeneratorTranslationConstants.selectSessionHint.tr),
        findsOneWidget,
      );
      await tester.tap(find.text('Mi sesión'));
      await tester.pumpAndSettle();
      expect(selected, same(session));
      expect(find.byType(AlertDialog), findsNothing);
    },
  );

  testWidgets('sessions show retry on load failure, then empty state', (
    tester,
  ) async {
    var calls = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChamberSessionsButton(
            loadSessions: () async {
              if (++calls == 1) throw StateError('test failure');
              return [];
            },
            onSelected: (_) async {},
          ),
        ),
      ),
    );
    await tester.tap(find.text(GeneratorTranslationConstants.mySessions.tr));
    await tester.pumpAndSettle();
    expect(
      find.text(GeneratorTranslationConstants.loadSessionsFailed.tr),
      findsOneWidget,
    );
    await tester.tap(find.text(GeneratorTranslationConstants.retryLoad.tr));
    await tester.pumpAndSettle();
    expect(
      find.text(GeneratorTranslationConstants.emptySessions.tr),
      findsOneWidget,
    );
    expect(calls, 2);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dismissed sessions do not select anything', (tester) async {
    var selected = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ChamberSessionsButton(
            loadSessions: () async => [],
            onSelected: (_) async => selected = true,
          ),
        ),
      ),
    );
    await tester.tap(find.text(GeneratorTranslationConstants.mySessions.tr));
    await tester.pumpAndSettle();
    await tester.tap(find.text(GeneratorTranslationConstants.cancelControl.tr));
    await tester.pumpAndSettle();
    expect(selected, isFalse);
  });

  testWidgets(
    'favorite and export act on the chosen session without loading it',
    (tester) async {
      final session = Incienso(
        id: 'session-1',
        isPublic: true,
        names: const {'es': 'Mi sesión'},
        leftFrequencyHz: 432,
        rightFrequencyHz: 440,
        suggestedDuration: const Duration(minutes: 5),
      );
      var favorite = false;
      Incienso? exported;
      var loads = 0;
      var exportError = '';
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ChamberSessionsButton(
              loadSessions: () async => [session],
              onSelected: (_) async {
                loads++;
              },
              isFavorite: (_) => favorite,
              onToggleFavorite: (id) async {
                expect(id, session.id);
                favorite = !favorite;
              },
              onExport: (value) async {
                exported = value;
                exportError = 'Could not export reference';
              },
              errorMessage: () => exportError,
            ),
          ),
        ),
      );
      await tester.tap(find.text(GeneratorTranslationConstants.mySessions.tr));
      await tester.pumpAndSettle();
      await tester.tap(
        find.byTooltip(GeneratorTranslationConstants.practiceSessionActions.tr),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(GeneratorTranslationConstants.practiceFavorite.tr),
      );
      await tester.pumpAndSettle();
      expect(favorite, isTrue);
      expect(loads, 0);
      await tester.tap(
        find.byTooltip(GeneratorTranslationConstants.practiceSessionActions.tr),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(GeneratorTranslationConstants.practiceExport.tr),
      );
      await tester.pumpAndSettle();
      expect(exported, same(session));
      expect(
        find.text('Could not export reference').hitTestable(),
        findsOneWidget,
      );
      expect(loads, 0);
      expect(tester.takeException(), isNull);
    },
  );
}
