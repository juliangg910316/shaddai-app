import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/free_slots.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/services/logic/price_list_view_logic.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';

// Horas de pared del salón. "Ahora" es el martes 10/11/2026 a las 7:00
// (bookingTestNow); el calendario por defecto abre de 9:00 a 18:00.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);
DateTime dayOf(int day) => DateTime.utc(2026, 11, day);

BilingualText text(String es) => BilingualText(es: es, pt: '$es (pt)');

/// s1 (45 min, R$ 30) con el adicional a1 (R$ 10); c1 (90 min, R$ 70).
PriceListModel priceList({bool s1Visible = true}) => PriceListModel(
  categories: [
    PriceCategoryModel(
      id: 'manos',
      name: text('Manos'),
      items: [
        PriceItemModel(
          id: 's1',
          kind: PriceItemKind.service,
          name: text('Manicura'),
          priceCents: 3000,
          durationMinutes: 45,
          visible: s1Visible,
        ),
        PriceItemModel(
          id: 'a1',
          kind: PriceItemKind.addon,
          name: text('Decoración'),
          priceCents: 1000,
        ),
        PriceItemModel(
          id: 's2',
          kind: PriceItemKind.service,
          name: text('Esmaltado'),
          priceCents: 2000,
          durationMinutes: 30,
        ),
      ],
    ),
  ],
  combos: [
    ComboModel(
      id: 'c1',
      name: text('Pies y manos'),
      priceCents: 7000,
      durationMinutes: 90,
    ),
  ],
);

const s1 = BookableRef(BookedKind.service, 's1');
const c1 = BookableRef(BookedKind.combo, 'c1');

BusySlot busy(String id, DateTime start, DateTime end) =>
    BusySlot(id: id, start: fromSalon(start), end: fromSalon(end));

