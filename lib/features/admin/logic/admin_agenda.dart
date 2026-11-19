/// La agenda de la admin, sin Flutter ni Firebase (spec 010, plan § 4).
///
/// El día de la agenda es un día del salón: un `DateTime.utc` a las 0:00
/// con la fecha de Curitiba (plan D-1). Todas las funciones reciben "ahora"
/// como parámetro.
library;

import '../../../data/models/appointment_model.dart';
import '../../booking/logic/booking_edit.dart';
import '../../booking/logic/booking_rules.dart';
import '../../booking/logic/salon_time.dart';

/// Días que el calendario deja ir hacia atrás y hacia delante desde hoy
/// (RF-4).
const agendaPickerDays = 365;

/// El día del salón con el año, el mes y el día de [date], sea de pared o
/// local: así sirve también una fecha guardada antes de la spec 010.
DateTime agendaDay(DateTime date) =>
    DateTime.utc(date.year, date.month, date.day);

/// El día de hoy del salón, con "ahora" del salón [nowSalon] (RF-2).
DateTime agendaToday(DateTime nowSalon) => salonDay(nowSalon);

/// Los instantes de la medianoche del salón de [day] a la del día siguiente
/// (RF-1).
({DateTime from, DateTime to}) agendaRange(DateTime day) {
  final start = agendaDay(day);
  return (
    from: fromSalon(start),
    to: fromSalon(DateTime.utc(start.year, start.month, start.day + 1)),
  );
}

/// El primer y el último día que ofrece el calendario, con hoy [today]
/// (RF-4).
({DateTime first, DateTime last}) agendaPickerBounds(DateTime today) {
  final day = agendaDay(today);
  return (
    first: DateTime.utc(day.year, day.month, day.day - agendaPickerDays),
    last: DateTime.utc(day.year, day.month, day.day + agendaPickerDays),
  );
}

/// El día en que abre el calendario: [day], o el límite más cercano si se
/// llegó fuera con las flechas (plan D-10).
DateTime agendaPickerInitial(
  DateTime day,
  ({DateTime first, DateTime last}) bounds,
) {
  final shown = agendaDay(day);
  if (shown.isBefore(bounds.first)) return bounds.first;
  if (shown.isAfter(bounds.last)) return bounds.last;
  return shown;
}

/// Los contadores de la cabecera: los turnos del día sin cancelar y los que
/// esperan confirmación (RF-6, plan D-8).
({int total, int waiting}) agendaCounts(Iterable<AppointmentModel> day) {
  var total = 0;
  var waiting = 0;
  for (final appointment in day) {
    if (appointment.status == 'cancelled') continue;
    total++;
    if (appointment.status == 'waiting_confirmation') waiting++;
  }
  return (total: total, waiting: waiting);
}

/// Qué ofrece la agenda en un turno (RF-7 a RF-9).
enum AgendaActions {
  /// Cancelado o pasado y confirmado: sin botones, salvo WhatsApp.
  none,

  /// Activo: "Editar", "Cancelar" y, si espera, "Confirmar".
  active,

  /// Pasado sin confirmar: sin botones y con la marca "Sin confirmar".
  pastUnconfirmed,
}

/// Las acciones de un turno con [status] que termina en [end] (instante),
/// con "ahora" del salón [nowSalon]. Un turno en curso sigue activo; en su
/// fin ya es pasado (Definiciones de la spec).
AgendaActions agendaActions({
  required String status,
  required DateTime end,
  required DateTime nowSalon,
}) {
  if (!activeStatuses.contains(status)) return AgendaActions.none;
  if (toSalon(end).isAfter(nowSalon)) return AgendaActions.active;
  return status == 'waiting_confirmation'
      ? AgendaActions.pastUnconfirmed
      : AgendaActions.none;
}

/// Resultado de la comprobación justo antes de que la admin cancele (RF-15).
enum AdminCancelCheck {
  ok,

  /// Ya no está activo: borrado, cancelado o terminado.
  notActive,

  /// Cambió el día, la hora o lo reservado desde que se abrió el diálogo.
  changed,
}

/// Comprueba otra vez, justo antes de cancelar, el turno que vio la admin
/// ([shown]) contra el guardado ahora ([current], `null` si ya no existe),
/// con "ahora" del salón [nowSalon].
///
/// El estado no cuenta como cambio: si otro dispositivo solo lo confirmó, se
/// cancela igual. El margen de edición no cuenta: solo limita a la clienta
/// (plan D-2). "Ya no está activo" manda sobre "cambió".
AdminCancelCheck checkAdminCancelBeforeSave({
  required EditOriginal shown,
  required AppointmentModel? current,
  required DateTime nowSalon,
}) {
  if (current == null ||
      !activeStatuses.contains(current.status) ||
      !toSalon(current.endTime).isAfter(nowSalon)) {
    return AdminCancelCheck.notActive;
  }
  final now = EditOriginal.of(current);
  if (now.start != shown.start ||
      now.end != shown.end ||
      now.booked != shown.booked) {
    return AdminCancelCheck.changed;
  }
  return AdminCancelCheck.ok;
}

/// Si se puede confirmar el turno guardado ahora ([current]): solo si sigue
/// esperando confirmación y no ha terminado, con "ahora" del salón
/// [nowSalon]. Así no se reactiva un turno ya cancelado (plan D-4).
bool checkAdminConfirmBeforeSave({
  required AppointmentModel? current,
  required DateTime nowSalon,
}) =>
    current != null &&
    current.status == 'waiting_confirmation' &&
    toSalon(current.endTime).isAfter(nowSalon);
