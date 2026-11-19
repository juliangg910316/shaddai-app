import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/active_appointment_view.dart';
import 'package:shaddai/features/booking/presentation/booking_form.dart';
import 'package:shaddai/features/booking/presentation/booking_notices.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

// Horas de pared del salón. "Ahora" es el martes 10/11/2026 a las 7:00.
DateTime at(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, 10, hour, minute);

/// Su turno activo: hoy de 9:00 a 9:45, Manicura.
AppointmentModel appointment({DateTime? start, String status = 'confirmed'}) {
  final from = fromSalon(start ?? at(9));
  return AppointmentModel(
    id: 't1',
    clientId: testClient.uid,
    clientName: testClient.displayName,
    clientPhone: testClient.phoneNumber!,
    startTime: from,
    endTime: from.add(const Duration(minutes: 45)),
    status: status,
    createdAt: bookingTestNow,
    booked: const BookedServiceModel(
      kind: BookedKind.service,
      id: 's1',
      name: BilingualText(es: 'Manicura', pt: 'Manicure'),
      priceCents: 3000,
      durationMinutes: 45,
    ),
  );
}

CalendarSettingsModel withMargin(int minutes) {
  final defaults = CalendarSettingsModel.defaultSettings();
  return CalendarSettingsModel(
    openingHours: defaults.openingHours,
    globalSlotDurationMinutes: defaults.globalSlotDurationMinutes,
    blockedDates: defaults.blockedDates,
    editMarginMinutes: minutes,
  );
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

final cancelButton = find.text('CANCELAR TURNO');
final dialog = find.byType(AlertDialog);
Finder inDialog(Finder finder) => find.descendant(of: dialog, matching: finder);
final confirmButton = inDialog(find.text('Sí, cancelar'));
final keepButton = inDialog(find.text('No, mantener'));

void main() {
  late FakeBookingRepository bookings;

  setUp(() {
    bookings = FakeBookingRepository(mine: [appointment()]);
  });

  /// La reserva con su turno activo. [now] es "ahora" para cancelar (hora
  /// de pared); la vista ve las 7:00, salvo con [nowStream].
  Future<void> pump(
    WidgetTester tester, {
    int margin = 0,
    String language = 'es',
    UserModel? user,
    DateTime? now,
  }) async {
    await pumpApp(
      tester,
      stored: {'language': language},
      home: const BookingView(),
      overrides: bookingDataOverrides(
        bookings: bookings,
        user: user,
        now: now == null ? null : fromSalon(now),
        nowStream: () => Stream.value(at(7)),
        settings: withMargin(margin),
      ),
    );
    await settle(tester);
  }

  /// Abre el diálogo de cancelar.
  Future<void> openDialog(WidgetTester tester) async {
    await tester.ensureVisible(cancelButton);
    await tester.tap(cancelButton);
    await tester.pump(const Duration(milliseconds: 300));
  }

  testWidgets('"Cancelar turno" está junto a "Editar turno" (RF-8)', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byType(ActiveAppointmentView), findsOneWidget);
    expect(find.text('EDITAR TURNO'), findsOneWidget);
    expect(cancelButton, findsOneWidget);
  });

  testWidgets('en portugués', (tester) async {
    await pump(tester, language: 'pt');
    expect(find.text('CANCELAR HORÁRIO'), findsOneWidget);
    await tester.ensureVisible(find.text('CANCELAR HORÁRIO'));
    await tester.tap(find.text('CANCELAR HORÁRIO'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(inDialog(find.text('Cancelar seu horário?')), findsOneWidget);
    expect(inDialog(find.text('Sim, cancelar')), findsOneWidget);
    expect(inDialog(find.text('Não, manter')), findsOneWidget);
    expect(inDialog(find.text('Manicure')), findsOneWidget);
  });

  testWidgets('el diálogo muestra el día, la hora del salón y el servicio '
      '(RF-9)', (tester) async {
    await pump(tester);
    await openDialog(tester);
    expect(inDialog(find.text('¿Cancelar tu turno?')), findsOneWidget);
    expect(inDialog(find.textContaining('10 de noviembre')), findsOneWidget);
    expect(inDialog(find.text('9:00 – 9:45')), findsOneWidget);
    expect(inDialog(find.text('Manicura')), findsOneWidget);
    expect(confirmButton, findsOneWidget);
    expect(keepButton, findsOneWidget);
  });

  testWidgets('"No, mantener" no cambia nada (RF-10)', (tester) async {
    await pump(tester);
    await openDialog(tester);
    await tester.tap(keepButton);
    await tester.pumpAndSettle();
    expect(dialog, findsNothing);
    expect(bookings.cancelled, isEmpty);
    expect(find.byType(ActiveAppointmentView), findsOneWidget);
  });

  testWidgets('"Sí, cancelar": lo cancela, avisa y vuelve a la vista de '
      'reservar (RF-11, RF-12)', (tester) async {
    await pump(tester);
    await openDialog(tester);
    await tester.tap(confirmButton);
    await settle(tester);
    await tester.pump(const Duration(milliseconds: 300));

    expect(bookings.cancelled, ['t1']);
    expect(dialog, findsNothing);
    expect(find.byType(ActiveAppointmentView), findsNothing);
    expect(find.byType(BookingForm), findsOneWidget);
    expect(find.text('Tu turno se canceló.'), findsOneWidget);
  });

  testWidgets('mientras cancela, los botones están desactivados y un segundo '
      'toque no cancela dos veces (RF-16)', (tester) async {
    final gate = Completer<void>();
    bookings.cancelGate = gate.future;
    await pump(tester);
    await openDialog(tester);
    await tester.tap(confirmButton);
    await tester.pump();

    expect(inDialog(find.byType(CircularProgressIndicator)), findsOneWidget);
    for (final button in tester.widgetList<ButtonStyleButton>(
      inDialog(find.byWidgetPredicate((w) => w is ButtonStyleButton)),
    )) {
      expect(button.onPressed, isNull);
    }
    await tester.tap(confirmButton, warnIfMissed: false);
    await tester.pump();

    gate.complete();
    await settle(tester);
    expect(bookings.cancelled, ['t1']);
  });

  group('si no se puede cancelar, un texto para cada caso (RF-14, RF-15)', () {
    Future<void> confirm(WidgetTester tester) async {
      await openDialog(tester);
      await tester.tap(confirmButton);
      await settle(tester);
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('la admin lo canceló', (tester) async {
      await pump(tester);
      bookings.emitAppointment('t1', appointment(status: 'cancelled'));
      await confirm(tester);
      expect(bookings.cancelled, isEmpty);
      expect(find.text('Este turno ya no está activo.'), findsOneWidget);
    });

    testWidgets('la admin lo movió', (tester) async {
      await pump(tester);
      bookings.emitAppointment('t1', appointment(start: at(11)));
      await confirm(tester);
      expect(bookings.cancelled, isEmpty);
      expect(
        find.text('Tu turno cambió. Revísalo antes de cancelarlo.'),
        findsOneWidget,
      );
    });

    testWidgets('ya falta poco (la vista aún no lo sabía)', (tester) async {
      await pump(tester, margin: 60, now: at(8, 30));
      await confirm(tester);
      expect(bookings.cancelled, isEmpty);
      expect(find.textContaining('falta poco para tu turno'), findsOneWidget);
    });

    testWidgets('falla al guardar: texto de error sin detalles', (
      tester,
    ) async {
      await pump(tester);
      bookings.cancelError = Exception('permission-denied');
      await confirm(tester);
      expect(bookings.cancelled, isEmpty);
      expect(
        find.text('No se pudo cancelar. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining('permission'), findsNothing);
      expect(find.byType(ActiveAppointmentView), findsOneWidget);
      expect(cancelButton, findsOneWidget);
    });
  });

  testWidgets('bloqueada: su aviso y "Cancelar turno", sin "Editar" (D-5)', (
    tester,
  ) async {
    await pump(tester, user: testClient.copyWith(isBlocked: true));
    expect(find.byType(BookingBlockedNotice), findsOneWidget);
    expect(find.text('EDITAR TURNO'), findsNothing);
    expect(cancelButton, findsOneWidget);
  });

  testWidgets('dentro del margen: ni "Editar" ni "Cancelar" (RF-4)', (
    tester,
  ) async {
    await pump(tester, margin: 180);
    expect(find.text('EDITAR TURNO'), findsNothing);
    expect(cancelButton, findsNothing);
    expect(
      find.textContaining('Ya no puedes cambiar este turno'),
      findsOneWidget,
    );
  });

  testWidgets('bloqueada dentro del margen: tampoco "Cancelar"', (
    tester,
  ) async {
    await pump(tester, margin: 180, user: testClient.copyWith(isBlocked: true));
    expect(find.byType(BookingBlockedNotice), findsOneWidget);
    expect(cancelButton, findsNothing);
  });
}
