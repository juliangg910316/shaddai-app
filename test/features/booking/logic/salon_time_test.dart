import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';

void main() {
  group('toSalon / fromSalon', () {
    test('el mediodía UTC son las 9:00 en Curitiba', () {
      final wall = toSalon(DateTime.utc(2026, 11, 10, 12));
      expect(wall, DateTime.utc(2026, 11, 10, 9));
      expect(wall.isUtc, isTrue);
    });

    test('las 2:30 UTC son las 23:30 del día anterior en Curitiba', () {
      expect(
        toSalon(DateTime.utc(2026, 11, 11, 2, 30)),
        DateTime.utc(2026, 11, 10, 23, 30),
      );
      expect(
        fromSalon(DateTime.utc(2026, 11, 10, 23, 30)),
        DateTime.utc(2026, 11, 11, 2, 30),
      );
    });

    test('ida y vuelta da el mismo instante', () {
      final instants = [
        DateTime.utc(2026, 1, 1),
        DateTime.utc(2026, 2, 28, 23, 59),
        DateTime.utc(2026, 12, 31, 2, 59),
        DateTime.utc(2027, 3, 1, 3),
      ];
      for (final instant in instants) {
        expect(fromSalon(toSalon(instant)), instant, reason: '$instant');
      }
    });

    test('no depende de la zona del instante de entrada', () {
      final instant = DateTime.utc(2026, 11, 10, 15);
      expect(toSalon(instant.toLocal()), toSalon(instant));
    });

    test('fromSalon ignora la marca de zona de la hora de pared', () {
      expect(
        fromSalon(DateTime(2026, 11, 10, 9)),
        DateTime.utc(2026, 11, 10, 12),
      );
    });
  });

  test('salonDay deja solo el día, a las 0:00', () {
    expect(
      salonDay(DateTime.utc(2026, 11, 10, 23, 30)),
      DateTime.utc(2026, 11, 10),
    );
  });

  group('deviceIsInSalonZone (RF-5)', () {
    const cases = {
      'Curitiba (−3 h)': (Duration(hours: -3), true),
      'Buenos Aires (−3 h)': (Duration(hours: -3), true),
      'Lisboa (+0 h)': (Duration.zero, false),
      'Manaos (−4 h)': (Duration(hours: -4), false),
      'Fernando de Noronha (−2 h)': (Duration(hours: -2), false),
    };
    cases.forEach((name, value) {
      test(name, () => expect(deviceIsInSalonZone(value.$1), value.$2));
    });
  });
}
