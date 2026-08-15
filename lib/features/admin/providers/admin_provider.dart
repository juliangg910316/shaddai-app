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
  return ref.watch(bookingRepositoryProvider).getAppointmentsForDate(date);
});

final adminUsersProvider = StreamProvider<List<UserModel>>((ref) {
  return ref.watch(userRepositoryProvider).getAllUsers();
});

class AdminController {
  final BookingRepository _bookingRepo;
  final UserRepository _userRepo;
  final ConfigRepository _configRepo;

  AdminController(this._bookingRepo, this._userRepo, this._configRepo);

  Future<void> updateAppointmentStatus(String id, String status) async {
    await _bookingRepo.updateAppointmentStatus(id, status);
  }

  Future<void> toggleUserBlock(String uid, bool isBlocked) async {
    await _userRepo.toggleBlockUser(uid, isBlocked);
  }

  Future<void> updateSettings(CalendarSettingsModel settings) async {
    await _configRepo.updateSettings(settings);
  }
}

final adminControllerProvider = Provider((ref) {
  return AdminController(
    ref.watch(bookingRepositoryProvider),
    ref.watch(userRepositoryProvider),
    ref.watch(configRepositoryProvider),
  );
});
