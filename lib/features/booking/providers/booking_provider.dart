import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/calendar_settings_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/config_repository.dart';
import 'package:intl/intl.dart';

final bookingRepositoryProvider = Provider((ref) => BookingRepository());
final configRepositoryProvider = Provider((ref) => ConfigRepository());

final calendarSettingsProvider = StreamProvider<CalendarSettingsModel>((ref) {
  return ref.watch(configRepositoryProvider).getCalendarSettings();
});

final selectedDateProvider = StateProvider<DateTime>((ref) {
  return DateTime.now();
});

final appointmentsForDateProvider = StreamProvider<List<AppointmentModel>>((
  ref,
) {
  final date = ref.watch(selectedDateProvider);
  return ref.watch(bookingRepositoryProvider).getActiveAppointmentsForDate(date);
});

// Calcula los horarios disponibles basándose en el calendario y las citas existentes
final availableSlotsProvider = Provider<AsyncValue<List<DateTime>>>((ref) {
  final settingsAsync = ref.watch(calendarSettingsProvider);
  final appointmentsAsync = ref.watch(appointmentsForDateProvider);
  final date = ref.watch(selectedDateProvider);

  if (settingsAsync.isLoading || appointmentsAsync.isLoading) {
    return const AsyncLoading();
  }

  if (settingsAsync.hasError) {
    return AsyncError(settingsAsync.error!, settingsAsync.stackTrace!);
  }

  final settings = settingsAsync.value!;
  final appointments = appointmentsAsync.value ?? [];

  // Chequear si el dia está bloqueado globalmente
  final dateString = DateFormat('yyyy-MM-dd').format(date);
  if (settings.blockedDates.contains(dateString)) {
    return const AsyncData([]);
  }

  // Obtener día de la semana para parsear en inglés
  final weekdayStr = DateFormat('EEEE').format(date).toLowerCase();

  final daySchedule = settings.openingHours[weekdayStr];
  if (daySchedule == null || daySchedule.isClosed) {
    return const AsyncData([]);
  }

  // Calcular slots
  final openParts = daySchedule.open.split(':');
  final closeParts = daySchedule.close.split(':');

  var currentTime = DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(openParts[0]),
    int.parse(openParts[1]),
  );

  final endTime = DateTime(
    date.year,
    date.month,
    date.day,
    int.parse(closeParts[0]),
    int.parse(closeParts[1]),
  );

  final List<DateTime> availableSlots = [];
  final now = DateTime.now();

  while (currentTime.isBefore(endTime)) {
    final slotEnd = currentTime.add(
      Duration(minutes: settings.globalSlotDurationMinutes),
    );

    // No mostrar horarios pasados del día actual
    if (currentTime.isAfter(now)) {
      // Chequear superposición con otras citas (para evitar reservas dobles)
      bool isOverlapping = appointments.any((app) {
        return (currentTime.isBefore(app.endTime) &&
            slotEnd.isAfter(app.startTime));
      });

      if (!isOverlapping) {
        availableSlots.add(currentTime);
      }
    }

    currentTime = slotEnd;
  }

  return AsyncData(availableSlots);
});
