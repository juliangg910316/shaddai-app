import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/admin/logic/admin_agenda.dart';
import 'package:shaddai/features/booking/logic/booking_edit.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';

/// Lógica pura de la agenda de la admin (spec 010, plan § 4, T1).
///
/// Las horas de pared del salón son `DateTime.utc` con la hora de Curitiba;
/// los instantes se sacan con `fromSalon`. Nada depende de la zona del
/// dispositivo: también pasa con `TZ=Asia/Tokyo`.
DateTime wall(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

const manicura = BookedServiceModel(
  kind: BookedKind.service,
  id: 's1',
  name: BilingualText(es: 'Manicura', pt: 'Manicure'),
  priceCents: 3000,
  durationMinutes: 45,
);

const pedicura = BookedServiceModel(
  kind: BookedKind.service,
  id: 's2',
  name: BilingualText(es: 'Pedicura', pt: 'Pedicure'),
  priceCents: 4000,
  durationMinutes: 45,
);

/// Un turno del 20/11 de 10:00 a 10:45 del salón, salvo que se diga otra cosa.
AppointmentModel appointment({
  String id = 't1',
  String status = 'waiting_confirmation',
  DateTime? start,
  DateTime? end,
  BookedServiceModel? booked = manicura,
}) {
  final from = start ?? wall(20, 10);
  return AppointmentModel(
    id: id,
    clientId: 'ana',
    clientName: 'Ana',
    clientPhone: '+55 41 99999-0000',
    startTime: fromSalon(from),
    endTime: fromSalon(end ?? from.add(const Duration(minutes: 45))),
    status: status,
    createdAt: fromSalon(wall(1, 9)),
    booked: booked,
  );
}

void main() {
  group('el día de la agenda (RF-1, RF-2)', () {
    test('agendaDay toma año, mes y día como día del salón', () {
      expect(
        agendaDay(DateTime(2026, 11, 20, 23, 59)),
        DateTime.utc(2026, 11, 20),
      );
      expect(agendaDay(wall(20, 1)), DateTime.utc(2026, 11, 20));
    });

    test('agendaToday es el día del salón de "ahora"', () {
      expect(agendaToday(wall(20, 0)), DateTime.utc(2026, 11, 20));
      expect(agendaToday(wall(20, 23, 59)), DateTime.utc(2026, 11, 20));
    });

    test('a las 22:30 de Curitiba ya es otro día en UTC, pero no en el '
        'salón', () {
      final now = DateTime.utc(2026, 11, 21, 1, 30); // 20/11 22:30 en Curitiba
      expect(agendaToday(toSalon(now)), DateTime.utc(2026, 11, 20));
    });

    test('agendaRange va de medianoche a medianoche del salón', () {
      final range = agendaRange(DateTime.utc(2026, 11, 20));
      expect(range.from, DateTime.utc(2026, 11, 20, 3));
      expect(range.to, DateTime.utc(2026, 11, 21, 3));
      expect(range.from.isAtSameMomentAs(fromSalon(wall(20, 0))), isTrue);
    });

    test('agendaRange cruza el fin de mes y de año', () {
      expect(
        agendaRange(DateTime.utc(2026, 11, 30)).to,
        DateTime.utc(2026, 12, 1, 3),
      );
      expect(
        agendaRange(DateTime.utc(2026, 12, 31)).to,
        DateTime.utc(2027, 1, 1, 3),
      );
    });

    test('agendaRange usa el día aunque llegue con hora', () {
      expect(
        agendaRange(DateTime(2026, 11, 20, 18)).from,
        DateTime.utc(2026, 11, 20, 3),
      );
    });
  });

  group('el calendario (RF-4)', () {
    final today = DateTime.utc(2026, 11, 20);
    final bounds = agendaPickerBounds(today);

    test('de 365 días antes a 365 días después de hoy', () {
      expect(bounds.first, DateTime.utc(2025, 11, 20));
      expect(bounds.last, DateTime.utc(2027, 11, 20));
    });

    test('abre en el día mostrado si está dentro', () {
      expect(agendaPickerInitial(today, bounds), today);
      expect(
        agendaPickerInitial(DateTime.utc(2027, 3, 1), bounds),
        DateTime.utc(2027, 3, 1),
      );
      expect(agendaPickerInitial(bounds.first, bounds), bounds.first);
      expect(agendaPickerInitial(bounds.last, bounds), bounds.last);
    });

    test('abre en el límite más cercano si está fuera', () {
      expect(
        agendaPickerInitial(DateTime.utc(2024, 1, 1), bounds),
        bounds.first,
      );
      expect(
        agendaPickerInitial(DateTime.utc(2028, 1, 1), bounds),
        bounds.last,
      );
    });
  });

  group('los contadores (RF-6)', () {
    test('sin cancelados; esperando solo los que esperan', () {
      final counts = agendaCounts([
        appointment(id: 'a'),
        appointment(id: 'b', status: 'confirmed'),
        appointment(id: 'c', status: 'cancelled'),
        appointment(id: 'd'),
      ]);
      expect(counts.total, 3);
      expect(counts.waiting, 2);
    });

    test('sin turnos, cero', () {
      final counts = agendaCounts(const []);
      expect(counts.total, 0);
      expect(counts.waiting, 0);
    });
  });

  group('las acciones de un turno (RF-7 a RF-10)', () {
    AgendaActions actions(String status, DateTime now) {
      final a = appointment(status: status);
      return agendaActions(status: a.status, end: a.endTime, nowSalon: now);
    }

    test('activo antes de empezar', () {
      expect(
        actions('waiting_confirmation', wall(20, 9)),
        AgendaActions.active,
      );
      expect(actions('confirmed', wall(20, 9)), AgendaActions.active);
    });

    test('en curso sigue activo', () {
      expect(actions('confirmed', wall(20, 10, 30)), AgendaActions.active);
    });

    test('justo en el fin ya es pasado', () {
      expect(actions('confirmed', wall(20, 10, 45)), AgendaActions.none);
      expect(
        actions('waiting_confirmation', wall(20, 10, 45)),
        AgendaActions.pastUnconfirmed,
      );
    });

    test('pasado confirmado: sin acciones', () {
      expect(actions('confirmed', wall(21, 9)), AgendaActions.none);
    });

    test('pasado sin confirmar: "Sin confirmar"', () {
      expect(
        actions('waiting_confirmation', wall(21, 9)),
        AgendaActions.pastUnconfirmed,
      );
    });

    test('cancelado: sin acciones, pasado o no', () {
      expect(actions('cancelled', wall(20, 9)), AgendaActions.none);
      expect(actions('cancelled', wall(21, 9)), AgendaActions.none);
    });
  });

  group('antes de cancelar (RF-14, RF-15)', () {
    final shown = EditOriginal.of(appointment());

    AdminCancelCheck check(AppointmentModel? current, [DateTime? now]) =>
        checkAdminCancelBeforeSave(
          shown: shown,
          current: current,
          nowSalon: now ?? wall(20, 9),
        );

    test('igual que se mostró: ok', () {
      expect(check(appointment()), AdminCancelCheck.ok);
    });

    test('solo confirmado entretanto: ok (el estado no cuenta)', () {
      expect(check(appointment(status: 'confirmed')), AdminCancelCheck.ok);
    });

    test('dentro de cualquier margen: ok (el margen no cuenta)', () {
      expect(check(appointment(), wall(20, 9, 59)), AdminCancelCheck.ok);
    });

    test('en curso: ok', () {
      expect(check(appointment(), wall(20, 10, 30)), AdminCancelCheck.ok);
    });

    test('cancelado, terminado o borrado: notActive', () {
      expect(
        check(appointment(status: 'cancelled')),
        AdminCancelCheck.notActive,
      );
      expect(
        check(appointment(), wall(20, 10, 45)),
        AdminCancelCheck.notActive,
      );
      expect(check(null), AdminCancelCheck.notActive);
    });

    test('otra hora, otro fin u otro servicio: changed', () {
      expect(check(appointment(start: wall(20, 11))), AdminCancelCheck.changed);
      expect(check(appointment(end: wall(20, 11))), AdminCancelCheck.changed);
      expect(check(appointment(booked: pedicura)), AdminCancelCheck.changed);
    });

    test('"ya no está activo" manda sobre "cambió"', () {
      expect(
        check(appointment(status: 'cancelled', start: wall(20, 11))),
        AdminCancelCheck.notActive,
      );
    });
  });

  group('antes de confirmar (plan D-4)', () {
    bool check(AppointmentModel? current, [DateTime? now]) =>
        checkAdminConfirmBeforeSave(
          current: current,
          nowSalon: now ?? wall(20, 9),
        );

    test('esperando y sin terminar: sí, también en curso', () {
      expect(check(appointment()), isTrue);
      expect(check(appointment(), wall(20, 10, 30)), isTrue);
    });

    test('confirmado, cancelado, terminado o borrado: no', () {
      expect(check(appointment(status: 'confirmed')), isFalse);
      expect(check(appointment(status: 'cancelled')), isFalse);
      expect(check(appointment(), wall(20, 10, 45)), isFalse);
      expect(check(null), isFalse);
    });
  });
}
