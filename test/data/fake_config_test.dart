import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/closure_model.dart';

import '../helpers/fake_config.dart';

/// El calendario y los cierres en memoria, para los tests (spec 008, plan
/// § 9). Se comprueba que se porta como Firestore.
void main() {
  ClosureModel closure(String id, int startDay, int endDay) => ClosureModel(
    id: id,
    start: DateTime.utc(2026, 11, startDay, 3),
    end: DateTime.utc(2026, 11, endDay, 3),
  );

  test('watchClosures solo da los que terminan en "desde" o después, y '
      'cambia en vivo', () async {
    final config = FakeConfigRepository(
      closures: [closure('viejo', 1, 2), closure('nuevo', 20, 21)],
    );
    final seen = <List<String>>[];
    final sub = config
        .watchClosures(DateTime.utc(2026, 11, 10))
        .listen((list) => seen.add([for (final c in list) c.id]));
    await pumpEventQueue();
    config.emitClosures([closure('nuevo', 20, 21), closure('otro', 25, 26)]);
    await pumpEventQueue();
    await sub.cancel();
    expect(seen, [
      ['nuevo'],
      ['nuevo', 'otro'],
    ]);
    expect(config.closureRequests, [DateTime.utc(2026, 11, 10)]);
  });

  test('failClosures envía un error a quien escucha', () async {
    final config = FakeConfigRepository();
    final errors = <Object>[];
    final sub = config
        .watchClosures(DateTime.utc(2026, 11, 10))
        .listen((_) {}, onError: errors.add);
    await pumpEventQueue();
    config.failClosures('sin red');
    await pumpEventQueue();
    await sub.cancel();
    expect(errors, ['sin red']);
  });

  test('fetchClosures responde como watchClosures, o lanza el error', () async {
    final config = FakeConfigRepository(
      closures: [closure('viejo', 1, 2), closure('nuevo', 20, 21)],
    );
    final read = await config.fetchClosures(DateTime.utc(2026, 11, 10));
    expect([for (final c in read) c.id], ['nuevo']);
    config.fetchClosuresError = 'sin red';
    expect(
      config.fetchClosures(DateTime.utc(2026, 11, 10)),
      throwsA('sin red'),
    );
  });

  test('crear y borrar cierres los registra y los envía en vivo', () async {
    final config = FakeConfigRepository();
    final seen = <int>[];
    final sub = config
        .watchClosures(DateTime.utc(2026, 11, 1))
        .listen((list) => seen.add(list.length));
    await pumpEventQueue();
    await config.createClosure(closure('a', 20, 21));
    await config.deleteClosure('a');
    await pumpEventQueue();
    await sub.cancel();
    expect(config.created.single.id, 'a');
    expect(config.deleted, ['a']);
    expect(seen, [0, 1, 0]);
  });

  test('con saveError, guardar o borrar lanza el error y no cambia nada', () {
    final config = FakeConfigRepository(closures: [closure('a', 20, 21)])
      ..saveError = 'sin red';
    expect(config.createClosure(closure('b', 22, 23)), throwsA('sin red'));
    expect(config.deleteClosure('a'), throwsA('sin red'));
    expect(config.removeBlockedDate('2026-12-25'), throwsA('sin red'));
    expect(config.updateEditMargin(60), throwsA('sin red'));
    expect(config.closures.single.id, 'a');
    expect(config.created, isEmpty);
  });

  test('quitar una fecha bloqueada y cambiar el margen se ven en el '
      'calendario en vivo', () async {
    final config = FakeConfigRepository(
      settings: CalendarSettingsModel(
        openingHours: CalendarSettingsModel.defaultSettings().openingHours,
        globalSlotDurationMinutes: 60,
        blockedDates: const ['2026-12-24', '2026-12-25'],
      ),
    );
    final seen = <CalendarSettingsModel>[];
    final sub = config.getCalendarSettings().listen(seen.add);
    await pumpEventQueue();
    await config.removeBlockedDate('2026-12-25');
    await config.updateEditMargin(120);
    await pumpEventQueue();
    await sub.cancel();
    expect(config.removedBlockedDates, ['2026-12-25']);
    expect(config.margins, [120]);
    expect(seen.last.blockedDates, ['2026-12-24']);
    expect(seen.last.editMarginMinutes, 120);
  });

  test('updateSettings conserva el margen y las fechas bloqueadas, como '
      '`merge` sin esos campos', () async {
    final config = FakeConfigRepository(
      settings: CalendarSettingsModel(
        openingHours: CalendarSettingsModel.defaultSettings().openingHours,
        globalSlotDurationMinutes: 60,
        blockedDates: const ['2026-12-25'],
        editMarginMinutes: 60,
      ),
    );
    await config.updateSettings(
      CalendarSettingsModel(
        openingHours: const {},
        globalSlotDurationMinutes: 30,
        blockedDates: const [],
      ),
    );
    expect(config.settings.globalSlotDurationMinutes, 30);
    expect(config.settings.blockedDates, ['2026-12-25']);
    expect(config.settings.editMarginMinutes, 60);
    expect(config.updatedSettings, hasLength(1));
  });

  test('sin escuchas, emitClosures no falla', () {
    final config = FakeConfigRepository();
    expect(() => config.emitClosures(const []), returnsNormally);
  });
}
