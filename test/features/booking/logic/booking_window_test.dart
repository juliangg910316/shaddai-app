import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/features/booking/logic/booking_window.dart';

/// Lunes a sábado de 8:00 a 18:00; domingo cerrado.
CalendarSettingsModel settings({
  Map<String, DaySchedule> overrides = const {},
  List<String> blockedDates = const [],
}) {
  DaySchedule open() =>
      DaySchedule(open: '08:00', close: '18:00', isClosed: false);
  return CalendarSettingsModel(
    openingHours: {
      'monday': open(),
      'tuesday': open(),
      'wednesday': open(),
      'thursday': open(),
      'friday': open(),
      'saturday': open(),
      'sunday': DaySchedule(open: '08:00', close: '18:00', isClosed: true),
      ...overrides,
    },
    globalSlotDurationMinutes: 60,
    blockedDates: blockedDates,
  );
}

// 2026-11-10 es martes.
final tuesday = DateTime.utc(2026, 11, 10);
final nowTuesday = DateTime.utc(2026, 11, 10, 10, 15);

void main() {
  group('bookingWindow', () {
    test('va de hoy a hoy + 60 días, los dos incluidos', () {
      final window = bookingWindow(nowTuesday);
      expect(window.first, tuesday);
      expect(window.last, DateTime.utc(2027, 1, 9));
      expect(window.contains(tuesday), isTrue);
      expect(window.contains(DateTime.utc(2027, 1, 9)), isTrue);
      expect(window.contains(DateTime.utc(2027, 1, 10)), isFalse);
      expect(window.contains(DateTime.utc(2026, 11, 9)), isFalse);
    });

    test('a las 23:59 del salón la ventana sigue empezando hoy', () {
      expect(bookingWindow(DateTime.utc(2026, 11, 10, 23, 59)).first, tuesday);
    });
  });

  group('dayGrid', () {
    test('cada 30 minutos desde la apertura y antes del cierre', () {
      final grid = dayGrid(
        tuesday,
        settings(
          overrides: {
            'tuesday': DaySchedule(
              open: '08:00',
              close: '10:00',
              isClosed: false,
            ),
          },
        ),
      );
      expect(grid, [
        DateTime.utc(2026, 11, 10, 8),
        DateTime.utc(2026, 11, 10, 8, 30),
        DateTime.utc(2026, 11, 10, 9),
        DateTime.utc(2026, 11, 10, 9, 30),
      ]);
    });

    test('una apertura que no cae en media hora exacta parte de ella', () {
      final grid = dayGrid(
        tuesday,
        settings(
          overrides: {
            'tuesday': DaySchedule(
              open: '08:15',
              close: '09:30',
              isClosed: false,
            ),
          },
        ),
      );
      expect(grid, [
        DateTime.utc(2026, 11, 10, 8, 15),
        DateTime.utc(2026, 11, 10, 8, 45),
        DateTime.utc(2026, 11, 10, 9, 15),
      ]);
    });

    final closedCases = {
      'día cerrado': DaySchedule(open: '08:00', close: '18:00', isClosed: true),
      'cierre igual a la apertura': DaySchedule(
        open: '09:00',
        close: '09:00',
        isClosed: false,
      ),
      'cierre antes de la apertura': DaySchedule(
        open: '18:00',
        close: '08:00',
        isClosed: false,
      ),
      'hora mal escrita': DaySchedule(
        open: 'nueve',
        close: '18:00',
        isClosed: false,
      ),
    };
    closedCases.forEach((name, schedule) {
      test('$name → sin rejilla', () {
        expect(
          dayGrid(tuesday, settings(overrides: {'tuesday': schedule})),
          isNull,
        );
      });
    });

    test('un día sin horario guardado → sin rejilla', () {
      final noTuesday = CalendarSettingsModel(
        openingHours: {},
        globalSlotDurationMinutes: 60,
        blockedDates: const [],
      );
      expect(dayGrid(tuesday, noTuesday), isNull);
    });
  });

  group('isSelectableDay (RF-3)', () {
    final window = bookingWindow(nowTuesday);
    final cases = <String, (DateTime, CalendarSettingsModel, bool)>{
      'hoy, abierto': (tuesday, settings(), true),
      'el día 60': (DateTime.utc(2027, 1, 9), settings(), true),
      'el día 61': (DateTime.utc(2027, 1, 11), settings(), false),
      'ayer': (DateTime.utc(2026, 11, 9), settings(), false),
      'domingo cerrado': (DateTime.utc(2026, 11, 15), settings(), false),
      'fecha bloqueada': (
        DateTime.utc(2026, 11, 12),
        settings(blockedDates: ['2026-11-12']),
        false,
      ),
      'cierre no posterior a la apertura': (
        tuesday,
        settings(
          overrides: {
            'tuesday': DaySchedule(
              open: '10:00',
              close: '10:00',
              isClosed: false,
            ),
          },
        ),
        false,
      ),
    };
    cases.forEach((name, value) {
      test(name, () {
        expect(isSelectableDay(value.$1, value.$2, window), value.$3);
      });
    });
  });

  group('initialDay (RF-1, RF-2)', () {
    test('hoy, si se puede elegir y tiene horas libres', () {
      expect(
        initialDay(
          nowSalon: nowTuesday,
          settings: settings(),
          hasFreeSlot: (_) => true,
        ),
        tuesday,
      );
    });

    test('mañana, si hoy ya no tiene horas libres', () {
      expect(
        initialDay(
          nowSalon: nowTuesday,
          settings: settings(),
          hasFreeSlot: (day) => day != tuesday,
        ),
        DateTime.utc(2026, 11, 11),
      );
    });

    test('se salta los días cerrados y bloqueados', () {
      // Sábado 14 bloqueado y domingo 15 cerrado: el lunes 16.
      final saturdayNight = DateTime.utc(2026, 11, 13, 20);
      expect(
        initialDay(
          nowSalon: saturdayNight,
          settings: settings(blockedDates: ['2026-11-14']),
          hasFreeSlot: (day) => day != DateTime.utc(2026, 11, 13),
        ),
        DateTime.utc(2026, 11, 16),
      );
    });

    test('ningún día con horas libres → el primero que se puede elegir', () {
      expect(
        initialDay(
          nowSalon: DateTime.utc(2026, 11, 15, 9), // domingo, cerrado
          settings: settings(),
          hasFreeSlot: (_) => false,
        ),
        DateTime.utc(2026, 11, 16),
      );
    });

    test('ningún día se puede elegir → null', () {
      final allClosed = CalendarSettingsModel(
        openingHours: {},
        globalSlotDurationMinutes: 60,
        blockedDates: const [],
      );
      expect(
        initialDay(
          nowSalon: nowTuesday,
          settings: allClosed,
          hasFreeSlot: (_) => true,
        ),
        isNull,
      );
    });

    test('solo pregunta por días que se pueden elegir', () {
      final asked = <DateTime>[];
      initialDay(
        nowSalon: DateTime.utc(2026, 11, 14, 9), // sábado
        settings: settings(),
        hasFreeSlot: (day) {
          asked.add(day);
          return day == DateTime.utc(2026, 11, 16);
        },
      );
      expect(asked, [DateTime.utc(2026, 11, 14), DateTime.utc(2026, 11, 16)]);
    });
  });

  test('blockedDateKey da yyyy-MM-dd con ceros', () {
    expect(blockedDateKey(DateTime.utc(2026, 1, 5)), '2026-01-05');
  });
}
