const _weekdayKeys = [
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
  'sunday',
];

/// Clave en inglés del día de la semana (`monday`…`sunday`), la que usa
/// `openingHours` en `settings/calendar`.
///
/// Sale de [DateTime.weekday] y no de un `DateFormat` con el nombre del día,
/// para que el cálculo de huecos no dependa del idioma de la interfaz.
String weekdayKey(DateTime date) => _weekdayKeys[date.weekday - 1];
