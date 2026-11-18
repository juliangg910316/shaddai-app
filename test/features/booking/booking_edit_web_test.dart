import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/active_appointment_view.dart';
import 'package:shaddai/features/booking/presentation/booking_form.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/navigation/presentation/web_top_bar.dart';

import '../../helpers/browser_history.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

// "Ahora" es el martes 10/11/2026 a las 7:00 en Curitiba.
DateTime at(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, 10, hour, minute);

/// Su turno activo: hoy de 10:00 a 10:45, "Spa de manos".
final appointment = AppointmentModel(
  id: 't1',
  clientId: testClient.uid,
  clientName: testClient.displayName,
  clientPhone: testClient.phoneNumber!,
  startTime: fromSalon(at(10)),
  endTime: fromSalon(at(10, 45)),
  status: 'confirmed',
  createdAt: bookingTestNow,
  booked: const BookedServiceModel(
    kind: BookedKind.service,
    id: 'spa',
    name: BilingualText(es: 'Spa de manos', pt: 'Spa das mãos'),
    priceCents: 5500,
    durationMinutes: 45,
  ),
);

Finder _inTopBar(String text) =>
    find.descendant(of: find.byType(WebTopBar), matching: find.text(text));

void main() {
  final browser = BrowserHistory();

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await settleWeb(tester);
    await tester.tap(finder);
    await settleWeb(tester);
  }

  BookingSelection selection(WidgetTester tester) =>
      appContainer(tester).read(bookingSelectionProvider).selection;

  /// La app en Web, en la landing; "Reservar" de la barra superior y
  /// "Editar turno", y elige las 11:00.
  Future<void> openEdit(WidgetTester tester) async {
    browser.record(tester);
    await pumpWebApp(
      tester,
      location: '/',
      user: testClient,
      priceListRepository: FakePriceListRepository(stored: testPriceList()),
      appointments: [appointment],
      overrides: bookingScheduleOverrides(bookings: FakeBookingRepository()),
    );
    await tap(tester, _inTopBar('RESERVAR'));
    expect(webLocation(tester).path, '/booking');
    await tap(tester, find.text('EDITAR TURNO'));
    await tap(tester, find.text('11:00'));
    expect(find.byType(BookingForm), findsOneWidget);
    expect(selection(tester).start, at(11));
  }

  testWidgets('D-8: al avisar, go_router distingue la navegación de la app '
      '(lleva su estado) de la del navegador (lleva el del historial)', (
    tester,
  ) async {
    await openEdit(tester);
    final provider = webRouter(tester).routeInformationProvider;
    // Lo que trae cada aviso. Después, el router escribe en el valor el
    // estado que guarda en el historial sin avisar: solo sirve el del aviso.
    final fromApp = <bool>[];
    void listener() =>
        fromApp.add(provider.value.state is RouteInformationState<void>);
    provider.addListener(listener);
    addTearDown(() => provider.removeListener(listener));

    webRouter(tester).go('/');
    await settleWeb(tester);
    await browser.goTo(tester, '/booking');
    webRouter(tester).push('/services/service/spa');
    await settleWeb(tester);
    await browser.goTo(tester, '/');

    expect(fromApp, [true, false, true, false]);
  });

  testWidgets('un enlace de la app a otra página y la vuelta conservan la '
      'edición (RF-19)', (tester) async {
    await openEdit(tester);

    // Barra superior: "Servicios" lleva a la landing.
    await tap(tester, _inTopBar('SERVICIOS'));
    expect(webLocation(tester).path, '/');
    await tap(tester, _inTopBar('RESERVAR'));
    expect(find.byType(BookingForm), findsOneWidget);
    expect(find.text('Editar turno'), findsOneWidget);
    expect(selection(tester).start, at(11));

    // El detalle de un servicio, y "Reservar" de la barra para volver.
    webRouter(tester).go('/services/service/spa');
    await settleWeb(tester);
    await tap(tester, _inTopBar('RESERVAR'));
    expect(find.byType(BookingForm), findsOneWidget);
    expect(selection(tester).start, at(11));
    expect(appContainer(tester).read(editTargetProvider), isNotNull);
  });

  testWidgets('"atrás" del navegador cierra la edición sin guardar y, al '
      'volver, se ve el turno (RF-20)', (tester) async {
    await openEdit(tester);

    await browser.goTo(tester, '/');
    expect(webLocation(tester).path, '/');
    expect(appContainer(tester).read(editTargetProvider), isNull);

    // "Adelante": de vuelta en la reserva, el turno sin cambios.
    await browser.goTo(tester, '/booking');
    expect(webLocation(tester).path, '/booking');
    expect(find.byType(BookingForm), findsNothing);
    expect(find.byType(ActiveAppointmentView), findsOneWidget);
  });

  testWidgets('recargar la página muestra el turno (RF-20)', (tester) async {
    await openEdit(tester);

    // Recargar es empezar la app de nuevo en la misma dirección.
    await tester.pumpWidget(const SizedBox());
    await pumpWebApp(
      tester,
      location: '/booking',
      user: testClient,
      priceListRepository: FakePriceListRepository(stored: testPriceList()),
      appointments: [appointment],
      overrides: bookingScheduleOverrides(bookings: FakeBookingRepository()),
    );

    expect(find.byType(ActiveAppointmentView), findsOneWidget);
    expect(find.byType(BookingForm), findsNothing);
  });
}
