import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/booking_rules.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/services/logic/price_list_view_logic.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';

import '../../helpers/fake_booking.dart';
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
}
