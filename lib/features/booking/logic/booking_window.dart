/// Ventana de reserva y días que se pueden elegir, sin Flutter ni Firebase
/// (spec 005, plan § 4.2). Todos los días y horas son horas de pared del
/// salón (`salon_time.dart`).
library;

import '../../../core/utils/weekday_key.dart';
import '../../../data/models/calendar_settings_model.dart';
import 'salon_time.dart';

/// Días después de hoy que se pueden reservar (los dos incluidos).
const bookingWindowDays = 60;

/// Paso de la rejilla de horas.
const slotStepMinutes = 30;

/// Desde hoy hasta [bookingWindowDays] días después, en días del salón.
class BookingWindow {
  const BookingWindow({required this.first, required this.last});

  final DateTime first;
  final DateTime last;

  bool contains(DateTime day) {
    final d = salonDay(day);
    return !d.isBefore(first) && !d.isAfter(last);
  }

  /// Los días de la ventana, en orden.
  Iterable<DateTime> get days sync* {
    for (var day = first; !day.isAfter(last); day = _nextDay(day)) {
      yield day;
    }
  }
}

DateTime _nextDay(DateTime day) =>
    DateTime.utc(day.year, day.month, day.day + 1);

/// La ventana de reserva con "ahora" del salón [nowSalon].
BookingWindow bookingWindow(DateTime nowSalon) {
  final first = salonDay(nowSalon);
  return BookingWindow(
    first: first,
    last: DateTime.utc(first.year, first.month, first.day + bookingWindowDays),
  );
}

/// La clave de [day] en `blockedDates`: `yyyy-MM-dd`.
String blockedDateKey(DateTime day) =>
    '${day.year.toString().padLeft(4, '0')}-'
    '${day.month.toString().padLeft(2, '0')}-'
    '${day.day.toString().padLeft(2, '0')}';

/// Minutos desde las 0:00 de una hora `HH:mm`, o `null` si no es válida.
int? _minutesOf(String time) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(time.trim());
  if (match == null) return null;
  final hours = int.parse(match.group(1)!);
  final minutes = int.parse(match.group(2)!);
  if (hours > 23 || minutes > 59) return null;
  return hours * 60 + minutes;
}

/// Apertura y cierre de [day], o `null` si ese día no abre: cerrado, sin
/// horario, con una hora no válida o con el cierre no posterior a la
/// apertura.
({DateTime open, DateTime close})? openingOf(
  DateTime day,
  CalendarSettingsModel settings,
) {
  final schedule = settings.openingHours[weekdayKey(day)];
  if (schedule == null || schedule.isClosed) return null;
  final open = _minutesOf(schedule.open);
  final close = _minutesOf(schedule.close);
  if (open == null || close == null || close <= open) return null;
  final d = salonDay(day);
  return (
    open: d.add(Duration(minutes: open)),
    close: d.add(Duration(minutes: close)),
  );
}

/// Las horas de inicio posibles de [day]: cada [slotStepMinutes] desde la
/// apertura y antes del cierre. `null` si ese día no abre.
List<DateTime>? dayGrid(DateTime day, CalendarSettingsModel settings) {
  final opening = openingOf(day, settings);
  if (opening == null) return null;
  return [
    for (
      var time = opening.open;
      time.isBefore(opening.close);
      time = time.add(const Duration(minutes: slotStepMinutes))
    )
      time,
  ];
}

/// Si [day] se puede elegir: dentro de [window], no bloqueado y abierto
/// (RF-3).
bool isSelectableDay(
  DateTime day,
  CalendarSettingsModel settings,
  BookingWindow window,
) =>
    window.contains(day) &&
    !settings.blockedDates.contains(blockedDateKey(day)) &&
    openingOf(day, settings) != null;

/// El día que se elige al abrir la reserva (RF-1): el primero de la ventana
/// que se puede elegir y tiene alguna hora libre ([hasFreeSlot]). Si ninguno
/// tiene, el primero que se puede elegir; si ninguno se puede elegir, `null`
/// (RF-2).
DateTime? initialDay({
  required DateTime nowSalon,
  required CalendarSettingsModel settings,
  required bool Function(DateTime day) hasFreeSlot,
}) {
  final window = bookingWindow(nowSalon);
  DateTime? firstSelectable;
  for (final day in window.days) {
    if (!isSelectableDay(day, settings, window)) continue;
    firstSelectable ??= day;
    if (hasFreeSlot(day)) return day;
  }
  return firstSelectable;
}
