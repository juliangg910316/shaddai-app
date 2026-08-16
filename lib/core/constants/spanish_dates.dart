/// Nombres de días y meses en español para la UI.
///
/// Se mantienen como constantes en vez de usar `DateFormat` con locale porque
/// la lógica de disponibilidad depende de `DateFormat('EEEE')` sin localizar
/// (ver `availableSlotsProvider`); inicializar datos de locale globalmente
/// rompería esa búsqueda por clave.
class SpanishDates {
  /// Índice 0 = enero.
  static const List<String> months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  /// Abreviatura de tres letras en mayúsculas. Índice 0 = enero.
  static const List<String> monthsShort = [
    'ENE',
    'FEB',
    'MAR',
    'ABR',
    'MAY',
    'JUN',
    'JUL',
    'AGO',
    'SEP',
    'OCT',
    'NOV',
    'DIC',
  ];

  /// Índice 0 = lunes (coincide con `DateTime.weekday - 1`).
  static const List<String> weekdays = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  /// Abreviatura de tres letras. Índice 0 = lunes.
  static const List<String> weekdaysShort = [
    'Lun',
    'Mar',
    'Mié',
    'Jue',
    'Vie',
    'Sáb',
    'Dom',
  ];

  /// Inicial de cada día para la cabecera del calendario: L M M J V S D.
  static const List<String> weekdayInitials = [
    'L',
    'M',
    'M',
    'J',
    'V',
    'S',
    'D',
  ];

  static String month(DateTime date) => months[date.month - 1];

  static String monthShort(DateTime date) => monthsShort[date.month - 1];

  static String weekday(DateTime date) => weekdays[date.weekday - 1];

  static String weekdayShort(DateTime date) => weekdaysShort[date.weekday - 1];

  static String weekdayInitial(DateTime date) =>
      weekdayInitials[date.weekday - 1];

  /// "Agosto 2026"
  static String monthAndYear(DateTime date) => '${month(date)} ${date.year}';

  /// "Sábado, 15 Ago 2026"
  static String longDate(DateTime date) {
    final abbr = monthShort(date);
    final capitalized = abbr[0] + abbr.substring(1).toLowerCase();
    return '${weekday(date)}, ${date.day} $capitalized ${date.year}';
  }
}
