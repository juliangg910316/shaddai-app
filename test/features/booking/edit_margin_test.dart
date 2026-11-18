import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/booking/logic/edit_margin.dart';

/// Las opciones del margen de edición (spec 008, RF-36, RF-37).
void main() {
  test('las opciones: sin margen, 1, 2, 3, 6, 12, 24, 48 y 72 horas', () {
    expect(editMarginOptions, [0, 60, 120, 180, 360, 720, 1440, 2880, 4320]);
  });

  group('marginChoices', () {
    for (final (current, expected) in [
      (0, editMarginOptions),
      (1440, editMarginOptions),
      (4320, editMarginOptions),
      (90, [0, 60, 90, 120, 180, 360, 720, 1440, 2880, 4320]),
      (30, [0, 30, 60, 120, 180, 360, 720, 1440, 2880, 4320]),
      (5000, [...editMarginOptions, 5000]),
    ]) {
      test('con $current', () => expect(marginChoices(current), expected));
    }
  });

  group('marginParts', () {
    for (final (minutes, expected) in [
      (0, (hours: 0, minutes: 0)),
      (45, (hours: 0, minutes: 45)),
      (60, (hours: 1, minutes: 0)),
      (90, (hours: 1, minutes: 30)),
      (1441, (hours: 24, minutes: 1)),
    ]) {
      test('$minutes minutos', () => expect(marginParts(minutes), expected));
    }
  });
}
