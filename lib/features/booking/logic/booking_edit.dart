/// Edición del turno activo, sin Flutter ni Firebase (spec 006, plan § 4).
///
/// Todas las funciones reciben "ahora" como parámetro. [isEditable] y
/// [startsWithinEditMargin] comparan instantes, así que no dependen de la
/// zona del dispositivo.
library;

import '../../../data/models/appointment_model.dart';
import '../../../data/models/booked_service_model.dart';
import '../../../data/models/calendar_settings_model.dart';
import 'booking_window.dart';
import 'free_slots.dart';
import 'salon_time.dart';

/// Si la clienta puede editar un turno que empieza en [start]: no está
/// bloqueada y [now] es anterior a [start] menos [marginMinutes] (RF-1 a
/// RF-3). Con un margen de 30, un turno de las 10:00 es editable hasta antes
/// de las 9:30; con margen 0, hasta que empieza.
bool isEditable({
  required DateTime start,
  required DateTime now,
  required int marginMinutes,
  required bool isBlocked,
}) =>
    !isBlocked &&
    now.isBefore(start.subtract(Duration(minutes: marginMinutes)));

/// Si un turno que empieza en [start] ya nace dentro del margen de edición,
/// para avisar al reservarlo de que no se podrá cambiar (RF-23).
bool startsWithinEditMargin({
  required DateTime start,
  required DateTime now,
  required int marginMinutes,
}) => !now.isBefore(start.subtract(Duration(minutes: marginMinutes)));

/// Lo que ve la clienta bajo su turno activo.
enum EditAvailability {
  /// Está bloqueada: solo el aviso de bloqueo (spec 005, RF-37; D-6).
  blocked,

  /// No se pudo leer el margen: aviso con "Reintentar" (RF-22).
  error,

  /// El calendario aún carga: sin botón todavía.
  loading,

  /// Botón "Editar turno" (RF-1).
  editable,

  /// Ya no se puede cambiar: explicación y WhatsApp (RF-2).
  closed,
}

/// Qué se muestra bajo el turno activo que empieza en [start].
///
/// [marginMinutes] es `null` mientras el calendario carga; [settingsError]
/// indica que no se pudo leer.
EditAvailability editAvailability({
  required bool isBlocked,
  required bool settingsError,
  required int? marginMinutes,
  required DateTime start,
  required DateTime now,
}) {
  if (isBlocked) return EditAvailability.blocked;
  if (settingsError) return EditAvailability.error;
  if (marginMinutes == null) return EditAvailability.loading;
  return isEditable(
        start: start,
        now: now,
        marginMinutes: marginMinutes,
        isBlocked: false,
      )
      ? EditAvailability.editable
      : EditAvailability.closed;
}

/// Lo que tenía el turno al abrir la edición (plan § 4.2). Sirve como
/// excepción a las reglas actuales (RF-5, RF-8), como "antes" del diálogo
/// (RF-11) y para saber si alguien cambió el turno (RF-12).
class EditOriginal {
  const EditOriginal({
    required this.id,
    required this.start,
    required this.end,
    required this.status,
    required this.booked,
  });

  /// El turno [appointment], con sus horas en hora de pared del salón.
  factory EditOriginal.of(AppointmentModel appointment) => EditOriginal(
    id: appointment.id,
    start: toSalon(appointment.startTime),
    end: toSalon(appointment.endTime),
    status: appointment.status,
    booked: appointment.booked,
  );

  final String id;

  /// Inicio y fin en hora de pared del salón.
  final DateTime start;
  final DateTime end;
  final String status;

  /// Lo reservado. Todo turno de la spec 005 lo tiene; es `null` solo si el
  /// documento no se pudo leer bien.
  final BookedServiceModel? booked;
}

/// Si [day] se puede elegir en la edición: con las reglas de siempre o, si es
/// el día del turno original, aunque ya no las cumpla (RF-5, RF-9).
bool isEditDaySelectable(
  DateTime day,
  CalendarSettingsModel settings,
  BookingWindow window,
  EditOriginal original,
) =>
    isSelectableDay(day, settings, window) ||
    salonDay(day) == salonDay(original.start);

/// Las horas libres de [day] en la edición (RF-5, RF-7, RF-8). [busy] ya no
/// tiene el propio turno.
///
/// Son las de [freeSlots] y, en el día original, también su hora aunque esté
/// fuera de la rejilla o el día ya no abra, si aún no ha pasado y no la ocupa
/// otro turno. Su cobertura llega hasta el cierre o el fin original, lo que
/// sea más tarde, sin pasar del siguiente turno ocupado (D-3).
List<FreeSlot> editFreeSlots({
  required DateTime day,
  required CalendarSettingsModel settings,
  required Iterable<BusyRange> busy,
  required DateTime nowSalon,
  required EditOriginal original,
}) {
  final slots = freeSlots(
    day: day,
    settings: settings,
    busy: busy,
    nowSalon: nowSalon,
  );
  final start = original.start;
  if (salonDay(day) != salonDay(start)) return slots;
  if (!start.isAfter(nowSalon)) return slots;
  final inside = busy.any(
    (range) => !range.start.isAfter(start) && start.isBefore(range.end),
  );
  if (inside) return slots;
  if (slots.any((slot) => slot.start == start)) return slots;

  final close = openingOf(day, settings)?.close;
  var limit = close != null && close.isAfter(original.end)
      ? close
      : original.end;
  for (final range in busy) {
    if (range.start.isAfter(start) && range.start.isBefore(limit)) {
      limit = range.start;
    }
  }
  final own = FreeSlot(
    start: start,
    coverageMinutes: limit.difference(start).inMinutes,
  );
  return [...slots, own]..sort((a, b) => a.start.compareTo(b.start));
}
