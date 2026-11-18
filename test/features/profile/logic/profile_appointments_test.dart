import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/booking/logic/booking_rules.dart';
import 'package:shaddai/features/profile/logic/profile_appointments.dart';

/// Un turno de prueba: su nombre, inicio, fin y estado.
typedef Turn = ({String id, DateTime start, DateTime end, String status});

Turn turn(String id, int day, String status, {int hours = 1}) => (
  id: id,
  start: DateTime.utc(2026, 11, day, 13),
  end: DateTime.utc(2026, 11, day, 13 + hours),
  status: status,
);

AppointmentTimes timesOf(Turn t) =>
    (start: t.start, end: t.end, status: t.status);

void main() {
  // "Ahora": 10 de noviembre a las 12:00 UTC.
  final now = DateTime.utc(2026, 11, 10, 12);

  List<String> ids(List<Turn> turns) => [for (final t in turns) t.id];

  group('profileAppointments (RF-1, RF-5, RF-20, RF-22)', () {
    test('separa el turno activo del historial', () {
      final mine = [
        turn('pasado', 3, 'confirmed'),
        turn('activo', 14, 'waiting_confirmation'),
        turn('cancelado', 20, 'cancelled'),
      ];
      final result = profileAppointments(mine, times: timesOf, now: now);
      expect(result.active?.id, 'activo');
      expect(ids(result.history), ['cancelado', 'pasado']);
    });

    test('el historial va del más reciente al más antiguo (RF-20)', () {
      final mine = [
        turn('a', 1, 'confirmed'),
        turn('c', 8, 'cancelled'),
        turn('b', 5, 'waiting_confirmation'),
        turn('d', 25, 'cancelled'),
      ];
      final result = profileAppointments(mine, times: timesOf, now: now);
      expect(result.active, isNull);
      expect(ids(result.history), ['d', 'c', 'b', 'a']);
    });

    test('un turno en curso sigue siendo el activo', () {
      final inProgress = (
        id: 'en curso',
        start: DateTime.utc(2026, 11, 10, 11, 30),
        end: DateTime.utc(2026, 11, 10, 12, 30),
        status: 'confirmed',
      );
      final result = profileAppointments(
        [inProgress, turn('pasado', 2, 'confirmed')],
        times: timesOf,
        now: now,
      );
      expect(result.active?.id, 'en curso');
      expect(ids(result.history), ['pasado']);
    });

    test('sin turno activo (RF-5)', () {
      final result = profileAppointments(
        [turn('cancelado', 14, 'cancelled')],
        times: timesOf,
        now: now,
      );
      expect(result.active, isNull);
      expect(ids(result.history), ['cancelado']);
    });

    test('sin turnos, nada (RF-22)', () {
      final result = profileAppointments(
        const <Turn>[],
        times: timesOf,
        now: now,
      );
      expect(result.active, isNull);
      expect(result.history, isEmpty);
    });

    test('con datos antiguos de dos activos, el segundo va al historial', () {
      final mine = [
        turn('segundo', 20, 'confirmed'),
        turn('primero', 14, 'confirmed'),
      ];
      final result = profileAppointments(mine, times: timesOf, now: now);
      expect(result.active?.id, 'primero');
      expect(ids(result.history), ['segundo']);
    });
  });

  group('historyLabel (RF-20, RF-21; plan D-1)', () {
    final past = DateTime.utc(2026, 11, 9, 14);
    final future = DateTime.utc(2026, 11, 20, 14);

    HistoryLabel label(String status, {bool byClient = false, DateTime? end}) =>
        historyLabel(
          status: status,
          cancelledByClient: byClient,
          end: end ?? past,
          now: now,
        );

    test('cancelado por la clienta', () {
      expect(label('cancelled', byClient: true), HistoryLabel.cancelledByYou);
      expect(
        label('cancelled', byClient: true, end: future),
        HistoryLabel.cancelledByYou,
      );
    });

    test('cancelado sin cancelledBy: por el salón', () {
      expect(label('cancelled'), HistoryLabel.cancelledBySalon);
      expect(label('cancelled', end: future), HistoryLabel.cancelledBySalon);
    });

    test('confirmado y terminado: realizado', () {
      expect(label('confirmed'), HistoryLabel.done);
    });

    test('terminado sin confirmar: no confirmado (RF-21)', () {
      expect(label('waiting_confirmation'), HistoryLabel.notConfirmed);
    });

    test('termina justo ahora: ya terminó', () {
      expect(label('confirmed', end: now), HistoryLabel.done);
    });

    test('activo que aún no terminó (datos antiguos): upcoming', () {
      expect(label('confirmed', end: future), HistoryLabel.upcoming);
      expect(label('waiting_confirmation', end: future), HistoryLabel.upcoming);
    });

    test('un estado desconocido que ya terminó: no confirmado', () {
      expect(label('raro'), HistoryLabel.notConfirmed);
    });
  });

  test('la lógica no importa Flutter ni Firebase (constitución, 3)', () {
    final source = File('lib/features/profile/logic/profile_appointments.dart')
        .readAsStringSync();
    expect(source, isNot(contains('package:flutter')));
    expect(source, isNot(contains('firebase')));
    expect(source, isNot(contains('cloud_firestore')));
  });
}
