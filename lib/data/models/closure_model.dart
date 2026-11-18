/// Un cierre de la agenda (`closures/{uuid}`, spec 008, plan § 2): un tiempo
/// concreto en el que el salón no atiende. Solo guarda su inicio y su fin
/// (RF-42), porque lo leen todas las personas con sesión para calcular las
/// horas libres. Las fechas son `DateTime`: el repositorio las convierte desde
/// y hacia `Timestamp`, como en los turnos.
class ClosureModel {
  const ClosureModel({
    required this.id,
    required this.start,
    required this.end,
  });

  final String id;

  /// Instantes: de [start] hasta antes de [end].
  final DateTime start;
  final DateTime end;

  /// `null` si le falta el inicio o el fin, o si el fin no es posterior al
  /// inicio (constitución, principio 5).
  static ClosureModel? fromMap(Map<String, dynamic> data, String id) {
    final start = data['start'];
    final end = data['end'];
    if (start is! DateTime || end is! DateTime || !end.isAfter(start)) {
      return null;
    }
    return ClosureModel(id: id, start: start, end: end);
  }

  Map<String, dynamic> toMap() => {'start': start, 'end': end};

  /// El cierre como lo recibe la lógica (`StoredClosure` de `closures.dart`).
  ({String id, DateTime start, DateTime end}) get stored =>
      (id: id, start: start, end: end);
}
