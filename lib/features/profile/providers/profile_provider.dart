import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/appointment_model.dart';
import '../../booking/logic/salon_time.dart';
import '../../booking/providers/booking_provider.dart';
import '../logic/profile_appointments.dart';

/// El turno activo y el historial de la clienta, en vivo con sus turnos y
/// con "ahora" (spec 009, RF-1, RF-5, RF-6, RF-20). Tras un error, el error,
/// aunque Riverpod esté reintentando (MEMORY).
final profileAppointmentsProvider =
    Provider<AsyncValue<ProfileAppointments<AppointmentModel>>>((ref) {
      final mine = ref.watch(myAppointmentsProvider);
      if (mine.hasError) return AsyncError(mine.error!, mine.stackTrace!);
      final now =
          ref.watch(salonNowProvider).value ??
          toSalon(ref.read(clockProvider)());
      return mine.whenData(
        (appointments) => profileAppointments(
          appointments,
          times: (a) => (start: a.startTime, end: a.endTime, status: a.status),
          now: fromSalon(now),
        ),
      );
    });
