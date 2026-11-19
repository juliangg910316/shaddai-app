import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/user_model.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';

/// Los fakes de los repositorios de la spec 010 (plan § 5 y § 10, T3): se
/// comportan como las transacciones de Firestore, para que los tests de
/// pantalla confíen en ellos.
final start = DateTime.utc(2026, 11, 20, 13);

AppointmentModel appointment(
  String id, {
  String status = 'waiting_confirmation',
  String? clientId = 'ana',
}) => AppointmentModel(
  id: id,
  clientId: clientId,
  clientName: 'Ana',
  clientPhone: '+55 41 99999-0000',
  startTime: start,
  endTime: start.add(const Duration(minutes: 45)),
  status: status,
  createdAt: start,
);

final slot = BusySlot(
  id: 't1',
  start: start,
  end: start.add(const Duration(minutes: 45)),
);

UserModel ana({bool blocked = false}) => UserModel(
  uid: 'ana',
  email: 'ana@example.com',
  displayName: 'Ana',
  isBlocked: blocked,
);

Future<void> flush() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('los turnos de un día (RF-1)', () {
    test('registra el rango pedido y emite en vivo', () async {
      final bookings = FakeBookingRepository()..day = [appointment('t1')];
      final from = DateTime.utc(2026, 11, 20, 3);
      final to = DateTime.utc(2026, 11, 21, 3);
      final seen = <List<String>>[];
      final sub = bookings
          .watchAppointmentsBetween(from, to)
          .listen((day) => seen.add([for (final a in day) a.id]));
      await flush();
      bookings.emitDay([appointment('t1'), appointment('t2')]);
      await flush();
      expect(bookings.dayRequests, [(from: from, to: to)]);
      expect(seen, [
        ['t1'],
        ['t1', 't2'],
      ]);
      await sub.cancel();
    });

    test('failDay envía el error', () async {
      final bookings = FakeBookingRepository();
      final errors = <Object>[];
      final sub = bookings
          .watchAppointmentsBetween(start, start)
          .listen((_) {}, onError: errors.add);
      await flush();
      bookings.failDay(StateError('sin red'));
      await flush();
      expect(errors, hasLength(1));
      await sub.cancel();
    });
  });

  group('la admin cancela (RF-14, RF-15, RF-17)', () {
    late FakeBookingRepository bookings;

    setUp(() {
      bookings = FakeBookingRepository(
        busy: [slot],
        active: [appointment('t1')],
      )..day = [appointment('t1')];
    });

    test('si expected lo da por bueno: cancelado por el salón y su hora '
        'libre en todas partes', () async {
      final seen = <AppointmentModel?>[];
      final sub = bookings.watchAppointment('t1').listen(seen.add);
      await flush();
      final ok = await bookings.cancelByAdmin(
        id: 't1',
        expected: (current) => current?.status == 'waiting_confirmation',
      );
      await flush();
      expect(ok, isTrue);
      expect(bookings.adminCancelled, ['t1']);
      expect(bookings.busy, isEmpty);
      for (final list in [bookings.day, bookings.active]) {
        expect(list.single.status, 'cancelled');
        expect(list.single.cancelledByClient, isFalse);
      }
      expect(seen.last?.status, 'cancelled');
      await sub.cancel();
    });

    test('si expected no lo da por bueno, no cambia nada', () async {
      final ok = await bookings.cancelByAdmin(id: 't1', expected: (_) => false);
      expect(ok, isFalse);
      expect(bookings.adminCancelled, isEmpty);
      expect(bookings.busy, [slot]);
      expect(bookings.day.single.status, 'waiting_confirmation');
    });

    test('expected recibe null si el turno no existe', () async {
      AppointmentModel? received = appointment('x');
      await bookings.cancelByAdmin(
        id: 'otro',
        expected: (current) {
          received = current;
          return false;
        },
      );
      expect(received, isNull);
    });

    test('con error, lo lanza y no cambia nada', () async {
      bookings.adminCancelError = StateError('sin red');
      await expectLater(
        bookings.cancelByAdmin(id: 't1', expected: (_) => true),
        throwsStateError,
      );
      expect(bookings.adminCancelled, isEmpty);
      expect(bookings.busy, [slot]);
    });

    test('espera a la puerta antes de cancelar', () async {
      final gate = Completer<void>();
      bookings.adminCancelGate = gate.future;
      final done = bookings.cancelByAdmin(id: 't1', expected: (_) => true);
      await flush();
      expect(bookings.adminCancelled, isEmpty);
      gate.complete();
      expect(await done, isTrue);
      expect(bookings.adminCancelled, ['t1']);
    });
  });

  group('la admin confirma (RF-11, RF-17)', () {
    late FakeBookingRepository bookings;

    setUp(() {
      bookings = FakeBookingRepository(active: [appointment('t1')])
        ..day = [appointment('t1')];
    });

    test('si expected lo da por bueno: confirmado', () async {
      final ok = await bookings.confirmByAdmin(
        id: 't1',
        expected: (current) => current != null,
      );
      await flush();
      expect(ok, isTrue);
      expect(bookings.confirmed, ['t1']);
      expect(bookings.day.single.status, 'confirmed');
      expect(bookings.active.single.status, 'confirmed');
    });

    test('si no, no cambia nada', () async {
      expect(
        await bookings.confirmByAdmin(id: 't1', expected: (_) => false),
        isFalse,
      );
      expect(bookings.confirmed, isEmpty);
      expect(bookings.day.single.status, 'waiting_confirmation');
    });

    test('con error, lo lanza; y espera a la puerta', () async {
      bookings.confirmError = StateError('sin red');
      await expectLater(
        bookings.confirmByAdmin(id: 't1', expected: (_) => true),
        throwsStateError,
      );
      bookings.confirmError = null;
      final gate = Completer<void>();
      bookings.confirmGate = gate.future;
      final done = bookings.confirmByAdmin(id: 't1', expected: (_) => true);
      await flush();
      expect(bookings.confirmed, isEmpty);
      gate.complete();
      expect(await done, isTrue);
    });
  });

  group('bloquear y desbloquear (RF-27, RF-28, RF-30, RF-34)', () {
    late FakeBookingRepository bookings;
    late FakeUserRepository users;

    setUp(() {
      bookings = FakeBookingRepository(
        busy: [slot],
        active: [appointment('t1', status: 'confirmed')],
      );
      users = FakeUserRepository(stored: ana(), users: [ana()])
        ..bookings = bookings;
    });

    test('bloquear con turno: bloqueada, turno cancelado y hora libre, a la '
        'vez', () async {
      final lists = <List<UserModel>>[];
      final sub = users.getAllUsers().listen(lists.add);
      await flush();
      final ok = await users.blockClient(
        uid: 'ana',
        appointmentId: 't1',
        expected: (current) => current?.status == 'confirmed',
      );
      await flush();
      expect(ok, isTrue);
      expect(users.blocks, [(uid: 'ana', appointmentId: 't1')]);
      expect(users.users.single.isBlocked, isTrue);
      expect(lists.last.single.isBlocked, isTrue);
      expect(bookings.active.single.status, 'cancelled');
      expect(bookings.active.single.cancelledByClient, isFalse);
      expect(bookings.busy, isEmpty);
      await sub.cancel();
    });

    test('bloquear sin turno: expected recibe null', () async {
      AppointmentModel? received = appointment('x');
      final ok = await users.blockClient(
        uid: 'ana',
        expected: (current) {
          received = current;
          return current == null;
        },
      );
      expect(ok, isTrue);
      expect(received, isNull);
      expect(users.users.single.isBlocked, isTrue);
      expect(bookings.active.single.status, 'confirmed');
    });

    test('si expected no lo da por bueno, no bloquea ni cancela', () async {
      final ok = await users.blockClient(
        uid: 'ana',
        appointmentId: 't1',
        expected: (_) => false,
      );
      expect(ok, isFalse);
      expect(users.blocks, isEmpty);
      expect(users.users.single.isBlocked, isFalse);
      expect(bookings.active.single.status, 'confirmed');
      expect(bookings.busy, [slot]);
    });

    test('con error, no cambia nada; espera a la puerta', () async {
      users.blockError = StateError('sin red');
      await expectLater(
        users.blockClient(
          uid: 'ana',
          appointmentId: 't1',
          expected: (_) => true,
        ),
        throwsStateError,
      );
      expect(users.users.single.isBlocked, isFalse);
      expect(bookings.busy, [slot]);

      users.blockError = null;
      final gate = Completer<void>();
      users.blockGate = gate.future;
      final done = users.blockClient(uid: 'ana', expected: (_) => true);
      await flush();
      expect(users.blocks, isEmpty);
      gate.complete();
      expect(await done, isTrue);
    });

    test('desbloquear: la ficha vuelve a estar activa; el turno sigue '
        'cancelado', () async {
      await users.blockClient(
        uid: 'ana',
        appointmentId: 't1',
        expected: (_) => true,
      );
      await users.unblockClient('ana');
      await flush();
      expect(users.unblocks, ['ana']);
      expect(users.users.single.isBlocked, isFalse);
      expect(users.live?.isBlocked, isFalse);
      expect(bookings.active.single.status, 'cancelled');
    });

    test('desbloquear con error no cambia nada; espera a la puerta', () async {
      users.users = [ana(blocked: true)];
      users.unblockError = StateError('sin red');
      await expectLater(users.unblockClient('ana'), throwsStateError);
      expect(users.users.single.isBlocked, isTrue);

      users.unblockError = null;
      final gate = Completer<void>();
      users.unblockGate = gate.future;
      final done = users.unblockClient('ana');
      await flush();
      expect(users.unblocks, isEmpty);
      gate.complete();
      await done;
      expect(users.unblocks, ['ana']);
    });
  });
}
