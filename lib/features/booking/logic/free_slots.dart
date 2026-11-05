/// Horas libres de un día y su cobertura, sin Flutter ni Firebase (spec 005,
/// plan § 4.3). Todas las horas son horas de pared del salón
/// (`salon_time.dart`).
library;

import '../../../data/models/calendar_settings_model.dart';
import 'booking_window.dart';

/// Un turno ocupado, en horas de pared del salón: de [start] hasta antes de
/// [end].
typedef BusyRange = ({DateTime start, DateTime end});

/// Una hora libre y los minutos que hay desde ella hasta el siguiente turno
/// ocupado del día o, si no hay ninguno, hasta el cierre.
class FreeSlot {
  const FreeSlot({required this.start, required this.coverageMinutes});

  final DateTime start;
  final int coverageMinutes;

  @override
  bool operator ==(Object other) =>
      other is FreeSlot &&
      other.start == start &&
      other.coverageMinutes == coverageMinutes;

  @override
  int get hashCode => Object.hash(start, coverageMinutes);

  @override
  String toString() => 'FreeSlot($start, $coverageMinutes min)';
}

/// Las horas libres de [day], en orden (RF-4): las de la rejilla posteriores
/// a [nowSalon] que no caen dentro de ningún turno de [busy], cada una con su
/// cobertura.
List<FreeSlot> freeSlots({
  required DateTime day,
  required CalendarSettingsModel settings,
  required Iterable<BusyRange> busy,
  required DateTime nowSalon,
}) {
  final opening = openingOf(day, settings);
  final grid = dayGrid(day, settings);
  if (opening == null || grid == null) return const [];

  final starts = [for (final range in busy) range.start]..sort();

  final slots = <FreeSlot>[];
  for (final time in grid) {
    // Una hora igual a "ahora" ya no es libre.
    if (!time.isAfter(nowSalon)) continue;
    final inside = busy.any(
      (range) => !range.start.isAfter(time) && time.isBefore(range.end),
    );
    if (inside) continue;

    var limit = opening.close;
    for (final start in starts) {
      if (start.isAfter(time)) {
        if (start.isBefore(limit)) limit = start;
        break;
      }
    }
    slots.add(
      FreeSlot(start: time, coverageMinutes: limit.difference(time).inMinutes),
    );
  }
  return slots;
}

/// Si un servicio de [durationMinutes] cabe en [slot] (RF-12, RF-15).
bool fits(int durationMinutes, FreeSlot slot) =>
    durationMinutes <= slot.coverageMinutes;
