import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/features/booking/logic/booking_edit.dart';
import 'package:shaddai/features/booking/logic/booking_rules.dart';
import 'package:shaddai/features/booking/logic/booking_window.dart';
import 'package:shaddai/features/booking/logic/free_slots.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';

/// Los casos compartidos de las reglas de horas (spec 012, RNF-2, plan D-4)
/// pasados por las funciones puras de la app. El servidor pasa los mismos en
/// `functions/test/agenda_rules_cases.test.ts`: si los dos dan lo mismo, la
/// app nunca ofrece una hora que el servidor vaya a rechazar.
///
/// La app decide en dos pasos: el día se puede elegir (`isSelectableDay`, o
/// `isEditDaySelectable` al editar) y la hora está entre las libres y el
/// servicio cabe (`checkSlot`, o `editFreeSlots` al editar).
Map<String, Object?> _readCases() =>
    jsonDecode(File('test/fixtures/agenda_rules_cases.json').readAsStringSync())
        as Map<String, Object?>;

DateTime _instant(Object? value) => DateTime.parse(value! as String);

BusyRange _wall(Map<String, Object?> range) => (
  start: toSalon(_instant(range['start'])),
  end: toSalon(_instant(range['end'])),
);

String _verdict(Map<String, Object?> c) {
  final settings = CalendarSettingsModel.fromMap(
    Map<String, dynamic>.from((c['settings'] as Map?) ?? const {}),
  );
  final now = _instant(c['now']);
  final nowSalon = toSalon(now);
  final admin = c['mode'] == 'admin';
  final window = bookingWindow(
    nowSalon,
    days: admin ? adminBookingWindowDays : bookingWindowDays,
  );
  // Los otros turnos que ocupan su hora: activos y sin terminar. En la app
  // son los turnos ocupados, que se borran al cancelar.
  final busy = [
    for (final raw in (c['busy'] as List?) ?? const [])
      if (activeStatuses.contains(
            (raw as Map)['status'] as String? ?? 'confirmed',
          ) &&
          _instant(raw['end']).isAfter(now))
        _wall(Map<String, Object?>.from(raw)),
  ];
  final closures = [
    for (final raw in (c['closures'] as List?) ?? const [])
      _wall(Map<String, Object?>.from(raw as Map)),
  ];
  final start = toSalon(_instant(c['start']));
  final duration = c['durationMinutes']! as int;
  final day = salonDay(start);
  final rawOriginal = c['original'] as Map?;

  if (rawOriginal == null) {
    if (!isSelectableDay(day, settings, window, closures: closures)) {
      return 'slot_taken';
    }
    return switch (checkSlot(
      start: start,
      durationMinutes: duration,
      settings: settings,
      busy: busy,
      closures: closures,
      nowSalon: nowSalon,
    )) {
      BookingCheck.ok => 'ok',
      BookingCheck.doesNotFit => 'does_not_fit',
      BookingCheck.slotTaken || BookingCheck.alreadyActive => 'slot_taken',
    };
  }

  final range = _wall(Map<String, Object?>.from(rawOriginal));
  final original = EditOriginal(
    id: 'original',
    start: range.start,
    end: range.end,
    status: 'confirmed',
    booked: null,
  );
  if (!isEditDaySelectable(
    day,
    settings,
    window,
    original,
    closures: closures,
  )) {
    return 'slot_taken';
  }
  FreeSlot? slot;
  for (final free in editFreeSlots(
    day: day,
    settings: settings,
    busy: [...busy, ...closures],
    nowSalon: nowSalon,
    original: original,
    allowStarted: admin,
  )) {
    if (free.start == start) slot = free;
  }
  if (slot == null) return 'slot_taken';
  return fits(duration, slot) ? 'ok' : 'does_not_fit';
}

void main() {
  final cases = (_readCases()['cases']! as List).cast<Map<String, Object?>>();

  test('hay casos de reserva y de edición, de la clienta y de la admin', () {
    expect(cases.where((c) => c['original'] == null), isNotEmpty);
    expect(cases.where((c) => c['original'] != null), isNotEmpty);
    expect(cases.where((c) => c['mode'] == 'admin'), isNotEmpty);
    expect(cases.map((c) => c['name']).toSet(), hasLength(cases.length));
  });

  for (final c in cases) {
    test('${c['name']}: ${c['verdict']}', () {
      expect(_verdict(c), c['verdict']);
    });
  }
}
