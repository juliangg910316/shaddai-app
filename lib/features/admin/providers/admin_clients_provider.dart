import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/appointment_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../../booking/logic/booking_rules.dart';
import '../../booking/logic/salon_time.dart';
import '../../booking/providers/admin_booking_provider.dart';
import '../../booking/providers/booking_provider.dart';
import '../logic/admin_clients.dart';

/// El turno activo de la clienta [uid], en vivo mientras el diálogo de
/// bloquear está abierto, o `null` (spec 010, RF-26, plan D-6).
final clientActiveAppointmentProvider =
    Provider.family<AppointmentModel?, String>((ref, uid) {
      final active = ref.watch(adminActiveAppointmentsProvider).value;
      if (active == null) return null;
      final now =
          ref.watch(salonNowProvider).value ??
          toSalon(ref.read(clockProvider)());
      return clientActiveAppointment(active, uid: uid, now: fromSalon(now));
    });

/// Cómo terminó un bloqueo (spec 010, RF-27, RF-28, RF-34).
enum BlockOutcome {
  ok,

  /// Su turno activo no es el que mostraba el diálogo: no se bloqueó.
  changed,

  /// Error o tiempo agotado: no cambió nada y se puede reintentar.
  failed,
}

/// Bloquear y desbloquear clientas (spec 010, plan § 6).
class ClientBlocker {
  ClientBlocker(this._ref);

  final Ref _ref;

  /// Bloquea a [uid], cuyo turno activo mostraba el diálogo como [shown]
  /// (`null` si no tenía). Primero lee del servidor su turno activo y lo
  /// compara con [shown]; después la transacción relee ese turno y guarda a
  /// la vez el bloqueo y su cancelación (plan D-5).
  Future<BlockOutcome> block(String uid, AppointmentModel? shown) async {
    try {
      final now = _ref.read(clockProvider)();
      final active = await _ref
          .read(bookingRepositoryProvider)
          .fetchActiveAppointments(now);
      final current = clientActiveAppointment(active, uid: uid, now: now);
      if (checkBlockBeforeSave(shown: shown, current: current) !=
          BlockCheck.ok) {
        return BlockOutcome.changed;
      }
      final saved = await _ref
          .read(userRepositoryProvider)
          .blockClient(
            uid: uid,
            appointmentId: current?.id,
            expected: (reread) =>
                current == null ||
                (reread != null &&
                    activeStatuses.contains(reread.status) &&
                    reread.endTime.isAfter(now) &&
                    checkBlockBeforeSave(shown: current, current: reread) ==
                        BlockCheck.ok),
          );
      return saved ? BlockOutcome.ok : BlockOutcome.changed;
    } catch (error) {
      debugPrint('No se pudo bloquear a la clienta: $error');
      return BlockOutcome.failed;
    }
  }

  /// Desbloquea a [uid]; devuelve si se guardó (RF-30, RF-34).
  Future<bool> unblock(String uid) async {
    try {
      await _ref.read(userRepositoryProvider).unblockClient(uid);
      return true;
    } catch (error) {
      debugPrint('No se pudo desbloquear a la clienta: $error');
      return false;
    }
  }
}

final clientBlockerProvider = Provider(ClientBlocker.new);
