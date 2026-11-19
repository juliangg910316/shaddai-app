/// Los turnos del perfil, sin Flutter ni Firebase (spec 009, plan § 4.2).
///
/// Las funciones son genéricas sobre el tipo de turno, como las de la
/// reserva: lo leen con `times`. Reciben "ahora" como parámetro.
library;

import '../../booking/logic/booking_rules.dart';

/// El turno activo (o `null`) y el historial, del más reciente al más
/// antiguo.
typedef ProfileAppointments<T> = ({T? active, List<T> history});

/// Separa de [mine] el turno activo en [now] (el mismo que muestra la
/// reserva, spec 005) del resto, que es el historial (RF-1, RF-5, RF-20).
///
/// Con datos antiguos de dos turnos activos, solo el que empieza antes es el
/// activo; el otro va al historial con su estado ([HistoryLabel.upcoming]).
ProfileAppointments<T> profileAppointments<T>(
  Iterable<T> mine, {
  required AppointmentTimes Function(T appointment) times,
  required DateTime now,
}) {
  final active = activeAppointment(mine, times: times, now: now);
  final history = mine.toList();
  // Se quita una sola vez, por su posición: `identical` no sirve con
  // registros, que no tienen identidad garantizada.
  if (active != null) {
    history.removeAt(
      history.indexWhere((a) => identical(a, active) || a == active),
    );
  }
  history.sort((a, b) => times(b).start.compareTo(times(a).start));
  return (active: active, history: history);
}

/// La etiqueta de un turno del historial (RF-20, RF-21).
enum HistoryLabel {
  /// "Cancelado por ti".
  cancelledByYou,

  /// "Cancelado por el salón": cancelado sin `cancelledBy` (plan D-1).
  cancelledBySalon,

  /// "Realizado": confirmado y ya terminado.
  done,

  /// "No confirmado": terminó sin confirmarse ni cancelarse (RF-21).
  notConfirmed,

  /// Activo que aún no terminó y no es el turno activo (solo con datos
  /// antiguos): se muestra con su estado de siempre.
  upcoming,
}

/// La etiqueta de un turno con [status] que termina en [end], en [now]
/// (instantes). [cancelledByClient] dice si lo canceló la clienta.
HistoryLabel historyLabel({
  required String status,
  required bool cancelledByClient,
  required DateTime end,
  required DateTime now,
}) {
  if (status == 'cancelled') {
    return cancelledByClient
        ? HistoryLabel.cancelledByYou
        : HistoryLabel.cancelledBySalon;
  }
  if (end.isAfter(now) && activeStatuses.contains(status)) {
    return HistoryLabel.upcoming;
  }
  return status == 'confirmed' ? HistoryLabel.done : HistoryLabel.notConfirmed;
}
