import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/booking_edit.dart';
import 'package:shaddai/features/booking/logic/booking_rules.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_edit_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/services/logic/price_list_view_logic.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/fake_session.dart';

/// Martes 10 de noviembre de 2026 a las 10:00 en Curitiba.
final nowInstant = DateTime.utc(2026, 11, 10, 13);

/// Un turno de [testClient] con horas de pared del salón.
AppointmentModel appointment(
  String id,
  DateTime start,
  DateTime end, {
  String status = 'confirmed',
}) => AppointmentModel(
  id: id,
  clientId: testClient.uid,
  clientName: testClient.displayName,
  clientPhone: testClient.phoneNumber ?? '',
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

  /// Contenedor con [bookings], el reloj fijo y la ficha [user] (por
  /// defecto, [testClient]).
  ProviderContainer container([
    List<Override> extra = const [],
    Stream<UserModel?> Function()? user,
  ]) {
    final c = ProviderContainer(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookings),
        configRepositoryProvider.overrideWithValue(FakeConfigRepository()),
        clockProvider.overrideWithValue(() => nowInstant),
        currentUserProvider.overrideWith(
          (ref) => user?.call() ?? Stream.value(testClient),
        ),
        ...extra,
      ],
    );
    addTearDown(c.dispose);
    return c;
  }

  setUp(() => bookings = FakeBookingRepository());

  group('clockProvider y salonNowProvider', () {
    test('"ahora" del salón empieza con la hora del reloj', () async {
      final c = container();
      c.listen(salonNowProvider, (_, _) {});
      await settle();
      expect(c.read(salonNowProvider).value, DateTime.utc(2026, 11, 10, 10));
    });

    test('el reloj por defecto es DateTime.now', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      final before = DateTime.now();
      final now = c.read(clockProvider)();
      expect(now.isBefore(before), isFalse);
    });
  });

  group('deviceUtcOffsetProvider (RF-5)', () {
    test('por defecto, la diferencia del dispositivo', () {
      final c = ProviderContainer();
      addTearDown(c.dispose);
      expect(c.read(deviceUtcOffsetProvider), DateTime.now().timeZoneOffset);
    });

    test('se puede sustituir', () {
      final c = container([
        deviceUtcOffsetProvider.overrideWithValue(Duration.zero),
      ]);
      expect(c.read(deviceUtcOffsetProvider), Duration.zero);
    });
  });

  group('busySlotsProvider (RF-6)', () {
    test('pide la ventana de hoy a hoy + 60 días, en instantes', () async {
      final c = container();
      c.listen(busySlotsProvider, (_, _) {});
      await settle();
      expect(bookings.busyWindows, [
        (
          from: fromSalon(DateTime.utc(2026, 11, 10)),
          to: fromSalon(DateTime.utc(2027, 1, 10)),
        ),
      ]);
    });

    test('se actualiza cuando cambian los turnos ocupados', () async {
      final c = container();
      c.listen(busySlotsProvider, (_, _) {});
      await settle();
      expect(c.read(busySlotsProvider).value, isEmpty);

      final slot = BusySlot(
        id: 'x',
        start: fromSalon(DateTime.utc(2026, 11, 10, 11)),
        end: fromSalon(DateTime.utc(2026, 11, 10, 12)),
      );
      bookings.emitBusy([slot]);
      await settle();
      expect(c.read(busySlotsProvider).value, [slot]);
    });

    test(
      'no vuelve a pedir la ventana mientras sigue siendo el mismo día',
      () async {
        final now = StreamController<DateTime>();
        addTearDown(now.close);
        final c = container([
          salonNowProvider.overrideWith((ref) => now.stream),
        ]);
        c.listen(busySlotsProvider, (_, _) {});
        now.add(DateTime.utc(2026, 11, 10, 10));
        await settle();
        now.add(DateTime.utc(2026, 11, 10, 10, 30));
        await settle();
        expect(bookings.busyWindows, hasLength(1));

        now.add(DateTime.utc(2026, 11, 11, 0, 1));
        await settle();
        expect(bookings.busyWindows, hasLength(2));
        expect(
          bookings.busyWindows.last.from,
          fromSalon(DateTime.utc(2026, 11, 11)),
        );
      },
    );

    test(
      'busyRangesProvider da los turnos ocupados en hora del salón',
      () async {
        bookings = FakeBookingRepository(
          busy: [
            BusySlot(
              id: 'x',
              start: DateTime.utc(2026, 11, 10, 14),
              end: DateTime.utc(2026, 11, 10, 15),
            ),
          ],
        );
        final c = container();
        c.listen(busyRangesProvider, (_, _) {});
        await settle();
        expect(c.read(busyRangesProvider).value, [
          (
            start: DateTime.utc(2026, 11, 10, 11),
            end: DateTime.utc(2026, 11, 10, 12),
          ),
        ]);
      },
    );
  });

  group('bookableCatalogProvider (RF-10, RF-43, RF-47)', () {
    PriceView<BookableCatalog> catalogFor(PriceListState state) =>
        container([currentPriceListProvider.overrideWithValue(state)])
            .read(bookableCatalogProvider);

    test('cargando', () {
      expect(
        catalogFor(const PriceListLoading()),
        isA<PriceViewLoading<BookableCatalog>>(),
      );
    });

    test('no disponible', () {
      expect(
        catalogFor(const PriceListUnavailable()),
        isA<PriceViewUnavailable<BookableCatalog>>(),
      );
    });

    test('lista: el catálogo que se puede reservar', () {
      final view = catalogFor(
        const PriceListReady(
          PriceListModel(
            categories: [
              PriceCategoryModel(
                id: 'manos',
                name: BilingualText(es: 'Manos', pt: 'Mãos'),
                items: [
                  PriceItemModel(
                    id: 's1',
                    kind: PriceItemKind.service,
                    name: BilingualText(es: 'Manicura', pt: 'Manicure'),
                    priceCents: 3000,
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      expect(view, isA<PriceViewReady<BookableCatalog>>());
      final catalog = (view as PriceViewReady<BookableCatalog>).value;
      expect(catalog.categories.single.services.single.id, 's1');
    });
  });

  group('myAppointmentsProvider (RF-33)', () {
    test('escucha los turnos de la clienta con sesión', () async {
      final mine = [
        appointment(
          'a',
          DateTime.utc(2026, 11, 12, 9),
          DateTime.utc(2026, 11, 12, 10),
        ),
      ];
      bookings = FakeBookingRepository(mine: mine);
      final c = container();
      c.listen(myAppointmentsProvider, (_, _) {});
      await settle();
      expect(bookings.clientRequests, [testClient.uid]);
      expect(c.read(myAppointmentsProvider).value, mine);
    });

    test('sin sesión, ninguno y sin pedirlos', () async {
      final c = container(const [], () => Stream.value(null));
      c.listen(myAppointmentsProvider, (_, _) {});
      await settle();
      expect(bookings.clientRequests, isEmpty);
      expect(c.read(myAppointmentsProvider).value, isEmpty);
    });

    test('un cambio en la ficha no vuelve a pedirlos', () async {
      final user = StreamController<Object?>();
      addTearDown(user.close);
      final c = container(const [], () => user.stream.map((_) => testClient));
      c.listen(myAppointmentsProvider, (_, _) {});
      user.add(null);
      await settle();
      user.add(null); // otra versión de la misma ficha
      await settle();
      expect(bookings.clientRequests, [testClient.uid]);
    });
  });

  group('bookingScreenProvider (RF-33, RF-35, RF-49)', () {
    test(
      'cambia a la vista de reserva cuando termina el turno activo',
      () async {
        bookings = FakeBookingRepository(
          mine: [
            appointment(
              'a',
              DateTime.utc(2026, 11, 10, 10),
              DateTime.utc(2026, 11, 10, 11),
            ),
          ],
        );
        final now = StreamController<DateTime>();
        addTearDown(now.close);
        final c = container([
          salonNowProvider.overrideWith((ref) => now.stream),
        ]);
        c.listen(bookingScreenProvider, (_, _) {});
        now.add(DateTime.utc(2026, 11, 10, 10, 30));
        await settle();
        expect(
          c.read(bookingScreenProvider),
          isA<BookingScreenActive<AppointmentModel>>(),
        );

        now.add(DateTime.utc(2026, 11, 10, 11));
        await settle();
        expect(
          c.read(bookingScreenProvider),
          isA<BookingScreenBooking<AppointmentModel>>(),
        );
      },
    );

    test('cambia en vivo al cancelarse el turno activo', () async {
      final active = appointment(
        'a',
        DateTime.utc(2026, 11, 12, 9),
        DateTime.utc(2026, 11, 12, 10),
      );
      bookings = FakeBookingRepository(mine: [active]);
      final c = container();
      c.listen(bookingScreenProvider, (_, _) {});
      await settle();
      expect(
        c.read(bookingScreenProvider),
        isA<BookingScreenActive<AppointmentModel>>(),
      );

      bookings.emitMine([
        appointment(
          'a',
          DateTime.utc(2026, 11, 12, 9),
          DateTime.utc(2026, 11, 12, 10),
          status: 'cancelled',
        ),
      ]);
      await settle();
      expect(
        c.read(bookingScreenProvider),
        isA<BookingScreenBooking<AppointmentModel>>(),
      );
    });

    test('con un error en mis turnos, error (RF-49)', () async {
      final c = container();
      c.listen(bookingScreenProvider, (_, _) {});
      await settle();
      bookings.failMine(Exception('permission-denied'));
      await settle();
      expect(
        c.read(bookingScreenProvider),
        isA<BookingScreenError<AppointmentModel>>(),
      );
    });

    test('sin sesión, el aviso de sesión', () async {
      final c = container(const [], () => Stream.value(null));
      c.listen(bookingScreenProvider, (_, _) {});
      await settle();
      expect(
        c.read(bookingScreenProvider),
        isA<BookingScreenSignedOut<AppointmentModel>>(),
      );
    });

    test('la admin, su texto', () async {
      final c = container(
        const [],
        () => Stream.value(testClient.copyWith(role: 'admin')),
      );
      c.listen(bookingScreenProvider, (_, _) {});
      await settle();
      expect(
        c.read(bookingScreenProvider),
        isA<BookingScreenAdmin<AppointmentModel>>(),
      );
    });
  });

  group('bookingDataOverrides', () {
    test('sesión de prueba, "ahora" fijo y la vista de reserva', () async {
      final c = ProviderContainer(
        overrides: bookingDataOverrides(bookings: bookings),
      );
      addTearDown(c.dispose);
      c.listen(bookingScreenProvider, (_, _) {});
      c.listen(salonNowProvider, (_, _) {});
      await settle();
      expect(c.read(salonNowProvider).value, toSalon(bookingTestNow));
      expect(c.read(deviceUtcOffsetProvider), salonUtcOffset);
      expect(
        c.read(bookingScreenProvider),
        isA<BookingScreenBooking<AppointmentModel>>(),
      );
    });

    test('sin sesión', () async {
      final c = ProviderContainer(
        overrides: bookingDataOverrides(bookings: bookings, signedIn: false),
      );
      addTearDown(c.dispose);
      c.listen(bookingScreenProvider, (_, _) {});
      await settle();
      expect(
        c.read(bookingScreenProvider),
        isA<BookingScreenSignedOut<AppointmentModel>>(),
      );
    });
  });

  group('edición (spec 006)', () {
    // "Ahora": martes 10 a las 7:00 (bookingTestNow). El calendario por
    // defecto abre de 9:00 a 18:00.
    DateTime at(int hour, [int minute = 0]) =>
        DateTime.utc(2026, 11, 10, hour, minute);
    final today = DateTime.utc(2026, 11, 10);
    BilingualText text(String es) => BilingualText(es: es, pt: es);
    PriceItemModel service(String id, int minutes) => PriceItemModel(
      id: id,
      kind: PriceItemKind.service,
      name: text(id),
      priceCents: 3000,
      durationMinutes: minutes,
    );

    // s1 (45 min) con a1; short (30 min); long (90 min).
    final list = PriceListModel(
      categories: [
        PriceCategoryModel(
          id: 'manos',
          name: text('Manos'),
          items: [
            service('s1', 45),
            PriceItemModel(
              id: 'a1',
              kind: PriceItemKind.addon,
              name: text('a1'),
              priceCents: 1000,
            ),
            service('short', 30),
            service('long', 90),
          ],
        ),
      ],
    );
    const s1 = BookableRef(BookedKind.service, 's1');
    const short = BookableRef(BookedKind.service, 'short');

    /// Su turno activo: hoy de 9:00 a 9:45, s1 con a1.
    AppointmentModel mine({String status = 'confirmed'}) => AppointmentModel(
      id: 't1',
      clientId: testClient.uid,
      clientName: testClient.displayName,
      clientPhone: testClient.phoneNumber ?? '',
      startTime: fromSalon(at(9)),
      endTime: fromSalon(at(9, 45)),
      status: status,
      createdAt: DateTime.utc(2026, 11, 1),
      booked: BookedServiceModel(
        kind: BookedKind.service,
        id: 's1',
        name: text('s1'),
        priceCents: 3000,
        durationMinutes: 45,
        addons: [
          BookedAddonModel(id: 'a1', name: text('a1'), priceCents: 1000),
        ],
      ),
    );

    BusySlot slot(String id, DateTime start, DateTime end) =>
        BusySlot(id: id, start: fromSalon(start), end: fromSalon(end));

    late StateProvider<PriceListState> priceState;

    ProviderContainer editing({
      Stream<UserModel?> Function()? user,
      Stream<DateTime> Function()? now,
      Stream<CalendarSettingsModel> Function()? settings,
    }) {
      priceState = StateProvider<PriceListState>((ref) => PriceListReady(list));
      final c = ProviderContainer(
        overrides: [
          ...bookingDataOverrides(
            bookings: bookings,
            userStream: user,
            nowStream: now,
            settingsStream: settings,
          ),
          currentPriceListProvider.overrideWith((ref) => ref.watch(priceState)),
        ],
      );
      addTearDown(c.dispose);
      c.listen(bookingSelectionProvider, (_, _) {});
      c.listen(bookingScreenProvider, (_, _) {});
      c.listen(editAvailabilityProvider, (_, _) {});
      return c;
    }

    setUp(() {
      bookings = FakeBookingRepository(
        mine: [mine()],
        busy: [slot('t1', at(9), at(9, 45)), slot('x', at(11), at(12))],
      );
    });

    BookingSelection selection(ProviderContainer c) =>
        c.read(bookingSelectionProvider).selection;

    test('bookingScreenProvider: la edición mientras se edita el turno '
        'activo; al terminar, el turno (RF-4, RF-18)', () async {
      final c = editing();
      await settle();
      c.read(editTargetProvider.notifier).start(mine());
      expect(
        c.read(bookingScreenProvider),
        isA<BookingScreenEditing<AppointmentModel>>(),
      );
      c.read(editTargetProvider.notifier).end();
      expect(
        c.read(bookingScreenProvider),
        isA<BookingScreenActive<AppointmentModel>>(),
      );
    });

    test('empezar la edición carga lo del turno; terminarla vuelve a la '
        'selección vacía (RF-4, RF-18)', () async {
      final c = editing();
      await settle();
      c.read(editTargetProvider.notifier).start(mine());
      await settle();
      expect(
        selection(c),
        BookingSelection(
          day: today,
          start: at(9),
          item: s1,
          addonIds: const {'a1'},
        ),
      );

      c.read(editTargetProvider.notifier).end();
      await settle();
      expect(selection(c).start, isNull);
      expect(selection(c).item, isNull);
      expect(selection(c).addonIds, isEmpty);
    });

    test('el propio turno no cuenta como ocupado, y su hora sale libre '
        '(RF-7)', () async {
      final c = editing();
      c.listen(busyRangesProvider, (_, _) {});
      await settle();
      expect(c.read(busyRangesProvider).value, hasLength(2));
      expect(
        c.read(freeSlotsOfDayProvider(today))!.map((s) => s.start),
        isNot(contains(at(9))),
      );

      c.read(editTargetProvider.notifier).start(mine());
      await settle();
      expect(c.read(busyRangesProvider).value, [(start: at(11), end: at(12))]);
      expect(
        c.read(freeSlotsOfDayProvider(today))!.map((s) => s.start),
        contains(at(9)),
      );
      expect(c.read(selectedFreeSlotProvider)?.start, at(9));
    });

    group('editAvailabilityProvider (RF-1 a RF-3, RF-22)', () {
      test('editable con margen 0; sin turno activo, null', () async {
        bookings.mine = const [];
        final none = editing();
        await settle();
        expect(none.read(editAvailabilityProvider), isNull);

        bookings.mine = [mine()];
        final c = editing();
        await settle();
        expect(c.read(editAvailabilityProvider), EditAvailability.editable);
      });

      test('cambia al pasar el tiempo', () async {
        final now = StreamController<DateTime>.broadcast();
        addTearDown(now.close);
        final c = editing(
          now: () async* {
            yield at(7);
            yield* now.stream;
          },
        );
        await settle();
        expect(c.read(editAvailabilityProvider), EditAvailability.editable);
        now.add(at(9));
        await settle();
        expect(c.read(editAvailabilityProvider), EditAvailability.closed);
      });

      test(
        'cambia al cambiar el margen, y avisa si no se puede leer',
        () async {
          final calendar = StreamController<CalendarSettingsModel>.broadcast();
          addTearDown(calendar.close);
          final defaults = CalendarSettingsModel.defaultSettings();
          CalendarSettingsModel withMargin(int minutes) =>
              CalendarSettingsModel(
                openingHours: defaults.openingHours,
                globalSlotDurationMinutes: defaults.globalSlotDurationMinutes,
                blockedDates: defaults.blockedDates,
                editMarginMinutes: minutes,
              );
          final c = editing(settings: () => calendar.stream);
          await settle();
          expect(c.read(editAvailabilityProvider), EditAvailability.loading);

          calendar.add(withMargin(0));
          await settle();
          expect(c.read(editAvailabilityProvider), EditAvailability.editable);

          calendar.add(withMargin(180)); // 7:00 está a menos de 3 h de las 9:00
          await settle();
          expect(c.read(editAvailabilityProvider), EditAvailability.closed);

          calendar.addError(Exception('permission-denied'));
          await settle();
          expect(c.read(editAvailabilityProvider), EditAvailability.error);
        },
      );

      test('cambia al bloquearla', () async {
        final users = StreamController<UserModel?>.broadcast();
        addTearDown(users.close);
        final c = editing(
          user: () async* {
            yield testClient;
            yield* users.stream;
          },
        );
        await settle();
        expect(c.read(editAvailabilityProvider), EditAvailability.editable);
        users.add(testClient.copyWith(isBlocked: true));
        await settle();
        expect(c.read(editAvailabilityProvider), EditAvailability.blocked);
      });
    });

    test('bloquearla mientras edita termina la edición, sin aviso (casos '
        'límite)', () async {
      final users = StreamController<UserModel?>.broadcast();
      addTearDown(users.close);
      final c = editing(
        user: () async* {
          yield testClient;
          yield* users.stream;
        },
      );
      await settle();
      c.read(editTargetProvider.notifier).start(mine());
      await settle();
      c.read(bookingSelectionProvider.notifier).consumeNotices();

      users.add(testClient.copyWith(isBlocked: true));
      await settle();
      expect(c.read(editTargetProvider), isNull);
      expect(c.read(bookingSelectionProvider).notices, isEmpty);
    });

    test('cancelar el turno mientras edita termina la edición y avisa '
        '(casos límite)', () async {
      final c = editing();
      await settle();
      c.read(editTargetProvider.notifier).start(mine());
      await settle();

      bookings.emitMine([mine(status: 'cancelled')]);
      await settle();
      expect(c.read(editTargetProvider), isNull);
      expect(c.read(bookingSelectionProvider).notices, [
        const BookingNotice(BookingNoticeKind.editNotActive),
      ]);
    });

    test('confirmarlo mientras edita no la termina: lo detecta el guardado '
        '(RF-12)', () async {
      final c = editing();
      await settle();
      c
          .read(editTargetProvider.notifier)
          .start(mine(status: 'waiting_confirmation'));
      bookings.emitMine([mine()]);
      await settle();
      expect(c.read(editTargetProvider), isNotNull);
    });

    test(
      'requestItem en la edición usa requestItemInEdit (RF-27, RF-28)',
      () async {
        final c = editing();
        await settle();
        c.read(editTargetProvider.notifier).start(mine());
        await settle();
        c.read(bookingSelectionProvider.notifier).consumeNotices();

        c.read(bookingSelectionProvider.notifier).requestItem(short);
        expect(
          selection(c),
          BookingSelection(day: today, start: at(9), item: short),
        );
        expect(
          c.read(bookingSelectionProvider).notices.single.kind,
          BookingNoticeKind.editItemChanged,
        );
      },
    );

    test('requestItem en la edición con el catálogo cargando: se aplica al '
        'llegar (RF-27)', () async {
      final c = editing();
      await settle();
      c.read(editTargetProvider.notifier).start(mine());
      await settle();
      c.read(priceState.notifier).state = const PriceListLoading();
      await settle();
      c.read(bookingSelectionProvider.notifier).consumeNotices();

      c.read(bookingSelectionProvider.notifier).requestItem(short);
      expect(selection(c).item, s1);

      c.read(priceState.notifier).state = PriceListReady(list);
      await settle();
      expect(selection(c).item, short);
      expect(
        c.read(bookingSelectionProvider).notices.map((n) => n.kind),
        contains(BookingNoticeKind.editItemChanged),
      );
    });
  });
}
