import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shaddai/core/utils/weekday_key.dart';

void main() {
  test('da la clave en inglés de cada día de la semana', () {
    // 2026-10-19 es lunes.
    final monday = DateTime(2026, 10, 19);
    const expected = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];

    for (var i = 0; i < 7; i++) {
      expect(weekdayKey(monday.add(Duration(days: i))), expected[i]);
    }
  });

  test('coincide con el DateFormat(EEEE) sin locale que sustituye', () {
    final start = DateTime(2026, 1, 1);
    for (var i = 0; i < 14; i++) {
      final date = start.add(Duration(days: i));
      expect(weekdayKey(date), DateFormat('EEEE').format(date).toLowerCase());
    }
  });

  test('no depende de la hora del día', () {
    expect(weekdayKey(DateTime(2026, 10, 25, 23, 59)), 'sunday');
    expect(weekdayKey(DateTime(2026, 10, 25)), 'sunday');
  });
}
