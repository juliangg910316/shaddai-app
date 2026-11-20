import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/pump_app.dart';

/// El diálogo de cancelar de la admin, desde la agenda (spec 010, T7). Los
/// choques de un cierre lo prueban en `admin_closures_view_test.dart`.
///
/// El turno es el viernes 20/11/2026 de 10:00 a 10:45 del salón; "ahora",
/// las 9:00.
DateTime wall(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, 20, hour, minute);

AppointmentModel appointment({
  String status = 'confirmed',
  int hour = 10,
  String service = 'Manicura',
}) {
  final start = fromSalon(wall(hour));
  return AppointmentModel(
    id: 't1',
    clientId: 'ana',
    clientName: 'Ana',
    clientPhone: '+55 41 99999-0000',
    startTime: start,
    endTime: start.add(const Duration(minutes: 45)),
    status: status,
    createdAt: start,
    booked: BookedServiceModel(
      kind: BookedKind.service,
      id: service,
      name: BilingualText(es: service, pt: service),
      priceCents: 3000,
      durationMinutes: 45,
    ),
  );
}

void main() {
  late FakeBookingRepository bookings;

  setUp(() => bookings = FakeBookingRepository()..day = [appointment()]);

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'language': 'es'},
      home: const AdminDashboardView(),
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookings),
        configRepositoryProvider.overrideWithValue(FakeConfigRepository()),
        clockProvider.overrideWithValue(() => fromSalon(wall(9))),
        salonNowProvider.overrideWith((ref) => Stream.value(wall(9))),
        isWebProvider.overrideWithValue(false),
      ],
    );
    await settle(tester);
  }

  final card = find.byKey(const ValueKey('agenda-appointment-t1'));
  final dialog = find.byType(AlertDialog);
  Finder inDialog(Finder finder) =>
      find.descendant(of: dialog, matching: finder);
  final keep = inDialog(find.text('No, mantener'));
  final yes = inDialog(find.text('Sí, cancelar'));

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(
      find.descendant(of: card, matching: find.text('CANCELAR')),
    );
    await settle(tester);
    expect(dialog, findsOneWidget);
  }

  testWidgets('pide confirmación con la persona, el día, la hora del salón '
      'y el servicio (RF-12)', (tester) async {
    await pump(tester);
    await openDialog(tester);
    expect(inDialog(find.text('¿Cancelar el turno de Ana?')), findsOneWidget);
    expect(
      inDialog(find.text('Viernes, 20 de noviembre de 2026')),
      findsOneWidget,
    );
    expect(inDialog(find.text('10:00 – 10:45')), findsOneWidget);
    expect(inDialog(find.text('Manicura')), findsOneWidget);
    expect(keep, findsOneWidget);
    expect(yes, findsOneWidget);
    expect(bookings.adminCancelled, isEmpty);
  });

  group('sin cambios (RF-13)', () {
    testWidgets('"No, mantener"', (tester) async {
      await pump(tester);
      await openDialog(tester);
      await tester.tap(keep);
      await settle(tester);
      expect(dialog, findsNothing);
      expect(bookings.adminCancelled, isEmpty);
    });

    testWidgets('cerrar el diálogo tocando fuera', (tester) async {
      await pump(tester);
      await openDialog(tester);
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);
      expect(dialog, findsNothing);
      expect(bookings.adminCancelled, isEmpty);
    });
  });

  testWidgets('"Sí, cancelar" lo cancela, libera la hora y avisa; la '
      'tarjeta lo muestra cancelado (RF-14, RF-18)', (tester) async {
    await pump(tester);
    await openDialog(tester);
    await tester.tap(yes);
    await settle(tester);
    expect(dialog, findsNothing);
    expect(bookings.adminCancelled, ['t1']);
    expect(find.text('Turno cancelado.'), findsOneWidget);
    expect(
      find.descendant(of: card, matching: find.text('CANCELAR')),
      findsNothing,
    );
  });

  group('si el turno cambió, no lo cancela y avisa (RF-15)', () {
    testWidgets('ya no está activo', (tester) async {
      await pump(tester);
      await openDialog(tester);
      bookings.emitAppointment('t1', appointment(status: 'cancelled'));
      await tester.tap(yes);
      await settle(tester);
      expect(bookings.adminCancelled, isEmpty);
      expect(find.text('Este turno ya no está activo.'), findsOneWidget);
    });

    testWidgets('otra hora', (tester) async {
      await pump(tester);
      await openDialog(tester);
      bookings.emitAppointment('t1', appointment(hour: 11));
      await tester.tap(yes);
      await settle(tester);
      expect(bookings.adminCancelled, isEmpty);
      expect(
        find.text('El turno cambió. Revísalo antes de cancelarlo.'),
        findsOneWidget,
      );
    });

    testWidgets('otro servicio', (tester) async {
      await pump(tester);
      await openDialog(tester);
      bookings.emitAppointment('t1', appointment(service: 'Pedicura'));
      await tester.tap(yes);
      await settle(tester);
      expect(bookings.adminCancelled, isEmpty);
      expect(
        find.text('El turno cambió. Revísalo antes de cancelarlo.'),
        findsOneWidget,
      );
    });

    testWidgets('solo confirmado: se cancela igual', (tester) async {
      bookings.day = [appointment(status: 'waiting_confirmation')];
      await pump(tester);
      await openDialog(tester);
      bookings.emitAppointment('t1', appointment());
      await tester.tap(yes);
      await settle(tester);
      expect(bookings.adminCancelled, ['t1']);
    });
  });

  testWidgets('si falla, avisa sin detalles y deja reintentar (RF-17)', (
    tester,
  ) async {
    bookings.adminCancelError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    await pump(tester);
    await openDialog(tester);
    await tester.tap(yes);
    await settle(tester);
    expect(bookings.adminCancelled, isEmpty);
    expect(
      find.text('No se pudo cancelar el turno. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.textContaining('permission'), findsNothing);

    bookings.adminCancelError = null;
    await openDialog(tester);
    await tester.tap(yes);
    await settle(tester);
    expect(bookings.adminCancelled, ['t1']);
  });

  testWidgets('mientras cancela, todo desactivado y un segundo toque no '
      'repite (RF-16)', (tester) async {
    final gate = Completer<void>();
    bookings.adminCancelGate = gate.future;
    await pump(tester);
    await openDialog(tester);
    await tester.tap(yes);
    await tester.pump();

    expect(inDialog(find.byType(CircularProgressIndicator)), findsOneWidget);
    for (final button in tester.widgetList<ButtonStyleButton>(
      inDialog(find.byWidgetPredicate((w) => w is ButtonStyleButton)),
    )) {
      expect(button.onPressed, isNull);
    }
    await tester.tap(yes, warnIfMissed: false);
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(dialog, findsOneWidget);

    gate.complete();
    await settle(tester);
    expect(bookings.adminCancelled, ['t1']);
  });

  testWidgets('al cambiar de idioma con el diálogo abierto, cambia (RC-1)', (
    tester,
  ) async {
    await pump(tester);
    await openDialog(tester);
    await appContainer(tester)
        .read(languagePreferenceProvider.notifier)
        .select(AppLanguage.pt);
    await settle(tester);
    expect(inDialog(find.text('Cancelar o horário de Ana?')), findsOneWidget);
    expect(inDialog(find.text('Sim, cancelar')), findsOneWidget);
    expect(inDialog(find.text('Não, manter')), findsOneWidget);
    expect(
      inDialog(find.text('Sexta-feira, 20 de novembro de 2026')),
      findsOneWidget,
    );
  });
}
