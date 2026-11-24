import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/repositories/agenda_functions.dart';

/// Un `FirebaseFunctions` falso: registra cada llamada (nombre, datos y
/// tiempo máximo) y responde con [respond].
class _FakeFunctions implements FirebaseFunctions {
  _FakeFunctions(this.respond);

  final FutureOr<Object?> Function() respond;
  final calls = <({String name, Object? data, Duration? timeout})>[];

  @override
  HttpsCallable httpsCallable(String name, {HttpsCallableOptions? options}) =>
      _FakeCallable(this, name, options?.timeout);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakeCallable implements HttpsCallable {
  _FakeCallable(this.functions, this.name, this.timeout);

  final _FakeFunctions functions;
  final String name;
  final Duration? timeout;

  @override
  Future<HttpsCallableResult<T>> call<T>([dynamic parameters]) async {
    functions.calls.add((name: name, data: parameters, timeout: timeout));
    return _Result<T>(await functions.respond() as T);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Result<T> implements HttpsCallableResult<T> {
  _Result(this.data);

  @override
  final T data;
}

FirebaseFunctionsException _error(String code, {Object? details}) =>
    FirebaseFunctionsException(message: code, code: code, details: details);

const _mani = BookedServiceModel(
  kind: BookedKind.service,
  id: 'mani',
  name: BilingualText(es: 'Manicura', pt: 'Manicure'),
  priceCents: 3000,
  durationMinutes: 60,
  addons: [
    BookedAddonModel(
      id: 'deco',
      name: BilingualText(es: 'Decoración', pt: 'Decoração'),
      priceCents: 500,
    ),
  ],
);

final _start = DateTime.utc(2026, 11, 24, 13);

final _current = AppointmentModel(
  id: 't1',
  clientId: 'ana',
  clientName: 'Ana',
  clientPhone: '41999990000',
  clientPhotoUrl: 'https://foto/ana',
  startTime: DateTime.utc(2026, 11, 24, 13),
  endTime: DateTime.utc(2026, 11, 24, 14),
  status: 'waiting_confirmation',
  createdAt: DateTime.utc(2026, 11, 20),
  booked: _mani,
);

/// Llamar a las funciones de la agenda desde la app (spec 012, RF-16,
/// RF-17; plan § 3 data).
void main() {
  AgendaFunctions agenda(_FakeFunctions functions, {Duration? timeout}) =>
      AgendaFunctions(
        functions: functions,
        timeout: timeout ?? const Duration(seconds: 15),
      );

  group('los datos de cada llamada', () {
    test(
      'reservar: id, inicio en ISO, servicio, adicionales y lo reservado',
      () async {
        final functions = _FakeFunctions(() => {'id': 't1'});
        final result = await agenda(functions)
            .book(id: 't1', start: _start, booked: _mani);

        expect(result.isOk, isTrue);
        expect(result.id, 't1');
        final call = functions.calls.single;
        expect(call.name, 'bookAppointment');
        expect(call.timeout, const Duration(seconds: 15));
        expect(call.data, {
          'id': 't1',
          'start': '2026-11-24T13:00:00.000Z',
          'item': {'kind': 'service', 'id': 'mani'},
          'addonIds': ['deco'],
          'booked': _mani.toMap(),
        });
      },
    );

    test('el inicio va en UTC aunque llegue en hora local', () async {
      final functions = _FakeFunctions(() => {'id': 't1'});
      await agenda(functions)
          .book(id: 't1', start: _start.toLocal(), booked: _mani);
      expect(
        (functions.calls.single.data! as Map)['start'],
        '2026-11-24T13:00:00.000Z',
      );
    });

    test('la admin: la persona con cuenta o sin ella', () async {
      final functions = _FakeFunctions(() => {'id': 't1'});
      await agenda(functions).book(
        id: 't1',
        start: _start,
        booked: _mani,
        recipient: const AgendaAccountRecipient('bea'),
      );
      await agenda(functions).book(
        id: 't2',
        start: _start,
        booked: _mani,
        recipient: const AgendaGuestRecipient(
          name: 'Carla',
          phone: '41966660000',
        ),
      );
      expect((functions.calls[0].data! as Map)['recipient'], {
        'clientId': 'bea',
      });
      expect((functions.calls[1].data! as Map)['recipient'], {
        'name': 'Carla',
        'phone': '41966660000',
      });
    });

    test('editar: además, lo que tenía el turno al abrir la edición', () async {
      final functions = _FakeFunctions(() => {'id': 't1'});
      await agenda(functions).edit(
        id: 't1',
        start: DateTime.utc(2026, 11, 24, 17),
        booked: _mani,
        expected: _current,
      );
      final call = functions.calls.single;
      expect(call.name, 'editAppointment');
      expect(call.data, {
        'id': 't1',
        'start': '2026-11-24T17:00:00.000Z',
        'item': {'kind': 'service', 'id': 'mani'},
        'addonIds': ['deco'],
        'booked': _mani.toMap(),
        'expected': {
          'startTime': '2026-11-24T13:00:00.000Z',
          'endTime': '2026-11-24T14:00:00.000Z',
          'status': 'waiting_confirmation',
          'booked': _mani.toMap(),
          'clientId': 'ana',
          'clientName': 'Ana',
          'clientPhone': '41999990000',
          'clientPhotoUrl': 'https://foto/ana',
          'createdByAdmin': false,
        },
      });
    });

    test(
      'editar un turno de antes de la spec 005: lo esperado sin copia',
      () async {
        final functions = _FakeFunctions(() => {'id': 't1'});
        final old = AppointmentModel(
          id: 't1',
          clientId: null,
          clientName: 'Carla',
          clientPhone: '41966660000',
          startTime: _current.startTime,
          endTime: _current.endTime,
          status: 'confirmed',
          createdAt: _current.createdAt,
          createdByAdmin: true,
        );
        await agenda(functions).edit(
          id: 't1',
          start: _start,
          booked: _mani,
          expected: old,
          recipient: const AgendaGuestRecipient(
            name: 'Carla',
            phone: '41966660000',
          ),
        );
        final data = functions.calls.single.data! as Map;
        expect((data['expected'] as Map)['booked'], isNull);
        expect((data['expected'] as Map)['clientId'], isNull);
        expect((data['expected'] as Map)['clientPhotoUrl'], isNull);
        expect(data['recipient'], {'name': 'Carla', 'phone': '41966660000'});
      },
    );

    test('cierre: inicio y fin en ISO', () async {
      final functions = _FakeFunctions(() => {'id': 'c1'});
      final result = await agenda(functions).saveClosure(
        start: DateTime.utc(2026, 11, 24, 17),
        end: DateTime.utc(2026, 11, 24, 19),
      );
      expect(result.isOk, isTrue);
      expect(result.id, 'c1');
      expect(functions.calls.single.name, 'saveClosure');
      expect(functions.calls.single.data, {
        'start': '2026-11-24T17:00:00.000Z',
        'end': '2026-11-24T19:00:00.000Z',
      });
    });
  });

  group('los rechazos (RF-16)', () {
    const reasons = {
      'slot_taken': AgendaRejection.slotTaken,
      'closed': AgendaRejection.closed,
      'outside_hours': AgendaRejection.outsideHours,
      'outside_window': AgendaRejection.outsideWindow,
      'past': AgendaRejection.past,
      'does_not_fit': AgendaRejection.doesNotFit,
      'already_active': AgendaRejection.alreadyActive,
      'person_active': AgendaRejection.personActive,
      'recipient_blocked': AgendaRejection.recipientBlocked,
      'item_unavailable': AgendaRejection.itemUnavailable,
      'item_changed': AgendaRejection.itemChanged,
      'not_active': AgendaRejection.notActive,
      'changed': AgendaRejection.changed,
      'not_editable': AgendaRejection.notEditable,
      'blocked': AgendaRejection.blocked,
      'invalid': AgendaRejection.invalid,
    };
    for (final MapEntry(key: reason, value: rejection) in reasons.entries) {
      test('$reason → ${rejection.name}', () async {
        final result = await agenda(
          _FakeFunctions(
            () => throw _error(
              'failed-precondition',
              details: {'reason': reason},
            ),
          ),
        ).book(id: 't1', start: _start, booked: _mani);
        expect(result.isOk, isFalse);
        expect(result.rejection, rejection);
        expect(result.conflictIds, isEmpty);
      });
    }

    test('conflicts lleva los ids de los turnos', () async {
      final result = await agenda(
        _FakeFunctions(
          () => throw _error(
            'failed-precondition',
            details: {
              'reason': 'conflicts',
              'ids': ['a', 'b'],
            },
          ),
        ),
      ).saveClosure(start: _start, end: _start.add(const Duration(hours: 1)));
      expect(result.rejection, AgendaRejection.conflicts);
      expect(result.conflictIds, ['a', 'b']);
    });

    test('sin ficha o sin permiso → notAllowed', () async {
      for (final details in [
        {'reason': 'no_profile'},
        {'reason': 'forbidden'},
        null,
      ]) {
        final result = await agenda(
          _FakeFunctions(
            () => throw _error('permission-denied', details: details),
          ),
        ).book(id: 't1', start: _start, booked: _mani);
        expect(
          result.rejection,
          AgendaRejection.notAllowed,
          reason: '$details',
        );
      }
    });

    test('datos con otra forma → invalid', () async {
      final result = await agenda(
        _FakeFunctions(() => throw _error('invalid-argument')),
      ).book(id: 't1', start: _start, booked: _mani);
      expect(result.rejection, AgendaRejection.invalid);
    });
  });

  group('los fallos (RF-17)', () {
    final failures = <String, Object Function()>{
      'sin conexión': () => _error('unavailable'),
      'error interno': () => _error('internal'),
      'sin sesión': () => _error('unauthenticated'),
      'un motivo desconocido': () =>
          _error('failed-precondition', details: {'reason': 'nuevo'}),
      'sin detalles': () => _error('failed-precondition'),
      'otro error': () => StateError('roto'),
    };
    for (final MapEntry(key: why, value: error) in failures.entries) {
      test('$why → failed', () async {
        final result = await agenda(_FakeFunctions(() => throw error()))
            .book(id: 't1', start: _start, booked: _mani);
        expect(result.rejection, AgendaRejection.failed);
      });
    }

    test('si tarda demasiado → TimeoutException', () async {
      final slow = _FakeFunctions(
        () => Future<Object?>.delayed(const Duration(seconds: 1)),
      );
      await expectLater(
        agenda(
          slow,
          timeout: const Duration(milliseconds: 10),
        ).book(id: 't1', start: _start, booked: _mani),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('el plazo de la función agotado → TimeoutException', () async {
      await expectLater(
        agenda(_FakeFunctions(() => throw _error('deadline-exceeded')))
            .book(id: 't1', start: _start, booked: _mani),
        throwsA(isA<TimeoutException>()),
      );
    });
  });
}
