import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/appointment_model.dart';
import '../logic/booking_edit.dart';
import '../logic/cancel_appointment.dart';
import '../logic/salon_time.dart';
import 'booking_provider.dart';

/// Si se puede cancelar ahora el turno que empieza en [start] (instante)
/// (spec 009, RF-3, RF-4, RF-7): cambia en vivo con el calendario y con
/// "ahora", que avanza cada 30 s.
final cancelAvailabilityProvider =
    Provider.family<CancelAvailability, DateTime>((ref, start) {
      final settings = ref.watch(calendarSettingsProvider);
      final now =
          ref.watch(salonNowProvider).value ??
          toSalon(ref.read(clockProvider)());
      return cancelAvailability(
        settingsError: settings.hasError,
        marginMinutes: settings.value?.editMarginMinutes,
        start: start,
        now: fromSalon(now),
      );
    });

/// Cómo terminó "Cancelar turno" (RF-11 a RF-15).
enum CancelOutcome { ok, notCancellable, notActive, changed, failed }

/// Cancela el turno activo de la clienta tras comprobarlo en el servidor
/// (spec 009, plan D-3, § 6).
class AppointmentCanceller {
  AppointmentCanceller(this._ref);

  final Ref _ref;

  /// Cancela [shown], el turno tal como lo vio la clienta. La transacción
  /// relee el turno y solo lo cancela si [checkCancelBeforeSave] lo da por
  /// bueno; si no, devuelve el motivo (RF-14). Si falla o tarda demasiado,
  /// no cambia nada (RF-15).
  ///
  /// Si la clienta estaba editando ese turno, cierra la edición antes de
  /// cancelar, sin guardar sus cambios (RF-17): así, cuando el turno deja de
  /// ser activo, la edición ya no avisa de que "ya no está activo".
  Future<CancelOutcome> cancel(AppointmentModel shown) async {
    final margin = _ref.read(calendarSettingsProvider).value?.editMarginMinutes;
    if (margin == null) return CancelOutcome.failed;

    if (_ref.read(editTargetProvider)?.id == shown.id) {
      // Primero la selección y después la edición (MEMORY).
      _ref.read(bookingSelectionProvider.notifier).clear();
      _ref.read(editTargetProvider.notifier).end();
    }

    final original = EditOriginal.of(shown);
    var check = CancelCheck.notActive;
    try {
      final cancelled = await _ref
          .read(bookingRepositoryProvider)
          .cancelByClient(
            id: shown.id,
            expected: (current) {
              check = checkCancelBeforeSave(
                shown: original,
                current: current,
                nowSalon: toSalon(_ref.read(clockProvider)()),
                marginMinutes: margin,
              );
              return check == CancelCheck.ok;
            },
          );
      if (cancelled) return CancelOutcome.ok;
    } catch (error) {
      debugPrint('No se pudo cancelar el turno: $error');
      return CancelOutcome.failed;
    }
    return switch (check) {
      CancelCheck.notActive => CancelOutcome.notActive,
      CancelCheck.changed => CancelOutcome.changed,
      CancelCheck.notCancellable => CancelOutcome.notCancellable,
      // La transacción no canceló aunque la comprobación diera ok: no
      // debería pasar; se trata como un fallo que se puede reintentar.
      CancelCheck.ok => CancelOutcome.failed,
    };
  }
}

final appointmentCancelProvider = Provider(AppointmentCanceller.new);
