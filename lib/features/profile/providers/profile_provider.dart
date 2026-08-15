import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/appointment_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/providers/booking_provider.dart';

final clientAppointmentsProvider =
    StreamProvider.autoDispose<List<AppointmentModel>>((ref) {
      final user = ref.watch(currentUserProvider).value;
      if (user == null) {
        return const Stream.empty();
      }

      return ref
          .watch(bookingRepositoryProvider)
          .getClientAppointments(user.uid);
    });
