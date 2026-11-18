import 'package:cloud_firestore/cloud_firestore.dart';

import '../firestore_dates.dart';
import '../models/appointment_model.dart';
import '../models/booked_service_model.dart';
import '../models/busy_slot_model.dart';

/// Lo que se lee del servidor justo antes de guardar un turno (spec 005,
/// RF-26): los turnos ocupados de ese día y los turnos de la clienta.
typedef BookingCheckData = ({List<BusySlot> busy, List<AppointmentModel> mine});

/// Lo que se lee del servidor justo antes de guardar la edición de un turno
/// (spec 006, RF-12): el turno tal como está ahora (`null` si ya no existe) y
/// los turnos ocupados del día nuevo.
typedef EditCheckData = ({AppointmentModel? appointment, List<BusySlot> busy});

/// Lo que se lee del servidor justo antes de guardar el turno que agenda la
/// admin (spec 007, RF-18): los turnos ocupados de ese día y los turnos que
/// aún no terminaron, de cualquier persona.
typedef AdminCheckData = ({List<BusySlot> busy, List<AppointmentModel> active});

/// Lo que se lee del servidor justo antes de guardar la edición de la admin
/// (spec 008, RF-28): el turno tal como está ahora (`null` si ya no existe),
/// los turnos ocupados del día nuevo y los turnos que aún no terminaron.
typedef AdminEditCheckData = ({
  AppointmentModel? appointment,
  List<BusySlot> busy,
  List<AppointmentModel> active,
});

