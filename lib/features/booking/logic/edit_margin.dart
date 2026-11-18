/// Opciones del margen de edición, sin Flutter ni Firebase (spec 008,
/// RF-36, RF-37; plan § 4.5).
library;

/// Sin margen, 1, 2, 3, 6, 12, 24, 48 y 72 horas, en minutos.
const editMarginOptions = [0, 60, 120, 180, 360, 720, 1440, 2880, 4320];

/// Las opciones del margen y, si el guardado [current] no es una de ellas,
/// también ese, en su lugar por orden (RF-37).
List<int> marginChoices(int current) => editMarginOptions.contains(current)
    ? editMarginOptions
    : ([...editMarginOptions, current]..sort());

/// [minutes] en horas y minutos, para mostrar un margen que no es una de las
/// opciones (RF-37).
({int hours, int minutes}) marginParts(int minutes) =>
    (hours: minutes ~/ 60, minutes: minutes % 60);
