/// Edición del turno activo, sin Flutter ni Firebase (spec 006, plan § 4).
///
/// Todas las funciones reciben "ahora" como parámetro. [isEditable] y
/// [startsWithinEditMargin] comparan instantes, así que no dependen de la
/// zona del dispositivo.
library;

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
