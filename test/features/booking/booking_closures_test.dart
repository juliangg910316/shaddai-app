import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/closure_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/agenda_functions_provider.dart';
import 'package:shaddai/features/booking/providers/admin_booking_provider.dart';
import 'package:shaddai/features/booking/providers/booking_edit_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/navigation/providers/tab_scroll_provider.dart';
import 'package:shaddai/features/services/logic/price_list_view_logic.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_agenda.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

/// Los cierres en la reserva de la clienta, en su edición y en la de la
/// admin (spec 008, RF-12 a RF-17; plan § 5).
///
/// "Ahora" es el martes 10/11/2026 a las 7:00 del salón; el calendario por
/// defecto abre de 9:00 a 18:00 y cierra los domingos.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);
DateTime dayOf(int day) => DateTime.utc(2026, 11, day);

/// Un cierre con horas de pared del salón.
ClosureModel closure(String id, DateTime start, DateTime end) =>
    ClosureModel(id: id, start: fromSalon(start), end: fromSalon(end));

BilingualText text(String es) => BilingualText(es: es, pt: '$es (pt)');

/// s1: manicura de 45 minutos.
final priceList = PriceListModel(
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
        ),
      ],
    ),
  ],
);

const s1 = BookableRef(BookedKind.service, 's1');

final admin = UserModel(
  uid: 'admin1',
  email: 'beidis@example.com',
  displayName: 'Beidis Viera',
  phoneNumber: '+55 41 98000-0000',
  role: 'admin',
);

final ana = UserModel(
  uid: 'ana',
  email: 'ana@example.com',
  displayName: 'Ana Souza',
  phoneNumber: '+55 41 99111-0000',
);

Finder inCalendar(String text) => find
    .descendant(of: find.byType(TableCalendar), matching: find.text(text))
    .hitTestable();

