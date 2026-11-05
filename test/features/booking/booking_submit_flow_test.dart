import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/active_appointment_view.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/booking_steps.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

// "Ahora" es el martes 10/11/2026 a las 7:00. La reserva elige las 10:00 y
// el primer servicio de la lista de los tests, de 1 h.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

BusySlot busy(DateTime start, DateTime end) =>
    BusySlot(id: 'x', start: fromSalon(start), end: fromSalon(end));

/// Un turno de [testClient] del viernes 20, reservado desde otro
/// dispositivo.
AppointmentModel otherActive() => AppointmentModel(
  id: 'otro',
  clientId: testClient.uid,
  clientName: testClient.displayName,
  clientPhone: testClient.phoneNumber!,
  startTime: fromSalon(at(20, 9)),
  endTime: fromSalon(at(20, 10)),
  status: 'waiting_confirmation',
  createdAt: bookingTestNow,
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeBookingRepository bookings;

  setUp(() => bookings = FakeBookingRepository());

  Future<void> pump(WidgetTester tester, {bool web = false}) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'language': 'es'},
      home: const BookingView(),
      overrides: [
        ...bookingDataOverrides(bookings: bookings),
        isWebProvider.overrideWithValue(web),
      ],
    );
    await settle(tester);
  }

  Future<void> book(WidgetTester tester) async {
    await openBookingConfirmation(tester, settle: () => settle(tester));
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ElevatedButton),
      ),
    );
    await settle(tester);
  }

  BookingSelection selection(WidgetTester tester) =>
      appContainer(tester).read(bookingSelectionProvider).selection;

  testWidgets('al confirmar, se guarda, sale el aviso de éxito y se ve el '
      'turno (RF-27, RF-32)', (tester) async {
    await pump(tester);
    await book(tester);

    expect(bookings.created, hasLength(1));
    expect(
      find.text(
        '¡Reserva creada exitosamente! Esperando confirmación del '
        'administrador.',
      ),
      findsOneWidget,
    );
    expect(find.byType(ActiveAppointmentView), findsOneWidget);
  });

  testWidgets('en Web, el diálogo con "Volver al inicio" (RF-32)', (
    tester,
  ) async {
    await pump(tester, web: true);
    await book(tester);

    expect(bookings.created, hasLength(1));
    expect(find.text('Reserva creada'), findsOneWidget);
    expect(find.text('Volver al inicio'), findsOneWidget);
  });

  testWidgets('hora ocupada: no guarda, quita la hora, conserva lo reservado '
      'y la fecha, y avisa (RF-29)', (tester) async {
    await pump(tester);
    bookings.checkData = (
      busy: [busy(at(10, 10), at(10, 11))],
      mine: const <AppointmentModel>[],
    );
    await book(tester);

    expect(bookings.created, isEmpty);
    expect(selection(tester).start, isNull);
    expect(selection(tester).item, isNotNull);
    expect(selection(tester).day, DateTime.utc(2026, 11, 10));
    expect(
      find.text('Esa hora acaba de ocuparse. Elige otra.'),
      findsOneWidget,
    );
  });

  testWidgets('ya no cabe: no guarda, quita la hora y avisa (RF-30)', (
    tester,
  ) async {
    await pump(tester);
    bookings.checkData = (
      busy: [busy(at(10, 10, 30), at(10, 11))],
      mine: const <AppointmentModel>[],
    );
    await book(tester);

    expect(bookings.created, isEmpty);
    expect(selection(tester).start, isNull);
    expect(selection(tester).item, isNotNull);
    expect(
      find.text(
        'La hora elegida ya no tiene tiempo suficiente para el servicio. '
        'Elige otra.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('ya tiene un turno activo: no guarda, avisa y se ve el que '
      'tiene (RF-36)', (tester) async {
    await pump(tester);
    // Reservado desde otro dispositivo: aún no ha llegado a esta pantalla.
    bookings.mine = [otherActive()];
    await book(tester);

    expect(bookings.created, isEmpty);
    expect(find.text('Ya tienes un turno pendiente.'), findsOneWidget);
    expect(find.byType(ActiveAppointmentView), findsOneWidget);
  });

  testWidgets('con un error, avisa sin detalles técnicos y conserva lo '
      'elegido (RF-31)', (tester) async {
    await pump(tester);
    bookings.saveError = Exception('permission-denied');
    await openBookingConfirmation(tester, settle: () => settle(tester));
    final before = selection(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(ElevatedButton),
      ),
    );
    await settle(tester);

    expect(bookings.created, isEmpty);
    expect(
      find.text('No pudimos crear la reserva. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.textContaining('permission-denied'), findsNothing);
    expect(selection(tester), before);
  });
}
