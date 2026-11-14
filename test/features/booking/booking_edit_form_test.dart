import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/booking_form.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/navigation/providers/tab_scroll_provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

// Horas de pared del salón. "Ahora" es el martes 10/11/2026 a las 7:00; el
// calendario por defecto abre de 9:00 a 18:00 y cierra los domingos. La
// ventana de reserva llega al 9/1/2027.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

BilingualText text(String es) => BilingualText(es: es, pt: '$es (pt)');

const s1 = BookableRef(BookedKind.service, 's1');

/// s1 (45 min) y el adicional a1.
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
        PriceItemModel(
          id: 'a1',
          kind: PriceItemKind.addon,
          name: text('Decoración'),
          priceCents: 1000,
        ),
      ],
    ),
  ],
);

/// Su turno activo de 45 min desde [start] (hora del salón), con s1 y a1.
AppointmentModel appointmentAt(DateTime start) => AppointmentModel(
  id: 't1',
  clientId: testClient.uid,
  clientName: testClient.displayName,
  clientPhone: testClient.phoneNumber!,
  startTime: fromSalon(start),
  endTime: fromSalon(start).add(const Duration(minutes: 45)),
  status: 'waiting_confirmation',
  createdAt: bookingTestNow,
  booked: BookedServiceModel(
    kind: BookedKind.service,
    id: 's1',
    name: text('Manicura'),
    priceCents: 3000,
    durationMinutes: 45,
    addons: [
      BookedAddonModel(id: 'a1', name: text('Decoración'), priceCents: 1000),
    ],
  ),
);

BusySlot busy(String id, DateTime start, DateTime end) =>
    BusySlot(id: id, start: fromSalon(start), end: fromSalon(end));

/// El calendario por defecto con los martes cerrados.
CalendarSettingsModel tuesdaysClosed() {
  final base = CalendarSettingsModel.defaultSettings();
  return CalendarSettingsModel(
    openingHours: {
      ...base.openingHours,
      'tuesday': DaySchedule(open: '09:00', close: '18:00', isClosed: true),
    },
    globalSlotDurationMinutes: base.globalSlotDurationMinutes,
    blockedDates: base.blockedDates,
  );
}

