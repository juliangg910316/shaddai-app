import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/features/admin/presentation/admin_settings_view.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/pump_app.dart';

/// El margen de edición en los ajustes del horario (spec 008, RF-36 a
/// RF-39, RF-41).
void main() {
  late FakeConfigRepository config;

  CalendarSettingsModel settingsWith(int margin) => CalendarSettingsModel(
    openingHours: CalendarSettingsModel.defaultSettings().openingHours,
    globalSlotDurationMinutes: 30,
    blockedDates: const ['2026-12-25'],
    editMarginMinutes: margin,
  );

  Future<void> open(
    WidgetTester tester, {
    int margin = 1440,
    String language = 'es',
  }) async {
    config = FakeConfigRepository(settings: settingsWith(margin));
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'language': language},
      home: const AdminSettingsView(),
      overrides: [
        configRepositoryProvider.overrideWithValue(config),
        bookingRepositoryProvider.overrideWithValue(FakeBookingRepository()),
        userRepositoryProvider.overrideWithValue(FakeUserRepository()),
      ],
    );
    await tester.pumpAndSettle();
  }

  final field = find.byKey(const ValueKey('edit-margin'));

  /// El texto elegido en el desplegable del margen.
  Finder shown(String text) =>
      find.descendant(of: field, matching: find.text(text));

  Future<void> choose(WidgetTester tester, String option) async {
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.text(option).last);
    await tester.pumpAndSettle();
  }

  testWidgets('muestra el margen actual, con su explicación (RF-36)', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('Margen de edición'), findsOneWidget);
    expect(
      find.text('Hasta cuánto antes del turno puede cambiarlo la clienta.'),
      findsOneWidget,
    );
    expect(shown('24 horas'), findsOneWidget);
  });

  testWidgets('las opciones, de "Sin margen" a 72 horas (RF-36)', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(field);
    await tester.pumpAndSettle();
    for (final option in [
      'Sin margen',
      '1 hora',
      '2 horas',
      '3 horas',
      '6 horas',
      '12 horas',
      '48 horas',
      '72 horas',
    ]) {
      expect(find.text(option), findsOneWidget, reason: option);
    }
  });

  testWidgets('en portugués', (tester) async {
    await open(tester, margin: 0, language: 'pt');
    expect(find.text('Prazo para alterações'), findsOneWidget);
    expect(shown('Sem prazo'), findsOneWidget);
  });

  testWidgets('un margen que no es una opción sale en horas y minutos '
      '(RF-37)', (tester) async {
    await open(tester, margin: 90);
    expect(shown('1 h 30 min'), findsOneWidget);
  });

  testWidgets('al elegir otra opción guarda solo el margen y lo confirma '
      '(RF-38, RF-41)', (tester) async {
    await open(tester);
    await choose(tester, '2 horas');

    expect(config.margins, [120]);
    expect(config.updatedSettings, isEmpty);
    expect(find.text('Margen guardado.'), findsOneWidget);
    expect(shown('2 horas'), findsOneWidget);
    expect(config.settings.blockedDates, ['2026-12-25']);
  });

  testWidgets('si no se puede guardar, lo dice y vuelve al margen que había '
      '(RF-39)', (tester) async {
    await open(tester);
    config.saveError = Exception('sin red');
    await choose(tester, '2 horas');

    expect(config.margins, isEmpty);
    expect(find.text('No se pudo guardar el margen.'), findsOneWidget);
    expect(shown('24 horas'), findsOneWidget);
    expect(shown('2 horas'), findsNothing);
  });

  testWidgets('"Guardar" del horario no cambia el margen ni las fechas '
      'bloqueadas (RF-41)', (tester) async {
    await open(tester);
    await tester.tap(find.byIcon(Icons.check));
    await tester.pumpAndSettle();

    expect(config.updatedSettings, hasLength(1));
    expect(config.margins, isEmpty);
    expect(config.settings.editMarginMinutes, 1440);
    expect(config.settings.blockedDates, ['2026-12-25']);
    // Lo que se envía a Firestore (con `merge`) no lleva esos campos.
    final sent = config.updatedSettings.single.toMap();
    expect(sent.containsKey('editMarginMinutes'), isFalse);
    expect(sent.containsKey('blockedDates'), isFalse);
  });
}
