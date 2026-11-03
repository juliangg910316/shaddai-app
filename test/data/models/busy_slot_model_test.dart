import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';

void main() {
  final start = DateTime.utc(2026, 11, 10, 12);
  final end = DateTime.utc(2026, 11, 10, 13);

  test('solo guarda el inicio y el fin (RF-53)', () {
    expect(BusySlot(id: 'ap1', start: start, end: end).toMap(), {
      'start': start,
      'end': end,
    });
  });

  test('ida y vuelta', () {
    final read = BusySlot.fromMap({'start': start, 'end': end}, 'ap1')!;
    expect(read.id, 'ap1');
    expect(read.start, start);
    expect(read.end, end);
  });

  test('sin inicio o sin fin no se puede leer → null', () {
    expect(BusySlot.fromMap({'start': start}, 'ap1'), isNull);
    expect(BusySlot.fromMap({'end': end}, 'ap1'), isNull);
    expect(BusySlot.fromMap({'start': 'hoy', 'end': end}, 'ap1'), isNull);
  });

  test('un fin no posterior al inicio no se puede leer → null', () {
    expect(BusySlot.fromMap({'start': start, 'end': start}, 'ap1'), isNull);
  });
}
