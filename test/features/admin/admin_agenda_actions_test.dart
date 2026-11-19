import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/pump_app.dart';

/// Las acciones de cada turno de la agenda y "Confirmar" (spec 010, T6).
///
/// El turno es el viernes 20/11/2026 de 10:00 a 10:45 del salón; "ahora"
/// cambia según el caso.
DateTime wall(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, 20, hour, minute);

AppointmentModel appointment({
  String status = 'waiting_confirmation',
  bool createdByAdmin = false,
}) {
  final start = fromSalon(wall(10));
  return AppointmentModel(
    id: 't1',
    clientId: 'ana',
    clientName: 'Ana',
    clientPhone: '+55 41 99999-0000',
    startTime: start,
    endTime: start.add(const Duration(minutes: 45)),
    status: status,
    createdAt: start,
    createdByAdmin: createdByAdmin,
    booked: const BookedServiceModel(
      kind: BookedKind.service,
      id: 's1',
      name: BilingualText(es: 'Manicura', pt: 'Manicure'),
      priceCents: 3000,
      durationMinutes: 45,
    ),
  );
}

void main() {
  late FakeBookingRepository bookings;
  late StreamController<DateTime> salonNow;

  setUp(() {
    bookings = FakeBookingRepository();
    salonNow = StreamController<DateTime>.broadcast();
  });
  tearDown(() => salonNow.close());

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  /// La agenda del 20/11 con [shown], con "ahora" del salón [now].
  Future<void> pump(
    WidgetTester tester,
    AppointmentModel shown, {
    DateTime? now,
  }) async {
    final nowSalon = now ?? wall(9);
    bookings.day = [shown];
    await pumpApp(
      tester,
      stored: {'language': 'es'},
      home: const AdminDashboardView(),
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookings),
        configRepositoryProvider.overrideWithValue(FakeConfigRepository()),
        clockProvider.overrideWithValue(() => fromSalon(nowSalon)),
        salonNowProvider.overrideWith((ref) async* {
          yield nowSalon;
          yield* salonNow.stream;
        }),
        isWebProvider.overrideWithValue(false),
      ],
    );
    await settle(tester);
  }

  final card = find.byKey(const ValueKey('agenda-appointment-t1'));
  Finder inCard(Finder finder) => find.descendant(of: card, matching: finder);
  final edit = inCard(find.text('EDITAR'));
  final cancel = inCard(find.text('CANCELAR'));
  final confirm = inCard(find.text('CONFIRMAR'));
  final whatsApp = find.byTooltip('Escribir a Ana por WhatsApp');

  group('los botones según el turno (RF-7 a RF-9)', () {
    testWidgets('esperando: Editar, Cancelar y Confirmar', (tester) async {
      await pump(tester, appointment());
      expect(edit, findsOneWidget);
      expect(cancel, findsOneWidget);
      expect(confirm, findsOneWidget);
      expect(whatsApp, findsOneWidget);
    });

    testWidgets('confirmado: Editar y Cancelar', (tester) async {
      await pump(tester, appointment(status: 'confirmed'));
      expect(edit, findsOneWidget);
      expect(cancel, findsOneWidget);
      expect(confirm, findsNothing);
    });

    testWidgets('en curso: sigue con sus botones', (tester) async {
      await pump(tester, appointment(), now: wall(10, 30));
      expect(edit, findsOneWidget);
      expect(cancel, findsOneWidget);
      expect(confirm, findsOneWidget);
    });

    testWidgets('pasado y confirmado: sin botones, con WhatsApp y sus '
        'marcas', (tester) async {
      await pump(
        tester,
        appointment(status: 'confirmed', createdByAdmin: true),
        now: wall(10, 45),
      );
      expect(edit, findsNothing);
      expect(cancel, findsNothing);
      expect(confirm, findsNothing);
      expect(whatsApp, findsOneWidget);
      expect(inCard(find.text('CONFIRMADO')), findsOneWidget);
      expect(inCard(find.text('AGENDADO POR LA ADMIN')), findsOneWidget);
    });

    testWidgets('pasado sin confirmar: "SIN CONFIRMAR" y sin botones', (
      tester,
    ) async {
      await pump(tester, appointment(), now: wall(12));
      expect(inCard(find.text('SIN CONFIRMAR')), findsOneWidget);
      expect(inCard(find.text('POR CONFIRMAR')), findsNothing);
      expect(edit, findsNothing);
      expect(cancel, findsNothing);
      expect(confirm, findsNothing);
      expect(whatsApp, findsOneWidget);
    });

    testWidgets('cancelado: sin botones, con WhatsApp', (tester) async {
      await pump(tester, appointment(status: 'cancelled'));
      expect(edit, findsNothing);
      expect(cancel, findsNothing);
      expect(confirm, findsNothing);
      expect(whatsApp, findsOneWidget);
    });
  });

  testWidgets('al terminar el turno, sus botones desaparecen sin recargar '
      '(RF-10)', (tester) async {
    await pump(tester, appointment(), now: wall(10, 30));
    expect(confirm, findsOneWidget);
    salonNow.add(wall(10, 45));
    await settle(tester);
    expect(edit, findsNothing);
    expect(cancel, findsNothing);
    expect(confirm, findsNothing);
    expect(inCard(find.text('SIN CONFIRMAR')), findsOneWidget);
  });

  group('Confirmar (RF-11, RF-16, RF-17)', () {
    testWidgets('confirma al momento, sin diálogo', (tester) async {
      await pump(tester, appointment());
      await tester.tap(confirm);
      await settle(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(bookings.confirmed, ['t1']);
      expect(inCard(find.text('CONFIRMADO')), findsOneWidget);
      expect(confirm, findsNothing);
    });

    testWidgets('mientras guarda, desactivado; un segundo toque no repite', (
      tester,
    ) async {
      final gate = Completer<void>();
      bookings.confirmGate = gate.future;
      await pump(tester, appointment());
      await tester.tap(confirm);
      await tester.pump();

      expect(inCard(find.byType(CircularProgressIndicator)), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: inCard(find.byType(CircularProgressIndicator)),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(button.onPressed, isNull);
      await tester.tap(
        inCard(find.byType(CircularProgressIndicator)),
        warnIfMissed: false,
      );

      gate.complete();
      await settle(tester);
      expect(bookings.confirmed, ['t1']);
    });

    testWidgets('si ya no está activo, no confirma y avisa', (tester) async {
      await pump(tester, appointment());
      // La clienta lo canceló; la agenda aún no lo sabe.
      bookings.emitAppointment('t1', appointment(status: 'cancelled'));
      await tester.tap(confirm);
      await settle(tester);
      expect(bookings.confirmed, isEmpty);
      expect(find.text('Este turno ya no está activo.'), findsOneWidget);
    });

    testWidgets('si falla, avisa sin detalles y deja reintentar', (
      tester,
    ) async {
      bookings.confirmError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      await pump(tester, appointment());
      await tester.tap(confirm);
      await settle(tester);
      expect(bookings.confirmed, isEmpty);
      expect(
        find.text('No se pudo confirmar. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining('permission'), findsNothing);

      bookings.confirmError = null;
      await tester.tap(confirm);
      await settle(tester);
      expect(bookings.confirmed, ['t1']);
    });
  });
}
