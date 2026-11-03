/// Un turno ocupado: solo el inicio y el fin de un turno que está esperando
/// confirmación o confirmado, con el mismo id que su turno (spec 005, plan
/// § 2, D-1). Las clientas calculan con ellos las horas libres sin leer los
/// turnos ajenos (RF-53).
class BusySlot {
  const BusySlot({required this.id, required this.start, required this.end});

  final String id;

  /// Instantes.
  final DateTime start;
  final DateTime end;

  /// `null` si le falta el inicio o el fin, o si el fin no es posterior al
  /// inicio.
  static BusySlot? fromMap(Map<String, dynamic> data, String id) {
    final start = data['start'];
    final end = data['end'];
    if (start is! DateTime || end is! DateTime || !end.isAfter(start)) {
      return null;
    }
    return BusySlot(id: id, start: start, end: end);
  }

  Map<String, dynamic> toMap() => {'start': start, 'end': end};
}
