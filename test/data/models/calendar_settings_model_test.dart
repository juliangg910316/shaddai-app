import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';

/// Margen de edición del calendario (spec 006, RF-21; plan § 2, D-4).
void main() {
  Map<String, dynamic> calendar([Map<String, dynamic> extra = const {}]) => {
    'openingHours': {
      'monday': {'open': '09:00', 'close': '18:00', 'isClosed': false},
    },
    'globalSlotDurationMinutes': 30,
    'blockedDates': ['2026-12-25'],
    ...extra,
  };

  group('editMarginMinutes se lee con tolerancia', () {
    for (final (label, value, expected) in [
      ('un entero', 30, 30),
      ('cero', 0, 0),
      ('un decimal sin parte fraccionaria', 45.0, 45),
      ('texto', '30', 0),
      ('negativo', -15, 0),
      ('decimal con parte fraccionaria', 12.5, 0),
      ('null', null, 0),
    ]) {
      test('$label → $expected', () {
        expect(
          CalendarSettingsModel.fromMap(calendar({'editMarginMinutes': value}))
              .editMarginMinutes,
          expected,
        );
      });
    }

    test('si falta, vale 0 (documentos de la 005)', () {
      expect(CalendarSettingsModel.fromMap(calendar()).editMarginMinutes, 0);
    });
  });

  group('sin horario, el horario por defecto (como sin documento)', () {
    final defaults = CalendarSettingsModel.defaultSettings().toMap();

    for (final (label, data) in [
      ('solo con el margen', <String, dynamic>{'editMarginMinutes': 1440}),
      ('con openingHours vacío', <String, dynamic>{'openingHours': {}}),
      (
        'con openingHours que no es un mapa',
        <String, dynamic>{'openingHours': 'lunes a sábado'},
      ),
    ]) {
      test(label, () {
        final settings = CalendarSettingsModel.fromMap(data);
        expect(settings.toMap()['openingHours'], defaults['openingHours']);
        expect(settings.globalSlotDurationMinutes, 60);
        expect(settings.blockedDates, isEmpty);
      });
    }

    test('conserva el margen guardado', () {
      expect(
        CalendarSettingsModel.fromMap({'editMarginMinutes': 1440})
            .editMarginMinutes,
        1440,
      );
    });

    test('un horario con solo algunos días se respeta tal cual', () {
      final settings = CalendarSettingsModel.fromMap(calendar());
      expect(settings.openingHours.keys, ['monday']);
    });
  });

  test('los ajustes por defecto tienen margen 0', () {
    expect(CalendarSettingsModel.defaultSettings().editMarginMinutes, 0);
  });

  test('toMap no escribe el margen ni las fechas bloqueadas, para que '
      'guardar el horario no los pise (spec 006, D-4; spec 008, D-6, '
      'RF-41)', () {
    final settings = CalendarSettingsModel.fromMap(
      calendar({'editMarginMinutes': 30}),
    );
    expect(settings.toMap(), {
      'openingHours': {
        'monday': {'open': '09:00', 'close': '18:00', 'isClosed': false},
      },
      'globalSlotDurationMinutes': 30,
    });
  });

  test('las fechas bloqueadas existentes se siguen leyendo (spec 008, '
      'RNF-4)', () {
    expect(CalendarSettingsModel.fromMap(calendar()).blockedDates, [
      '2026-12-25',
    ]);
    expect(
      CalendarSettingsModel.fromMap({...calendar(), 'blockedDates': null})
          .blockedDates,
      isEmpty,
    );
  });
}
