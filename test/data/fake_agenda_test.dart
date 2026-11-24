import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/data/repositories/agenda_functions.dart';

import '../helpers/fake_agenda.dart';
import '../helpers/fake_booking.dart';
import '../helpers/fake_config.dart';
import '../helpers/fake_session.dart';

const _mani = BookedServiceModel(
  kind: BookedKind.service,
  id: 'mani',
  name: BilingualText(es: 'Manicura', pt: 'Manicure'),
  priceCents: 3000,
  durationMinutes: 60,
);

final _admin = UserModel(
  uid: 'admin',
  email: 'admin@example.com',
  displayName: 'Beidis',
  role: 'admin',
);

final _bea = UserModel(
  uid: 'bea',
  email: 'bea@example.com',
  displayName: 'Bea',
  phoneNumber: '41888880000',
);

/// El doble de las funciones de la agenda que usan los tests de pantalla
/// (spec 012, T6): guarda lo que escribiría la función y puede rechazar.
void main() {
  final start = DateTime.utc(2026, 11, 24, 13);
  final now = DateTime.utc(2026, 11, 23, 13);

  test('la clienta: a su nombre, esperando confirmación', () async {
    final booking = FakeBookingRepository();
    final agenda = FakeAgendaFunctions(
      booking: booking,
      caller: testClient,
      clock: () => now,
    );
    final result = await agenda.book(id: 't1', start: start, booked: _mani);

    expect(result.isOk, isTrue);
    final saved = booking.created.single;
    expect(saved.clientId, testClient.uid);
    expect(saved.clientName, testClient.displayName);
    expect(saved.clientPhone, testClient.phoneNumber);
    expect(saved.status, 'waiting_confirmation');
    expect(saved.createdByAdmin, isFalse);
    expect(saved.endTime, start.add(const Duration(hours: 1)));
    expect(saved.createdAt, now);
    expect(booking.mine.single.id, 't1');
  });

  test('la admin: confirmado y marcado, para la persona elegida', () async {
    final booking = FakeBookingRepository();
    final agenda = FakeAgendaFunctions(
      booking: booking,
      caller: _admin,
      users: {'bea': _bea},
    );
    await agenda.book(
      id: 't1',
      start: start,
      booked: _mani,
      recipient: const AgendaAccountRecipient('bea'),
    );
    await agenda.book(
      id: 't2',
      start: start,
      booked: _mani,
      recipient: const AgendaGuestRecipient(name: ' Carla ', phone: '419'),
    );
    final [first, second] = booking.created;
    expect(
      (first.clientId, first.clientName, first.status),
      ('bea', 'Bea', 'confirmed'),
    );
    expect(first.createdByAdmin, isTrue);
    expect((second.clientId, second.clientName), (null, 'Carla'));
  });

  test('editar: la clienta en su turno; si cambió, changed', () async {
    final original = testAppointment(start, status: 'waiting_confirmation');
    final booking = FakeBookingRepository(mine: [original]);
    final agenda = FakeAgendaFunctions(booking: booking, caller: testClient);
    final later = start.add(const Duration(hours: 2));

    final ok = await agenda.edit(
      id: original.id,
      start: later,
      booked: _mani,
      expected: original,
    );
    expect(ok.isOk, isTrue);
    expect(booking.mine.single.startTime, later);

    final stale = await agenda.edit(
      id: original.id,
      start: start,
      booked: _mani,
      expected: original,
    );
    expect(stale.rejection, AgendaRejection.changed);
  });

  test('cierre: lo guarda en la configuración', () async {
    final config = FakeConfigRepository();
    final agenda = FakeAgendaFunctions(config: config);
    final result = await agenda.saveClosure(
      start: start,
      end: start.add(const Duration(hours: 2)),
    );
    expect(result.isOk, isTrue);
    expect(config.created.single.start, start);
  });

  test('con un rechazo: lo devuelve y no guarda nada', () async {
    final booking = FakeBookingRepository();
    final config = FakeConfigRepository();
    final agenda =
        FakeAgendaFunctions(booking: booking, config: config, caller: _admin)
          ..rejection = AgendaRejection.conflicts
          ..conflictIds = ['t9'];

    final closure = await agenda.saveClosure(start: start, end: start);
    expect(closure.rejection, AgendaRejection.conflicts);
    expect(closure.conflictIds, ['t9']);
    expect(config.created, isEmpty);

    agenda.rejection = AgendaRejection.slotTaken;
    final booked = await agenda.book(id: 't1', start: start, booked: _mani);
    expect(booked.rejection, AgendaRejection.slotTaken);
    expect(booking.created, isEmpty);
    expect(agenda.books.single.id, 't1');
  });

  test('sin repositorios, solo registra y responde que sí', () async {
    final agenda = FakeAgendaFunctions();
    expect(
      (await agenda.book(id: 't1', start: start, booked: _mani)).isOk,
      isTrue,
    );
    expect(agenda.books, hasLength(1));
  });
}