/// [label] en el mes que se ve del calendario (el calendario también tiene
/// construidos los meses de al lado).
Finder inCalendar(String label) => find
    .descendant(of: find.byType(TableCalendar), matching: find.text(label))
    .hitTestable();

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeBookingRepository bookings;

  /// Abre la edición del turno que empieza en [start].
  Future<void> openEdit(
    WidgetTester tester, {
    required DateTime start,
    List<BusySlot> busySlots = const [],
    CalendarSettingsModel? settings,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    bookings = FakeBookingRepository(
      mine: [appointmentAt(start)],
      busy: busySlots,
    );
    await pumpApp(
      tester,
      stored: {'language': 'es'},
      home: const BookingView(),
      priceListRepository: FakePriceListRepository(stored: priceList),
      overrides: [
        ...bookingDataOverrides(bookings: bookings, settings: settings),
      ],
    );
    await settle(tester);
    await tester.tap(find.text('EDITAR TURNO'));
    await settle(tester);
    expect(find.byType(BookingForm), findsOneWidget);
  }

  BookingSelection selection(WidgetTester tester) =>
      appContainer(tester).read(bookingSelectionProvider).selection;

  Future<void> tapDay(WidgetTester tester, String day) async {
    appContainer(tester)
        .read(tabScrollControllerProvider(MobileTab.booking))
        .jumpTo(0);
    await tester.pump();
    await tester.tap(inCalendar(day));
    await settle(tester);
  }

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settle(tester);
  }

  group('El día y la hora originales (RF-5, RF-7, RF-8)', () {
    testWidgets('más allá de la ventana: se ve, está elegido y se puede '
        'volver a elegir; los demás días de fuera, no', (tester) async {
      final start = DateTime.utc(2027, 1, 20, 10);
      await openEdit(tester, start: start);

      expect(selection(tester).day, DateTime.utc(2027, 1, 20));
      expect(selection(tester).start, start);
      expect(inCalendar('Enero de 2027'), findsOneWidget);
      expect(find.text('10:00'), findsOneWidget);

      await tapDay(tester, '8');
      expect(selection(tester).day, DateTime.utc(2027, 1, 8));
      await tapDay(tester, '20');
      expect(selection(tester).day, DateTime.utc(2027, 1, 20));
      await tapDay(tester, '21');
      expect(selection(tester).day, DateTime.utc(2027, 1, 20));
    });

    testWidgets('en un día ahora cerrado: se puede elegir, con solo su hora; '
        'los demás días cerrados, no', (tester) async {
      await openEdit(tester, start: at(10, 9), settings: tuesdaysClosed());

      expect(selection(tester).day, DateTime.utc(2026, 11, 10));
      expect(selection(tester).start, at(10, 9));
      expect(find.text('9:00'), findsOneWidget);
      expect(find.text('9:30'), findsNothing);

      await tapDay(tester, '11');
      expect(selection(tester).day, DateTime.utc(2026, 11, 11));
      await tapDay(tester, '10');
      expect(selection(tester).day, DateTime.utc(2026, 11, 10));
      expect(find.text('9:00'), findsOneWidget);
      await tapDay(tester, '17');
      expect(selection(tester).day, DateTime.utc(2026, 11, 10));
    });

    testWidgets('su hora sale libre aunque esté fuera de la rejilla', (
      tester,
    ) async {
      await openEdit(tester, start: at(10, 9, 15));

      expect(selection(tester).start, at(10, 9, 15));
      expect(find.text('9:15'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('9:15')),
        isSemantics(label: '9:15', isSelected: true),
      );
    });

    testWidgets('la hora del propio turno no sale ocupada; las de otros, sí '
        '(RF-7)', (tester) async {
      await openEdit(
        tester,
        start: at(10, 9),
        busySlots: [
          busy('t1', at(10, 9), at(10, 9, 45)),
          busy('x', at(10, 10), at(10, 11)),
        ],
      );

      expect(find.text('9:00'), findsOneWidget);
      expect(find.bySemanticsLabel('9:00'), findsOneWidget);
      expect(find.text('10:00'), findsNothing);
      expect(find.text('11:00'), findsOneWidget);
    });
  });

  testWidgets('otra fecha sigue las reglas de siempre (RF-9)', (tester) async {
    await openEdit(
      tester,
      start: at(10, 9),
      busySlots: [busy('y', at(11, 12), at(11, 13))],
    );

    await tapDay(tester, '11');
    expect(selection(tester).day, DateTime.utc(2026, 11, 11));
    expect(find.text('11:30'), findsOneWidget);
    expect(find.text('12:00'), findsNothing);
    expect(find.text('12:30'), findsNothing);

    // Domingo cerrado y día fuera de la ventana: no se eligen.
    await tapDay(tester, '15');
    expect(selection(tester).day, DateTime.utc(2026, 11, 11));
  });

  group('"Guardar cambios" con algo sin elegir (RF-10)', () {
    Finder inSnackBar(String message) => find.descendant(
      of: find.byType(SnackBar),
      matching: find.text(message),
    );

    testWidgets('sin hora: lo dice y la marca', (tester) async {
      await openEdit(tester, start: at(10, 10));
      await tap(tester, find.text('10:00'));
      expect(selection(tester).start, isNull);

      await tap(tester, find.text('GUARDAR CAMBIOS'));

      expect(inSnackBar('Elige una hora'), findsOneWidget);
      expect(find.text('Elige una hora'), findsNWidgets(2));
      expect(find.text('Elige un servicio'), findsNothing);
      expect(find.byType(AlertDialog), findsNothing);
      expect(bookings.edited, isEmpty);
    });

    testWidgets('sin servicio: lo dice y lo marca', (tester) async {
      await openEdit(tester, start: at(10, 10));
      appContainer(tester)
          .read(bookingSelectionProvider.notifier)
          .selectItem(s1);
      await settle(tester);
      expect(selection(tester).item, isNull);

      await tap(tester, find.text('GUARDAR CAMBIOS'));

      expect(inSnackBar('Elige un servicio'), findsOneWidget);
      expect(find.text('Elige un servicio'), findsNWidgets(2));
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('sin las dos: lo dice y marca las dos', (tester) async {
      await openEdit(tester, start: at(10, 10));
      await tap(tester, find.text('10:00'));
      appContainer(tester)
          .read(bookingSelectionProvider.notifier)
          .selectItem(s1);
      await settle(tester);

      await tap(tester, find.text('GUARDAR CAMBIOS'));

      expect(
        inSnackBar('Elige una hora y un servicio para agendar.'),
        findsOneWidget,
      );
      expect(find.text('Elige una hora'), findsOneWidget);
      expect(find.text('Elige un servicio'), findsOneWidget);
    });
  });
}
