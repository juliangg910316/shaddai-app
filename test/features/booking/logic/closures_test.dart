import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/features/booking/logic/booking_rules.dart';
import 'package:shaddai/features/booking/logic/closures.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';

/// Un turno de prueba: sus horas en hora de pared y su estado.
typedef Appt = ({String id, DateTime start, DateTime end, String status});

/// Cierres de la agenda de la admin, sin Flutter ni Firebase (spec 008,
/// RF-3 a RF-5, RF-8, RF-9, RF-13; RNF-1; plan § 4.1).
void main() {
  // Horas de pared del salón. 2026-11-10 es martes.
  DateTime at(int hour, [int minute = 0, int day = 10, int month = 11]) =>
      DateTime.utc(2026, month, day, hour, minute);
  DateTime day(int d, [int month = 11, int year = 2026]) =>
      DateTime.utc(year, month, d);

  /// "Ahora": el martes 10/11/2026 a las 9:00.
  final now = at(9);

  /// El martes abre de 8:00 a 12:00; el lunes, cerrado.
  final settings = CalendarSettingsModel(
    openingHours: {
      'monday': DaySchedule(open: '08:00', close: '12:00', isClosed: true),
      'tuesday': DaySchedule(open: '08:00', close: '12:00', isClosed: false),
      'wednesday': DaySchedule(open: '08:00', close: '12:00', isClosed: false),
    },
    globalSlotDurationMinutes: 60,
    blockedDates: const [],
  );

  group('closureRange (RF-3)', () {
    test('una franja va de su hora de inicio a su hora de fin', () {
      final range = closureRange(
        RangeDraft(day: day(24), fromMinutes: 13 * 60, toMinutes: 14 * 60 + 30),
      );
      expect(range.start, at(13, 0, 24));
      expect(range.end, at(14, 30, 24));
    });

    test('unos días enteros van de las 0:00 del primero a las 0:00 del día '
        'siguiente al último', () {
      final range = closureRange(DaysDraft(firstDay: day(2), lastDay: day(9)));
      expect(range.start, day(2));
      expect(range.end, day(10));
    });

    test('un solo día va de sus 0:00 a las del día siguiente', () {
      final range = closureRange(
        DaysDraft(firstDay: day(31, 12), lastDay: day(31, 12)),
      );
      expect(range.start, day(31, 12));
      expect(range.end, day(1, 1, 2027));
    });
  });

  group('closureErrors (RF-4)', () {
    Set<ClosureError> errors(ClosureDraft draft) =>
        closureErrors(draft, nowSalon: now);

    final cases = <(String, ClosureDraft, Set<ClosureError>)>[
      (
        'franja válida de mañana',
        RangeDraft(day: day(11), fromMinutes: 13 * 60, toMinutes: 14 * 60),
        {},
      ),
      (
        'franja con el fin igual al inicio',
        RangeDraft(day: day(11), fromMinutes: 13 * 60, toMinutes: 13 * 60),
        {ClosureError.endNotAfterStart},
      ),
      (
        'franja con el fin antes del inicio',
        RangeDraft(day: day(11), fromMinutes: 14 * 60, toMinutes: 13 * 60),
        {ClosureError.endNotAfterStart},
      ),
      (
        'franja de hoy que ya terminó',
        RangeDraft(day: day(10), fromMinutes: 7 * 60, toMinutes: 9 * 60),
        {ClosureError.past},
      ),
      (
        'franja de hoy que empezó y aún no terminó',
        RangeDraft(day: day(10), fromMinutes: 8 * 60, toMinutes: 10 * 60),
        {},
      ),
      (
        'franja de ayer',
        RangeDraft(day: day(9), fromMinutes: 13 * 60, toMinutes: 14 * 60),
        {ClosureError.past},
      ),
      (
        'días enteros desde hoy',
        DaysDraft(firstDay: day(10), lastDay: day(12)),
        {},
      ),
      (
        'días al revés',
        DaysDraft(firstDay: day(12), lastDay: day(11)),
        {ClosureError.daysReversed},
      ),
      (
        'días que terminaron ayer',
        DaysDraft(firstDay: day(5), lastDay: day(9)),
        {ClosureError.past},
      ),
      (
        'días que empezaron antes y llegan a hoy',
        DaysDraft(firstDay: day(5), lastDay: day(10)),
        {},
      ),
      (
        'franja el día 365 después de hoy',
        RangeDraft(
          day: day(10, 11, 2027),
          fromMinutes: 13 * 60,
          toMinutes: 14 * 60,
        ),
        {},
      ),
      (
        'franja el día 366 después de hoy',
        RangeDraft(
          day: day(11, 11, 2027),
          fromMinutes: 13 * 60,
          toMinutes: 14 * 60,
        ),
        {ClosureError.tooFar},
      ),
      (
        'días hasta el día 365',
        DaysDraft(firstDay: day(1, 11, 2027), lastDay: day(10, 11, 2027)),
        {},
      ),
      (
        'días que pasan del día 365',
        DaysDraft(firstDay: day(1, 11, 2027), lastDay: day(11, 11, 2027)),
        {ClosureError.tooFar},
      ),
      (
        'días al revés y demasiado lejos',
        DaysDraft(firstDay: day(20, 11, 2027), lastDay: day(1, 11, 2027)),
        {ClosureError.daysReversed, ClosureError.tooFar},
      ),
    ];

    for (final (name, draft, expected) in cases) {
      test(name, () => expect(errors(draft), expected));
    }
  });

  group('closureKind (plan D-3)', () {
    test('de 0:00 a 0:00 son días enteros', () {
      expect(closureKind(day(2), day(10)), ClosureKind.days);
    });

    test('con alguna hora que no es las 0:00, es una franja', () {
      expect(closureKind(at(13), at(14)), ClosureKind.range);
      expect(closureKind(day(2), at(14, 0, 2)), ClosureKind.range);
      expect(closureKind(at(13, 0, 2), day(3)), ClosureKind.range);
    });
  });

  group('closureConflicts (RF-5)', () {
    Appt appt(
      String id,
      DateTime start,
      DateTime end, [
      String status = 'confirmed',
    ]) => (id: id, start: start, end: end, status: status);

    AppointmentTimes times(Appt a) =>
        (start: fromSalon(a.start), end: fromSalon(a.end), status: a.status);

    List<String> conflicts(Iterable<Appt> appointments) => [
      for (final a in closureConflicts(
        (start: at(13, 0, 11), end: at(15, 0, 11)),
        appointments,
        times: times,
        nowSalon: now,
      ))
        a.id,
    ];

    final cases = <(String, Appt, bool)>[
      ('dentro', appt('a', at(13, 30, 11), at(14, 15, 11)), true),
      (
        'empieza antes y acaba dentro',
        appt('a', at(12, 30, 11), at(13, 30, 11)),
        true,
      ),
      (
        'empieza dentro y acaba después',
        appt('a', at(14, 30, 11), at(15, 30, 11)),
        true,
      ),
      ('cubre todo el cierre', appt('a', at(12, 0, 11), at(16, 0, 11)), true),
      (
        'termina justo cuando empieza el cierre',
        appt('a', at(12, 0, 11), at(13, 0, 11)),
        false,
      ),
      (
        'empieza justo cuando termina el cierre',
        appt('a', at(15, 0, 11), at(16, 0, 11)),
        false,
      ),
      ('otro día', appt('a', at(13, 0, 12), at(14, 0, 12)), false),
      (
        'esperando confirmación',
        appt('a', at(13, 30, 11), at(14, 0, 11), 'waiting_confirmation'),
        true,
      ),
      (
        'cancelado',
        appt('a', at(13, 30, 11), at(14, 0, 11), 'cancelled'),
        false,
      ),
    ];

    for (final (name, a, expected) in cases) {
      test(name, () => expect(conflicts([a]), expected ? ['a'] : isEmpty));
    }

    test('un turno en curso choca con un cierre que empieza ahora; uno ya '
        'terminado, no', () {
      final ids = [
        for (final a in closureConflicts(
          (start: at(8), end: at(12)),
          [appt('curso', at(8, 30), at(9, 30)), appt('fin', at(8), at(9))],
          times: times,
          nowSalon: now,
        ))
          a.id,
      ];
      expect(ids, ['curso']);
    });

    test('los que chocan salen ordenados por su inicio', () {
      expect(
        conflicts([
          appt('b', at(14, 0, 11), at(14, 30, 11)),
          appt('a', at(13, 0, 11), at(13, 30, 11)),
        ]),
        ['a', 'b'],
      );
    });

    test('un cierre de varios días choca con los turnos de cualquiera de '
        'ellos', () {
      final ids = [
        for (final a in closureConflicts(
          closureRange(DaysDraft(firstDay: day(11), lastDay: day(12))),
          [
            appt('mie', at(10, 0, 11), at(11, 0, 11)),
            appt('jue', at(10, 0, 12), at(11, 0, 12)),
            appt('vie', at(10, 0, 13), at(11, 0, 13)),
          ],
          times: times,
          nowSalon: now,
        ))
          a.id,
      ];
      expect(ids, ['mie', 'jue']);
    });
  });

  group('closureEntries (RF-1, RF-8)', () {
    test('los cierres guardados, en hora de pared, con su tipo', () {
      final entries = closureEntries(
        closures: [
          (
            id: 'c1',
            start: fromSalon(at(13, 0, 24)),
            end: fromSalon(at(14, 0, 24)),
          ),
          (id: 'c2', start: fromSalon(day(2, 12)), end: fromSalon(day(5, 12))),
        ],
        blockedDates: const [],
        nowSalon: now,
      );
      expect(entries, hasLength(2));
      expect(entries[0].source, const StoredClosureSource('c1'));
      expect(entries[0].start, at(13, 0, 24));
      expect(entries[0].end, at(14, 0, 24));
      expect(entries[0].kind, ClosureKind.range);
      expect(entries[1].source, const StoredClosureSource('c2'));
      expect(entries[1].kind, ClosureKind.days);
    });

    test('las fechas bloqueadas son días enteros, de 0:00 a 0:00', () {
      final entries = closureEntries(
        closures: const [],
        blockedDates: const ['2026-12-25'],
        nowSalon: now,
      );
      expect(entries.single.source, const BlockedDateSource('2026-12-25'));
      expect(entries.single.start, day(25, 12));
      expect(entries.single.end, day(26, 12));
      expect(entries.single.kind, ClosureKind.days);
    });

    test('las fechas bloqueadas que no son una fecha se ignoran', () {
      expect(
        closureEntries(
          closures: const [],
          blockedDates: const ['25/12/2026', '', '2026-13-01'],
          nowSalon: now,
        ),
        isEmpty,
      );
    });

    test('solo los que terminan después de ahora; hoy cuenta', () {
      final entries = closureEntries(
        closures: [
          (id: 'pasado', start: fromSalon(at(7)), end: fromSalon(at(9))),
          (id: 'curso', start: fromSalon(at(8)), end: fromSalon(at(10))),
        ],
        blockedDates: const ['2026-11-09', '2026-11-10'],
        nowSalon: now,
      );
      expect(
        [for (final e in entries) e.source],
        [
          const BlockedDateSource('2026-11-10'),
          const StoredClosureSource('curso'),
        ],
      );
    });

    test('ordenados por inicio', () {
      final entries = closureEntries(
        closures: [
          (
            id: 'tarde',
            start: fromSalon(at(13, 0, 20)),
            end: fromSalon(at(14, 0, 20)),
          ),
          (
            id: 'pronto',
            start: fromSalon(at(10, 0, 12)),
            end: fromSalon(at(11, 0, 12)),
          ),
        ],
        blockedDates: const ['2026-11-15'],
        nowSalon: now,
      );
      expect(
        [for (final e in entries) e.source],
        [
          const StoredClosureSource('pronto'),
          const BlockedDateSource('2026-11-15'),
          const StoredClosureSource('tarde'),
        ],
      );
    });
  });

  group('closuresOfDay (RF-9)', () {
    final entries = closureEntries(
      closures: [
        (
          id: 'franja',
          start: fromSalon(at(13, 0, 11)),
          end: fromSalon(at(14, 0, 11)),
        ),
        (id: 'varios', start: fromSalon(day(12)), end: fromSalon(day(15))),
      ],
      blockedDates: const ['2026-11-20'],
      nowSalon: now,
    );

    List<ClosureSource> of(DateTime d) => [
      for (final e in closuresOfDay(entries, d)) e.source,
    ];

    test('la franja sale en su día y no en otro', () {
      expect(of(day(11)), [const StoredClosureSource('franja')]);
      expect(of(day(16)), isEmpty);
    });

    test('un cierre de varios días sale en cada uno de ellos', () {
      for (final d in [12, 13, 14]) {
        expect(of(day(d)), [const StoredClosureSource('varios')]);
      }
      // Termina a las 0:00 del 15: ese día ya no está cerrado.
      expect(of(day(15)), isEmpty);
    });

    test('una fecha bloqueada sale en su día', () {
      expect(of(day(20)), [const BlockedDateSource('2026-11-20')]);
    });
  });

  group('isClosedAllDay (RF-13)', () {
    bool closed(DateTime d, List<({DateTime start, DateTime end})> closures) =>
        isClosedAllDay(d, settings, closures);

    test('sin cierres, no', () => expect(closed(day(10), const []), isFalse));

    test('una franja que cubre todo el horario, sí', () {
      expect(closed(day(10), [(start: at(8), end: at(12))]), isTrue);
      expect(closed(day(10), [(start: at(7), end: at(13))]), isTrue);
    });

    test('unos días enteros que lo incluyen, sí', () {
      expect(
        closed(day(11), [
          closureRange(DaysDraft(firstDay: day(10), lastDay: day(12))),
        ]),
        isTrue,
      );
    });

    test('dos franjas que se unen sin hueco, sí', () {
      expect(
        closed(day(10), [
          (start: at(10), end: at(12)),
          (start: at(8), end: at(10)),
        ]),
        isTrue,
      );
    });

    test('dos franjas que se cruzan, sí', () {
      expect(
        closed(day(10), [
          (start: at(8), end: at(10, 30)),
          (start: at(10), end: at(12)),
        ]),
        isTrue,
      );
    });

    test('con un hueco entre dos franjas, no', () {
      expect(
        closed(day(10), [
          (start: at(8), end: at(10)),
          (start: at(10, 15), end: at(12)),
        ]),
        isFalse,
      );
    });

    test('una franja que deja libre el principio o el final, no', () {
      expect(closed(day(10), [(start: at(8, 30), end: at(12))]), isFalse);
      expect(closed(day(10), [(start: at(8), end: at(11, 45))]), isFalse);
    });

    test('un día que ya no abre no cuenta como cerrado por un cierre', () {
      // El lunes ya está cerrado por el horario semanal.
      expect(closed(day(9), [(start: day(9), end: day(10))]), isFalse);
    });
  });

  test('no importa Flutter ni Firebase (RNF-1)', () {
    final source = File('lib/features/booking/logic/closures.dart')
        .readAsStringSync();
    expect(source, isNot(contains('package:flutter')));
    expect(source, isNot(contains('cloud_firestore')));
  });
}
