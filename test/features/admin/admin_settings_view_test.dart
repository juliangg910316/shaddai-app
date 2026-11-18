import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/widgets/app_widgets.dart';
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
    Stream<CalendarSettingsModel> Function() settings, {
    Size size = const Size(800, 2400),
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
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

  /// La tarjeta del lunes: "Cerrado" y su interruptor van al extremo
  /// derecho, separados del nombre del día (spec 008, RNF-2).
  void expectClosedAtRight(WidgetTester tester) {
    final card = find.ancestor(
      of: find.text('Lunes'),
      matching: find.byType(FlatCard),
    );
    final toggle = find.descendant(of: card, matching: find.byType(Switch));
    final label = find.descendant(of: card, matching: find.text('CERRADO'));
    // A la derecha: el interruptor acaba donde acaba el contenido de la
    // tarjeta (su margen derecho es de 12 px).
    expect(
      tester.getRect(toggle).right,
      closeTo(tester.getRect(card).right - 12, 1),
    );
    // Separado del día: entre "Lunes" y "CERRADO" hay más de 24 px, o están
    // en líneas distintas.
    // Lo que ocupan las letras del día, no su caja.
    final box = tester.getRect(find.text('Lunes'));
    final letters = tester
        .renderObject<RenderParagraph>(find.text('Lunes'))
        .getMaxIntrinsicWidth(double.infinity);
    final day = box.topLeft & Size(letters, box.height);
    final closed = tester.getRect(label);
    expect(
      closed.left - day.right > 24 || closed.top >= day.bottom,
      isTrue,
      reason: 'Lunes $day, CERRADO $closed',
    );
  }

  testWidgets('"Cerrado" y su interruptor van al extremo derecho', (
    tester,
  ) async {
    await open(
      tester,
      () => Stream.value(CalendarSettingsModel.defaultSettings()),
    );
    expectClosedAtRight(tester);
    // En una línea: el día, centrado con el interruptor.
    expect(
      tester.getCenter(find.text('Lunes')).dy,
      closeTo(tester.getCenter(find.byType(Switch).first).dy, 1),
    );
  });

  testWidgets('con el texto al 200 % en 320 px, bajan de línea, también a la '
      'derecha', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await open(
      tester,
      () => Stream.value(CalendarSettingsModel.defaultSettings()),
      size: const Size(320, 6000),
    );
    expect(tester.takeException(), isNull);
    expectClosedAtRight(tester);
  });
}
