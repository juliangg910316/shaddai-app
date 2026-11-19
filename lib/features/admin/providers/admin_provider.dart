import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/models/appointment_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/calendar_settings_model.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/config_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/logic/salon_time.dart';
import '../../booking/providers/booking_provider.dart';
import '../logic/admin_agenda.dart';
import '../logic/admin_clients.dart';

/// El día que muestra la agenda: un día del salón (`DateTime.utc` a las
/// 0:00 con la fecha de Curitiba). Empieza en hoy del salón (spec 010, RF-2,
/// plan D-1). Quien escriba una fecha local también vale: se lee con
/// [agendaDay].
final adminSelectedDateProvider = StateProvider<DateTime>(
  (ref) => agendaToday(toSalon(ref.read(clockProvider)())),
);

/// Hoy del salón; cambia solo a medianoche. Decide "Hoy" (spec 010, RF-3).
final adminTodayProvider = Provider<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  return ref.watch(
    salonNowProvider.select(
      (now) => agendaToday(now.value ?? toSalon(clock())),
    ),
  );
});

/// Los turnos del día de la agenda, de medianoche a medianoche del salón
/// (spec 010, RF-1).
final adminAppointmentsProvider = StreamProvider<List<AppointmentModel>>((ref) {
  final range = agendaRange(ref.watch(adminSelectedDateProvider));
  return ref
      .watch(bookingRepositoryProvider)
      .watchAppointmentsBetween(range.from, range.to);
});

final adminUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(userRepositoryProvider).getAllUsers();
});

/// Las clientas para la lista del panel: sin admins y por nombre (spec 010,
/// RF-19, RF-20). Con error si no se pudieron cargar: el error manda
/// (MEMORY).
final adminClientsProvider = Provider<AsyncValue<List<UserModel>>>((ref) {
  final users = ref.watch(adminUsersProvider);
  if (users.hasError) return AsyncError(users.error!, users.stackTrace!);
  return users.whenData(clientsForAdmin);
});

class AdminController {
  final UserRepository _userRepo;
  final ConfigRepository _configRepo;

  AdminController(this._userRepo, this._configRepo);

  /// Bloquea (sin tocar sus turnos) o desbloquea a [uid], como hasta ahora:
  /// el diálogo y la cancelación del turno llegan con la spec 010 (T9).
  Future<void> setClientBlocked(String uid, bool isBlocked) => isBlocked
      ? _userRepo.blockClient(uid: uid, expected: (_) => true)
      : _userRepo.unblockClient(uid);

  Future<void> updateSettings(CalendarSettingsModel settings) async {
    await _configRepo.updateSettings(settings);
  }

  /// Guarda solo el margen de edición (spec 008, RF-38, RF-41).
  Future<void> updateEditMargin(int minutes) =>
      _configRepo.updateEditMargin(minutes);
}

final adminControllerProvider = Provider((ref) {
  return AdminController(
    ref.watch(userRepositoryProvider),
    ref.watch(configRepositoryProvider),
  );
});
