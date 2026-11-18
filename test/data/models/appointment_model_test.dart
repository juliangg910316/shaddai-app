import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';

void main() {
  final start = DateTime.utc(2026, 11, 10, 12);
  final end = DateTime.utc(2026, 11, 10, 12, 45);
  final created = DateTime.utc(2026, 11, 3, 18);

  const booked = BookedServiceModel(
    kind: BookedKind.service,
    id: 's1',
    name: BilingualText(es: 'Manicura', pt: 'Manicure'),
    priceCents: 3000,
    durationMinutes: 45,
    addons: [
      BookedAddonModel(
        id: 'a1',
        name: BilingualText(es: 'Decoración', pt: 'Decoração'),
        priceCents: 1500,
      ),
    ],
  );

  AppointmentModel appointment({BookedServiceModel? booked}) =>
      AppointmentModel(
        id: 'ap1',
        clientId: 'u1',
        clientName: 'Ana',
        clientPhone: '+55 41 99999-0000',
        clientPhotoUrl: 'https://example.com/ana.png',
        startTime: start,
        endTime: end,
        status: 'waiting_confirmation',
        createdAt: created,
        booked: booked,
      );

  test('ida y vuelta con lo reservado (RF-27)', () {
    final map = appointment(booked: booked).toMap();
    expect(map['startTime'], start);
    expect(map['endTime'], end);
    expect(map['createdAt'], created);
    expect(map['booked'], booked.toMap());

    final read = AppointmentModel.fromMap(map, 'ap1');
    expect(read.id, 'ap1');
    expect(read.clientId, 'u1');
    expect(read.clientName, 'Ana');
    expect(read.clientPhone, '+55 41 99999-0000');
    expect(read.clientPhotoUrl, 'https://example.com/ana.png');
    expect(read.startTime, start);
    expect(read.endTime, end);
    expect(read.createdAt, created);
    expect(read.status, 'waiting_confirmation');
    expect(read.booked!.toMap(), booked.toMap());
  });

  test('un turno sin lo reservado se lee con booked == null (RF-51)', () {
    final map = appointment().toMap();
    expect(map.containsKey('booked'), isFalse);
    expect(AppointmentModel.fromMap(map, 'ap1').booked, isNull);
  });

  test('lo reservado que no se puede leer queda en null', () {
    final map = {...appointment().toMap(), 'booked': 'texto'};
    expect(AppointmentModel.fromMap(map, 'ap1').booked, isNull);
  });

  test('los campos que faltan toman su valor por defecto', () {
    final read = AppointmentModel.fromMap({
      'startTime': start,
      'endTime': end,
    }, 'ap1');
    expect(read.clientId, isNull);
    expect(read.hasAccount, isFalse);
    expect(read.createdByAdmin, isFalse);
    expect(read.clientName, '');
    expect(read.clientPhone, '');
    expect(read.clientPhotoUrl, isNull);
    expect(read.status, 'waiting_confirmation');
    expect(read.createdAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
  });

  group('persona sin cuenta y turno de la admin (spec 007, RF-19)', () {
    test('clientId nulo, vacío o que falta se lee como null', () {
      for (final data in <Map<String, dynamic>>[
        {'clientId': null},
        {'clientId': ''},
        {},
      ]) {
        final read = AppointmentModel.fromMap(data, 'ap1');
        expect(read.clientId, isNull, reason: '$data');
        expect(read.hasAccount, isFalse, reason: '$data');
      }
    });

    test('con clientId tiene cuenta', () {
      final read = AppointmentModel.fromMap({'clientId': 'u1'}, 'ap1');
      expect(read.clientId, 'u1');
      expect(read.hasAccount, isTrue);
    });

    test('createdByAdmin se lee; si falta o no es bool, false', () {
      expect(
        AppointmentModel.fromMap({
          'createdByAdmin': true,
        }, 'ap1').createdByAdmin,
        isTrue,
      );
      expect(
        AppointmentModel.fromMap({
          'createdByAdmin': 'sí',
        }, 'ap1').createdByAdmin,
        isFalse,
      );
      expect(appointment().createdByAdmin, isFalse);
    });

    test('toMap escribe clientId null de forma explícita y createdByAdmin', () {
      final guest = AppointmentModel(
        id: 'ap2',
        clientId: null,
        clientName: 'Rosa',
        clientPhone: '41 99999-1111',
        startTime: start,
        endTime: end,
        status: 'confirmed',
        createdAt: created,
        createdByAdmin: true,
        booked: booked,
      );
      final map = guest.toMap();
      expect(map.containsKey('clientId'), isTrue);
      expect(map['clientId'], isNull);
      expect(map['createdByAdmin'], isTrue);
      expect(map['clientPhotoUrl'], isNull);

      final read = AppointmentModel.fromMap(map, 'ap2');
      expect(read.hasAccount, isFalse);
      expect(read.createdByAdmin, isTrue);
      expect(read.clientName, 'Rosa');
      expect(read.status, 'confirmed');
    });

    test('el turno de la clienta escribe createdByAdmin: false', () {
      expect(appointment().toMap()['createdByAdmin'], isFalse);
    });
  });

  group('quién canceló y cuenta eliminada (spec 009, D-1, D-2)', () {
    test("cancelledBy: 'client' se lee como cancelado por la clienta", () {
      final read = AppointmentModel.fromMap({
        'status': 'cancelled',
        'cancelledBy': 'client',
      }, 'ap1');
      expect(read.cancelledByClient, isTrue);
    });

    test('sin cancelledBy o con otro valor, lo canceló el salón (RF-20)', () {
      for (final data in <Map<String, dynamic>>[
        {'status': 'cancelled'},
        {'status': 'cancelled', 'cancelledBy': null},
        {'status': 'cancelled', 'cancelledBy': 'admin'},
        {'status': 'cancelled', 'cancelledBy': true},
      ]) {
        expect(
          AppointmentModel.fromMap(data, 'ap1').cancelledByClient,
          isFalse,
          reason: '$data',
        );
      }
    });

    test('accountDeleted se lee; si falta o no es true, false (RF-35)', () {
      expect(
        AppointmentModel.fromMap({
          'accountDeleted': true,
        }, 'ap1').accountDeleted,
        isTrue,
      );
      for (final data in <Map<String, dynamic>>[
        {},
        {'accountDeleted': false},
        {'accountDeleted': 'sí'},
      ]) {
        expect(
          AppointmentModel.fromMap(data, 'ap1').accountDeleted,
          isFalse,
          reason: '$data',
        );
      }
    });

    test('un turno de una cuenta eliminada conserva nombre y WhatsApp', () {
      final read = AppointmentModel.fromMap({
        'clientId': 'u1',
        'clientName': 'Ana',
        'clientPhone': '41 99999-0000',
        'clientPhotoUrl': null,
        'accountDeleted': true,
        'status': 'cancelled',
        'cancelledBy': 'client',
      }, 'ap1');
      expect(read.clientName, 'Ana');
      expect(read.clientPhone, '41 99999-0000');
      expect(read.clientPhotoUrl, isNull);
      expect(read.hasAccount, isTrue);
      expect(read.accountDeleted, isTrue);
      expect(read.cancelledByClient, isTrue);
    });

    test('toMap no escribe cancelledBy ni accountDeleted', () {
      final map = AppointmentModel(
        id: 'ap1',
        clientId: 'u1',
        clientName: 'Ana',
        clientPhone: '41 99999-0000',
        startTime: start,
        endTime: end,
        status: 'cancelled',
        createdAt: created,
        cancelledByClient: true,
        accountDeleted: true,
      ).toMap();
      expect(map.containsKey('cancelledBy'), isFalse);
      expect(map.containsKey('accountDeleted'), isFalse);
    });

    test('un turno nuevo no está cancelado por la clienta ni eliminado', () {
      expect(appointment().cancelledByClient, isFalse);
      expect(appointment().accountDeleted, isFalse);
    });

    test('un turno antiguo sin lo reservado sigue leyéndose (RF-44)', () {
      final read = AppointmentModel.fromMap({
        'clientId': 'u1',
        'startTime': start,
        'endTime': end,
        'status': 'confirmed',
      }, 'ap1');
      expect(read.booked, isNull);
      expect(read.cancelledByClient, isFalse);
      expect(read.accountDeleted, isFalse);
    });
  });

  test('el modelo no importa Firebase (plan, D-6)', () {
    final source = File('lib/data/models/appointment_model.dart')
        .readAsStringSync();
    expect(source, isNot(contains('cloud_firestore')));
  });
}
