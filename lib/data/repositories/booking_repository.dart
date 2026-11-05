import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_dates.dart';
import '../models/appointment_model.dart';
import '../models/busy_slot_model.dart';

/// Lo que se lee del servidor justo antes de guardar un turno (spec 005,
/// RF-26): los turnos ocupados de ese día y los turnos de la clienta.
typedef BookingCheckData = ({List<BusySlot> busy, List<AppointmentModel> mine});

/// Turnos (`appointments`) y turnos ocupados (`busySlots`, spec 005, plan
/// § 2). Un turno y su turno ocupado se escriben siempre juntos.
class BookingRepository {
  final FirebaseFirestore _firestore;

  /// Tiempo máximo para guardar un turno (plan, D-8).
  final Duration saveTimeout;

  BookingRepository({
    FirebaseFirestore? firestore,
    this.saveTimeout = const Duration(seconds: 15),
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _appointments =>
      _firestore.collection('appointments');

  CollectionReference<Map<String, dynamic>> get _busySlots =>
      _firestore.collection('busySlots');

  static AppointmentModel _appointment(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) => AppointmentModel.fromMap(decodeDates(doc.data() ?? const {}), doc.id);

  static List<BusySlot> _slots(QuerySnapshot<Map<String, dynamic>> snapshot) =>
      [
        for (final doc in snapshot.docs)
          ?BusySlot.fromMap(decodeDates(doc.data()), doc.id),
      ];

  /// Guarda [appointment] y su turno ocupado en un solo lote (RF-27; las
  /// reglas exigen los dos juntos). Si no termina en [saveTimeout], lanza
  /// `TimeoutException` (RF-31).
  Future<void> createAppointment(AppointmentModel appointment) {
    final batch = _firestore.batch()
      ..set(_appointments.doc(appointment.id), encodeDates(appointment.toMap()))
      ..set(
        _busySlots.doc(appointment.id),
        encodeDates(
          BusySlot(
            id: appointment.id,
            start: appointment.startTime,
            end: appointment.endTime,
          ).toMap(),
        ),
      );
    return batch.commit().timeout(saveTimeout);
  }

  /// Los turnos ocupados que empiezan entre [from] (incluido) y [to]
  /// (excluido), en vivo (RF-6).
  Stream<List<BusySlot>> watchBusySlots(DateTime from, DateTime to) =>
      _busySlots
          .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('start', isLessThan: Timestamp.fromDate(to))
          .snapshots()
          .map(_slots);

  /// Lee **del servidor** los turnos ocupados que empiezan entre [from] y
  /// [to] y los turnos de [clientId], para comprobarlos antes de guardar
  /// (RF-26). Sin conexión falla, en lugar de responder con la caché (plan,
  /// D-4).
  Future<BookingCheckData> fetchBookingCheck({
    required String clientId,
    required DateTime from,
    required DateTime to,
  }) async {
    const server = GetOptions(source: Source.server);
    final results = await Future.wait([
      _busySlots
          .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('start', isLessThan: Timestamp.fromDate(to))
          .get(server),
      _appointments.where('clientId', isEqualTo: clientId).get(server),
    ]);
    return (
      busy: _slots(results[0]),
      mine: [for (final doc in results[1].docs) _appointment(doc)],
    );
  }

  Stream<List<AppointmentModel>> getAppointmentsForDate(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    final end = start.add(const Duration(days: 1));

    return _appointments
        .where('startTime', isGreaterThanOrEqualTo: Timestamp.fromDate(start))
        .where('startTime', isLessThan: Timestamp.fromDate(end))
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_appointment).toList());
  }

  Stream<List<AppointmentModel>> getClientAppointments(String clientId) {
    return _appointments
        .where('clientId', isEqualTo: clientId)
        .orderBy('startTime', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs.map(_appointment).toList());
  }

  // ADMIN METHODS

  /// Cambia el estado del turno [id]. Al cancelarlo, borra en el mismo lote
  /// su turno ocupado: la hora vuelve a quedar libre (spec 005, plan § 2).
  Future<void> updateAppointmentStatus(String id, String status) async {
    if (status != 'cancelled') {
      await _appointments.doc(id).update({'status': status});
      return;
    }
    final batch = _firestore.batch()
      ..update(_appointments.doc(id), {'status': status})
      ..delete(_busySlots.doc(id));
    await batch.commit();
  }
}
