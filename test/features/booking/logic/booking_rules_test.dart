import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/features/booking/logic/booking_rules.dart';
import 'package:shaddai/features/booking/logic/free_slots.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';

// Horas de pared del salón. 2026-11-10 es martes.
DateTime at(int hour, [int minute = 0, int day = 10]) =>
    DateTime.utc(2026, 11, day, hour, minute);

/// Un turno de prueba: sus horas son instantes, como en Firestore.
class Appt {
  const Appt(this.id, this.start, this.end, [this.status = 'confirmed']);

  final String id;
  final DateTime start;
  final DateTime end;
  final String status;
}

/// Un turno con horas de pared del salón.
Appt appt(
  String id,
  DateTime start,
  DateTime end, [
  String status = 'confirmed',
]) => Appt(id, fromSalon(start), fromSalon(end), status);

AppointmentTimes timesOf(Appt a) =>
    (start: a.start, end: a.end, status: a.status);

/// El martes abre de 8:00 a 12:00.
final settings = CalendarSettingsModel(
  openingHours: {
    'tuesday': DaySchedule(open: '08:00', close: '12:00', isClosed: false),
  },
  globalSlotDurationMinutes: 60,
  blockedDates: const [],
);

void main() {
  group('activeAppointment (RF-33, RF-35)', () {
    final now = at(10);
    final cases = <String, (List<Appt>, String?)>{
      'sin turnos': ([], null),
      'uno futuro esperando confirmación': (
        [appt('a', at(11), at(12), 'waiting_confirmation')],
        'a',
      ),
      'uno futuro confirmado': ([appt('a', at(9, 0, 12), at(10, 0, 12))], 'a'),
      'uno en curso sigue activo hasta su fin': (
        [appt('a', at(9, 30), at(10, 30))],
        'a',
      ),
      'uno que termina justo ahora ya no es activo': (
        [appt('a', at(9), at(10))],
        null,
      ),
      'uno pasado que sigue esperando confirmación no es activo': (
        [appt('a', at(8), at(9), 'waiting_confirmation')],
        null,
      ),
      'uno futuro cancelado no es activo': (
        [appt('a', at(11), at(12), 'cancelled')],
        null,
      ),
      'con varios, el que empieza antes': (
        [
          appt('tarde', at(9, 0, 20), at(10, 0, 20)),
          appt('pronto', at(11), at(12)),
          appt('cancelado', at(10, 30), at(11), 'cancelled'),
        ],
        'pronto',
      ),
    };
    cases.forEach((name, c) {
      test(name, () {
        final active = activeAppointment(
          c.$1,
          times: timesOf,
          now: fromSalon(now),
        );
        expect(active?.id, c.$2);
      });
    });
  });

  group('checkBeforeSave (RF-26, RF-29, RF-30, RF-36)', () {
    final now = at(7);
    BusyRange busy(DateTime start, DateTime end) => (start: start, end: end);

    final cases =
        <
          String,
          ({
            DateTime start,
            int duration,
            List<BusyRange> busy,
            List<Appt> mine,
            DateTime now,
            BookingCheck expected,
          })
        >{
          'todo bien': (
            start: at(9),
            duration: 60,
            busy: [busy(at(10), at(11))],
            mine: [],
            now: now,
            expected: BookingCheck.ok,
          ),
          'cabe justo hasta el siguiente turno': (
            start: at(9),
            duration: 60,
            busy: [busy(at(10), at(11))],
            mine: [appt('viejo', at(8, 0, 3), at(9, 0, 3))],
            now: now,
            expected: BookingCheck.ok,
          ),
          'ya tiene un turno activo (RF-36)': (
            start: at(9),
            duration: 60,
            busy: [],
            mine: [appt('a', at(11, 0, 20), at(12, 0, 20))],
            now: now,
            expected: BookingCheck.alreadyActive,
          ),
          'la hora acaba de ocuparse (RF-29)': (
            start: at(9),
            duration: 60,
            busy: [busy(at(8, 30), at(9, 30))],
            mine: [],
            now: now,
            expected: BookingCheck.slotTaken,
          ),
          'la hora ya pasó (RF-29)': (
            start: at(9),
            duration: 30,
            busy: [],
            mine: [],
            now: at(9),
            expected: BookingCheck.slotTaken,
          ),
          'el servicio ya no cabe (RF-30)': (
            start: at(9),
            duration: 90,
            busy: [busy(at(10), at(11))],
            mine: [],
            now: now,
            expected: BookingCheck.doesNotFit,
          ),
          'no cabe antes del cierre (RF-30)': (
            start: at(11, 30),
            duration: 45,
            busy: [],
            mine: [],
            now: now,
            expected: BookingCheck.doesNotFit,
          ),
          'el turno activo gana a la hora ocupada': (
            start: at(9),
            duration: 60,
            busy: [busy(at(9), at(10))],
            mine: [appt('a', at(9), at(10))],
            now: now,
            expected: BookingCheck.alreadyActive,
          ),
        };

    cases.forEach((name, c) {
      test(name, () {
        expect(
          checkBeforeSave(
            start: c.start,
            durationMinutes: c.duration,
            settings: settings,
            busy: c.busy,
            mine: c.mine,
            times: timesOf,
            nowSalon: c.now,
          ),
          c.expected,
        );
      });
    });
  });

  group('bookingScreen (RF-33, RF-37, RF-39, RF-49)', () {
    final now = fromSalon(at(10));
    final future = appt('a', at(11), at(12));
    const client = (isAdmin: false, isBlocked: false);
    const blocked = (isAdmin: false, isBlocked: true);
    const admin = (isAdmin: true, isBlocked: false);

    BookingScreen<Appt> screen({
      bool userLoading = false,
      bool userError = false,
      BookingUser? user = client,
      List<Appt>? mine = const [],
      bool mineError = false,
    }) => bookingScreen(
      userLoading: userLoading,
      userError: userError,
      user: user,
      mine: mine,
      mineError: mineError,
      times: timesOf,
      now: now,
    );

    test('la ficha cargando → cargando', () {
      expect(screen(userLoading: true), isA<BookingScreenLoading<Appt>>());
    });

    test('sin sesión (o sin ficha) → aviso de sesión', () {
      expect(screen(user: null), isA<BookingScreenSignedOut<Appt>>());
    });

    test('la ficha cargando gana a la falta de sesión', () {
      expect(
        screen(userLoading: true, user: null),
        isA<BookingScreenLoading<Appt>>(),
      );
    });

    test('error al leer la ficha → error', () {
      expect(screen(userError: true), isA<BookingScreenError<Appt>>());
    });

    test('la admin → su texto, sin esperar a sus turnos (RF-39)', () {
      expect(screen(user: admin, mine: null), isA<BookingScreenAdmin<Appt>>());
      expect(
        screen(user: admin, mine: [future]),
        isA<BookingScreenAdmin<Appt>>(),
      );
    });

    test('mis turnos cargando → cargando', () {
      expect(screen(mine: null), isA<BookingScreenLoading<Appt>>());
    });

    test('error al leer mis turnos → error (RF-49)', () {
      expect(screen(mineError: true), isA<BookingScreenError<Appt>>());
      expect(
        screen(user: blocked, mineError: true),
        isA<BookingScreenError<Appt>>(),
      );
    });

    test('con un turno activo → el turno (RF-33)', () {
      final result = screen(mine: [future]);
      expect(result, isA<BookingScreenActive<Appt>>());
      result as BookingScreenActive<Appt>;
      expect(result.appointment.id, 'a');
      expect(result.isBlocked, isFalse);
    });

    test('bloqueada con turno activo → el turno, con el aviso (RF-37)', () {
      final result = screen(user: blocked, mine: [future]);
      expect(result, isA<BookingScreenActive<Appt>>());
      expect((result as BookingScreenActive<Appt>).isBlocked, isTrue);
    });

    test('bloqueada sin turno activo → su aviso (RF-37)', () {
      expect(screen(user: blocked), isA<BookingScreenBlocked<Appt>>());
    });

    test('con turnos que ya no son activos → la vista de reserva', () {
      expect(
        screen(mine: [appt('pasado', at(8), at(9))]),
        isA<BookingScreenBooking<Appt>>(),
      );
    });
  });
}
