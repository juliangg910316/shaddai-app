import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/repositories/booking_repository.dart';

import '../helpers/fake_booking.dart';

/// El repositorio de turnos falso en lo que añade la edición de la admin
/// (spec 008, T10): se comporta como la transacción de Firestore.
final start = DateTime.utc(2026, 11, 20, 12);
final end = DateTime.utc(2026, 11, 20, 13);

const booked = BookedServiceModel(
  kind: BookedKind.service,
  id: 's1',
  name: BilingualText(es: 'Manicura', pt: 'Manicure'),
  priceCents: 3000,
  durationMinutes: 60,
);

const pedicure = BookedServiceModel(
  kind: BookedKind.service,
  id: 's2',
  name: BilingualText(es: 'Pedicura', pt: 'Pedicure'),
  priceCents: 4000,
  durationMinutes: 60,
);

AppointmentModel appt({String status = 'waiting_confirmation'}) =>
    AppointmentModel(
      id: 't1',
      clientId: 'ana',
      clientName: 'Ana',
      clientPhone: '+55 41 99111-0000',
      clientPhotoUrl: 'ana.png',
      startTime: start,
      endTime: end,
      status: status,
      createdAt: DateTime.utc(2026, 11, 1),
      booked: booked,
    );

void main() {
  late FakeBookingRepository bookings;

  setUp(() {
    bookings = FakeBookingRepository(
      active: [appt()],
      busy: [BusySlot(id: 't1', start: start, end: end)],
    );
  });

  group('watchAppointment', () {
    test(
      'empieza con el turno conocido y cambia con emitAppointment',
      () async {
        final values = <AppointmentModel?>[];
        final sub = bookings.watchAppointment('t1').listen(values.add);
        await Future<void>.delayed(Duration.zero);
        bookings.emitAppointment('t1', appt(status: 'cancelled'));
        bookings.emitAppointment('t1', null);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(values.map((a) => a?.status), [
          'waiting_confirmation',
          'cancelled',
          null,
        ]);
        expect(bookings.appointmentRequests, ['t1']);
      },
    );

    test('un turno que no existe: null', () async {
      expect(await bookings.watchAppointment('nada').first, isNull);
    });
  });

  group('fetchAdminEditCheck', () {
    test('por defecto, el turno, los ocupados y los activos', () async {
      final from = DateTime.utc(2026, 11, 20, 3);
      final to = DateTime.utc(2026, 11, 21, 3);
      final now = DateTime.utc(2026, 11, 10);
      final data = await bookings.fetchAdminEditCheck(
        appointmentId: 't1',
        from: from,
        to: to,
        now: now,
      );
      expect(data.appointment?.id, 't1');
      expect(data.busy, hasLength(1));
      expect(data.active, hasLength(1));
      expect(bookings.adminEditCheckRequests, [
        (appointmentId: 't1', from: from, to: to, now: now),
      ]);
    });

    test('lanza adminEditCheckError', () {
      bookings.adminEditCheckError = Exception('sin red');
      expect(
        bookings.fetchAdminEditCheck(
          appointmentId: 't1',
          from: start,
          to: end,
          now: start,
        ),
        throwsException,
      );
    });
  });

  group('updateAppointmentByAdmin', () {
    final newStart = start.add(const Duration(hours: 2));
    final newEnd = end.add(const Duration(hours: 2));

    test('sin persona: cambia horas, lo reservado y el estado, y conserva lo '
        'demás y su turno ocupado', () async {
      final values = <AppointmentModel?>[];
      bookings.watchAppointment('t1').listen(values.add);

      final ok = await bookings.updateAppointmentByAdmin(
        id: 't1',
        expected: (current) => current?.status == 'waiting_confirmation',
        start: newStart,
        end: newEnd,
        booked: pedicure,
      );
      await Future<void>.delayed(Duration.zero);

      expect(ok, isTrue);
      final saved = bookings.active.single;
      expect(saved.startTime, newStart);
      expect(saved.endTime, newEnd);
      expect(saved.booked, pedicure);
      expect(saved.status, 'confirmed');
      expect(saved.clientId, 'ana');
      expect(saved.clientName, 'Ana');
      expect(saved.clientPhotoUrl, 'ana.png');
      expect(saved.createdByAdmin, isFalse);
      expect(saved.createdAt, DateTime.utc(2026, 11, 1));
      expect(values.last?.startTime, newStart);
      expect(bookings.busy.single.start, newStart);
      expect(bookings.busy.single.end, newEnd);
      final edit = bookings.adminEdits.single;
      expect(edit.id, 't1');
      expect(edit.person, isNull);
    });

    test('con persona: la cambia y lo marca como de la admin', () async {
      await bookings.updateAppointmentByAdmin(
        id: 't1',
        expected: (_) => true,
        start: start,
        end: end,
        booked: booked,
        person: const (
          clientId: null,
          clientName: 'Rosa',
          clientPhone: '41 99333-0000',
          clientPhotoUrl: null,
        ),
      );
      final saved = bookings.active.single;
      expect(saved.clientId, isNull);
      expect(saved.clientName, 'Rosa');
      expect(saved.clientPhone, '41 99333-0000');
      expect(saved.clientPhotoUrl, isNull);
      expect(saved.createdByAdmin, isTrue);
    });

    test('si expected falla, no guarda nada', () async {
      final ok = await bookings.updateAppointmentByAdmin(
        id: 't1',
        expected: (_) => false,
        start: newStart,
        end: newEnd,
        booked: pedicure,
      );
      expect(ok, isFalse);
      expect(bookings.adminEdits, isEmpty);
      expect(bookings.active.single.startTime, start);
      expect(bookings.busy.single.start, start);
    });

    test('sin turno ocupado, lo crea (como `set`)', () async {
      bookings.busy = const [];
      await bookings.updateAppointmentByAdmin(
        id: 't1',
        expected: (_) => true,
        start: newStart,
        end: newEnd,
        booked: booked,
      );
      expect(bookings.busy.single.id, 't1');
      expect(bookings.busy.single.start, newStart);
    });

    test('lanza updateError', () {
      bookings.updateError = Exception('sin red');
      expect(
        bookings.updateAppointmentByAdmin(
          id: 't1',
          expected: (_) => true,
          start: start,
          end: end,
          booked: booked,
        ),
        throwsException,
      );
    });
  });

  test('AppointmentPerson es un registro con la persona', () {
    const AppointmentPerson person = (
      clientId: 'bea',
      clientName: 'Bea',
      clientPhone: '2',
      clientPhotoUrl: null,
    );
    expect(person.clientId, 'bea');
  });
}
