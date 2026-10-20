import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';

import '../helpers/pump_app.dart';

void _setDeviceLocales(WidgetTester tester, List<Locale> locales) {
  tester.platformDispatcher.localesTestValue = locales;
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
}

String _appText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('app'))).data!;

String _materialText(WidgetTester tester) =>
    tester.widget<Text>(find.byKey(const Key('material'))).data!;

void main() {
  group('sin preferencia guardada (RF-9)', () {
    testWidgets('dispositivo en portugués de Brasil → portugués', (
      tester,
    ) async {
      _setDeviceLocales(tester, const [Locale('pt', 'BR')]);

      await pumpApp(tester);

      expect(probeLanguage(tester), 'pt');
      expect(_appText(tester), 'Início');
    });

    testWidgets('dispositivo en español de Argentina → español', (
      tester,
    ) async {
      _setDeviceLocales(tester, const [Locale('es', 'AR')]);

      await pumpApp(tester);

      expect(probeLanguage(tester), 'es');
      expect(_appText(tester), 'Inicio');
    });

    testWidgets('dispositivo en inglés → español', (tester) async {
      _setDeviceLocales(tester, const [Locale('en', 'US')]);

      await pumpApp(tester);

      expect(probeLanguage(tester), 'es');
    });
  });

  testWidgets(
    'con portugués guardado y el dispositivo en español, portugués desde el '
    'primer fotograma (RF-12)',
    (tester) async {
      _setDeviceLocales(tester, const [Locale('es', 'ES')]);

      await pumpApp(tester, stored: {'language': 'pt'});

      expect(probeLanguage(tester), 'pt');
      expect(_appText(tester), 'Início');
    },
  );

  testWidgets('elegir portugués traduce los textos de la app y los de Material '
      '(RF-10, RNF-2)', (tester) async {
    _setDeviceLocales(tester, const [Locale('es', 'ES')]);
    await pumpApp(tester);
    expect(_materialText(tester), 'ACEPTAR');

    await appContainer(
      tester,
    ).read(languagePreferenceProvider.notifier).select(AppLanguage.pt);
    await tester.pump();

    expect(_appText(tester), 'Início');
    expect(_materialText(tester), 'OK');
  });

  group('idioma del dispositivo cambiado con la app abierta (RF-20)', () {
    testWidgets('sin preferencia, la app cambia de idioma', (tester) async {
      _setDeviceLocales(tester, const [Locale('es', 'ES')]);
      await pumpApp(tester);
      expect(probeLanguage(tester), 'es');

      tester.platformDispatcher.localesTestValue = const [Locale('pt', 'BR')];
      await tester.pump();

      expect(probeLanguage(tester), 'pt');
      expect(_appText(tester), 'Início');
    });

    testWidgets('con preferencia guardada, no cambia', (tester) async {
      _setDeviceLocales(tester, const [Locale('pt', 'BR')]);
      await pumpApp(tester, stored: {'language': 'es'});

      tester.platformDispatcher.localesTestValue = const [Locale('pt', 'PT')];
      await tester.pump();

      expect(probeLanguage(tester), 'es');
    });
  });

  testWidgets('cambiar el idioma conserva lo escrito (RF-10)', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('field')), 'Ana');

    await appContainer(
      tester,
    ).read(languagePreferenceProvider.notifier).select(AppLanguage.pt);
    await tester.pump();

    expect(find.text('Ana'), findsOneWidget);
  });
}
