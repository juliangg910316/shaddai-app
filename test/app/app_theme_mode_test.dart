import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/core/theme/brand_colors.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';

import '../helpers/pump_app.dart';

void _setDeviceBrightness(WidgetTester tester, Brightness brightness) {
  tester.platformDispatcher.platformBrightnessTestValue = brightness;
  addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
}

void main() {
  testWidgets('con oscuro guardado, el primer fotograma ya es oscuro (RF-7)', (
    tester,
  ) async {
    _setDeviceBrightness(tester, Brightness.light);

    await pumpApp(tester, stored: {'theme': 'dark'});

    expect(probeBrightness(tester), Brightness.dark);
    final context = tester.element(find.byType(ProbePage));
    expect(context.brand, BrandColors.dark);
  });

  testWidgets('con claro guardado ignora el modo oscuro del dispositivo', (
    tester,
  ) async {
    _setDeviceBrightness(tester, Brightness.dark);

    await pumpApp(tester, stored: {'theme': 'light'});

    expect(probeBrightness(tester), Brightness.light);
  });

  testWidgets('sin preferencia sigue al dispositivo (RF-2, RF-3)', (
    tester,
  ) async {
    _setDeviceBrightness(tester, Brightness.dark);

    await pumpApp(tester);

    expect(probeBrightness(tester), Brightness.dark);
  });

  testWidgets(
    'con sistema, el cambio del dispositivo se aplica en el siguiente '
    'fotograma (RF-4, RNF-2)',
    (tester) async {
      _setDeviceBrightness(tester, Brightness.light);
      await pumpApp(tester, stored: {'theme': 'system'});
      expect(probeBrightness(tester), Brightness.light);

      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      await tester.pump();

      expect(probeBrightness(tester), Brightness.dark);
    },
  );

  testWidgets('un dispositivo sin modo oscuro da claro', (tester) async {
    // Sin valor de prueba, el dispositivo de test informa de brillo claro.
    await pumpApp(tester);

    expect(probeBrightness(tester), Brightness.light);
  });

  testWidgets('elegir un tema se ve en el siguiente fotograma (RF-5, RNF-2)', (
    tester,
  ) async {
    _setDeviceBrightness(tester, Brightness.light);
    await pumpApp(tester);

    await appContainer(
      tester,
    ).read(themePreferenceProvider.notifier).select(ThemePreference.dark);
    await tester.pump();

    expect(probeBrightness(tester), Brightness.dark);
  });

  testWidgets('cambiar el tema conserva lo escrito (RF-5)', (tester) async {
    await pumpApp(tester);
    await tester.enterText(find.byKey(const Key('field')), 'Ana');

    await appContainer(
      tester,
    ).read(themePreferenceProvider.notifier).select(ThemePreference.dark);
    await tester.pump();

    expect(find.text('Ana'), findsOneWidget);
  });
}
