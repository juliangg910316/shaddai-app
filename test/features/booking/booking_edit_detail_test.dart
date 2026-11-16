import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/booking_form.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/services/presentation/price_detail_view.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

// "Ahora" es el martes 10/11/2026 a las 7:00 en Curitiba. En la lista de los
// tests, "Spa de manos" (spa) dura 45 min y cuesta R$ 55; "Mantenimiento"
// (gel-maintenance), 1 h 30 min desde R$ 110; "Corto" (gel-short), 2 h; y el
// adicional "Cromado" (chrome) cuesta R$ 15.
DateTime at(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, 10, hour, minute);

const spa = BookableRef(BookedKind.service, 'spa');
const maintenance = BookableRef(BookedKind.service, 'gel-maintenance');

BilingualText text(String es, String pt) => BilingualText(es: es, pt: pt);

/// Su turno activo: hoy de 10:00 a 10:45, "Spa de manos" con "Cromado".
final appointment = AppointmentModel(
  id: 't1',
  clientId: testClient.uid,
  clientName: testClient.displayName,
  clientPhone: testClient.phoneNumber!,
  startTime: fromSalon(at(10)),
  endTime: fromSalon(at(10, 45)),
  status: 'confirmed',
  createdAt: bookingTestNow,
  booked: BookedServiceModel(
    kind: BookedKind.service,
    id: 'spa',
    name: text('Spa de manos', 'Spa das mãos'),
    priceCents: 5500,
    durationMinutes: 45,
    addons: [
      BookedAddonModel(
        id: 'chrome',
        name: text('Cromado', 'Cromado'),
        priceCents: 1500,
      ),
    ],
  ),
);

BusySlot busy(String id, DateTime start, DateTime end) =>
    BusySlot(id: id, start: fromSalon(start), end: fromSalon(end));

final _reserve = find.descendant(
  of: find.byType(PriceDetailView),
  matching: find.text('RESERVAR CITA'),
);

Finder inSnackBar(String message) => find.descendant(
  of: find.byType(SnackBar),
  matching: find.textContaining(message),
);

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settleWeb(tester);
  await tester.tap(finder);
  await settleWeb(tester);
}

BookingSelection _selection(WidgetTester tester) =>
    appContainer(tester).read(bookingSelectionProvider).selection;

void main() {
  late FakeBookingRepository bookings;

  setUp(() {
    // Su propio turno y otro de 11:30 a 12:30: a las 10:00 quedan 1 h 30 min
    // libres sin contar el propio turno.
    bookings = FakeBookingRepository(
      busy: [busy('t1', at(10), at(10, 45)), busy('x', at(11, 30), at(12, 30))],
    );
  });

  /// Abre la app en Reservas (Android/iOS o Web) y abre la edición.
  Future<void> openEdit(WidgetTester tester, {bool isWeb = false}) async {
    final pump = isWeb ? pumpWebApp : pumpMobileApp;
    await pump(
      tester,
      location: '/booking',
      user: testClient,
      priceListRepository: FakePriceListRepository(stored: testPriceList()),
      appointments: [appointment],
      overrides: bookingScheduleOverrides(bookings: bookings),
    );
    await _tap(tester, find.text('EDITAR TURNO'));
    expect(find.byType(BookingForm), findsOneWidget);
    expect(_selection(tester).item, spa);
    expect(_selection(tester).addonIds, {'chrome'});
  }

  /// "Reservar cita" en el detalle del servicio [id].
  Future<void> reserveFromDetail(WidgetTester tester, String id) async {
    webRouter(tester).go('/services/service/$id');
    await settleWeb(tester);
    await _tap(tester, _reserve);
  }

  for (final isWeb in [false, true]) {
    final platform = isWeb ? 'Web' : 'Android/iOS';

    testWidgets('$platform: un servicio que cabe vuelve a la edición con la '
        'misma fecha y hora, el servicio nuevo sin adicionales y el aviso '
        'con antes → después (RF-27, RF-28)', (tester) async {
      await openEdit(tester, isWeb: isWeb);
      await reserveFromDetail(tester, 'gel-maintenance');

      expect(find.byType(BookingForm), findsOneWidget);
      expect(find.text('Editar turno'), findsOneWidget);
      expect(_selection(tester).day, DateTime.utc(2026, 11, 10));
      expect(_selection(tester).start, at(10));
      expect(_selection(tester).item, maintenance);
      expect(_selection(tester).addonIds, isEmpty);

      expect(inSnackBar('Cambiaste el servicio:'), findsOneWidget);
      expect(
        inSnackBar('Servicio: Spa de manos → Mantenimiento'),
        findsOneWidget,
      );
      expect(inSnackBar('Fin: 10:45 → 11:30'), findsOneWidget);
      expect(inSnackBar('Duración: 45 min → 1 h 30 min'), findsOneWidget);
      expect(inSnackBar('Total: R\$ 70 → desde R\$ 110'), findsOneWidget);
      expect(inSnackBar('Inicio:'), findsNothing);
    });
  }

  testWidgets('uno que no cabe: no cambia y avisa con su duración y los '
      'minutos libres (RF-29)', (tester) async {
    await openEdit(tester);
    await reserveFromDetail(tester, 'gel-short');

    expect(find.byType(BookingForm), findsOneWidget);
    expect(_selection(tester).start, at(10));
    expect(_selection(tester).item, spa);
    expect(_selection(tester).addonIds, {'chrome'});
    expect(
      inSnackBar(
        'Corto dura 2 h y a esa hora solo hay 1 h 30 min libres. Elige otra '
        'hora u otro servicio.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('uno no disponible: no cambia y avisa (RF-30)', (tester) async {
    await openEdit(tester);
    webRouter(tester).go('/booking?service=no-existe');
    await settleWeb(tester);

    expect(find.byType(BookingForm), findsOneWidget);
    expect(_selection(tester).item, spa);
    expect(_selection(tester).addonIds, {'chrome'});
    expect(
      inSnackBar('El servicio elegido ya no está disponible.'),
      findsOneWidget,
    );
  });

  testWidgets('el mismo servicio: sin cambios, con sus adicionales', (
    tester,
  ) async {
    await openEdit(tester);
    await reserveFromDetail(tester, 'spa');

    expect(find.byType(BookingForm), findsOneWidget);
    expect(_selection(tester).start, at(10));
    expect(_selection(tester).item, spa);
    expect(_selection(tester).addonIds, {'chrome'});
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('Android/iOS: cambiar de pestaña y volver conserva la edición '
      '(RF-19)', (tester) async {
    await openEdit(tester);
    // Otra hora: las 9:00 (la lista de horas queda fuera de la pantalla).
    final container = appContainer(tester);
    container
        .read(bookingSelectionProvider.notifier)
        .selectSlot(
          container
              .read(freeSlotsOfDayProvider(DateTime.utc(2026, 11, 10)))!
              .firstWhere((slot) => slot.start == at(9)),
        );
    await settleWeb(tester);
    expect(_selection(tester).start, at(9));

    await _tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Inicio'),
      ),
    );
    expect(find.byType(BookingForm), findsNothing);
    await _tap(
      tester,
      find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text('Turnos'),
      ),
    );

    expect(find.byType(BookingForm), findsOneWidget);
    expect(find.text('Editar turno'), findsOneWidget);
    expect(_selection(tester).start, at(9));
    expect(_selection(tester).item, spa);
    expect(_selection(tester).addonIds, {'chrome'});
  });
}
