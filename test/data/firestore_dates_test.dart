import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/firestore_dates.dart';

void main() {
  final instant = DateTime.utc(2026, 11, 10, 12, 30);

  test('decodeDates pasa los Timestamp a DateTime, sin tocar lo demás', () {
    final decoded = decodeDates({
      'startTime': Timestamp.fromDate(instant),
      'status': 'confirmed',
      'booked': {'id': 's1'},
    });
    expect(decoded['startTime'], isA<DateTime>());
    expect(
      (decoded['startTime'] as DateTime).isAtSameMomentAs(instant),
      isTrue,
    );
    expect(decoded['status'], 'confirmed');
    expect(decoded['booked'], {'id': 's1'});
  });

  test('decodeDates da la hora local, como Timestamp.toDate', () {
    // Perfil y la lista de la admin muestran hoy la hora del dispositivo:
    // no cambia hasta que pasen a la hora del salón (T11, T16).
    final decoded = decodeDates({'t': Timestamp.fromDate(instant)});
    expect((decoded['t'] as DateTime).isUtc, isFalse);
  });

  test('encodeDates pasa los DateTime a Timestamp', () {
    final encoded = encodeDates({
      'startTime': instant,
      'clientName': 'Ana',
      'clientPhotoUrl': null,
    });
    expect(encoded['startTime'], Timestamp.fromDate(instant));
    expect(encoded['clientName'], 'Ana');
    expect(encoded.containsKey('clientPhotoUrl'), isTrue);
  });

  test('ida y vuelta da el mismo instante', () {
    final back = decodeDates(encodeDates({'t': instant}))['t'] as DateTime;
    expect(back.isAtSameMomentAs(instant), isTrue);
  });
}
