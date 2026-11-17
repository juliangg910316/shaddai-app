/// Edición del turno activo, sin Flutter ni Firebase (spec 006, plan § 4).
///
/// Todas las funciones reciben "ahora" como parámetro. [isEditable] y
/// [startsWithinEditMargin] comparan instantes, así que no dependen de la
/// zona del dispositivo.
library;

import '../../../data/models/appointment_model.dart';
import '../../../data/models/booked_service_model.dart';
import '../../../data/models/calendar_settings_model.dart';
import '../../../data/models/price_list_model.dart';
import 'bookable_catalog.dart';
import 'booking_rules.dart';
import 'booking_selection.dart';
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
  EditOriginal original, {
  Iterable<BusyRange> closures = const [],
}) =>
    isSelectableDay(day, settings, window, closures: closures) ||
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

/// Un turno tal como se enseña en el antes y el después (plan § 4.4). Los
/// nombres van en los dos idiomas: la vista los traduce al pintarlos.
class BookingDraft {
  const BookingDraft({
    required this.day,
    required this.start,
    required this.end,
    required this.name,
    required this.addons,
    required this.durationMinutes,
    required this.totalCents,
    required this.totalFrom,
  });

  /// Día del salón, a las 0:00. `null` si aún no se eligió.
  final DateTime? day;

  /// Inicio y fin en hora de pared. `null` si aún no se eligió la hora.
  final DateTime? start;
  final DateTime? end;
  final BilingualText name;
  final List<BilingualText> addons;
  final int durationMinutes;
  final int totalCents;

  /// Si el total es "desde".
  final bool totalFrom;

  @override
  bool operator ==(Object other) =>
      other is BookingDraft &&
      other.day == day &&
      other.start == start &&
      other.end == end &&
      other.name.es == name.es &&
      other.name.pt == name.pt &&
      other.addons.length == addons.length &&
      [
        for (var i = 0; i < addons.length; i++)
          other.addons[i].es == addons[i].es &&
              other.addons[i].pt == addons[i].pt,
      ].every((same) => same) &&
      other.durationMinutes == durationMinutes &&
      other.totalCents == totalCents &&
      other.totalFrom == totalFrom;

  @override
  int get hashCode => Object.hash(
    day,
    start,
    end,
    name.es,
    name.pt,
    Object.hashAll([for (final addon in addons) '${addon.es}/${addon.pt}']),
    durationMinutes,
    totalCents,
    totalFrom,
  );
}

/// Lo guardado en el turno original.
BookingDraft draftOfOriginal(EditOriginal original) {
  final booked = original.booked;
  return BookingDraft(
    day: salonDay(original.start),
    start: original.start,
    end: original.end,
    name: booked?.name ?? BilingualText.empty,
    addons: [for (final addon in booked?.addons ?? const []) addon.name],
    durationMinutes: original.end.difference(original.start).inMinutes,
    totalCents: booked?.totalCents ?? 0,
    totalFrom: booked?.priceFrom ?? false,
  );
}

/// Lo elegido en [selection], con los precios y la duración actuales de
/// [catalog]. Los adicionales van en el orden del catálogo. `null` sin
/// servicio o si ya no se puede reservar.
BookingDraft? draftOfSelection(
  BookingSelection selection,
  BookableCatalog catalog,
) {
  final item = selection.item;
  if (item == null) return null;
  final bookable = findBookable(catalog, item);
  if (bookable == null) return null;
  final addons = [
    for (final addon in availableAddons(catalog, item))
      if (selection.addonIds.contains(addon.id)) addon,
  ];
  final total = totalPrice(bookable, addons);
  final start = selection.start;
  return BookingDraft(
    day: selection.day,
    start: start,
    end: start?.add(Duration(minutes: bookable.durationMinutes)),
    name: bookable.name,
    addons: [for (final addon in addons) addon.name],
    durationMinutes: bookable.durationMinutes,
    totalCents: total.cents,
    totalFrom: total.from,
  );
}

