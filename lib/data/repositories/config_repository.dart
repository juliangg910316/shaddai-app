import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_dates.dart';
import '../models/calendar_settings_model.dart';
import '../models/closure_model.dart';

/// El calendario del salón (`settings/calendar`) y sus cierres (`closures`,
/// spec 008, plan § 2, D-9).
class ConfigRepository {
  final FirebaseFirestore _firestore;

  /// Tiempo máximo para guardar o borrar, como los turnos.
  final Duration saveTimeout;

  ConfigRepository({
    FirebaseFirestore? firestore,
    this.saveTimeout = const Duration(seconds: 15),
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  DocumentReference<Map<String, dynamic>> get _calendar =>
      _firestore.collection('settings').doc('calendar');

  CollectionReference<Map<String, dynamic>> get _closures =>
      _firestore.collection('closures');

  Stream<CalendarSettingsModel> getCalendarSettings() {
    return _calendar.snapshots().map((doc) {
      if (doc.exists && doc.data() != null) {
        return CalendarSettingsModel.fromMap(doc.data()!);
      }
      // Sin documento, el horario por defecto.
      return CalendarSettingsModel.defaultSettings();
    });
  }

  /// Guarda el horario semanal. Con `merge`, no toca el margen ni las fechas
  /// bloqueadas, que `toMap` no escribe (spec 008, RF-41, D-6).
  Future<void> updateSettings(CalendarSettingsModel settings) async {
    await _calendar.set(settings.toMap(), SetOptions(merge: true));
  }

  /// Guarda solo el margen de edición, como entero (spec 008, RF-38).
  Future<void> updateEditMargin(int minutes) => _calendar
      .set({'editMarginMinutes': minutes}, SetOptions(merge: true))
      .timeout(saveTimeout);

  /// Quita la fecha bloqueada existente [key] (`yyyy-MM-dd`), sin tocar las
  /// demás (spec 008, RF-8).
  Future<void> removeBlockedDate(String key) => _calendar
      .update({
        'blockedDates': FieldValue.arrayRemove([key]),
      })
      .timeout(saveTimeout);

  Query<Map<String, dynamic>> _endingFrom(DateTime from) =>
      _closures.where('end', isGreaterThanOrEqualTo: Timestamp.fromDate(from));

  static List<ClosureModel> _read(QuerySnapshot<Map<String, dynamic>> s) => [
    for (final doc in s.docs)
      ?ClosureModel.fromMap(decodeDates(doc.data()), doc.id),
  ];

  /// Los cierres que terminan en [from] o después, en vivo (spec 008, RF-1,
  /// RF-9, RF-12, RF-15). Un solo campo filtrado: sin índice compuesto.
  Stream<List<ClosureModel>> watchClosures(DateTime from) =>
      _endingFrom(from).snapshots().map(_read);

  /// Lee **del servidor** los cierres que terminan en [from] o después, para
  /// comprobar un turno antes de guardarlo (spec 008, RF-12). Sin conexión
  /// falla, en lugar de responder con la caché.
  Future<List<ClosureModel>> fetchClosures(DateTime from) async => _read(
    await _endingFrom(from).get(const GetOptions(source: Source.server)),
  );

  /// Guarda el cierre [closure] con su id (spec 008, RF-6).
  Future<void> createClosure(ClosureModel closure) => _closures
      .doc(closure.id)
      .set(encodeDates(closure.toMap()))
      .timeout(saveTimeout);

  /// Borra el cierre [id] (spec 008, RF-7).
  Future<void> deleteClosure(String id) =>
      _closures.doc(id).delete().timeout(saveTimeout);
}
