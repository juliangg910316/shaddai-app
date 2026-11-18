import 'dart:async';

import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/repositories/booking_repository.dart';

/// Turnos y turnos ocupados en memoria, sin Firebase (spec 005, plan § 9).
///
/// [busy] y [mine] llegan en vivo: [emitBusy] y [emitMine] los cambian y los
/// envían a quien escucha; [failBusy] y [failMine] envían un error. La
/// comprobación previa devuelve [checkData] (por defecto, lo que hay en
/// [busy] y [mine]) o lanza [checkError]; el guardado lanza [saveError] o
/// guarda en [created] y lo envía como uno más de [mine].
///
/// La edición (spec 006): la comprobación previa devuelve [editCheckData]
/// (por defecto, el turno de [mine] con ese id y [busy]) o lanza
/// [editCheckError]. El guardado lanza [updateError]; si no, como la
/// transacción de Firestore, aplica `expected` al turno de [mine] y, si lo da
/// por bueno, lo cambia (esperando confirmación) junto a su turno ocupado de
/// [busy], los envía a quien escucha y lo registra en [edited].
///
/// La reserva de la admin (spec 007): [active] son los turnos que aún no
/// terminaron, en vivo ([emitActive], [failActive]); la comprobación previa
/// devuelve [adminCheckData] (por defecto, [busy] y [active]) o lanza
/// [adminCheckError]. Un turno guardado llega también a [active].
///
/// Los cierres (spec 008): [fetchActiveAppointments] devuelve [active] o
/// lanza [activeFetchError], y registra cada "ahora" en [activeFetches].
///
/// La edición de la admin (spec 008): [watchAppointment] empieza con el
/// turno de ese id en [active], [mine] o [created], y cambia con
/// [emitAppointment]. La comprobación previa devuelve [adminEditCheckData]
/// (por defecto, ese turno, [busy] y [active]) o lanza
/// [adminEditCheckError]. El guardado lanza [updateError]; si no, como la
/// transacción, aplica `expected` y, si vale, cambia el turno (confirmado)
/// en [active], [mine] y a quien lo escucha, escribe su turno ocupado de
/// [busy] y lo registra en [adminEdits].
///
/// La cancelación de la clienta (spec 009): [cancelByClient] lanza
/// [cancelError]; si no, como la transacción, aplica `expected` al turno de
/// ese id y, si vale, lo deja cancelado por la clienta en [mine], [active] y
/// a quien lo escucha, quita su turno ocupado de [busy] y lo registra en
/// [cancelled].
class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({
    this.busy = const [],
    this.mine = const [],
    this.active = const [],
  });

  /// Lo que reciben las escuchas al empezar y la comprobación previa.
  List<BusySlot> busy;
  List<AppointmentModel> mine;
  List<AppointmentModel> active;

  final _busyListeners = <StreamController<List<BusySlot>>>[];
  final _mineListeners = <StreamController<List<AppointmentModel>>>[];
  final _activeListeners = <StreamController<List<AppointmentModel>>>[];

  /// Instantes pedidos a [watchActiveAppointments], en orden.
  final activeRequests = <DateTime>[];

  /// Instantes pedidos a [fetchActiveAppointments], en orden.
  final activeFetches = <DateTime>[];
  Object? activeFetchError;

  AdminCheckData? adminCheckData;
  Object? adminCheckError;
  final adminCheckRequests = <({DateTime from, DateTime to, DateTime now})>[];

  /// Ventanas pedidas a [watchBusySlots], en orden.
  final busyWindows = <({DateTime from, DateTime to})>[];

  /// Clientas pedidas a [getClientAppointments], en orden.
  final clientRequests = <String>[];

  BookingCheckData? checkData;
  Object? checkError;
  final checkRequests = <({String clientId, DateTime from, DateTime to})>[];

  Object? saveError;
  final created = <AppointmentModel>[];

  final statusChanges = <({String id, String status})>[];

  EditCheckData? editCheckData;
  Object? editCheckError;
  final editCheckRequests =
      <({String appointmentId, DateTime from, DateTime to})>[];

  Object? updateError;

  final _appointmentListeners =
      <({String id, StreamController<AppointmentModel?> controller})>[];
  final _appointments = <String, AppointmentModel?>{};

  /// Turnos pedidos a [watchAppointment], en orden.
  final appointmentRequests = <String>[];

  /// Espera, tras enviar el turno guardado y antes de terminar el guardado:
  /// como Firestore, el turno puede llegar a quien escucha antes de que
  /// termine la transacción.
  Duration? adminEditLatency;

  AdminEditCheckData? adminEditCheckData;
  Object? adminEditCheckError;
  final adminEditCheckRequests =
      <({String appointmentId, DateTime from, DateTime to, DateTime now})>[];
  final adminEdits =
      <
        ({
          String id,
          DateTime start,
          DateTime end,
          BookedServiceModel booked,
          AppointmentPerson? person,
        })
      >[];

  /// El turno [id] tal como lo ve el fake ahora.
  AppointmentModel? appointmentById(String id) {
    if (_appointments.containsKey(id)) return _appointments[id];
    for (final a in [...active, ...mine, ...created]) {
      if (a.id == id) return a;
    }
    return null;
  }

  /// Cambia el turno [id] (o lo borra con `null`) y lo envía a quien lo
  /// escucha.
  void emitAppointment(String id, AppointmentModel? value) {
    _appointments[id] = value;
    for (final listener in List.of(_appointmentListeners)) {
      if (listener.id == id) listener.controller.add(value);
    }
  }

  @override
  Stream<AppointmentModel?> watchAppointment(String id) {
    appointmentRequests.add(id);
    late final StreamController<AppointmentModel?> controller;
    late final ({String id, StreamController<AppointmentModel?> controller})
    entry;
    controller = StreamController<AppointmentModel?>(
      onListen: () => controller.add(appointmentById(id)),
      onCancel: () => _appointmentListeners.remove(entry),
    );
    entry = (id: id, controller: controller);
    _appointmentListeners.add(entry);
    return controller.stream;
  }

  @override
  Future<AdminEditCheckData> fetchAdminEditCheck({
    required String appointmentId,
    required DateTime from,
    required DateTime to,
    required DateTime now,
  }) async {
    adminEditCheckRequests.add((
      appointmentId: appointmentId,
      from: from,
      to: to,
      now: now,
    ));
    final error = adminEditCheckError;
    if (error != null) throw error;
    return adminEditCheckData ??
        (
          appointment: appointmentById(appointmentId),
          busy: busy,
          active: active,
        );
  }

  @override
  Future<bool> updateAppointmentByAdmin({
    required String id,
    required bool Function(AppointmentModel? current) expected,
    required DateTime start,
    required DateTime end,
    required BookedServiceModel booked,
    AppointmentPerson? person,
  }) async {
    final error = updateError;
    if (error != null) throw error;
    final current = appointmentById(id);
    if (!expected(current)) return false;
    adminEdits.add((
      id: id,
      start: start,
      end: end,
      booked: booked,
      person: person,
    ));
    if (current != null) {
      // Como el `update` de Firestore: lo que no se envía no cambia.
      final updated = AppointmentModel(
        id: id,
        clientId: person != null ? person.clientId : current.clientId,
        clientName: person?.clientName ?? current.clientName,
        clientPhone: person?.clientPhone ?? current.clientPhone,
        clientPhotoUrl: person != null
            ? person.clientPhotoUrl
            : current.clientPhotoUrl,
        startTime: start,
        endTime: end,
        status: 'confirmed',
        createdAt: current.createdAt,
        createdByAdmin: person != null || current.createdByAdmin,
        booked: booked,
      );
      AppointmentModel replace(AppointmentModel a) => a.id == id ? updated : a;
      if (active.any((a) => a.id == id)) {
        emitActive([for (final a in active) replace(a)]);
      }
      if (mine.any((a) => a.id == id)) {
        emitMine([for (final a in mine) replace(a)]);
      }
      emitAppointment(id, updated);
    }
    // Como el `set` de Firestore: crea o sustituye su turno ocupado.
    final slot = BusySlot(id: id, start: start, end: end);
    emitBusy([
      for (final s in busy)
        if (s.id != id) s,
      slot,
    ]);
    final latency = adminEditLatency;
    if (latency != null) await Future<void>.delayed(latency);
    return true;
  }

  final edited =
      <
        ({String id, DateTime start, DateTime end, BookedServiceModel booked})
      >[];

  @override
  Duration get saveTimeout => const Duration(seconds: 15);

  Stream<T> _live<T>(List<StreamController<T>> listeners, T Function() now) {
    late final StreamController<T> controller;
    controller = StreamController<T>(
      onListen: () => controller.add(now()),
      onCancel: () => listeners.remove(controller),
    );
    listeners.add(controller);
    return controller.stream;
  }

  void _send<T>(List<StreamController<T>> listeners, T value) {
    for (final listener in List.of(listeners)) {
      listener.add(value);
    }
  }

  void _fail<T>(List<StreamController<T>> listeners, Object error) {
    for (final listener in List.of(listeners)) {
      listener.addError(error);
    }
  }

  void emitBusy(List<BusySlot> value) => _send(_busyListeners, busy = value);
  void failBusy(Object error) => _fail(_busyListeners, error);
  void emitMine(List<AppointmentModel> value) =>
      _send(_mineListeners, mine = value);
  void failMine(Object error) => _fail(_mineListeners, error);
  void emitActive(List<AppointmentModel> value) =>
      _send(_activeListeners, active = value);
  void failActive(Object error) => _fail(_activeListeners, error);

  @override
  Stream<List<AppointmentModel>> watchActiveAppointments(DateTime now) {
    activeRequests.add(now);
    return _live(_activeListeners, () => active);
  }

  @override
  Future<List<AppointmentModel>> fetchActiveAppointments(DateTime now) async {
    activeFetches.add(now);
    final error = activeFetchError;
    if (error != null) throw error;
    return active;
  }

  @override
  Future<AdminCheckData> fetchAdminBookingCheck({
    required DateTime from,
    required DateTime to,
    required DateTime now,
  }) async {
    adminCheckRequests.add((from: from, to: to, now: now));
    final error = adminCheckError;
    if (error != null) throw error;
    return adminCheckData ?? (busy: busy, active: active);
  }

  @override
  Stream<List<BusySlot>> watchBusySlots(DateTime from, DateTime to) {
    busyWindows.add((from: from, to: to));
    return _live(_busyListeners, () => busy);
  }

  @override
  Stream<List<AppointmentModel>> getClientAppointments(String clientId) {
    clientRequests.add(clientId);
    return _live(_mineListeners, () => mine).map(
      (all) => [
        for (final a in all)
          if (a.clientId == clientId) a,
      ],
    );
  }

  @override
  Future<BookingCheckData> fetchBookingCheck({
    required String clientId,
    required DateTime from,
    required DateTime to,
  }) async {
    checkRequests.add((clientId: clientId, from: from, to: to));
    final error = checkError;
    if (error != null) throw error;
    return checkData ?? (busy: busy, mine: mine);
  }

  @override
  Future<void> createAppointment(AppointmentModel appointment) async {
    final error = saveError;
    if (error != null) throw error;
    created.add(appointment);
    // Como Firestore, el turno guardado llega a quien escucha los turnos.
    emitMine([...mine, appointment]);
    emitActive([...active, appointment]);
  }

  @override
  Future<EditCheckData> fetchEditCheck({
    required String appointmentId,
    required DateTime from,
    required DateTime to,
  }) async {
    editCheckRequests.add((appointmentId: appointmentId, from: from, to: to));
    final error = editCheckError;
    if (error != null) throw error;
    return editCheckData ??
        (
          appointment: mine.where((a) => a.id == appointmentId).firstOrNull,
          busy: busy,
        );
  }

  @override
  Future<bool> updateEditedAppointment({
    required String id,
    required bool Function(AppointmentModel? current) expected,
    required DateTime start,
    required DateTime end,
    required BookedServiceModel booked,
  }) async {
    final error = updateError;
    if (error != null) throw error;
    final current = mine.where((a) => a.id == id).firstOrNull;
    if (!expected(current)) return false;
    edited.add((id: id, start: start, end: end, booked: booked));
    emitMine([
      for (final a in mine)
        a.id == id
            ? AppointmentModel(
                id: a.id,
                clientId: a.clientId,
                clientName: a.clientName,
                clientPhone: a.clientPhone,
                clientPhotoUrl: a.clientPhotoUrl,
                startTime: start,
                endTime: end,
                status: 'waiting_confirmation',
                createdAt: a.createdAt,
                // Como el `update` de Firestore: los demás campos no cambian
                // (spec 007, RF-30).
                createdByAdmin: a.createdByAdmin,
                booked: booked,
              )
            : a,
    ]);
    if (busy.any((slot) => slot.id == id)) {
      emitBusy([
        for (final slot in busy)
          slot.id == id ? BusySlot(id: id, start: start, end: end) : slot,
      ]);
    }
    return true;
  }

  Object? cancelError;

  /// Si está, la cancelación espera a que termine antes de releer el turno:
  /// así un test ve la cancelación en curso.
  Future<void>? cancelGate;

  /// Turnos cancelados por la clienta, en orden.
  final cancelled = <String>[];

  @override
  Future<bool> cancelByClient({
    required String id,
    required bool Function(AppointmentModel? current) expected,
  }) async {
    final gate = cancelGate;
    if (gate != null) await gate;
    final error = cancelError;
    if (error != null) throw error;
    final current = appointmentById(id);
    if (!expected(current)) return false;
    cancelled.add(id);
    if (current != null) {
      // Como el `update` de Firestore: lo que no se envía no cambia.
      final updated = AppointmentModel(
        id: id,
        clientId: current.clientId,
        clientName: current.clientName,
        clientPhone: current.clientPhone,
        clientPhotoUrl: current.clientPhotoUrl,
        startTime: current.startTime,
        endTime: current.endTime,
        status: 'cancelled',
        createdAt: current.createdAt,
        booked: current.booked,
        createdByAdmin: current.createdByAdmin,
        cancelledByClient: true,
        accountDeleted: current.accountDeleted,
      );
      AppointmentModel replace(AppointmentModel a) => a.id == id ? updated : a;
      if (mine.any((a) => a.id == id)) {
        emitMine([for (final a in mine) replace(a)]);
      }
      if (active.any((a) => a.id == id)) {
        emitActive([for (final a in active) replace(a)]);
      }
      emitAppointment(id, updated);
    }
    if (busy.any((slot) => slot.id == id)) {
      emitBusy([
        for (final slot in busy)
          if (slot.id != id) slot,
      ]);
    }
    return true;
  }

  @override
  Future<void> updateAppointmentStatus(String id, String status) async =>
      statusChanges.add((id: id, status: status));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
