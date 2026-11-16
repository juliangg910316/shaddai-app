import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/features/admin/presentation/admin_settings_view.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/pump_app.dart';

/// La pantalla de ajustes del calendario no se queda cargando para siempre:
/// ni si el calendario llega después de abrirla, ni con un horario
/// incompleto, ni si no se puede leer.
void main() {
  Future<void> open(
    WidgetTester tester,
    Stream<CalendarSettingsModel> Function() settings,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'language': 'es'},
      home: const AdminSettingsView(),
      overrides: [calendarSettingsProvider.overrideWith((ref) => settings())],
    );
    await tester.pump();
    await tester.pump();
  }

  testWidgets('el calendario llega después de abrir la pantalla: se ven los '
      'días', (tester) async {
    final controller = StreamController<CalendarSettingsModel>();
    addTearDown(controller.close);
    await open(tester, () => controller.stream);
    expect(find.text('Lunes'), findsNothing);

    controller.add(CalendarSettingsModel.defaultSettings());
    await tester.pump();
    await tester.pump();
    expect(find.text('Lunes'), findsOneWidget);
    expect(find.text('Domingo'), findsOneWidget);
  });

  testWidgets('documento con solo el margen: se ve el horario por defecto', (
    tester,
  ) async {
    await open(
      tester,
      () => Stream.value(
        CalendarSettingsModel.fromMap({'editMarginMinutes': 1440}),
      ),
    );
    expect(find.text('Lunes'), findsOneWidget);
    expect(find.text('09:00'), findsWidgets);
  });

  testWidgets('horario con algún día sin guardar: ese día sale cerrado, sin '
      'fallar', (tester) async {
    await open(
      tester,
      () => Stream.value(
        CalendarSettingsModel.fromMap({
          'openingHours': {
            'monday': {'open': '10:00', 'close': '19:00', 'isClosed': false},
          },
        }),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Lunes'), findsOneWidget);
    expect(find.text('10:00'), findsOneWidget);
    expect(find.text('Martes'), findsOneWidget);
    // Solo el lunes abre: un único par de campos de hora.
    expect(find.byType(TextFormField), findsNWidgets(2));
  });

  testWidgets('no se puede leer el calendario: aviso con "Reintentar"', (
    tester,
  ) async {
    await open(tester, () => Stream.error(Exception('sin red')));
    expect(find.byType(CircularProgressIndicator), findsNothing);
    expect(find.textContaining('REINTENTAR'), findsOneWidget);
  });
}
