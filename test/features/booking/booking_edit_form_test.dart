import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
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
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../helpers/booking_steps.dart';
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
    String language = 'es',
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
      stored: {'language': language},
      home: const BookingView(),
      priceListRepository: FakePriceListRepository(stored: priceList),
      overrides: [
        ...bookingDataOverrides(bookings: bookings, settings: settings),
      ],
    );
    await settle(tester);
    await tester.tap(
      find.text(language == 'pt' ? 'EDITAR HORÁRIO' : 'EDITAR TURNO'),
    );
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

  group('Diálogo de antes y después (RF-11)', () {
    Finder inDialog(Finder finder) =>
        find.descendant(of: find.byType(AlertDialog), matching: finder);

    /// Toca "Guardar cambios" (o "Salvar alterações") y deja terminar la
    /// animación del diálogo: mientras aparece, su contenido aún no está en
    /// el árbol de semántica.
    Future<void> save(WidgetTester tester, {String language = 'es'}) async {
      await tap(
        tester,
        find.text(language == 'pt' ? 'SALVAR ALTERAÇÕES' : 'GUARDAR CAMBIOS'),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('marca lo que cambia con antes → después y "cambia"; lo demás '
        'con un valor; avisa de que volverá a esperar la confirmación', (
      tester,
    ) async {
      await openEdit(tester, start: at(10, 10));
      await tap(tester, find.text('11:00'));
      await save(tester);
      expect(inDialog(find.text('Confirmar cambios')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Inicio, cambia. Antes: 10:00. Después: 11:00.'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Fin, cambia. Antes: 10:45. Después: 11:45.'),
        findsOneWidget,
      );
      expect(
        inDialog(find.text('10:00 → 11:00', findRichText: true)),
        findsOneWidget,
      );
      // Sin cambios: un solo valor y sin "cambia".
      expect(inDialog(find.text('Manicura')), findsOneWidget);
      expect(inDialog(find.text('Decoración')), findsOneWidget);
      expect(inDialog(find.text('45 min')), findsOneWidget);
      expect(inDialog(find.text('R\$ 40')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r'^Fecha, cambia')), findsNothing);
      expect(find.bySemanticsLabel(RegExp(r'^Servicio, cambia')), findsNothing);
      expect(
        inDialog(
          find.text('El turno volverá a esperar la confirmación de Beidis.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('la fecha, los adicionales y el total', (tester) async {
      await openEdit(tester, start: at(10, 10));
      await tapDay(tester, '11');
      await tap(tester, find.text('10:00'));
      appContainer(tester)
          .read(bookingSelectionProvider.notifier)
          .toggleAddon('a1');
      await settle(tester);
      await save(tester);

      expect(
        find.bySemanticsLabel(
          'Fecha, cambia. Antes: Martes, 10 de noviembre de 2026. '
          'Después: Miércoles, 11 de noviembre de 2026.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel(
          'Adicionales, cambia. Antes: Decoración. Después: Ninguno.',
        ),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Total, cambia. Antes: R\$ 40. Después: R\$ 30.'),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(RegExp(r'^Inicio, cambia')), findsNothing);
      expect(find.bySemanticsLabel(RegExp(r'^Duración, cambia')), findsNothing);
    });

    testWidgets('sin cambios: nada marcado', (tester) async {
      await openEdit(tester, start: at(10, 10));
      await save(tester);

      expect(inDialog(find.text('Confirmar cambios')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp(r', cambia\.')), findsNothing);
    });

    testWidgets('"Cancelar" lo cierra sin guardar y sigue la edición', (
      tester,
    ) async {
      await openEdit(tester, start: at(10, 10));
      await tap(tester, find.text('11:00'));
      await save(tester);

      await tester.tap(inDialog(find.text('CANCELAR')));
      // Un fotograma para empezar a cerrarlo y otro para terminar.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await settle(tester);

      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(BookingForm), findsOneWidget);
      expect(selection(tester).start, at(10, 11));
      expect(appContainer(tester).read(editTargetProvider), isNotNull);
      expect(bookings.edited, isEmpty);
      expect(bookings.editCheckRequests, isEmpty);
    });

    testWidgets('en portugués', (tester) async {
      await openEdit(tester, start: at(10, 10), language: 'pt');
      await tap(tester, find.text('11:00'));
      await save(tester, language: 'pt');

      expect(inDialog(find.text('Confirmar alterações')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Início, muda. Antes: 10:00. Depois: 11:00.'),
        findsOneWidget,
      );
      expect(inDialog(find.text('Manicura (pt)')), findsOneWidget);
      expect(
        inDialog(
          find.text('O horário voltará a aguardar a confirmação de Beidis.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('al cambiar de idioma con el diálogo abierto, cambia', (
      tester,
    ) async {
      await openEdit(tester, start: at(10, 10));
      await tap(tester, find.text('11:00'));
      await save(tester);
      expect(inDialog(find.text('Confirmar cambios')), findsOneWidget);

      await appContainer(tester)
          .read(languagePreferenceProvider.notifier)
          .select(AppLanguage.pt);
      await settle(tester);

      expect(inDialog(find.text('Confirmar alterações')), findsOneWidget);
      expect(
        find.bySemanticsLabel('Fim, muda. Antes: 10:45. Depois: 11:45.'),
        findsOneWidget,
      );
      expect(inDialog(find.text('Manicura (pt)')), findsOneWidget);
    });
  });

  group('Aviso del margen al reservar un turno nuevo (RF-23)', () {
    /// La reserva sin turno activo, con un margen de [margin] minutos.
    Future<void> openNewBooking(WidgetTester tester, int margin) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 2400);
      addTearDown(tester.view.reset);
      final base = CalendarSettingsModel.defaultSettings();
      bookings = FakeBookingRepository();
      await pumpApp(
        tester,
        stored: {'language': 'es'},
        home: const BookingView(),
        overrides: [
          ...bookingDataOverrides(
            bookings: bookings,
            settings: CalendarSettingsModel(
              openingHours: base.openingHours,
              globalSlotDurationMinutes: base.globalSlotDurationMinutes,
              blockedDates: base.blockedDates,
              editMarginMinutes: margin,
            ),
          ),
        ],
      );
      await settle(tester);
      // Hoy, el primer día con horas: a las 7:00 elige las 10:00.
      await openBookingConfirmation(tester, settle: () => settle(tester));
      expect(find.text('Confirmar turno'), findsOneWidget);
    }

    const warning =
        'No podrás cambiar este turno: falta menos de 3 h para que empiece.';

    testWidgets('dentro del margen, el diálogo lo avisa', (tester) async {
      await openNewBooking(tester, 180);
      expect(find.text(warning), findsOneWidget);
    });

    testWidgets('fuera del margen, no', (tester) async {
      await openNewBooking(tester, 60);
      expect(find.textContaining('No podrás cambiar'), findsNothing);
    });

    testWidgets('con margen 0, nunca', (tester) async {
      await openNewBooking(tester, 0);
      expect(find.textContaining('No podrás cambiar'), findsNothing);
    });

    testWidgets('en portugués, al cambiar de idioma con el diálogo abierto', (
      tester,
    ) async {
      await openNewBooking(tester, 180);
      await appContainer(tester)
          .read(languagePreferenceProvider.notifier)
          .select(AppLanguage.pt);
      await settle(tester);
      expect(
        find.text(
          'Você não poderá alterar este horário: falta menos de 3 h para '
          'começar.',
        ),
        findsOneWidget,
      );
    });
  });
}
