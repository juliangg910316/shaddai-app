/// Cierres de la agenda de la admin, sin Flutter ni Firebase (spec 008,
/// plan § 4.1). Todos los días y horas son horas de pared del salón
/// (`salon_time.dart`), salvo los cierres guardados y los turnos, que llegan
/// como instantes.
library;

import '../../../data/models/calendar_settings_model.dart';
import 'booking_rules.dart';
import 'booking_window.dart';
import 'free_slots.dart';
import 'salon_time.dart';

/// Paso de las horas de una franja (RF-3).
const closureStepMinutes = 15;

/// Lo que elige la admin al crear un cierre (RF-3).
sealed class ClosureDraft {
  const ClosureDraft();
}

/// Una franja: de [fromMinutes] a [toMinutes] (minutos desde las 0:00) de
/// [day].
class RangeDraft extends ClosureDraft {
  const RangeDraft({
    required this.day,
    required this.fromMinutes,
    required this.toMinutes,
  });

  /// Día del salón, a las 0:00.
  final DateTime day;
  final int fromMinutes;
  final int toMinutes;
}

/// Días enteros, de [firstDay] a [lastDay], los dos incluidos.
class DaysDraft extends ClosureDraft {
  const DaysDraft({required this.firstDay, required this.lastDay});

  final DateTime firstDay;
  final DateTime lastDay;
}

/// Lo que está mal en un cierre (RF-4).
enum ClosureError {
  /// La franja no termina después de su inicio.
  endNotAfterStart,

  /// El último día es anterior al primero.
  daysReversed,

  /// El cierre termina antes o en "ahora".
  past,

  /// Alguna fecha queda a más de 365 días de hoy.
  tooFar,
}

DateTime _addDays(DateTime day, int days) =>
    DateTime.utc(day.year, day.month, day.day + days);

/// Inicio y fin del cierre [draft], en hora de pared (plan § 2): una franja,
/// de su hora de inicio a la de fin; unos días enteros, de las 0:00 del
/// primero a las 0:00 del día siguiente al último.
BusyRange closureRange(ClosureDraft draft) => switch (draft) {
  RangeDraft(:final day, :final fromMinutes, :final toMinutes) => (
    start: salonDay(day).add(Duration(minutes: fromMinutes)),
    end: salonDay(day).add(Duration(minutes: toMinutes)),
  ),
  DaysDraft(:final firstDay, :final lastDay) => (
    start: salonDay(firstDay),
    end: _addDays(salonDay(lastDay), 1),
  ),
};

/// Lo que está mal en [draft] con "ahora" [nowSalon] (RF-4). Si el orden
/// está mal, no se mira si ya pasó. Un cierre que empezó y aún no terminó
/// vale: solo cuenta lo que queda.
Set<ClosureError> closureErrors(
  ClosureDraft draft, {
  required DateTime nowSalon,
  int windowDays = adminBookingWindowDays,
}) {
  final lastAllowed = _addDays(salonDay(nowSalon), windowDays);
  final errors = <ClosureError>{};
  final List<DateTime> days;
  switch (draft) {
    case RangeDraft(:final day, :final fromMinutes, :final toMinutes):
      if (toMinutes <= fromMinutes) errors.add(ClosureError.endNotAfterStart);
      days = [salonDay(day)];
    case DaysDraft(:final firstDay, :final lastDay):
      if (salonDay(lastDay).isBefore(salonDay(firstDay))) {
        errors.add(ClosureError.daysReversed);
      }
      days = [salonDay(firstDay), salonDay(lastDay)];
  }
  if (errors.isEmpty && !closureRange(draft).end.isAfter(nowSalon)) {
    errors.add(ClosureError.past);
  }
  if (days.any((d) => d.isAfter(lastAllowed))) errors.add(ClosureError.tooFar);
  return errors;
}

/// Franja o días enteros.
enum ClosureKind { range, days }

bool _isMidnight(DateTime wall) =>
    wall.hour == 0 &&
    wall.minute == 0 &&
    wall.second == 0 &&
    wall.millisecond == 0 &&
    wall.microsecond == 0;

/// El tipo de un cierre de [start] a [end] (hora de pared): días enteros si
/// los dos son las 0:00 (plan D-3). Una franja nunca termina a las 0:00.
ClosureKind closureKind(DateTime start, DateTime end) =>
    _isMidnight(start) && _isMidnight(end)
    ? ClosureKind.days
    : ClosureKind.range;

/// Si [a] y [b] se cruzan. Tocar el borde no cuenta (casos límite).
bool overlaps(BusyRange a, BusyRange b) =>
    a.start.isBefore(b.end) && b.start.isBefore(a.end);

