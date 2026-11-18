class DaySchedule {
  final String open;
  final String close;
  final bool isClosed;

  DaySchedule({
    required this.open,
    required this.close,
    required this.isClosed,
  });

  factory DaySchedule.fromMap(Map<String, dynamic> data) {
    return DaySchedule(
      open: data['open'] ?? '09:00',
      close: data['close'] ?? '18:00',
      isClosed: data['isClosed'] ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {'open': open, 'close': close, 'isClosed': isClosed};
  }
}

class CalendarSettingsModel {
  final Map<String, DaySchedule> openingHours;
  final int globalSlotDurationMinutes;
  final List<String> blockedDates; // YYYY-MM-DD format

  /// Minutos antes del inicio de un turno a partir de los cuales la clienta
  /// ya no puede editarlo (spec 006, RF-21). Lo cambia la admin en la spec
  /// 008; hasta entonces solo se lee, y vale 0 si no está.
  final int editMarginMinutes;

  CalendarSettingsModel({
    required this.openingHours,
    required this.globalSlotDurationMinutes,
    required this.blockedDates,
    this.editMarginMinutes = 0,
  });

  /// Sin `openingHours` (falta, está vacío o no es un mapa), usa el horario
  /// por defecto, igual que si no hubiera documento: un documento creado a
  /// mano con solo el margen no deja el salón cerrado todos los días.
  factory CalendarSettingsModel.fromMap(Map<String, dynamic> data) {
    final hoursData = data['openingHours'];
    final parsedHours = <String, DaySchedule>{};
    if (hoursData is Map && hoursData.isNotEmpty) {
      hoursData.forEach((key, value) {
        parsedHours[key.toString()] = DaySchedule.fromMap(
          Map<String, dynamic>.from(value as Map),
        );
      });
    } else {
      parsedHours.addAll(CalendarSettingsModel.defaultSettings().openingHours);
    }

    final blocked = data['blockedDates'] as List<dynamic>? ?? [];

    return CalendarSettingsModel(
      openingHours: parsedHours,
      globalSlotDurationMinutes: data['globalSlotDurationMinutes'] ?? 60,
      blockedDates: blocked.map((e) => e.toString()).toList(),
      editMarginMinutes: _readMargin(data['editMarginMinutes']),
    );
  }

  /// Un entero ≥ 0 (también guardado como decimal sin parte fraccionaria);
  /// cualquier otra cosa vale 0 (constitución, principio 5).
  static int _readMargin(Object? value) {
    if (value is! num || value < 0 || value != value.roundToDouble()) return 0;
    return value.toInt();
  }

  factory CalendarSettingsModel.defaultSettings() {
    final defaultDay = DaySchedule(
      open: '09:00',
      close: '18:00',
      isClosed: false,
    );
    return CalendarSettingsModel(
      openingHours: {
        'monday': defaultDay,
        'tuesday': defaultDay,
        'wednesday': defaultDay,
        'thursday': defaultDay,
        'friday': defaultDay,
        'saturday': defaultDay,
        'sunday': DaySchedule(open: '09:00', close: '18:00', isClosed: true),
      },
      globalSlotDurationMinutes: 60,
      blockedDates: [],
    );
  }

  /// No escribe `editMarginMinutes` ni `blockedDates`: la admin guarda con
  /// `merge: true`, así que guardar el horario no pisa el margen (spec 006,
  /// plan D-4) ni vuelve a poner una fecha bloqueada que se acaba de quitar
  /// (spec 008, plan D-6). Cada uno se guarda con su propio método.
  Map<String, dynamic> toMap() {
    final hoursMap = <String, dynamic>{};
    openingHours.forEach((key, value) {
      hoursMap[key] = value.toMap();
    });
    return {
      'openingHours': hoursMap,
      'globalSlotDurationMinutes': globalSlotDurationMinutes,
    };
  }
}
