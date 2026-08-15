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
    return {
      'open': open,
      'close': close,
      'isClosed': isClosed,
    };
  }
}

class CalendarSettingsModel {
  final Map<String, DaySchedule> openingHours;
  final int globalSlotDurationMinutes;
  final List<String> blockedDates; // YYYY-MM-DD format

  CalendarSettingsModel({
    required this.openingHours,
    required this.globalSlotDurationMinutes,
    required this.blockedDates,
  });

  factory CalendarSettingsModel.fromMap(Map<String, dynamic> data) {
    final hoursMap = data['openingHours'] as Map<String, dynamic>? ?? {};
    final parsedHours = <String, DaySchedule>{};
    hoursMap.forEach((key, value) {
      parsedHours[key] = DaySchedule.fromMap(Map<String, dynamic>.from(value));
    });

    final blocked = data['blockedDates'] as List<dynamic>? ?? [];

    return CalendarSettingsModel(
      openingHours: parsedHours,
      globalSlotDurationMinutes: data['globalSlotDurationMinutes'] ?? 60,
      blockedDates: blocked.map((e) => e.toString()).toList(),
    );
  }
  
  factory CalendarSettingsModel.defaultSettings() {
    final defaultDay = DaySchedule(open: '09:00', close: '18:00', isClosed: false);
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
  
  Map<String, dynamic> toMap() {
    final hoursMap = <String, dynamic>{};
    openingHours.forEach((key, value) {
      hoursMap[key] = value.toMap();
    });
    return {
      'openingHours': hoursMap,
      'globalSlotDurationMinutes': globalSlotDurationMinutes,
      'blockedDates': blockedDates,
    };
  }
}
