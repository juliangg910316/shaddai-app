import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../data/models/appointment_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/calendar_settings_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../data/repositories/config_repository.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/providers/booking_provider.dart';

final adminSelectedDateProvider = StateProvider<DateTime>(
  (ref) => DateTime.now(),
);

final adminAppointmentsProvider = StreamProvider<List<AppointmentModel>>((ref) {
  final date = ref.watch(adminSelectedDateProvider);
  // El día del dispositivo, de medianoche a medianoche local, como hasta
  // ahora; la spec 010 lo pasa al día del salón (T4).
  final start = DateTime(date.year, date.month, date.day);
  return ref
      .watch(bookingRepositoryProvider)
      .watchAppointmentsBetween(start, start.add(const Duration(days: 1)));
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
