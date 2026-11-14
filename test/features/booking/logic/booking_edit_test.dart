import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/booking_edit.dart';
import 'package:shaddai/features/booking/logic/booking_window.dart';
import 'package:shaddai/features/booking/logic/free_slots.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';

// Horas de pared del salón. 2026-11-10 es martes.
DateTime at(int hour, [int minute = 0, int day = 10]) =>
    DateTime.utc(2026, 11, day, hour, minute);

/// Martes y jueves abren de 8:00 a 12:00; el miércoles está cerrado. Los
/// jueves 12 y 19 están bloqueados.
final settings = CalendarSettingsModel(
  openingHours: {
    'tuesday': DaySchedule(open: '08:00', close: '12:00', isClosed: false),
    'wednesday': DaySchedule(open: '08:00', close: '12:00', isClosed: true),
    'thursday': DaySchedule(open: '08:00', close: '12:00', isClosed: false),
  },
  globalSlotDurationMinutes: 60,
  blockedDates: const ['2026-11-12', '2026-11-19'],
);

const booked = BookedServiceModel(
  kind: BookedKind.service,
  id: 's1',
  name: BilingualText(es: 'Manicura', pt: 'Manicure'),
  priceCents: 5000,
  durationMinutes: 60,
);

/// El turno original, con horas de pared del salón.
EditOriginal original(DateTime start, DateTime end) => EditOriginal(
  id: 't1',
  start: start,
  end: end,
  status: 'confirmed',
  booked: booked,
);

BusyRange busy(DateTime start, DateTime end) => (start: start, end: end);

