import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/booking/logic/booking_edit.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';

// Horas de pared del salón. 2026-11-10 es martes.
DateTime at(int hour, [int minute = 0, int day = 10]) =>
    DateTime.utc(2026, 11, day, hour, minute);

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
}
