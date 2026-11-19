import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/models/appointment_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/calendar_settings_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/config_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/logic/salon_time.dart';
import '../../booking/providers/booking_provider.dart';
import '../logic/admin_agenda.dart';

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

class AdminController {
  final BookingRepository _bookingRepo;
  final UserRepository _userRepo;
  final ConfigRepository _configRepo;

  AdminController(this._bookingRepo, this._userRepo, this._configRepo);

  /// Cancela el turno [id] y libera su hora, sin comprobar nada todavía:
  /// el diálogo con su comprobación llega con la spec 010 (T7).
  Future<void> cancelAppointment(String id) =>
      _bookingRepo.cancelByAdmin(id: id, expected: (_) => true);

  /// Confirma el turno [id], sin comprobar nada todavía (spec 010, T6).
  Future<void> confirmAppointment(String id) =>
      _bookingRepo.confirmByAdmin(id: id, expected: (_) => true);

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
    ref.watch(bookingRepositoryProvider),
    ref.watch(userRepositoryProvider),
    ref.watch(configRepositoryProvider),
  );
});
