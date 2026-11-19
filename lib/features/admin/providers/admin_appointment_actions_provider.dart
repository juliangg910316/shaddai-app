import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../booking/logic/salon_time.dart';
import '../../booking/providers/booking_provider.dart';
import '../logic/admin_agenda.dart';

/// Cómo terminó "Confirmar" (spec 010, RF-11, RF-17).
enum AdminConfirmOutcome {
  ok,

  /// Ya no espera confirmación: cancelado, confirmado, borrado o terminado.
  notActive,

  /// Error o tiempo agotado: no cambió nada y se puede reintentar.
  failed,
}

/// Lo que la admin hace sobre un turno de la agenda (spec 010, plan § 6).
class AdminAppointmentActions {
  AdminAppointmentActions(this._ref);

  final Ref _ref;

  /// Confirma el turno [id] si, releído en la transacción, sigue esperando
  /// confirmación y sin terminar (plan D-4). Los errores se quedan en
  /// `debugPrint`: la interfaz solo muestra un texto de la app.
  Future<AdminConfirmOutcome> confirm(String id) async {
    try {
      final confirmed = await _ref
          .read(bookingRepositoryProvider)
          .confirmByAdmin(
            id: id,
            expected: (current) => checkAdminConfirmBeforeSave(
              current: current,
              nowSalon: toSalon(_ref.read(clockProvider)()),
            ),
          );
      return confirmed ? AdminConfirmOutcome.ok : AdminConfirmOutcome.notActive;
    } catch (error) {
      debugPrint('No se pudo confirmar el turno: $error');
      return AdminConfirmOutcome.failed;
    }
  }
}

final adminAppointmentActionsProvider = Provider(AdminAppointmentActions.new);
