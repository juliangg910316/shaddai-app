import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/features/auth/presentation/phone_capture_view.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/free_slots.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/active_appointment_view.dart';
import 'package:shaddai/features/booking/presentation/booking_sign_in_prompt.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/navigation/presentation/web_top_bar.dart';
import 'package:shaddai/features/services/presentation/price_detail_view.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

// "Ahora" es el martes 10/11/2026 a las 7:00 en Curitiba. En la lista de los
// tests, "Spa de manos" (spa) dura 45 min y "Corto" (gel-short), 2 h.
const spa = BookableRef(BookedKind.service, 'spa');
const short = BookableRef(BookedKind.service, 'gel-short');

DateTime at(int day, int hour) => DateTime.utc(2026, 11, day, hour);

final _reserve = find.descendant(
  of: find.byType(PriceDetailView),
  matching: find.text('RESERVAR CITA'),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settleWeb(tester);
  await tester.tap(finder);
  await settleWeb(tester);
}

BookingSelection _selection(WidgetTester tester) =>
    appContainer(tester).read(bookingSelectionProvider).selection;

/// Elige el miércoles 11 a las [hour], con la cobertura que tiene ese día
/// sin turnos ocupados (hasta las 18:00).
void _chooseSlot(WidgetTester tester, int hour) {
  final controller = appContainer(tester)
      .read(bookingSelectionProvider.notifier);
  controller.selectDay(DateTime.utc(2026, 11, 11));
  controller.selectSlot(
    FreeSlot(start: at(11, hour), coverageMinutes: (18 - hour) * 60),
  );
}

void main() {
  late FakeBookingRepository bookings;
  late FakePriceListRepository prices;

  setUp(() {
    bookings = FakeBookingRepository();
    prices = FakePriceListRepository(stored: testPriceList());
  });

  Future<FakeWebSession> web(
    WidgetTester tester, {
    String location = '/services/service/spa',
    bool signedIn = true,
    List<AppointmentModel> appointments = const [],
  }) => pumpWebApp(
    tester,
    location: location,
    user: signedIn ? testClient : null,
    priceListRepository: prices,
    appointments: appointments,
    overrides: bookingScheduleOverrides(bookings: bookings),
  );

  group('Web', () {
    testWidgets('desde el detalle, con sesión: el servicio queda elegido, sin '
        'adicionales, y la dirección lo dice (RF-40)', (tester) async {
      await web(tester);
      await _tap(tester, _reserve);

      expect(webLocation(tester).toString(), '/booking?service=spa');
      expect(_selection(tester).item, spa);
      expect(_selection(tester).addonIds, isEmpty);
    });

    testWidgets('conserva la fecha y la hora si el servicio cabe', (
      tester,
    ) async {
      await web(tester);
      _chooseSlot(tester, 10);
      await _tap(tester, _reserve);

      expect(_selection(tester).day, DateTime.utc(2026, 11, 11));
      expect(_selection(tester).start, at(11, 10));
      expect(_selection(tester).item, spa);
    });

    testWidgets('si no cabe, quita la hora, conserva la fecha y avisa', (
      tester,
    ) async {
      await web(tester, location: '/services/service/gel-short');
      _chooseSlot(tester, 17);
      await _tap(tester, _reserve);

      expect(_selection(tester).item, short);
      expect(_selection(tester).start, isNull);
      expect(_selection(tester).day, DateTime.utc(2026, 11, 11));
      expect(
        find.text(
          'La hora elegida ya no tiene tiempo suficiente para el servicio. '
          'Elige otra.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('sin sesión y sin WhatsApp, vuelve con el servicio elegido '
        '(RF-41, RF-42)', (tester) async {
      final session = await web(tester, signedIn: false);
      await _tap(tester, _reserve);
      expect(webLocation(tester).path, '/login');

      session.signIn(testClientWithoutPhone);
      await settleWeb(tester);
      expect(find.byType(PhoneCaptureView), findsOneWidget);

      await tester.enterText(find.byType(TextField), '41999990000');
      await tester.tap(find.text('GUARDAR Y CONTINUAR'));
      await settleWeb(tester);

      expect(webLocation(tester).toString(), '/booking?service=spa');
      expect(_selection(tester).item, spa);
    });

    testWidgets('la dirección abre directamente la reserva con el servicio, '
        'y con la lista cargando espera (RF-43)', (tester) async {
      prices = FakePriceListRepository(
        stored: testPriceList(),
        autoEmit: false,
      );
      await web(tester, location: '/booking?service=spa');
      expect(webLocation(tester).toString(), '/booking?service=spa');
      expect(_selection(tester).item, spa);

      prices.change(testPriceList());
      await settleWeb(tester);
      expect(_selection(tester).item, spa);
      expect(
        find.text('El servicio elegido ya no está disponible.'),
        findsNothing,
      );
    });

    testWidgets('un id que no existe avisa y no elige nada (RF-44)', (
      tester,
    ) async {
      await web(tester, location: '/booking?service=no-existe');

      expect(_selection(tester).item, isNull);
      expect(
        find.text('El servicio elegido ya no está disponible.'),
        findsOneWidget,
      );
    });

    testWidgets('un combo, por su dirección', (tester) async {
      await web(tester, location: '/booking?combo=full-gel');
      expect(
        _selection(tester).item,
        const BookableRef(BookedKind.combo, 'full-gel'),
      );
    });

    testWidgets('los otros "Reservar" conservan lo elegido (RF-45)', (
      tester,
    ) async {
      await web(tester, location: '/booking?service=spa');
      webRouter(tester).go('/');
      await settleWeb(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(WebTopBar),
          matching: find.text('RESERVAR'),
        ),
      );
      await settleWeb(tester);
      expect(webLocation(tester).toString(), '/booking');
      expect(_selection(tester).item, spa);
    });

    testWidgets('con un turno activo, se ve el turno (RF-46)', (tester) async {
      await web(
        tester,
        location: '/booking?service=spa',
        appointments: [
          AppointmentModel(
            id: 't1',
            clientId: testClient.uid,
            clientName: testClient.displayName,
            clientPhone: testClient.phoneNumber!,
            startTime: fromSalon(at(20, 9)),
            endTime: fromSalon(at(20, 10)),
            status: 'confirmed',
            createdAt: bookingTestNow,
          ),
        ],
      );
      expect(find.byType(ActiveAppointmentView), findsOneWidget);
    });
  });

  group('Android/iOS', () {
    testWidgets('desde el detalle, sin sesión: Reservas pide iniciarla con el '
        'servicio ya pedido, y tras el WhatsApp vuelve con él (RF-41, RF-42)', (
      tester,
    ) async {
      final session = await pumpMobileApp(
        tester,
        location: '/services/service/spa',
        priceListRepository: prices,
        overrides: bookingScheduleOverrides(bookings: bookings),
      );
      await _tap(tester, _reserve);

      expect(webLocation(tester).toString(), '/booking?service=spa');
      expect(find.byType(BookingSignInPrompt), findsOneWidget);
      expect(_selection(tester).item, spa);

      session.signIn(testClientWithoutPhone);
      await settleWeb(tester);
      expect(find.byType(PhoneCaptureView), findsOneWidget);

      await tester.enterText(find.byType(TextField), '41999990000');
      await tester.tap(find.text('GUARDAR Y CONTINUAR'));
      await settleWeb(tester);

      expect(webLocation(tester).toString(), '/booking?service=spa');
      expect(_selection(tester).item, spa);
      expect(
        appContainer(tester).read(bookableCatalogProvider),
        isA<PriceViewReady<BookableCatalog>>(),
      );
    });
  });
}
