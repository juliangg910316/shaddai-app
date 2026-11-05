import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/features/booking/logic/free_slots.dart';

// 2026-11-10 es martes. Todas las horas son de pared del salón.
DateTime at(int hour, [int minute = 0, int day = 10]) =>
    DateTime.utc(2026, 11, day, hour, minute);

final tuesday = DateTime.utc(2026, 11, 10);

/// La noche anterior: ninguna hora del martes ha pasado.
final earlier = DateTime.utc(2026, 11, 9, 20);

/// El martes abre de [open] a [close].
CalendarSettingsModel opening(String open, String close) =>
    CalendarSettingsModel(
      openingHours: {
        'tuesday': DaySchedule(open: open, close: close, isClosed: false),
      },
      globalSlotDurationMinutes: 60,
      blockedDates: const [],
    );

BusyRange busy(DateTime start, DateTime end) => (start: start, end: end);

/// Las horas libres como `'H:mm/cobertura'`, para leer las tablas.
List<String> describe(List<FreeSlot> slots) => [
  for (final slot in slots)
    '${slot.start.hour}:${slot.start.minute.toString().padLeft(2, '0')}'
        '/${slot.coverageMinutes}',
];

void main() {
  group('freeSlots (RF-4, RNF-1)', () {
    final cases =
        <
          String,
          ({
            CalendarSettingsModel settings,
            List<BusyRange> busy,
            DateTime now,
            List<String> expected,
          })
        >{
          'sin turnos: toda la rejilla, con cobertura hasta el cierre': (
            settings: opening('08:00', '10:00'),
            busy: [],
            now: earlier,
            expected: ['8:00/120', '8:30/90', '9:00/60', '9:30/30'],
          ),
          'ejemplo de la spec: turno de 8:00 a 9:10 → 9:30 es la primera': (
            settings: opening('08:00', '11:00'),
            busy: [busy(at(8), at(9, 10))],
            now: earlier,
            expected: ['9:30/90', '10:00/60', '10:30/30'],
          ),
          'turno de 8:00 a 9:00 → 9:00 es libre': (
            settings: opening('08:00', '10:00'),
            busy: [busy(at(8), at(9))],
            now: earlier,
            expected: ['9:00/60', '9:30/30'],
          ),
          'la cobertura termina en el siguiente turno ocupado': (
            settings: opening('08:00', '12:00'),
            busy: [busy(at(10), at(11))],
            now: earlier,
            expected: [
              '8:00/120',
              '8:30/90',
              '9:00/60',
              '9:30/30',
              '11:00/60',
              '11:30/30',
            ],
          ),
          'la rejilla no coincide con el fin del turno (8:00 a 8:45)': (
            settings: opening('08:00', '10:00'),
            busy: [busy(at(8), at(8, 45))],
            now: earlier,
            expected: ['9:00/60', '9:30/30'],
          ),
          'un turno que empieza entre dos horas recorta la anterior': (
            settings: opening('08:00', '10:00'),
            busy: [busy(at(9, 10), at(9, 40))],
            now: earlier,
            expected: ['8:00/70', '8:30/40', '9:00/10'],
          ),
          'apertura a las 8:15': (
            settings: opening('08:15', '10:00'),
            busy: [],
            now: earlier,
            expected: ['8:15/105', '8:45/75', '9:15/45', '9:45/15'],
          ),
          'una hora igual a "ahora" no es libre': (
            settings: opening('08:00', '10:00'),
            busy: [],
            now: at(9),
            expected: ['9:30/30'],
          ),
          'una hora un minuto después de "ahora" sí es libre': (
            settings: opening('08:00', '10:00'),
            busy: [],
            now: at(8, 59),
            expected: ['9:00/60', '9:30/30'],
          ),
          'turnos de otro día no cuentan': (
            settings: opening('08:00', '09:00'),
            busy: [
              busy(at(8, 0, 9), at(9, 0, 9)),
              busy(at(8, 0, 11), at(9, 0, 11)),
            ],
            now: earlier,
            expected: ['8:00/60', '8:30/30'],
          ),
          'turnos desordenados y que se solapan': (
            settings: opening('08:00', '12:00'),
            busy: [
              busy(at(10), at(11)),
              busy(at(8), at(9)),
              busy(at(8, 30), at(9, 30)),
            ],
            now: earlier,
            expected: ['9:30/30', '11:00/60', '11:30/30'],
          ),
          'todo ocupado → ninguna hora libre': (
            settings: opening('08:00', '10:00'),
            busy: [busy(at(8), at(10))],
            now: earlier,
            expected: [],
          ),
          'día sin rejilla (cierre no posterior a la apertura)': (
            settings: opening('10:00', '10:00'),
            busy: [],
            now: earlier,
            expected: [],
          ),
          'ya pasó el cierre': (
            settings: opening('08:00', '10:00'),
            busy: [],
            now: at(10),
            expected: [],
          ),
        };

    cases.forEach((name, c) {
      test(name, () {
        expect(
          describe(
            freeSlots(
              day: tuesday,
              settings: c.settings,
              busy: c.busy,
              nowSalon: c.now,
            ),
          ),
          c.expected,
        );
      });
    });

    test('las horas son horas de pared del día pedido', () {
      final slots = freeSlots(
        day: DateTime.utc(2026, 11, 10, 15), // la hora del día no importa
        settings: opening('08:00', '09:00'),
        busy: const [],
        nowSalon: earlier,
      );
      expect(slots.map((s) => s.start), [at(8), at(8, 30)]);
      expect(slots.first.start.isUtc, isTrue);
    });
  });

  group('fits (RF-12, RF-15)', () {
    final slot = FreeSlot(start: at(9, 30), coverageMinutes: 30);

    test('un servicio que cabe justo', () => expect(fits(30, slot), isTrue));
    test('uno más corto', () => expect(fits(20, slot), isTrue));
    test('uno un minuto más largo', () => expect(fits(31, slot), isFalse));

    test('cobertura que llega justo al cierre', () {
      final last = freeSlots(
        day: tuesday,
        settings: opening('08:00', '10:00'),
        busy: const [],
        nowSalon: earlier,
      ).last;
      expect(last.coverageMinutes, 30);
      expect(fits(30, last), isTrue);
      expect(fits(45, last), isFalse);
    });
  });

  test('FreeSlot se compara por valor', () {
    expect(
      FreeSlot(start: at(8), coverageMinutes: 60),
      FreeSlot(start: at(8), coverageMinutes: 60),
    );
    expect(
      FreeSlot(start: at(8), coverageMinutes: 60),
      isNot(FreeSlot(start: at(8), coverageMinutes: 30)),
    );
  });
}