void main() {
  // Un turno de las 10:00 (instante, como en Firestore).
  final start = fromSalon(at(10));

  group('isEditable (RF-1 a RF-3, RNF-1)', () {
    for (final (label, now, margin, blocked, expected) in [
      ('margen 0, un minuto antes de empezar', at(9, 59), 0, false, true),
      ('margen 0, al empezar', at(10), 0, false, false),
      ('margen 0, ya empezado', at(10, 1), 0, false, false),
      ('margen 30, a las 9:29', at(9, 29), 30, false, true),
      ('margen 30, justo en el límite (9:30)', at(9, 30), 30, false, false),
      ('margen 30, a las 9:45', at(9, 45), 30, false, false),
      ('margen 30, el día antes', at(10, 0, 9), 30, false, true),
      ('bloqueada, con tiempo de sobra', at(7), 0, true, false),
    ]) {
      test('$label → $expected', () {
        expect(
          isEditable(
            start: start,
            now: fromSalon(now),
            marginMinutes: margin,
            isBlocked: blocked,
          ),
          expected,
        );
      });
    }

    test('no depende de la zona del dispositivo: usa instantes', () {
      // Las 9:29 de Curitiba son las 12:29 en Lisboa (UTC+0).
      final lisbonNow = DateTime.utc(2026, 11, 10, 12, 29);
      expect(
        isEditable(
          start: start,
          now: lisbonNow.toLocal(),
          marginMinutes: 30,
          isBlocked: false,
        ),
        isTrue,
      );
      expect(
        isEditable(
          start: start,
          now: lisbonNow.add(const Duration(minutes: 1)),
          marginMinutes: 30,
          isBlocked: false,
        ),
        isFalse,
      );
    });
  });

  group('startsWithinEditMargin (RF-23)', () {
    for (final (label, now, margin, expected) in [
      ('margen 60, a las 9:30', at(9, 30), 60, true),
      ('margen 60, justo en el límite (9:00)', at(9), 60, true),
      ('margen 60, a las 8:59', at(8, 59), 60, false),
      ('margen 0, con una hora futura', at(9, 59), 0, false),
    ]) {
      test('$label → $expected', () {
        expect(
          startsWithinEditMargin(
            start: start,
            now: fromSalon(now),
            marginMinutes: margin,
          ),
          expected,
        );
      });
    }
  });

  group('editAvailability (RF-1 a RF-3, RF-22; D-6)', () {
    for (final (label, blocked, error, margin, now, expected) in [
      ('bloqueada', true, false, 0, at(7), EditAvailability.blocked),
      (
        'bloqueada aunque el calendario falle',
        true,
        true,
        null,
        at(7),
        EditAvailability.blocked,
      ),
      ('el calendario falla', false, true, null, at(7), EditAvailability.error),
      (
        'el calendario carga',
        false,
        false,
        null,
        at(7),
        EditAvailability.loading,
      ),
      ('editable', false, false, 30, at(9), EditAvailability.editable),
      (
        'dentro del margen',
        false,
        false,
        30,
        at(9, 30),
        EditAvailability.closed,
      ),
      ('ya empezado', false, false, 0, at(10), EditAvailability.closed),
    ]) {
      test('$label → ${expected.name}', () {
        expect(
          editAvailability(
            isBlocked: blocked,
            settingsError: error,
            marginMinutes: margin,
            start: start,
            now: fromSalon(now),
          ),
          expected,
        );
      });
    }
  });

  group('EditOriginal (RF-4, RF-5)', () {
    test('se toma del turno, con horas de pared del salón', () {
      final appointment = AppointmentModel(
        id: 't1',
        clientId: 'c1',
        clientName: 'Ana',
        clientPhone: '+55',
        startTime: fromSalon(at(9)),
        endTime: fromSalon(at(10)),
        status: 'confirmed',
        createdAt: fromSalon(at(7)),
        booked: booked,
      );
      final o = EditOriginal.of(appointment);
      expect(o.id, 't1');
      expect(o.start, at(9));
      expect(o.end, at(10));
      expect(o.status, 'confirmed');
      expect(o.booked, booked);
    });
  });

  group('isEditDaySelectable (RF-5, RF-9)', () {
    final window = bookingWindow(at(7));
    // 2027-01-19 es martes, más allá de los 60 días.
    final beyond = DateTime.utc(2027, 1, 19);

    for (final (label, day, originalDay, expected) in [
      ('el día original, más allá de la ventana', beyond, beyond, true),
      ('otro día más allá de la ventana', beyond, at(0, 0, 17), false),
      (
        'el día original, ahora cerrado (miércoles)',
        at(0, 0, 11),
        at(0, 0, 11),
        true,
      ),
      ('otro día cerrado', at(0, 0, 18), at(0, 0, 11), false),
      ('el día original, ahora bloqueado', at(0, 0, 12), at(0, 0, 12), true),
      ('otro día bloqueado', at(0, 0, 19), at(0, 0, 12), false),
      ('un día normal', at(0, 0, 17), at(0, 0, 12), true),
    ]) {
      test('$label → $expected', () {
        final o = original(
          originalDay.add(const Duration(hours: 10)),
          originalDay.add(const Duration(hours: 11)),
        );
        expect(isEditDaySelectable(day, settings, window, o), expected);
      });
    }
  });

  group('editFreeSlots (RF-5, RF-7, RF-8; D-3)', () {
    List<FreeSlot> slots(
      DateTime day,
      EditOriginal o, {
      List<BusyRange> others = const [],
      DateTime? now,
    }) => editFreeSlots(
      day: day,
      settings: settings,
      busy: others,
      nowSalon: now ?? at(7),
      original: o,
    );

    test('sin el propio turno en los ocupados, su hora sale libre', () {
      final result = slots(at(0, 0, 10), original(at(9), at(10)));
      expect(result.map((s) => s.start), contains(at(9)));
      expect(
        result,
        freeSlots(
          day: at(0, 0, 10),
          settings: settings,
          busy: const [],
          nowSalon: at(7),
        ),
      );
    });

    test('hora fuera de la rejilla: sale en orden, con la cobertura hasta el '
        'siguiente ocupado', () {
      final result = slots(
        at(0, 0, 10),
        original(at(9, 15), at(10, 15)),
        others: [busy(at(11), at(12))],
      );
      expect(result.map((s) => s.start), [
        at(8),
        at(8, 30),
        at(9),
        at(9, 15),
        at(9, 30),
        at(10),
        at(10, 30),
      ]);
      expect(
        result.firstWhere((s) => s.start == at(9, 15)).coverageMinutes,
        105,
      );
    });

    test('hora fuera de la rejilla cuyo fin pasa del cierre actual: el límite '
        'es el fin original', () {
      final result = slots(at(0, 0, 10), original(at(11, 45), at(12, 45)));
      expect(result.last, FreeSlot(start: at(11, 45), coverageMinutes: 60));
    });

    test('día ahora cerrado: solo su hora, hasta el fin original', () {
      expect(slots(at(0, 0, 11), original(at(10, 0, 11), at(11, 0, 11))), [
        FreeSlot(start: at(10, 0, 11), coverageMinutes: 60),
      ]);
    });

    test('día ahora cerrado con otro turno más tarde: el límite sigue siendo '
        'el fin original (D-3, aclarado con el autor)', () {
      expect(
        slots(
          at(0, 0, 11),
          original(at(10, 0, 11), at(11, 0, 11)),
          others: [busy(at(15, 0, 11), at(16, 0, 11))],
        ),
        [FreeSlot(start: at(10, 0, 11), coverageMinutes: 60)],
      );
    });

    test('día ahora cerrado con otro turno antes del fin original: el límite '
        'es ese turno', () {
      expect(
        slots(
          at(0, 0, 11),
          original(at(10, 0, 11), at(11, 0, 11)),
          others: [busy(at(10, 30, 11), at(11, 30, 11))],
        ),
        [FreeSlot(start: at(10, 0, 11), coverageMinutes: 30)],
      );
    });

    test('hora original ya pasada: no se añade', () {
      final result = slots(
        at(0, 0, 10),
        original(at(9, 15), at(10, 15)),
        now: at(9, 30),
      );
      expect(result.map((s) => s.start), isNot(contains(at(9, 15))));
    });

    test('hora original dentro de otro turno ocupado: no se añade', () {
      final result = slots(
        at(0, 0, 10),
        original(at(9, 15), at(10, 15)),
        others: [busy(at(9), at(10))],
      );
      expect(result.map((s) => s.start), isNot(contains(at(9, 15))));
    });

    test('otro día: igual que freeSlots', () {
      expect(
        slots(at(0, 0, 17), original(at(9, 15), at(10, 15))),
        freeSlots(
          day: at(0, 0, 17),
          settings: settings,
          busy: const [],
          nowSalon: at(7),
        ),
      );
    });
  });
}