/// Los turnos de [appointments] que chocan con [range] (hora de pared),
/// ordenados por su inicio (RF-5): esperando confirmación o confirmados,
/// que terminan después de [nowSalon] y cuyo tiempo se cruza con el cierre.
List<T> closureConflicts<T>(
  BusyRange range,
  Iterable<T> appointments, {
  required AppointmentTimes Function(T appointment) times,
  required DateTime nowSalon,
}) {
  final found = <(DateTime, T)>[];
  for (final appointment in appointments) {
    final t = times(appointment);
    if (!activeStatuses.contains(t.status)) continue;
    final start = toSalon(t.start);
    final end = toSalon(t.end);
    if (!end.isAfter(nowSalon)) continue;
    if (overlaps((start: start, end: end), range)) {
      found.add((start, appointment));
    }
  }
  found.sort((a, b) => a.$1.compareTo(b.$1));
  return [for (final (_, appointment) in found) appointment];
}

/// Un cierre guardado: su id y su inicio y fin como instantes.
typedef StoredClosure = ({String id, DateTime start, DateTime end});

/// De dónde sale un cierre de la lista: un cierre guardado o una fecha
/// bloqueada existente (RF-8). Se quitan de forma distinta.
sealed class ClosureSource {
  const ClosureSource();
}

class StoredClosureSource extends ClosureSource {
  const StoredClosureSource(this.id);

  final String id;

  @override
  bool operator ==(Object other) =>
      other is StoredClosureSource && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'StoredClosureSource($id)';
}

class BlockedDateSource extends ClosureSource {
  const BlockedDateSource(this.key);

  /// La fecha en `blockedDates`: `yyyy-MM-dd`.
  final String key;

  @override
  bool operator ==(Object other) =>
      other is BlockedDateSource && other.key == key;

  @override
  int get hashCode => key.hashCode;

  @override
  String toString() => 'BlockedDateSource($key)';
}

/// Un cierre tal como se lista, en hora de pared.
class ClosureEntry {
  const ClosureEntry({
    required this.source,
    required this.start,
    required this.end,
    required this.kind,
  });

  final ClosureSource source;
  final DateTime start;
  final DateTime end;
  final ClosureKind kind;

  BusyRange get range => (start: start, end: end);
}

final _dateKey = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// El día de la clave [key] (`yyyy-MM-dd`), o `null` si no es una fecha.
DateTime? _dayOfKey(String key) {
  final match = _dateKey.firstMatch(key);
  if (match == null) return null;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime.utc(year, month, day);
  if (date.year != year || date.month != month || date.day != day) {
    return null;
  }
  return date;
}

/// Los cierres próximos (RF-1, RF-8): los guardados en [closures] y las
/// fechas bloqueadas existentes de [blockedDates] como días enteros. Solo los
/// que terminan después de [nowSalon], ordenados por su inicio. Una fecha
/// bloqueada que no es una fecha se ignora (constitución, principio 5).
List<ClosureEntry> closureEntries({
  required Iterable<StoredClosure> closures,
  required Iterable<String> blockedDates,
  required DateTime nowSalon,
}) {
  final entries = <ClosureEntry>[
    for (final closure in closures)
      ClosureEntry(
        source: StoredClosureSource(closure.id),
        start: toSalon(closure.start),
        end: toSalon(closure.end),
        kind: closureKind(toSalon(closure.start), toSalon(closure.end)),
      ),
    for (final key in blockedDates)
      if (_dayOfKey(key) case final day?)
        ClosureEntry(
          source: BlockedDateSource(key),
          start: day,
          end: _addDays(day, 1),
          kind: ClosureKind.days,
        ),
  ];
  return entries.where((e) => e.end.isAfter(nowSalon)).toList()
    ..sort((a, b) => a.start.compareTo(b.start));
}

/// Los cierres de [entries] que se cruzan con [day] (RF-9).
List<ClosureEntry> closuresOfDay(Iterable<ClosureEntry> entries, DateTime day) {
  final d = salonDay(day);
  final range = (start: d, end: _addDays(d, 1));
  return [
    for (final entry in entries)
      if (overlaps(entry.range, range)) entry,
  ];
}

/// Si los cierres de [closures] cubren todo el horario de [day], sin huecos
/// (RF-13). Un día que ya no abre no cuenta: ya está cerrado.
bool isClosedAllDay(
  DateTime day,
  CalendarSettingsModel settings,
  Iterable<BusyRange> closures,
) {
  final opening = openingOf(day, settings);
  if (opening == null) return false;
  var covered = opening.open;
  while (covered.isBefore(opening.close)) {
    DateTime? next;
    for (final closure in closures) {
      if (!closure.start.isAfter(covered) && closure.end.isAfter(covered)) {
        if (next == null || closure.end.isAfter(next)) next = closure.end;
      }
    }
    if (next == null) return false;
    covered = next;
  }
  return true;
}
