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
    expect(read.clientId, '');
    expect(read.clientName, '');
    expect(read.clientPhone, '');
    expect(read.clientPhotoUrl, isNull);
    expect(read.status, 'waiting_confirmation');
    expect(read.createdAt, DateTime.fromMillisecondsSinceEpoch(0, isUtc: true));
  });

  test('el modelo no importa Firebase (plan, D-6)', () {
    final source = File('lib/data/models/appointment_model.dart')
        .readAsStringSync();
    expect(source, isNot(contains('cloud_firestore')));
  });
}
