import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/presentation/admin_users_view.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/pump_app.dart';

/// Bloquear y desbloquear a una clienta desde la lista (spec 010, T9).
///
/// "Ahora" es el viernes 20/11/2026 a las 9:00 del salón. Ana tiene un
/// turno a las 10:00; Bea, ninguno; Carla está bloqueada.
DateTime wall(int hour) => DateTime.utc(2026, 11, 20, hour);

UserModel user(String uid, String name, {bool blocked = false}) => UserModel(
  uid: uid,
  email: '$uid@example.com',
  displayName: name,
  phoneNumber: '+55 41 99999-0000',
  isBlocked: blocked,
);

AppointmentModel appointment({
  String id = 't1',
  String clientId = 'ana',
  int hour = 10,
  String status = 'confirmed',
}) {
  final start = fromSalon(wall(hour));
  return AppointmentModel(
    id: id,
    clientId: clientId,
    clientName: clientId,
    clientPhone: '+55 41 99999-0000',
    startTime: start,
    endTime: start.add(const Duration(minutes: 45)),
    status: status,
    createdAt: start,
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
  late FakeUserRepository users;

  setUp(() {
    final start = fromSalon(wall(10));
    bookings = FakeBookingRepository(
      active: [appointment()],
      busy: [
        BusySlot(
          id: 't1',
          start: start,
          end: start.add(const Duration(minutes: 45)),
        ),
      ],
    );
    users = FakeUserRepository(
      users: [
        user('ana', 'Ana'),
        user('bea', 'Bea'),
        user('carla', 'Carla', blocked: true),
      ],
    )..bookings = bookings;
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.pump();
    }
    await tester.pump(const Duration(milliseconds: 300));
    await tester.pump();
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(600, 1400);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'language': 'es'},
      home: const AdminUsersView(),
      overrides: [
        userRepositoryProvider.overrideWithValue(users),
        bookingRepositoryProvider.overrideWithValue(bookings),
        clockProvider.overrideWithValue(() => fromSalon(wall(9))),
        salonNowProvider.overrideWith((ref) => Stream.value(wall(9))),
      ],
    );
    await settle(tester);
  }

  Finder switchOf(String uid) => find.descendant(
    of: find.byKey(ValueKey('client-$uid')),
    matching: find.byType(Switch),
  );
  bool switchValue(WidgetTester tester, String uid) =>
      tester.widget<Switch>(switchOf(uid)).value;

  final dialog = find.byType(AlertDialog);
  Finder inDialog(Finder finder) =>
      find.descendant(of: dialog, matching: finder);
  final back = inDialog(find.text('No, volver'));
  final block = inDialog(find.text('Sí, bloquear'));
  final unblock = inDialog(find.text('Sí, desbloquear'));
  final mentionsAppointment = inDialog(find.text('Su turno se cancelará:'));

  Future<void> openFor(WidgetTester tester, String uid) async {
    await tester.tap(switchOf(uid));
    await settle(tester);
    expect(dialog, findsOneWidget);
  }

  group('el diálogo de bloquear (RF-25, RF-26)', () {
    testWidgets('sin turno activo: no menciona turnos', (tester) async {
      await pump(tester);
      await openFor(tester, 'bea');
      expect(inDialog(find.text('¿Bloquear a Bea?')), findsOneWidget);
      expect(
        inDialog(find.text('No podrá iniciar sesión ni reservar.')),
        findsOneWidget,
      );
      expect(mentionsAppointment, findsNothing);
      expect(back, findsOneWidget);
      expect(block, findsOneWidget);
    });

    testWidgets('con turno activo: su día, la hora del salón y el servicio, '
        'y que se cancelará', (tester) async {
      await pump(tester);
      await openFor(tester, 'ana');
      expect(mentionsAppointment, findsOneWidget);
      expect(
        inDialog(find.text('Viernes, 20 de noviembre de 2026')),
        findsOneWidget,
      );
      expect(inDialog(find.text('10:00 – 10:45')), findsOneWidget);
      expect(inDialog(find.text('Manicura')), findsOneWidget);
    });

    testWidgets('un turno de una persona sin cuenta con su WhatsApp no es '
        'suyo', (tester) async {
      bookings.active = [appointment(id: 'g1', clientId: 'invitada')];
      await pump(tester);
      await openFor(tester, 'bea');
      expect(mentionsAppointment, findsNothing);
    });

    testWidgets('el turno aparece y cambia en vivo con el diálogo abierto', (
      tester,
    ) async {
      await pump(tester);
      await openFor(tester, 'bea');
      bookings.emitActive([
        ...bookings.active,
        appointment(id: 'b1', clientId: 'bea', hour: 15),
      ]);
      await settle(tester);
      expect(mentionsAppointment, findsOneWidget);
      expect(inDialog(find.text('15:00 – 15:45')), findsOneWidget);
    });
  });

  group('confirmar el bloqueo (RF-27, RF-33)', () {
    testWidgets('bloquea, cancela su turno y libera la hora a la vez, y '
        'avisa', (tester) async {
      await pump(tester);
      await openFor(tester, 'ana');
      await tester.tap(block);
      await settle(tester);

      expect(dialog, findsNothing);
      expect(users.blocks, [(uid: 'ana', appointmentId: 't1')]);
      expect(bookings.active.single.status, 'cancelled');
      expect(bookings.busy, isEmpty);
      expect(find.text('Ana está bloqueada.'), findsOneWidget);
      expect(switchValue(tester, 'ana'), isTrue);
    });

    testWidgets('sin turno, solo bloquea', (tester) async {
      await pump(tester);
      await openFor(tester, 'bea');
      await tester.tap(block);
      await settle(tester);
      expect(users.blocks, [(uid: 'bea', appointmentId: null)]);
      expect(bookings.active.single.status, 'confirmed');
      expect(switchValue(tester, 'bea'), isTrue);
    });
  });

  group('si su turno cambió, no bloquea y avisa (RF-28)', () {
    testWidgets('reservó un turno con el diálogo abierto', (tester) async {
      await pump(tester);
      await openFor(tester, 'bea');
      // En el servidor ya está; a la lista aún no ha llegado.
      bookings.active = [
        ...bookings.active,
        appointment(id: 'b1', clientId: 'bea', hour: 15),
      ];
      await tester.tap(block);
      await settle(tester);
      expect(users.blocks, isEmpty);
      expect(
        find.text('Su turno cambió. Revísalo antes de bloquearla.'),
        findsOneWidget,
      );
      expect(switchValue(tester, 'bea'), isFalse);
    });

    testWidgets('su turno se movió; al volver a abrirlo, sale el de ahora', (
      tester,
    ) async {
      await pump(tester);
      await openFor(tester, 'ana');
      bookings.active = [appointment(hour: 11)];
      await tester.tap(block);
      await settle(tester);
      expect(users.blocks, isEmpty);
      expect(bookings.active.single.status, 'confirmed');
      expect(
        find.text('Su turno cambió. Revísalo antes de bloquearla.'),
        findsOneWidget,
      );

      bookings.emitActive(bookings.active);
      await settle(tester);
      await openFor(tester, 'ana');
      expect(inDialog(find.text('11:00 – 11:45')), findsOneWidget);
    });
  });

  testWidgets('si falla, avisa sin detalles y no cambia nada (RF-34)', (
    tester,
  ) async {
    users.blockError = FirebaseException(
      plugin: 'cloud_firestore',
      code: 'permission-denied',
    );
    await pump(tester);
    await openFor(tester, 'ana');
    await tester.tap(block);
    await settle(tester);
    expect(
      find.text('No se pudo bloquear. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.textContaining('permission'), findsNothing);
    expect(switchValue(tester, 'ana'), isFalse);
    expect(bookings.active.single.status, 'confirmed');
  });

  group('sin cambios (RF-31)', () {
    testWidgets('"No, volver"', (tester) async {
      await pump(tester);
      await openFor(tester, 'ana');
      await tester.tap(back);
      await settle(tester);
      expect(dialog, findsNothing);
      expect(users.blocks, isEmpty);
    });

    testWidgets('cerrar tocando fuera', (tester) async {
      await pump(tester);
      await openFor(tester, 'carla');
      await tester.tapAt(const Offset(5, 5));
      await settle(tester);
      expect(dialog, findsNothing);
      expect(users.unblocks, isEmpty);
    });
  });

  group('desbloquear (RF-29, RF-30, RF-34)', () {
    testWidgets('pide confirmación, desbloquea y avisa', (tester) async {
      await pump(tester);
      await openFor(tester, 'carla');
      expect(inDialog(find.text('¿Desbloquear a Carla?')), findsOneWidget);
      expect(
        inDialog(find.text('Podrá volver a iniciar sesión y reservar.')),
        findsOneWidget,
      );
      await tester.tap(unblock);
      await settle(tester);
      expect(users.unblocks, ['carla']);
      expect(find.text('Carla está desbloqueada.'), findsOneWidget);
      expect(switchValue(tester, 'carla'), isFalse);
    });

    testWidgets('si falla, avisa y sigue bloqueada', (tester) async {
      users.unblockError = StateError('sin red');
      await pump(tester);
      await openFor(tester, 'carla');
      await tester.tap(unblock);
      await settle(tester);
      expect(
        find.text('No se pudo desbloquear. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(switchValue(tester, 'carla'), isTrue);
    });
  });

  testWidgets('mientras guarda, todo desactivado y el interruptor solo '
      'cambia al llegar la ficha (RF-32, plan D-7)', (tester) async {
    final gate = Completer<void>();
    users.blockGate = gate.future;
    await pump(tester);
    await openFor(tester, 'ana');
    await tester.tap(block);
    await tester.pump();

    expect(inDialog(find.byType(CircularProgressIndicator)), findsOneWidget);
    for (final button in tester.widgetList<ButtonStyleButton>(
      inDialog(find.byWidgetPredicate((w) => w is ButtonStyleButton)),
    )) {
      expect(button.onPressed, isNull);
    }
    await tester.tapAt(const Offset(5, 5));
    await tester.pump();
    expect(dialog, findsOneWidget);
    expect(switchValue(tester, 'ana'), isFalse);

    gate.complete();
    await settle(tester);
    expect(users.blocks, hasLength(1));
    expect(switchValue(tester, 'ana'), isTrue);
  });
}
