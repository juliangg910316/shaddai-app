import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/closure_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/data/repositories/agenda_functions.dart';
import 'package:shaddai/data/repositories/booking_repository.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import 'fake_booking.dart';
import 'fake_config.dart';

/// Una llamada a reservar o editar.
typedef AgendaCall = ({
  String id,
  DateTime start,
  BookedServiceModel booked,
  AppointmentModel? expected,
  AgendaRecipient? recipient,
});

/// Las funciones de la agenda en memoria (spec 012): nunca llaman al
/// servidor. Los helpers de los tests la ponen por defecto.
///
/// Registra cada llamada ([books], [edits], [closures]). Con [booking] y
/// [config], guarda en ellos lo que escribiría la función, para que los
/// turnos y cierres lleguen en vivo como en la app: la clienta ([caller])
/// reserva a su nombre esperando confirmación; la admin, confirmado y
/// marcado para la persona elegida (sus fichas en [users]). Con [rejection],
/// responde con ese rechazo (y [conflictIds]) sin guardar nada; con [error],
/// lanza; con [latency], tarda.
///
/// [FakeAgendaFunctions.linked], la que ponen los helpers, lee en cada
/// llamada los repositorios falsos, la sesión y el reloj del test: lo que
/// guarda llega a quien escucha, y los errores de guardado de los
/// repositorios falsos (`saveError`, `updateError`) siguen fallando igual.
class FakeAgendaFunctions implements AgendaFunctions {
  FakeAgendaFunctions({
    FakeBookingRepository? booking,
    FakeConfigRepository? config,
    UserModel? caller,
    this.users = const {},
    DateTime Function()? clock,
  }) : _booking = (() => booking),
       _config = (() => config),
       _caller = (() => caller),
       _clock = clock ?? DateTime.now;

  /// Unida a los providers de [ref]: `bookingRepositoryProvider`,
  /// `configRepositoryProvider`, `currentUserProvider` y `clockProvider`.
  FakeAgendaFunctions.linked(Ref ref, {this.users = const {}})
    : _booking = (() => _tryRead(() => ref.read(bookingRepositoryProvider))),
      _config = (() => _tryRead(() => ref.read(configRepositoryProvider))),
      _caller = (() => _tryRead(() => ref.read(currentUserProvider).value)),
      _clock = (() => ref.read(clockProvider)());

  /// Lo que hay en el provider si es un doble; nada si no lo es o si leerlo
  /// tocaría Firebase.
  static T? _tryRead<T>(Object? Function() read) {
    try {
      final value = read();
      return value is T ? value : null;
    } catch (_) {
      return null;
    }
  }

  final FakeBookingRepository? Function() _booking;
  final FakeConfigRepository? Function() _config;
  final UserModel? Function() _caller;
  final DateTime Function() _clock;
  Map<String, UserModel> users;

  FakeBookingRepository? get booking => _booking();
  FakeConfigRepository? get config => _config();
  UserModel? get caller => _caller();

  AgendaRejection? rejection;
  List<String> conflictIds = const [];
  Object? error;
  Duration? latency;

  final books = <AgendaCall>[];
  final edits = <AgendaCall>[];
  final closures = <({DateTime start, DateTime end})>[];

  @override
  Duration get timeout => const Duration(seconds: 15);

  bool get _admin => caller?.role == 'admin';

  /// Lo que responde antes de guardar: el error, el rechazo o nada.
  Future<AgendaWriteResult?> _answer() async {
    final wait = latency;
    if (wait != null) await Future<void>.delayed(wait);
    final thrown = error;
    if (thrown != null) throw thrown;
    final rejected = rejection;
    if (rejected == null) return null;
    return AgendaWriteResult.rejected(rejected, conflictIds: conflictIds);
  }

  /// La persona del turno, como la escribe la función.
  AppointmentPerson? _person(AgendaRecipient? recipient) => switch (recipient) {
    null => null,
    AgendaAccountRecipient(:final clientId) => (
      clientId: clientId,
      clientName: users[clientId]?.displayName ?? '',
      clientPhone: users[clientId]?.phoneNumber ?? '',
      clientPhotoUrl: users[clientId]?.photoUrl,
    ),
    AgendaGuestRecipient(:final name, :final phone) => (
      clientId: null,
      clientName: name.trim(),
      clientPhone: phone.trim(),
      clientPhotoUrl: null,
    ),
  };

  @override
  Future<AgendaWriteResult> book({
    required String id,
    required DateTime start,
    required BookedServiceModel booked,
    AgendaRecipient? recipient,
  }) async {
    books.add((
      id: id,
      start: start,
      booked: booked,
      expected: null,
      recipient: recipient,
    ));
    final answer = await _answer();
    if (answer != null) return answer;
    final repository = booking;
    if (repository != null) {
      final person =
          _person(recipient) ??
          (
            clientId: caller?.uid,
            clientName: caller?.displayName ?? '',
            clientPhone: caller?.phoneNumber ?? '',
            clientPhotoUrl: caller?.photoUrl,
          );
      await repository.createAppointment(
        AppointmentModel(
          id: id,
          clientId: person.clientId,
          clientName: person.clientName,
          clientPhone: person.clientPhone,
          clientPhotoUrl: person.clientPhotoUrl,
          startTime: start,
          endTime: start.add(Duration(minutes: booked.durationMinutes)),
          status: _admin ? 'confirmed' : 'waiting_confirmation',
          createdAt: _clock(),
          createdByAdmin: _admin,
          booked: booked,
        ),
      );
    }
    return AgendaWriteResult.ok(id);
  }

  @override
  Future<AgendaWriteResult> edit({
    required String id,
    required DateTime start,
    required BookedServiceModel booked,
    required AppointmentModel expected,
    AgendaRecipient? recipient,
  }) async {
    edits.add((
      id: id,
      start: start,
      booked: booked,
      expected: expected,
      recipient: recipient,
    ));
    final answer = await _answer();
    if (answer != null) return answer;
    final repository = booking;
    if (repository == null) return AgendaWriteResult.ok(id);

    bool same(AppointmentModel? current) =>
        current != null &&
        current.startTime == expected.startTime &&
        current.endTime == expected.endTime &&
        current.status == expected.status &&
        current.booked == expected.booked;
    final end = start.add(Duration(minutes: booked.durationMinutes));
    final person = _person(recipient);
    final changedPerson =
        person != null &&
        (person.clientId != expected.clientId ||
            person.clientName != expected.clientName ||
            person.clientPhone != expected.clientPhone);
    final saved = _admin
        ? await repository.updateAppointmentByAdmin(
            id: id,
            expected: same,
            start: start,
            end: end,
            booked: booked,
            person: changedPerson ? person : null,
          )
        : await repository.updateEditedAppointment(
            id: id,
            expected: same,
            start: start,
            end: end,
            booked: booked,
          );
    return saved
        ? AgendaWriteResult.ok(id)
        : const AgendaWriteResult.rejected(AgendaRejection.changed);
  }

  @override
  Future<AgendaWriteResult> saveClosure({
    required DateTime start,
    required DateTime end,
  }) async {
    closures.add((start: start, end: end));
    final answer = await _answer();
    if (answer != null) return answer;
    final id = 'cierre-${closures.length}';
    await config?.createClosure(ClosureModel(id: id, start: start, end: end));
    return AgendaWriteResult.ok(id);
  }
}
