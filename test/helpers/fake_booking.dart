import 'dart:async';

import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/repositories/booking_repository.dart';

/// Turnos y turnos ocupados en memoria, sin Firebase (spec 005, plan § 9).
///
/// [busy] y [mine] llegan en vivo: [emitBusy] y [emitMine] los cambian y los
/// envían a quien escucha; [failBusy] y [failMine] envían un error. La
/// comprobación previa devuelve [checkData] (por defecto, lo que hay en
/// [busy] y [mine]) o lanza [checkError]; el guardado lanza [saveError] o
/// guarda en [created] y lo envía como uno más de [mine].
class FakeBookingRepository implements BookingRepository {
  FakeBookingRepository({this.busy = const [], this.mine = const []});

  /// Lo que reciben las escuchas al empezar y la comprobación previa.
  List<BusySlot> busy;
  List<AppointmentModel> mine;

  final _busyListeners = <StreamController<List<BusySlot>>>[];
  final _mineListeners = <StreamController<List<AppointmentModel>>>[];

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

  @override
  Stream<List<BusySlot>> watchBusySlots(DateTime from, DateTime to) {
    busyWindows.add((from: from, to: to));
    return _live(_busyListeners, () => busy);
  }

  @override
  Stream<List<AppointmentModel>> getClientAppointments(String clientId) {
    clientRequests.add(clientId);
    return _live(_mineListeners, () => mine);
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
  }

  @override
  Future<void> updateAppointmentStatus(String id, String status) async =>
      statusChanges.add((id: id, status: status));

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
