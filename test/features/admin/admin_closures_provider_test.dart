import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/closure_model.dart';
import 'package:shaddai/features/admin/providers/admin_closures_provider.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/booking/logic/closures.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/fake_session.dart';

/// Guardar y quitar cierres, y los cierres que ve la admin (spec 008, RF-1,
/// RF-3 a RF-9, RF-11; plan § 5).
///
/// "Ahora" es el martes 10/11/2026 a las 7:00 del salón (bookingTestNow).
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);
DateTime dayOf(int day) => DateTime.utc(2026, 11, day);

ClosureModel closure(String id, DateTime start, DateTime end) =>
    ClosureModel(id: id, start: fromSalon(start), end: fromSalon(end));

AppointmentModel appt(
  String id,
  DateTime start,
  DateTime end, {
  String status = 'confirmed',
}) => AppointmentModel(
  id: id,
  clientId: 'c-$id',
  clientName: id,
  clientPhone: '41 90000-0000',
  startTime: fromSalon(start),
  endTime: fromSalon(end),
  status: status,
  createdAt: DateTime.utc(2026, 11, 1),
);

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeBookingRepository bookings;
  late FakeConfigRepository config;
  late ProviderContainer c;

  Future<void> start({List<String> blockedDates = const []}) async {
    config.settings = CalendarSettingsModel(
      openingHours: CalendarSettingsModel.defaultSettings().openingHours,
      globalSlotDurationMinutes: 60,
      blockedDates: blockedDates,
    );
    c = ProviderContainer(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookings),
        configRepositoryProvider.overrideWithValue(config),
        clockProvider.overrideWithValue(() => bookingTestNow),
        salonNowProvider.overrideWith(
          (ref) => Stream.value(toSalon(bookingTestNow)),
        ),
      ],
    );
    addTearDown(c.dispose);
    await settle();
  }

  setUp(() {
    bookings = FakeBookingRepository();
    config = FakeConfigRepository();
  });

  ClosureController controller() => c.read(closureControllerProvider);

  group('ClosureController.save (RF-3 a RF-6, RF-11)', () {
    final wednesdayRange = RangeDraft(
      day: dayOf(11),
      fromMinutes: 13 * 60,
      toMinutes: 14 * 60 + 30,
    );

    test('con errores, no lee ni guarda, y los devuelve (RF-4)', () async {
      await start();
      final result = await controller().save(
        RangeDraft(day: dayOf(11), fromMinutes: 600, toMinutes: 600),
      );
      expect(result, isA<ClosureSaveInvalid>());
      expect((result as ClosureSaveInvalid).errors, {
        ClosureError.endNotAfterStart,
      });
      expect(bookings.activeFetches, isEmpty);
      expect(config.created, isEmpty);
    });

    test('con turnos que chocan, no guarda y los devuelve en orden '
        '(RF-5)', () async {
      bookings.active = [
        appt('tarde', at(11, 14), at(11, 15)),
        appt('fuera', at(11, 15), at(11, 16)),
        appt('pronto', at(11, 12, 30), at(11, 13, 15)),
        appt('cancelado', at(11, 13), at(11, 14), status: 'cancelled'),
      ];
      await start();

      final result = await controller().save(wednesdayRange);

      expect(result, isA<ClosureSaveConflicts>());
      expect(
        [for (final a in (result as ClosureSaveConflicts).appointments) a.id],
        ['pronto', 'tarde'],
      );
      expect(config.created, isEmpty);
    });

    test('lee del servidor los turnos activos desde "ahora", justo antes de '
        'guardar (RF-6)', () async {
      await start();
      await controller().save(wednesdayRange);
      expect(bookings.activeFetches, [bookingTestNow]);
    });

    test(
      'sin choques, guarda el inicio y el fin como instantes (RF-6)',
      () async {
        await start();

        final result = await controller().save(wednesdayRange);

        expect(result, isA<ClosureSaveOk>());
        final saved = config.created.single;
        expect(saved.start, fromSalon(at(11, 13)));
        expect(saved.end, fromSalon(at(11, 14, 30)));
        expect(saved.id, hasLength(36));
      },
    );

    test('unos días enteros van de las 0:00 a las 0:00 del día siguiente al '
        'último', () async {
      await start();
      await controller().save(
        DaysDraft(firstDay: dayOf(20), lastDay: dayOf(22)),
      );
      final saved = config.created.single;
      expect(saved.start, fromSalon(dayOf(20)));
      expect(saved.end, fromSalon(dayOf(23)));
    });

    test('si no se pueden leer los turnos, no guarda (RF-11)', () async {
      bookings.activeFetchError = Exception('sin red');
      await start();
      expect(await controller().save(wednesdayRange), isA<ClosureSaveFailed>());
      expect(config.created, isEmpty);
    });

    test('si no se puede guardar, failed (RF-11)', () async {
      config.saveError = Exception('sin red');
      await start();
      expect(await controller().save(wednesdayRange), isA<ClosureSaveFailed>());
    });
  });

  group('ClosureController.delete (RF-7, RF-8, RF-11)', () {
    test('un cierre guardado se borra', () async {
      config.closures = [closure('c1', at(11, 13), at(11, 14))];
      await start();
      final entry = ClosureEntry(
        source: const StoredClosureSource('c1'),
        start: at(11, 13),
        end: at(11, 14),
        kind: ClosureKind.range,
      );
      expect(await controller().delete(entry), isTrue);
      expect(config.deleted, ['c1']);
    });

    test('una fecha bloqueada existente se quita de la lista', () async {
      await start(blockedDates: ['2026-12-25']);
      final entry = ClosureEntry(
        source: const BlockedDateSource('2026-12-25'),
        start: DateTime.utc(2026, 12, 25),
        end: DateTime.utc(2026, 12, 26),
        kind: ClosureKind.days,
      );
      expect(await controller().delete(entry), isTrue);
      expect(config.removedBlockedDates, ['2026-12-25']);
    });

    test('si falla, false y no cambia nada', () async {
      config.closures = [closure('c1', at(11, 13), at(11, 14))];
      config.saveError = Exception('sin red');
      await start();
      final entry = ClosureEntry(
        source: const StoredClosureSource('c1'),
        start: at(11, 13),
        end: at(11, 14),
        kind: ClosureKind.range,
      );
      expect(await controller().delete(entry), isFalse);
      expect(config.closures, hasLength(1));
    });
  });

  group('adminClosureEntriesProvider (RF-1, RF-2, RF-8, RF-10)', () {
    test('los cierres próximos y las fechas bloqueadas, en orden', () async {
      config.closures = [
        closure('tarde', at(20, 13), at(20, 14)),
        closure('pronto', at(12, 10), at(12, 11)),
      ];
      await start(blockedDates: ['2026-11-15', '2026-11-01']);
      c.listen(adminClosureEntriesProvider, (_, _) {});
      await settle();

      final entries = c.read(adminClosureEntriesProvider).value!;
      expect(
        [for (final e in entries) e.source],
        [
          const StoredClosureSource('pronto'),
          const BlockedDateSource('2026-11-15'),
          const StoredClosureSource('tarde'),
        ],
      );
    });

    test('cambia en vivo al crear o quitar uno', () async {
      await start();
      c.listen(adminClosureEntriesProvider, (_, _) {});
      await settle();
      expect(c.read(adminClosureEntriesProvider).value, isEmpty);

      config.emitClosures([closure('c1', at(12, 10), at(12, 11))]);
      await settle();
      expect(c.read(adminClosureEntriesProvider).value, hasLength(1));
    });

    test('con un error de los cierres, el error (RF-10)', () async {
      await start();
      c.listen(adminClosureEntriesProvider, (_, _) {});
      await settle();
      config.failClosures(Exception('sin red'));
      await settle();
      expect(c.read(adminClosureEntriesProvider).hasError, isTrue);
    });
  });

  group('adminDayClosuresProvider (RF-9, RF-10)', () {
    test('los cierres y las fechas bloqueadas del día de la agenda', () async {
      config.closures = [
        closure('franja', at(12, 13), at(12, 14)),
        closure('varios', dayOf(11), dayOf(14)),
        closure('otro', at(20, 9), at(20, 10)),
      ];
      await start(blockedDates: ['2026-11-12', '2026-11-13']);
      c.read(adminSelectedDateProvider.notifier).state = DateTime(2026, 11, 12);
      c.listen(adminDayClosuresProvider, (_, _) {});
      await settle();

      expect(
        [for (final e in c.read(adminDayClosuresProvider).value!) e.source],
        [
          const StoredClosureSource('varios'),
          const BlockedDateSource('2026-11-12'),
          const StoredClosureSource('franja'),
        ],
      );
    });

    test('también en un día pasado: pide los cierres desde ese día', () async {
      config.closures = [closure('ayer', at(9, 13), at(9, 14))];
      await start();
      c.read(adminSelectedDateProvider.notifier).state = DateTime(2026, 11, 9);
      c.listen(adminDayClosuresProvider, (_, _) {});
      await settle();

      expect(config.closureRequests.last, fromSalon(dayOf(9)));
      expect(
        [for (final e in c.read(adminDayClosuresProvider).value!) e.source],
        [const StoredClosureSource('ayer')],
      );
    });

    test('con un error, el error (RF-10)', () async {
      await start();
      c.read(adminSelectedDateProvider.notifier).state = DateTime(2026, 11, 12);
      c.listen(adminDayClosuresProvider, (_, _) {});
      await settle();
      config.failClosures(Exception('sin red'));
      await settle();
      expect(c.read(adminDayClosuresProvider).hasError, isTrue);
    });
  });
}
