import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/closure_model.dart';

/// Un cierre de la agenda (spec 008, RF-42; plan § 2).
void main() {
  final start = DateTime.utc(2026, 11, 24, 16);
  final end = DateTime.utc(2026, 11, 24, 17, 30);

  test('solo guarda el inicio y el fin (RF-42)', () {
    expect(ClosureModel(id: 'c1', start: start, end: end).toMap(), {
      'start': start,
      'end': end,
    });
  });

  test('ida y vuelta', () {
    final read = ClosureModel.fromMap({'start': start, 'end': end}, 'c1')!;
    expect(read.id, 'c1');
    expect(read.start, start);
    expect(read.end, end);
  });

  test('ignora los campos que no conoce', () {
    final read = ClosureModel.fromMap({
      'start': start,
      'end': end,
      'motivo': 'médico',
    }, 'c1');
    expect(read, isNotNull);
  });

  test('sin inicio o sin fin, o con otro tipo, no se puede leer → null', () {
    expect(ClosureModel.fromMap({'start': start}, 'c1'), isNull);
    expect(ClosureModel.fromMap({'end': end}, 'c1'), isNull);
    expect(ClosureModel.fromMap({'start': 'hoy', 'end': end}, 'c1'), isNull);
  });

  test('un fin no posterior al inicio no se puede leer → null', () {
    expect(ClosureModel.fromMap({'start': start, 'end': start}, 'c1'), isNull);
    expect(ClosureModel.fromMap({'start': end, 'end': start}, 'c1'), isNull);
  });

  test('como cierre guardado para la lógica (`StoredClosure`)', () {
    final closure = ClosureModel(id: 'c1', start: start, end: end);
    expect(closure.stored, (id: 'c1', start: start, end: end));
  });
}
