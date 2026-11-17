import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/appointment_model.dart';
import '../logic/admin_edit.dart';
import '../logic/booking_edit.dart';
import '../logic/booking_selection.dart';
import '../logic/recipient.dart';
import 'admin_booking_provider.dart';
import 'booking_provider.dart';

/// La edición de un turno por la admin (spec 008, RF-19 a RF-35; plan § 5).
///
/// Reutiliza la selección de la reserva y "Para quién" (plan D-2): al abrir
/// la edición guarda aparte lo que la admin tenía a medias para agendar, y al
/// cerrarla se lo devuelve.

/// El turno [id] en vivo, o `null` si no existe (RF-19, RF-30).
final adminEditAppointmentProvider =
    StreamProvider.family<AppointmentModel?, String>(
      (ref, id) => ref.watch(bookingRepositoryProvider).watchAppointment(id),
    );

/// El id del turno que edita la admin, o `null`.
class AdminEditController extends Notifier<String?> {
  /// Lo que la admin tenía elegido para agendar al abrir la edición (RF-33).
  BookingSelection? _savedSelection;
  Recipient? _savedRecipient;

  @override
  String? build() => null;

  /// Abre la edición de [appointment]: guarda aparte la selección y "Para
  /// quién", pone la persona del turno y carga su día, su hora y lo reservado
  /// (RF-19, RF-24).
  void start(AppointmentModel appointment) {
    if (state == null) {
      _savedSelection = ref.read(bookingSelectionProvider).selection;
      _savedRecipient = ref.read(bookingRecipientProvider).recipient;
    }
    ref
        .read(bookingRecipientProvider.notifier)
        .restore(recipientOf(EditOriginal.of(appointment)));
    ref.read(editTargetProvider.notifier).start(appointment);
    state = appointment.id;
  }

  /// Cierra la edición y devuelve lo que la admin tenía a medias, ajustado a
  /// los datos de ahora (RF-33, RF-35). Sin edición abierta, no hace nada.
  void end() {
    if (state == null) return;
    ref.read(editTargetProvider.notifier).end();
    ref
        .read(bookingSelectionProvider.notifier)
        .restore(_savedSelection ?? BookingSelection.empty);
    ref.read(bookingRecipientProvider.notifier).restore(_savedRecipient);
    _savedSelection = null;
    _savedRecipient = null;
    state = null;
  }
}

final adminEditProvider = NotifierProvider<AdminEditController, String?>(
  AdminEditController.new,
);
