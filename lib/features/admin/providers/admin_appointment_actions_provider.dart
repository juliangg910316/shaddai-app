import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/appointment_model.dart';
import '../../booking/logic/booking_edit.dart';
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

/// Cómo terminó la cancelación de la admin (spec 010, RF-14, RF-15, RF-17).
enum AdminCancelOutcome {
  ok,

  /// Ya no está activo: cancelado, borrado o terminado.
  notActive,

  /// Cambió el día, la hora o lo reservado desde que se abrió el diálogo.
  changed,

  /// Error o tiempo agotado: no cambió nada y se puede reintentar.
  failed,
}

/// Lo que la admin hace sobre un turno de la agenda (spec 010, plan § 6).
class AdminAppointmentActions {
  AdminAppointmentActions(this._ref);

  final Ref _ref;

  /// Cancela [shown], el turno tal como lo vio la admin. La transacción lo
  /// relee y solo lo cancela si [checkAdminCancelBeforeSave] lo da por
  /// bueno; si no, devuelve el motivo (plan D-2).
  Future<AdminCancelOutcome> cancel(AppointmentModel shown) async {
    final original = EditOriginal.of(shown);
    var check = AdminCancelCheck.notActive;
    try {
      final cancelled = await _ref
          .read(bookingRepositoryProvider)
          .cancelByAdmin(
            id: shown.id,
            expected: (current) {
              check = checkAdminCancelBeforeSave(
                shown: original,
                current: current,
                nowSalon: toSalon(_ref.read(clockProvider)()),
              );
              return check == AdminCancelCheck.ok;
            },
          );
      if (cancelled) return AdminCancelOutcome.ok;
    } catch (error) {
      debugPrint('No se pudo cancelar el turno: $error');
      return AdminCancelOutcome.failed;
    }
    return switch (check) {
      AdminCancelCheck.notActive => AdminCancelOutcome.notActive,
      AdminCancelCheck.changed => AdminCancelOutcome.changed,
      // No canceló aunque la comprobación diera ok: se trata como un fallo
      // que se puede reintentar.
      AdminCancelCheck.ok => AdminCancelOutcome.failed,
    };
  }

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
