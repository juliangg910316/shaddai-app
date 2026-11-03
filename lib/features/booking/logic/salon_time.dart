/// Hora del salón (Curitiba), sin Flutter ni Firebase (spec 005, plan § 4.1).
///
/// La "hora de pared" es un `DateTime` UTC cuyos campos son la hora de
/// Curitiba: no depende de la zona del dispositivo y `DateFormat` la muestra
/// tal cual. Los instantes (lo que se guarda en Firestore) se convierten con
/// [toSalon] y [fromSalon].
library;

/// Diferencia de Curitiba con UTC. Sin horario de verano desde 2019: si
/// volviera, se cambia aquí (plan, D-3).
const salonUtcOffset = Duration(hours: -3);

/// La hora de pared del salón en el [instant] dado.
DateTime toSalon(DateTime instant) => instant.toUtc().add(salonUtcOffset);

/// El instante de la hora de pared [wall] del salón. Solo cuentan sus campos,
/// no su marca de zona.
DateTime fromSalon(DateTime wall) => DateTime.utc(
  wall.year,
  wall.month,
  wall.day,
  wall.hour,
  wall.minute,
  wall.second,
  wall.millisecond,
  wall.microsecond,
).subtract(salonUtcOffset);

/// El día de la hora de pared [wall], a las 0:00.
DateTime salonDay(DateTime wall) =>
    DateTime.utc(wall.year, wall.month, wall.day);

/// Si un dispositivo con la diferencia con UTC [deviceOffset] muestra la
/// misma hora que el salón (RF-5).
bool deviceIsInSalonZone(Duration deviceOffset) =>
    deviceOffset == salonUtcOffset;
