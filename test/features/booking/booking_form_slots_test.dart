import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/landing/landing_content.dart';
import 'package:shaddai/features/navigation/providers/tab_scroll_provider.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/recording_link_launcher.dart';

// Horas de pared del salón. "Ahora" es el martes 10/11/2026 a las 7:00; el
// calendario por defecto abre de 9:00 a 18:00 y cierra los domingos.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

BusySlot busy(String id, DateTime start, DateTime end) =>
    BusySlot(id: id, start: fromSalon(start), end: fromSalon(end));

/// [text] en el mes que se ve del calendario (el calendario también tiene
/// construidos los meses de al lado).
Finder inCalendar(String text) => find
    .descendant(of: find.byType(TableCalendar), matching: find.text(text))
    .hitTestable();

CalendarSettingsModel settingsWith({
  List<String> blocked = const [],
  bool allClosed = false,
}) {
  final base = CalendarSettingsModel.defaultSettings();
  return CalendarSettingsModel(
    openingHours: {
      for (final MapEntry(:key, :value) in base.openingHours.entries)
        key: allClosed
            ? DaySchedule(open: value.open, close: value.close, isClosed: true)
            : value,
    },
    globalSlotDurationMinutes: base.globalSlotDurationMinutes,
    blockedDates: blocked,
  );
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeBookingRepository bookings;
  late RecordingLinkLauncher links;

  setUp(() {
    bookings = FakeBookingRepository();
    links = RecordingLinkLauncher();
  });

  Future<void> pump(
    WidgetTester tester, {
    CalendarSettingsModel? settings,
    Duration deviceOffset = salonUtcOffset,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2400);
    addTearDown(tester.view.reset);
    await pumpApp(
      tester,
      stored: {'language': 'es'},
      home: const BookingView(),
      overrides: [
        ...bookingDataOverrides(
          bookings: bookings,
          settings: settings,
          deviceOffset: deviceOffset,
        ),
        links.override,
      ],
    );
    await settle(tester);
  }

  DateTime? selectedDay(WidgetTester tester) =>
      appContainer(tester).read(bookingSelectionProvider).selection.day;
  DateTime? selectedStart(WidgetTester tester) =>
      appContainer(tester).read(bookingSelectionProvider).selection.start;

  Future<void> tapDay(WidgetTester tester, String day) async {
    // Tras elegir una hora, el calendario puede quedar fuera de la lista.
    appContainer(tester)
        .read(tabScrollControllerProvider(MobileTab.booking))
        .jumpTo(0);
    await tester.pump();
    await tester.tap(inCalendar(day));
    await settle(tester);
  }

  Future<void> tapSlot(WidgetTester tester, String time) async {
    await tester.ensureVisible(find.text(time));
    await tester.tap(find.text(time));
    await settle(tester);
  }

  testWidgets('abre en el día inicial, con sus horas (RF-1, RF-4)', (
    tester,
  ) async {
    bookings.busy = [busy('x', at(10, 9), at(10, 18))];
    await pump(tester);

    expect(selectedDay(tester), DateTime.utc(2026, 11, 11));
    expect(inCalendar('Noviembre de 2026'), findsOneWidget);
    expect(find.text('9:00'), findsOneWidget);
    expect(find.text('17:30'), findsOneWidget);
  });

  testWidgets('sin días que se puedan elegir, el texto y WhatsApp (RF-2)', (
    tester,
  ) async {
    await pump(tester, settings: settingsWith(allClosed: true));

    expect(find.byType(TableCalendar), findsNothing);
    expect(
      find.text(
        'No hay fechas disponibles para reservar. Escríbenos por WhatsApp.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.textContaining('WHATSAPP'));
    expect(links.opened, [Uri.parse(LandingContent.whatsappUrl)]);
  });

  testWidgets('los días cerrados y bloqueados no se pueden elegir (RF-3)', (
    tester,
  ) async {
    await pump(tester, settings: settingsWith(blocked: ['2026-11-12']));

    await tapDay(tester, '12');
    expect(selectedDay(tester), DateTime.utc(2026, 11, 10));
    await tapDay(tester, '15'); // domingo
    expect(selectedDay(tester), DateTime.utc(2026, 11, 10));
    await tapDay(tester, '9'); // ayer
    expect(selectedDay(tester), DateTime.utc(2026, 11, 10));

    await tapDay(tester, '13');
    expect(selectedDay(tester), DateTime.utc(2026, 11, 13));
  });

  testWidgets('en otra zona, las horas dicen que son de Curitiba (RF-5)', (
    tester,
  ) async {
    await pump(tester, deviceOffset: Duration.zero);
    expect(find.text('Horas de Curitiba'), findsOneWidget);
  });

  testWidgets('en la zona del salón no lo dicen (RF-5)', (tester) async {
    await pump(tester);
    expect(find.text('Horas de Curitiba'), findsNothing);
  });

  testWidgets('las horas cambian en vivo al ocuparse una (RF-6)', (
    tester,
  ) async {
    await pump(tester);
    expect(find.text('9:00'), findsOneWidget);

    bookings.emitBusy([busy('x', at(10, 9), at(10, 10))]);
    await settle(tester);
    expect(find.text('9:00'), findsNothing);
    expect(find.text('9:30'), findsNothing);
    expect(find.text('10:00'), findsOneWidget);
  });

  testWidgets('sin horas libres, su texto (RF-7)', (tester) async {
    bookings.busy = [busy('x', at(11, 9), at(11, 18))];
    await pump(tester);

    await tapDay(tester, '11');
    expect(
      find.text('No quedan horas libres este día. Prueba otra fecha.'),
      findsOneWidget,
    );
  });

  testWidgets('cambiar de fecha quita la hora (RF-8)', (tester) async {
    await pump(tester);
    await tapSlot(tester, '9:00');
    expect(selectedStart(tester), at(10, 9));

    await tapDay(tester, '11');
    expect(selectedStart(tester), isNull);
  });

  testWidgets('una hora que se ocupa se quita y avisa (RF-9)', (tester) async {
    await pump(tester);
    await tapSlot(tester, '9:00');

    bookings.emitBusy([busy('x', at(10, 9), at(10, 10))]);
    await settle(tester);
    expect(selectedStart(tester), isNull);
    expect(
      find.text('La hora elegida ya no está disponible. Elige otra.'),
      findsOneWidget,
    );
  });

  testWidgets('con un servicio de 1 h, las horas que no alcanzan se ven '
      'desactivadas y avisan (RF-15)', (tester) async {
    await pump(tester);
    final catalog = appContainer(
      tester,
    ).read(bookableCatalogProvider) as PriceViewReady<BookableCatalog>;
    final service = catalog.value.categories.first.services.first;
    appContainer(tester)
        .read(bookingSelectionProvider.notifier)
        .selectItem(BookableRef(BookedKind.service, service.id));
    await settle(tester);

    expect(find.bySemanticsLabel('17:30, no disponible'), findsOneWidget);
    expect(find.bySemanticsLabel('17:00'), findsOneWidget);

    await tapSlot(tester, '17:30');
    expect(selectedStart(tester), isNull);
    expect(
      find.text(
        'No hay tiempo suficiente a esta hora para un servicio de 1 h.',
      ),
      findsOneWidget,
    );

    await tapSlot(tester, '17:00');
    expect(selectedStart(tester), at(10, 17));
  });

  testWidgets('con un error de los turnos ocupados, el aviso con '
      '"Reintentar" y WhatsApp (RF-48)', (tester) async {
    await pump(tester);
    bookings.failBusy(Exception('unavailable'));
    await settle(tester);

    expect(find.text('No se pudo cargar la agenda.'), findsOneWidget);
    expect(find.text('9:00'), findsNothing);
    expect(find.textContaining('unavailable'), findsNothing);
    expect(find.textContaining('WHATSAPP'), findsOneWidget);

    await tester.tap(find.text('REINTENTAR'));
    await settle(tester);
    expect(find.text('No se pudo cargar la agenda.'), findsNothing);
    expect(find.text('9:00'), findsOneWidget);
    expect(bookings.busyWindows, hasLength(2));
  });
}