/// Un valor del turno que se enseña en el antes y el después.
enum EditField { date, start, end, item, addons, duration, total }

/// Los valores que cambian de [before] a [after] (RF-11, RF-17, RF-28). El
/// inicio y el fin se comparan por la hora del día: si solo cambia el día,
/// cambia la fecha.
Set<EditField> changedFields(BookingDraft before, BookingDraft after) {
  bool sameText(BilingualText a, BilingualText b) =>
      a.es == b.es && a.pt == b.pt;
  bool sameTime(DateTime? a, DateTime? b) =>
      a?.hour == b?.hour && a?.minute == b?.minute;
  String key(BilingualText text) => '${text.es}\u0000${text.pt}';
  bool sameAddons(List<BilingualText> a, List<BilingualText> b) {
    if (a.length != b.length) return false;
    final rest = [for (final text in a) key(text)];
    for (final text in b) {
      if (!rest.remove(key(text))) return false;
    }
    return true;
  }

  return {
    if (before.day != after.day) EditField.date,
    if (!sameTime(before.start, after.start)) EditField.start,
    if (!sameTime(before.end, after.end)) EditField.end,
    if (!sameText(before.name, after.name)) EditField.item,
    if (!sameAddons(before.addons, after.addons)) EditField.addons,
    if (before.durationMinutes != after.durationMinutes) EditField.duration,
    if (before.totalCents != after.totalCents ||
        before.totalFrom != after.totalFrom)
      EditField.total,
  };
}

/// Resultado de la comprobación antes de guardar la edición.
enum EditCheck {
  ok,

  /// El turno ya no está activo: borrado, cancelado o terminado (RF-15).
  notActive,

  /// Alguien cambió el turno desde que se abrió la edición (RF-15).
  changed,

  /// Ya está dentro del margen de edición (RF-15).
  notEditable,

  /// La hora nueva ya no es libre (RF-14; spec 005, RF-29).
  slotTaken,

  /// El servicio ya no cabe en la hora nueva (RF-14; spec 005, RF-30).
  doesNotFit,
}

/// Comprueba otra vez, justo antes de guardar, la edición de [original]
/// (RF-12). [current] es el turno leído del servidor (`null` si ya no
/// existe); [start] y [durationMinutes], lo elegido; [busy], los turnos
/// ocupados del día de [start] sin el propio.
///
/// El orden da el motivo más útil: si la admin canceló el turno, "ya no está
/// activo" explica más que "cambió".
EditCheck checkEditBeforeSave({
  required EditOriginal original,
  required AppointmentModel? current,
  required DateTime start,
  required int durationMinutes,
  required CalendarSettingsModel settings,
  required Iterable<BusyRange> busy,
  Iterable<BusyRange> closures = const [],
  required DateTime nowSalon,
  required int marginMinutes,
}) {
  if (current == null ||
      !activeStatuses.contains(current.status) ||
      !toSalon(current.endTime).isAfter(nowSalon)) {
    return EditCheck.notActive;
  }
  final now = EditOriginal.of(current);
  if (now.start != original.start ||
      now.end != original.end ||
      now.status != original.status ||
      now.booked != original.booked) {
    return EditCheck.changed;
  }
  if (!isEditable(
    start: current.startTime,
    now: fromSalon(nowSalon),
    marginMinutes: marginMinutes,
    isBlocked: false,
  )) {
    return EditCheck.notEditable;
  }
  FreeSlot? slot;
  for (final free in editFreeSlots(
    day: salonDay(start),
    settings: settings,
    busy: [...busy, ...closures],
    nowSalon: nowSalon,
    original: original,
  )) {
    if (free.start == start) slot = free;
  }
  if (slot == null) return EditCheck.slotTaken;
  if (!fits(durationMinutes, slot)) return EditCheck.doesNotFit;
  return EditCheck.ok;
}
