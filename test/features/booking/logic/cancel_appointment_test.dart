import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/booking_edit.dart';
import 'package:shaddai/features/booking/logic/cancel_appointment.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';

// Horas de pared del salón. 2026-11-10 es martes.
DateTime at(int hour, [int minute = 0, int day = 10]) =>
    DateTime.utc(2026, 11, day, hour, minute);

const manicure = BookedServiceModel(
  kind: BookedKind.service,
  id: 's1',
  name: BilingualText(es: 'Manicura', pt: 'Manicure'),
  priceCents: 5000,
  durationMinutes: 60,
);

const pedicure = BookedServiceModel(
  kind: BookedKind.service,
  id: 's2',
  name: BilingualText(es: 'Pedicura', pt: 'Pedicure'),
  priceCents: 6000,
  durationMinutes: 60,
);

/// Un turno guardado (instantes, como en Firestore) de [start] a [end] en
/// hora de pared del salón.
AppointmentModel stored({
  DateTime? start,
  DateTime? end,
  String status = 'waiting_confirmation',
  BookedServiceModel? booked = manicure,
}) => AppointmentModel(
  id: 't1',
  clientId: 'u1',
  clientName: 'Ana',
  clientPhone: '41 99999-0000',
  startTime: fromSalon(start ?? at(10)),
  endTime: fromSalon(end ?? at(11)),
  status: status,
  createdAt: DateTime.utc(2026, 11, 1),
  booked: booked,
);

void main() {
  group('cancelAvailability (RF-3, RF-4, RF-7)', () {
    // Un turno de las 10:00 del salón, con margen de 60 minutos: se puede
    // cancelar hasta antes de las 9:00.
    final start = fromSalon(at(10));

    CancelAvailability availability({
      required DateTime nowSalon,
      int? margin = 60,
      bool settingsError = false,
    }) => cancelAvailability(
      settingsError: settingsError,
      marginMinutes: margin,
      start: start,
      now: fromSalon(nowSalon),
    );

    test('fuera del margen se puede cancelar', () {
      expect(availability(nowSalon: at(8, 59)), CancelAvailability.cancellable);
    });

    test('en el borde exacto del margen ya no (como editar, spec 006)', () {
      expect(availability(nowSalon: at(9)), CancelAvailability.closed);
    });

    test('dentro del margen, cerrado', () {
      expect(availability(nowSalon: at(9, 30)), CancelAvailability.closed);
    });

    test('con margen 0, hasta que empieza', () {
      expect(
        availability(nowSalon: at(9, 59), margin: 0),
        CancelAvailability.cancellable,
      );
      expect(
        availability(nowSalon: at(10), margin: 0),
        CancelAvailability.closed,
      );
    });

    test('ya empezado, cerrado', () {
      expect(
        availability(nowSalon: at(10, 15), margin: 0),
        CancelAvailability.closed,
      );
    });

    test('mientras el calendario carga, loading', () {
      expect(
        availability(nowSalon: at(8), margin: null),
        CancelAvailability.loading,
      );
    });

    test('si el calendario falla, error (gana a loading)', () {
      expect(
        availability(nowSalon: at(8), margin: null, settingsError: true),
        CancelAvailability.error,
      );
      expect(
        availability(nowSalon: at(8), settingsError: true),
        CancelAvailability.error,
      );
    });
  });

  group('checkCancelBeforeSave (RF-14)', () {
    // Lo que vio la clienta: su turno de 10:00 a 11:00, esperando
    // confirmación.
    final shown = EditOriginal.of(stored());

    CancelCheck check(
      AppointmentModel? current, {
      DateTime? nowSalon,
      int margin = 60,
    }) => checkCancelBeforeSave(
      shown: shown,
      current: current,
      nowSalon: nowSalon ?? at(8),
      marginMinutes: margin,
    );

    test('sin cambios y fuera del margen, ok', () {
      expect(check(stored()), CancelCheck.ok);
    });

    test('si la admin solo lo confirmó, ok: el estado no cuenta (D-3)', () {
      expect(check(stored(status: 'confirmed')), CancelCheck.ok);
    });

    test('si ya no existe, notActive', () {
      expect(check(null), CancelCheck.notActive);
    });

    test('si ya está cancelado, notActive', () {
      expect(check(stored(status: 'cancelled')), CancelCheck.notActive);
    });

    test('si ya terminó, notActive', () {
      expect(
        check(stored(), nowSalon: at(11), margin: 0),
        CancelCheck.notActive,
      );
    });

    test('notActive gana a changed', () {
      expect(
        check(stored(start: at(9), status: 'cancelled')),
        CancelCheck.notActive,
      );
    });

    test('otra hora de inicio, changed', () {
      expect(
        check(stored(start: at(10, 30), end: at(11, 30))),
        CancelCheck.changed,
      );
    });

    test('otro fin, changed', () {
      expect(check(stored(end: at(11, 30))), CancelCheck.changed);
    });

    test('otro día a la misma hora, changed', () {
      expect(
        check(stored(start: at(10, 0, 12), end: at(11, 0, 12))),
        CancelCheck.changed,
      );
    });

    test('otro servicio, changed', () {
      expect(check(stored(booked: pedicure)), CancelCheck.changed);
    });

    test('dentro del margen, notCancellable', () {
      expect(check(stored(), nowSalon: at(9, 30)), CancelCheck.notCancellable);
    });

    test('changed gana a notCancellable', () {
      expect(
        check(stored(booked: pedicure), nowSalon: at(9, 30)),
        CancelCheck.changed,
      );
    });

    test('con margen 0, en curso ya no se puede cancelar', () {
      expect(
        check(stored(), nowSalon: at(10, 15), margin: 0),
        CancelCheck.notCancellable,
      );
    });
  });

  test('la lógica no importa Flutter ni Firebase (constitución, 3)', () {
    final source = File('lib/features/booking/logic/cancel_appointment.dart')
        .readAsStringSync();
    expect(source, isNot(contains('package:flutter')));
    expect(source, isNot(contains('firebase')));
    expect(source, isNot(contains('cloud_firestore')));
  });
}
