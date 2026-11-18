/// Cancelar el turno activo, sin Flutter ni Firebase (spec 009, plan § 4.1).
///
/// Cancelar usa el mismo margen que editar (spec 006): se puede hasta antes
/// de su inicio menos el margen de edición. Todas las funciones reciben
/// "ahora" como parámetro.
library;

import '../../../data/models/appointment_model.dart';
import 'booking_edit.dart';
import 'booking_rules.dart';
import 'salon_time.dart';

/// Si la clienta puede cancelar su turno activo ahora.
enum CancelAvailability {
  /// El calendario aún carga: sin botón todavía.
  loading,

  /// No se pudo leer el margen: aviso con "Reintentar".
  error,

  /// "Cancelar turno" (RF-3).
  cancellable,

  /// Falta poco: explicación y WhatsApp (RF-4).
  closed,
}

/// Si se puede cancelar un turno que empieza en [start] (instante), con
/// "ahora" [now] (instante). [marginMinutes] es `null` mientras el calendario
/// carga; [settingsError] indica que no se pudo leer. No mira el bloqueo: una
/// clienta bloqueada puede cancelar (plan D-5).
CancelAvailability cancelAvailability({
  required bool settingsError,
  required int? marginMinutes,
  required DateTime start,
  required DateTime now,
}) {
  if (settingsError) return CancelAvailability.error;
  if (marginMinutes == null) return CancelAvailability.loading;
  return isEditable(
        start: start,
        now: now,
        marginMinutes: marginMinutes,
        isBlocked: false,
      )
      ? CancelAvailability.cancellable
      : CancelAvailability.closed;
}

/// Resultado de la comprobación justo antes de cancelar (RF-14).
enum CancelCheck {
  ok,

  /// El turno ya no está activo: borrado, cancelado o terminado.
  notActive,

  /// Cambió el día, la hora o lo reservado desde que la clienta lo vio.
  changed,

  /// Ya está dentro del margen de edición.
  notCancellable,
}

/// Comprueba otra vez, justo antes de cancelar, el turno que vio la clienta
/// ([shown]) contra el que está guardado ahora ([current], `null` si ya no
/// existe), con "ahora" del salón [nowSalon].
///
/// El estado no cuenta como cambio: si la admin solo lo confirmó, se cancela
/// igual (plan D-3). El orden da el motivo más útil, como en la edición:
/// "ya no está activo" antes que "cambió", y "cambió" antes que "falta poco".
CancelCheck checkCancelBeforeSave({
  required EditOriginal shown,
  required AppointmentModel? current,
  required DateTime nowSalon,
  required int marginMinutes,
}) {
  if (current == null ||
      !activeStatuses.contains(current.status) ||
      !toSalon(current.endTime).isAfter(nowSalon)) {
    return CancelCheck.notActive;
  }
  final now = EditOriginal.of(current);
  if (now.start != shown.start ||
      now.end != shown.end ||
      now.booked != shown.booked) {
    return CancelCheck.changed;
  }
  if (!isEditable(
    start: current.startTime,
    now: fromSalon(nowSalon),
    marginMinutes: marginMinutes,
    isBlocked: false,
  )) {
    return CancelCheck.notCancellable;
  }
  return CancelCheck.ok;
}