/// La lista de precios que ve la app; el test la cambia.
final _priceState = StateProvider<PriceListState>(
  (ref) => PriceListReady(priceList()),
);

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeBookingRepository bookings;
  late StreamController<CalendarSettingsModel> calendar;
  late StreamController<DateTime> now;
  late ProviderContainer c;

  setUp(() async {
    bookings = FakeBookingRepository();
    calendar = StreamController<CalendarSettingsModel>.broadcast();
    now = StreamController<DateTime>.broadcast();
    c = ProviderContainer(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookings),
        currentUserProvider.overrideWith((ref) => Stream.value(testClient)),
        calendarSettingsProvider.overrideWith((ref) => calendar.stream),
        clockProvider.overrideWithValue(() => bookingTestNow),
        salonNowProvider.overrideWith((ref) => now.stream),
        currentPriceListProvider.overrideWith((ref) => ref.watch(_priceState)),
      ],
    );
    c.listen(bookingSelectionProvider, (_, _) {});
    // La pantalla de reserva escucha la ficha (bookingScreenProvider).
    c.listen(currentUserProvider, (_, _) {});
    calendar.add(CalendarSettingsModel.defaultSettings());
    now.add(toSalon(bookingTestNow));
    await settle();
  });

  tearDown(() async {
    c.dispose();
    await calendar.close();
    await now.close();
  });

  BookingSelection selection() => c.read(bookingSelectionProvider).selection;
  List<BookingNotice> notices() => c.read(bookingSelectionProvider).notices;
  BookingSelectionController controller() =>
      c.read(bookingSelectionProvider.notifier);

  /// La hora libre de [start] de hoy.
  FreeSlot slot(DateTime start) => freeSlots(
    day: salonDay(start),
    settings: CalendarSettingsModel.defaultSettings(),
    busy: const [],
    nowSalon: toSalon(bookingTestNow),
  ).firstWhere((s) => s.start == start);

  group('BookingSelectionController', () {
    test('empieza con el día de initialDay (RF-1)', () {
      expect(selection().day, dayOf(10));
      expect(notices(), isEmpty);
    });

    test('elige día, hora, servicio y adicionales', () {
      controller().selectSlot(slot(at(10, 9)));
      controller().selectItem(s1);
      controller().toggleAddon('a1');
      expect(
        selection(),
        BookingSelection(
          day: dayOf(10),
          start: at(10, 9),
          item: s1,
          addonIds: const {'a1'},
        ),
      );

      controller().selectDay(dayOf(11));
      expect(selection().start, isNull);
      expect(selection().item, s1);
    });

    test('guarda los avisos de una acción rechazada (RF-13)', () {
      controller().selectSlot(slot(at(10, 17, 30))); // 30 min hasta el cierre
      controller().selectItem(c1);
      expect(selection().item, isNull);
      expect(notices(), [
        const BookingNotice(BookingNoticeKind.needsLongerSlot, minutes: 90),
      ]);
    });

    test('consumeNotices los vacía', () {
      controller().selectSlot(slot(at(10, 17, 30)));
      controller().selectItem(c1);
      controller().consumeNotices();
      expect(notices(), isEmpty);
    });

    test(
      'al ocuparse la hora elegida, la quita y avisa (RF-6, RF-9)',
      () async {
        controller().selectSlot(slot(at(10, 9)));
        bookings.emitBusy([busy('x', at(10, 9), at(10, 10))]);
        await settle();
        expect(selection().start, isNull);
        expect(notices(), [const BookingNotice(BookingNoticeKind.slotGone)]);
      },
    );

    test('al pasar la hora elegida, la quita y avisa (RF-9)', () async {
      controller().selectSlot(slot(at(10, 9)));
      now.add(at(10, 9));
      await settle();
      expect(selection().start, isNull);
      expect(notices(), [const BookingNotice(BookingNoticeKind.slotGone)]);
    });

    test(
      'al ocultarse el servicio elegido, lo quita y avisa (RF-17)',
      () async {
        controller().selectItem(s1);
        controller().toggleAddon('a1');
        c.read(_priceState.notifier).state = PriceListReady(
          priceList(s1Visible: false),
        );
        await settle();
        expect(selection().item, isNull);
        expect(selection().addonIds, isEmpty);
        expect(notices(), [
          const BookingNotice(BookingNoticeKind.itemUnavailable),
        ]);
      },
    );

    test('al bloquearse la fecha elegida, pasa a otra y avisa', () async {
      controller().selectDay(dayOf(12));
      calendar.add(
        CalendarSettingsModel(
          openingHours: CalendarSettingsModel.defaultSettings().openingHours,
          globalSlotDurationMinutes: 60,
          blockedDates: const ['2026-11-12'],
        ),
      );
      await settle();
      expect(selection().day, dayOf(10));
      expect(notices(), [const BookingNotice(BookingNoticeKind.dateMoved)]);
    });

    test('con la lista cargando, requestItem espera y se aplica al llegar '
        '(RF-43)', () async {
      c.read(_priceState.notifier).state = const PriceListLoading();
      await settle();
      controller().requestItem(s1);
      expect(selection().item, s1);

      c.read(_priceState.notifier).state = PriceListReady(priceList());
      await settle();
      expect(selection().item, s1);
      expect(notices(), isEmpty);
    });

    test('un servicio pedido que no existe se quita y avisa (RF-44)', () async {
      c.read(_priceState.notifier).state = const PriceListLoading();
      await settle();
      controller().requestItem(const BookableRef(BookedKind.service, 'x'));

      c.read(_priceState.notifier).state = PriceListReady(priceList());
      await settle();
      expect(selection().item, isNull);
      expect(notices(), [
        const BookingNotice(BookingNoticeKind.itemUnavailable),
      ]);
    });

    test(
      'lo elegido se conserva al volver a leer el provider (RF-45)',
      () async {
        controller().selectItem(s1);
        final sub = c.listen(bookingSelectionProvider, (_, _) {});
        sub.close();
        await settle();
        expect(selection().item, s1);
      },
    );
  });

  group('bookingSubmitProvider', () {
    void choose() {
      controller().selectSlot(slot(at(10, 9)));
      controller().selectItem(s1);
      controller().toggleAddon('a1');
    }

    test(
      'con ok, guarda el turno con la copia de lo reservado (RF-27)',
      () async {
        choose();
        final result = await c.read(bookingSubmitProvider).confirm();

        expect(result, BookingSubmitResult.ok);
        final saved = bookings.created.single;
        expect(saved.clientId, testClient.uid);
        expect(saved.clientName, testClient.displayName);
        expect(saved.clientPhone, testClient.phoneNumber);
        expect(saved.status, 'waiting_confirmation');
        expect(saved.startTime.isAtSameMomentAs(fromSalon(at(10, 9))), isTrue);
        expect(
          saved.endTime.isAtSameMomentAs(fromSalon(at(10, 9, 45))),
          isTrue,
        );
        expect(saved.createdAt.isAtSameMomentAs(bookingTestNow), isTrue);
        expect(saved.booked!.toMap(), {
          'kind': 'service',
          'id': 's1',
          'name': {'es': 'Manicura', 'pt': 'Manicura (pt)'},
          'priceCents': 3000,
          'priceFrom': false,
          'durationMinutes': 45,
          'addons': [
            {
              'id': 'a1',
              'name': {'es': 'Decoración', 'pt': 'Decoración (pt)'},
              'priceCents': 1000,
            },
          ],
        });
        expect(saved.id, hasLength(36)); // UUID v4
      },
    );

    test(
      'comprueba en el servidor el día de la hora elegida (RF-26)',
      () async {
        choose();
        await c.read(bookingSubmitProvider).confirm();
        expect(bookings.checkRequests.single.clientId, testClient.uid);
        expect(
          bookings.checkRequests.single.from.isAtSameMomentAs(
            fromSalon(dayOf(10)),
          ),
          isTrue,
        );
        expect(
          bookings.checkRequests.single.to.isAtSameMomentAs(
            fromSalon(dayOf(11)),
          ),
          isTrue,
        );
      },
    );

    test('tras guardar, vacía la hora y lo reservado', () async {
      choose();
      await c.read(bookingSubmitProvider).confirm();
      expect(selection().start, isNull);
      expect(selection().item, isNull);
      expect(selection().day, dayOf(10));
    });

    test('hora ocupada: slotTaken, sin guardar, sin la hora y con lo '
        'reservado (RF-29)', () async {
      choose();
      bookings.checkData = (
        busy: [busy('x', at(10, 9), at(10, 10))],
        mine: const <AppointmentModel>[],
      );
      final result = await c.read(bookingSubmitProvider).confirm();
      expect(result, BookingSubmitResult.slotTaken);
      expect(bookings.created, isEmpty);
      expect(selection().start, isNull);
      expect(selection().item, s1);
      expect(selection().addonIds, {'a1'});
      expect(selection().day, dayOf(10));
    });

    test('ya no cabe: doesNotFit, sin guardar y sin la hora (RF-30)', () async {
      choose();
      bookings.checkData = (
        busy: [busy('x', at(10, 9, 30), at(10, 10))],
        mine: const <AppointmentModel>[],
      );
      final result = await c.read(bookingSubmitProvider).confirm();
      expect(result, BookingSubmitResult.doesNotFit);
      expect(bookings.created, isEmpty);
      expect(selection().start, isNull);
      expect(selection().item, s1);
    });

    test(
      'ya tiene un turno activo: alreadyActive, sin guardar (RF-36)',
      () async {
        choose();
        bookings.checkData = (
          busy: const <BusySlot>[],
          mine: [
            AppointmentModel(
              id: 'otro',
              clientId: testClient.uid,
              clientName: testClient.displayName,
              clientPhone: '',
              startTime: fromSalon(at(20, 9)),
              endTime: fromSalon(at(20, 10)),
              status: 'waiting_confirmation',
              createdAt: bookingTestNow,
            ),
          ],
        );
        final result = await c.read(bookingSubmitProvider).confirm();
        expect(result, BookingSubmitResult.alreadyActive);
        expect(bookings.created, isEmpty);
      },
    );

    final failures = <String, void Function(FakeBookingRepository)>{
      'la comprobación previa falla (sin conexión)': (b) =>
          b.checkError = Exception('unavailable'),
      'el guardado falla': (b) => b.saveError = Exception('permission-denied'),
      'se agota el tiempo al guardar': (b) =>
          b.saveError = TimeoutException('15 s'),
    };
    failures.forEach((name, fail) {
      test('$name: failed y conserva lo elegido (RF-31)', () async {
        choose();
        fail(bookings);
        final before = selection();
        final result = await c.read(bookingSubmitProvider).confirm();
        expect(result, BookingSubmitResult.failed);
        expect(bookings.created, isEmpty);
        expect(selection(), before);
      });
    });

    test('sin hora o sin servicio no guarda: failed (RF-24)', () async {
      controller().selectItem(s1);
      final result = await c.read(bookingSubmitProvider).confirm();
      expect(result, BookingSubmitResult.failed);
      expect(bookings.checkRequests, isEmpty);
    });
  });
}