/// La persona a cuyo nombre queda un turno. `clientId` es `null` para una
/// persona sin cuenta (spec 007).
typedef AppointmentPerson = ({
  String? clientId,
  String clientName,
  String clientPhone,
  String? clientPhotoUrl,
});

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

  /// Lee **del servidor** el turno [appointmentId] y los turnos ocupados que
  /// empiezan entre [from] y [to], para comprobar la edición antes de
  /// guardarla (spec 006, RF-12). Sin conexión falla, como
  /// [fetchBookingCheck].
  Future<EditCheckData> fetchEditCheck({
    required String appointmentId,
    required DateTime from,
    required DateTime to,
  }) async {
    const server = GetOptions(source: Source.server);
    final results = await Future.wait([
      _appointments.doc(appointmentId).get(server),
      _busySlots
          .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('start', isLessThan: Timestamp.fromDate(to))
          .get(server),
    ]);
    final doc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    return (
      appointment: doc.exists ? _appointment(doc) : null,
      busy: _slots(results[1] as QuerySnapshot<Map<String, dynamic>>),
    );
  }

  /// Guarda la edición del turno [id] en una transacción (spec 006, plan
  /// D-5): vuelve a leer el turno y, solo si [expected] lo da por bueno,
  /// cambia su inicio, su fin y lo reservado, lo deja esperando confirmación
  /// (RF-13) y cambia a la vez su turno ocupado (RF-26).
  ///
  /// Devuelve `false` si el turno ya no es el esperado. Si no termina en
  /// [saveTimeout], lanza `TimeoutException` (RF-16).
  Future<bool> updateEditedAppointment({
    required String id,
    required bool Function(AppointmentModel? current) expected,
    required DateTime start,
    required DateTime end,
    required BookedServiceModel booked,
  }) {
    final appointmentRef = _appointments.doc(id);
    return _firestore
        .runTransaction<bool>((transaction) async {
          final doc = await transaction.get(appointmentRef);
          if (!expected(doc.exists ? _appointment(doc) : null)) return false;
          transaction
            ..update(
              appointmentRef,
              encodeDates({
                'startTime': start,
                'endTime': end,
                'booked': booked.toMap(),
                'status': 'waiting_confirmation',
              }),
            )
            ..update(
              _busySlots.doc(id),
              encodeDates({'start': start, 'end': end}),
            );
          return true;
        })
        .timeout(saveTimeout);
  }

  /// El turno [id] en vivo, o `null` si no existe (spec 008, RF-19, RF-30).
  /// Lo lee la edición de la admin, también al abrirla desde su dirección en
  /// Web.
  Stream<AppointmentModel?> watchAppointment(String id) => _appointments
      .doc(id)
      .snapshots()
      .map((doc) => doc.exists ? _appointment(doc) : null);

  /// Lee **del servidor** el turno [appointmentId], los turnos ocupados que
  /// empiezan entre [from] y [to] y los que terminan en [now] o después, para
  /// comprobar la edición de la admin antes de guardarla (spec 008, RF-28).
  /// Sin conexión falla, como [fetchBookingCheck].
  Future<AdminEditCheckData> fetchAdminEditCheck({
    required String appointmentId,
    required DateTime from,
    required DateTime to,
    required DateTime now,
  }) async {
    const server = GetOptions(source: Source.server);
    final results = await Future.wait<Object>([
      _appointments.doc(appointmentId).get(server),
      _busySlots
          .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('start', isLessThan: Timestamp.fromDate(to))
          .get(server),
      _endingFrom(now).get(server),
    ]);
    final doc = results[0] as DocumentSnapshot<Map<String, dynamic>>;
    final active = results[2] as QuerySnapshot<Map<String, dynamic>>;
    return (
      appointment: doc.exists ? _appointment(doc) : null,
      busy: _slots(results[1] as QuerySnapshot<Map<String, dynamic>>),
      active: [for (final doc in active.docs) _appointment(doc)],
    );
  }

  /// Guarda la edición de la admin del turno [id] en una transacción (spec
  /// 008, RF-28, plan § 2): vuelve a leer el turno y, solo si [expected] lo da
  /// por bueno, cambia su inicio, su fin y lo reservado, lo deja confirmado
  /// y escribe a la vez su turno ocupado con `set` (plan D-8).
  ///
  /// Con [person], cambia la persona y marca el turno como de la admin
  /// (RF-31); sin ella, la persona y la marca no se tocan. Devuelve `false`
  /// si el turno ya no es el esperado. Si no termina en [saveTimeout], lanza
  /// `TimeoutException`.
  Future<bool> updateAppointmentByAdmin({
    required String id,
    required bool Function(AppointmentModel? current) expected,
    required DateTime start,
    required DateTime end,
    required BookedServiceModel booked,
    AppointmentPerson? person,
  }) {
    final appointmentRef = _appointments.doc(id);
    return _firestore
        .runTransaction<bool>((transaction) async {
          final doc = await transaction.get(appointmentRef);
          if (!expected(doc.exists ? _appointment(doc) : null)) return false;
          transaction
            ..update(
              appointmentRef,
              encodeDates({
                'startTime': start,
                'endTime': end,
                'booked': booked.toMap(),
                'status': 'confirmed',
                if (person != null) ...{
                  // `null` escrito a propósito para una persona sin cuenta.
                  'clientId': person.clientId,
                  'clientName': person.clientName,
                  'clientPhone': person.clientPhone,
                  'clientPhotoUrl': person.clientPhotoUrl,
                  'createdByAdmin': true,
                },
              }),
            )
            ..set(
              _busySlots.doc(id),
              encodeDates(BusySlot(id: id, start: start, end: end).toMap()),
            );
          return true;
        })
        .timeout(saveTimeout);
  }

  /// La clienta cancela su turno [id] en una transacción (spec 009, RF-11,
  /// RF-14, plan D-3): vuelve a leer el turno y, solo si [expected] lo da por
  /// bueno, lo deja cancelado por ella (`cancelledBy: 'client'`) y borra a la
  /// vez su turno ocupado, para que la hora quede libre (RF-13). Las reglas
  /// exigen las dos cosas juntas.
  ///
  /// [expected] recibe el turno releído (`null` si ya no existe), así quien
  /// llama sabe también por qué no se canceló. Devuelve `false` si no lo da
  /// por bueno. Si no termina en [saveTimeout], lanza `TimeoutException`
  /// (RF-15).
  Future<bool> cancelByClient({
    required String id,
    required bool Function(AppointmentModel? current) expected,
  }) {
    final appointmentRef = _appointments.doc(id);
    return _firestore
        .runTransaction<bool>((transaction) async {
          final doc = await transaction.get(appointmentRef);
          if (!expected(doc.exists ? _appointment(doc) : null)) return false;
          transaction
            ..update(appointmentRef, {
              'status': 'cancelled',
              'cancelledBy': 'client',
            })
            ..delete(_busySlots.doc(id));
          return true;
        })
        .timeout(saveTimeout);
  }

  Query<Map<String, dynamic>> _endingFrom(DateTime now) => _appointments.where(
    'endTime',
    isGreaterThanOrEqualTo: Timestamp.fromDate(now),
  );

  /// Los turnos que terminan en [now] o después, de cualquier persona, en
  /// vivo. Solo los lee la admin, para el turno activo de una persona (spec
  /// 007, RF-14). Un solo campo filtrado: no necesita índice compuesto.
  Stream<List<AppointmentModel>> watchActiveAppointments(DateTime now) =>
      _endingFrom(now)
          .snapshots()
          .map((snapshot) => snapshot.docs.map(_appointment).toList());

  /// Lee **del servidor** los turnos que terminan en [now] o después, de
  /// cualquier persona, para buscar los que chocan con un cierre justo antes
  /// de guardarlo (spec 008, RF-5, RF-6). Sin conexión falla.
  Future<List<AppointmentModel>> fetchActiveAppointments(DateTime now) async {
    final snapshot = await _endingFrom(now)
        .get(const GetOptions(source: Source.server));
    return snapshot.docs.map(_appointment).toList();
  }

  /// Lee **del servidor** los turnos ocupados que empiezan entre [from] y
  /// [to] y los turnos que terminan en [now] o después, para comprobar el
  /// turno de la admin antes de guardarlo (spec 007, RF-18). Sin conexión
  /// falla, como [fetchBookingCheck].
  Future<AdminCheckData> fetchAdminBookingCheck({
    required DateTime from,
    required DateTime to,
    required DateTime now,
  }) async {
    const server = GetOptions(source: Source.server);
    final results = await Future.wait([
      _busySlots
          .where('start', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
          .where('start', isLessThan: Timestamp.fromDate(to))
          .get(server),
      _endingFrom(now).get(server),
    ]);
    return (
      busy: _slots(results[0]),
      active: [for (final doc in results[1].docs) _appointment(doc)],
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