Future<void> settleWidgets(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeBookingRepository bookings;
  late FakeConfigRepository config;

  setUp(() {
    bookings = FakeBookingRepository();
    config = FakeConfigRepository();
  });

  group('la reserva de la clienta', () {
    Future<void> pump(WidgetTester tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 2400);
      addTearDown(tester.view.reset);
      await pumpApp(
        tester,
        stored: const {'language': 'es'},
        home: const BookingView(),
        overrides: bookingDataOverrides(bookings: bookings, config: config),
      );
      await settleWidgets(tester);
    }

    DateTime? selected(WidgetTester tester, {bool day = false}) {
      final selection = appContainer(tester)
          .read(bookingSelectionProvider)
          .selection;
      return day ? selection.day : selection.start;
    }

    testWidgets('no ve las horas de un cierre ni ninguna marca de cierre '
        '(RF-12, RF-17)', (tester) async {
      config.closures = [closure('c1', at(10, 10), at(10, 12))];
      await pump(tester);

      expect(selected(tester, day: true), dayOf(10));
      expect(find.text('9:00'), findsOneWidget);
      expect(find.text('9:30'), findsOneWidget);
      for (final hour in ['10:00', '10:30', '11:00', '11:30']) {
        expect(find.text(hour), findsNothing);
      }
      expect(find.text('12:00'), findsOneWidget);
      expect(
        find.textContaining(RegExp('cierre|cerrad', caseSensitive: false)),
        findsNothing,
      );
    });

    testWidgets('un día cerrado entero por un cierre no se puede elegir '
        '(RF-13)', (tester) async {
      config.closures = [closure('c1', dayOf(12), dayOf(13))];
      await pump(tester);

      await tester.tap(inCalendar('12'));
      await settleWidgets(tester);
      expect(selected(tester, day: true), dayOf(10));

      await tester.tap(inCalendar('13'));
      await settleWidgets(tester);
      expect(selected(tester, day: true), dayOf(13));
    });

    testWidgets('un cierre que llega en vivo quita la hora elegida y avisa '
        '(RF-15, RF-16)', (tester) async {
      await pump(tester);
      await tester.ensureVisible(find.text('10:00'));
      await tester.tap(find.text('10:00'));
      await settleWidgets(tester);
      expect(selected(tester), at(10, 10));

      config.emitClosures([closure('c1', at(10, 10), at(10, 11))]);
      await settleWidgets(tester);

      expect(selected(tester), isNull);
      expect(find.text('10:00'), findsNothing);
      expect(
        find.text('La hora elegida ya no está disponible. Elige otra.'),
        findsOneWidget,
      );
    });

    testWidgets('quitar un cierre vuelve a dejar libres sus horas, sin '
        'recargar (RF-15)', (tester) async {
      config.closures = [closure('c1', at(10, 10), at(10, 11))];
      await pump(tester);
      expect(find.text('10:00'), findsNothing);

      config.emitClosures(const []);
      await settleWidgets(tester);
      expect(find.text('10:00'), findsOneWidget);
    });

    testWidgets('con un error de los cierres, el aviso con "Reintentar"; al '
        'reintentar, vuelven a pedirse (RF-12; spec 005, RF-48)', (
      tester,
    ) async {
      await pump(tester);
      config.failClosures(Exception('unavailable'));
      await settleWidgets(tester);

      expect(find.text('No se pudo cargar la agenda.'), findsOneWidget);
      expect(find.text('9:00'), findsNothing);

      appContainer(tester)
          .read(tabScrollControllerProvider(MobileTab.booking))
          .jumpTo(0);
      await tester.pump();
      await tester.tap(find.text('REINTENTAR'));
      await settleWidgets(tester);
      expect(find.text('No se pudo cargar la agenda.'), findsNothing);
      expect(find.text('9:00'), findsOneWidget);
      expect(config.closureRequests, hasLength(2));
    });
  });

  group('providers', () {
    late ProviderContainer c;
    late FakeUserRepository users;

    Future<void> start({UserModel? user}) async {
      users = FakeUserRepository(users: [ana, admin]);
      c = ProviderContainer(
        overrides: [
          ...bookingDataOverrides(
            bookings: bookings,
            config: config,
            user: user ?? testClient,
          ),
          userRepositoryProvider.overrideWithValue(users),
          currentPriceListProvider.overrideWithValue(PriceListReady(priceList)),
          agendaFunctionsProvider.overrideWith(FakeAgendaFunctions.linked),
        ],
      );
      addTearDown(c.dispose);
      c.listen(currentUserProvider, (_, _) {});
      c.listen(bookingSelectionProvider, (_, _) {});
      c.listen(calendarSettingsProvider, (_, _) {});
      c.listen(adminUsersProvider, (_, _) {});
      await settle();
    }

    List<DateTime> starts(DateTime day) => [
      for (final slot in c.read(freeSlotsOfDayProvider(day))!) slot.start,
    ];

    /// Elige [start] y, si aún no hay servicio, s1 (en la edición ya viene
    /// del turno; volver a tocarlo lo quitaría).
    void choose(DateTime start) {
      final selector = c.read(bookingSelectionProvider.notifier);
      selector.selectSlot(
        c
            .read(freeSlotsOfDayProvider(salonDay(start)))!
            .firstWhere((s) => s.start == start),
      );
      if (selector.selection.item == null) selector.selectItem(s1);
    }

    test('closuresProvider pide los cierres desde hoy a las 0:00 del salón '
        '(RF-12)', () async {
      await start();
      c.listen(closuresProvider, (_, _) {});
      await settle();
      expect(config.closureRequests, [fromSalon(dayOf(10))]);
    });

    test(
      'la cobertura de una hora termina donde empieza el cierre (RF-14)',
      () async {
        config.closures = [closure('c1', at(10, 10), at(10, 11))];
        await start();
        final slots = c.read(freeSlotsOfDayProvider(dayOf(10)))!;
        expect(
          slots.firstWhere((s) => s.start == at(10, 9, 30)).coverageMinutes,
          30,
        );
      },
    );

    test('la edición de la clienta tampoco ofrece las horas de un cierre '
        '(RF-12)', () async {
      final mine = AppointmentModel(
        id: 't1',
        clientId: testClient.uid,
        clientName: testClient.displayName,
        clientPhone: testClient.phoneNumber!,
        startTime: fromSalon(at(10, 9)),
        endTime: fromSalon(at(10, 9, 45)),
        status: 'confirmed',
        createdAt: bookingTestNow,
      );
      bookings = FakeBookingRepository(
        mine: [mine],
        busy: [BusySlot(id: 't1', start: mine.startTime, end: mine.endTime)],
      );
      config.closures = [closure('c1', at(10, 11), at(10, 12))];
      await start();
      c.read(editTargetProvider.notifier).start(mine);
      await settle();

      expect(starts(dayOf(10)), contains(at(10, 9)));
      expect(starts(dayOf(10)), isNot(contains(at(10, 11))));
      expect(starts(dayOf(10)), isNot(contains(at(10, 11, 30))));
    });

    test('la reserva de la admin tampoco, también lejos en su ventana de 365 '
        'días (RF-12)', () async {
      final far = DateTime.utc(2027, 9, 7); // martes
      config.closures = [
        closure(
          'c1',
          far.add(const Duration(hours: 9)),
          far.add(const Duration(hours: 12)),
        ),
      ];
      await start(user: admin);
      final free = [
        for (final slot in c.read(freeSlotsOfDayProvider(far))!) slot.start,
      ];
      expect(free, isNot(contains(far.add(const Duration(hours: 9)))));
      expect(free, contains(far.add(const Duration(hours: 12))));
    });

    group('al guardar se leen los cierres del servidor (RF-12)', () {
      test('la reserva de la clienta no guarda una hora dentro de un '
          'cierre', () async {
        await start();
        choose(at(10, 10));
        // Llega al servidor, todavía no a la vista.
        config.closures = [closure('c1', at(10, 10), at(10, 11))];

        final result = await c.read(bookingSubmitProvider).confirm();

        expect(result, BookingSubmitResult.slotTaken);
        expect(bookings.created, isEmpty);
        expect(config.closureFetches, [fromSalon(dayOf(10))]);
      });

      test('si no se pueden leer los cierres, no guarda', () async {
        await start();
        choose(at(10, 10));
        config.fetchClosuresError = Exception('unavailable');

        final result = await c.read(bookingSubmitProvider).confirm();

        expect(result, BookingSubmitResult.failed);
        expect(bookings.created, isEmpty);
      });

      test('la edición de la clienta no guarda una hora dentro de un '
          'cierre', () async {
        final mine = AppointmentModel(
          id: 't1',
          clientId: testClient.uid,
          clientName: testClient.displayName,
          clientPhone: testClient.phoneNumber!,
          startTime: fromSalon(at(10, 9)),
          endTime: fromSalon(at(10, 9, 45)),
          status: 'confirmed',
          createdAt: bookingTestNow,
          booked: BookedServiceModel(
            kind: BookedKind.service,
            id: 's1',
            name: text('Manicura'),
            priceCents: 3000,
            durationMinutes: 45,
          ),
        );
        final own = BusySlot(
          id: 't1',
          start: mine.startTime,
          end: mine.endTime,
        );
        bookings = FakeBookingRepository(mine: [mine], busy: [own]);
        await start();
        c.read(editTargetProvider.notifier).start(mine);
        await settle();
        bookings.editCheckData = (appointment: mine, busy: [own]);
        choose(at(10, 10));
        config.closures = [closure('c1', at(10, 10), at(10, 11))];

        final result = await c.read(bookingEditSaveProvider).save();

        expect(result.outcome, EditSaveOutcome.slotTaken);
        expect(bookings.edited, isEmpty);
        expect(config.closureFetches, [fromSalon(dayOf(10))]);
      });

      test(
        'la reserva de la admin no guarda una hora dentro de un cierre',
        () async {
          await start(user: admin);
          c.read(bookingRecipientProvider.notifier).chooseAccount(ana);
          choose(at(10, 10));
          config.closures = [closure('c1', at(10, 10), at(10, 11))];

          final result = await c.read(adminBookingSubmitProvider).confirm();

          expect(result.outcome, AdminBookingOutcome.slotTaken);
          expect(bookings.created, isEmpty);
          expect(config.closureFetches, [fromSalon(dayOf(10))]);
        },
      );
    });
  });
}
