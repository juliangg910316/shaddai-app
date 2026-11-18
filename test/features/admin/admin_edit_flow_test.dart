import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/admin/presentation/admin_edit_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/recipient.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/booking_form.dart';
import 'package:shaddai/features/booking/providers/admin_booking_provider.dart';
import 'package:shaddai/features/booking/providers/admin_edit_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/browser_history.dart';
import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// La edición de la admin de punta a punta (spec 008, RF-33, RF-35): lo que
/// tenía a medio agendar sigue ahí al terminar, en Android/iOS con la pestaña
/// Reservas montada debajo y en Web con "atrás" del navegador.
///
/// "Ahora" es el martes 10/11/2026 a las 7:00 del salón. El turno de Ana es
/// el viernes 20, de 10:00 a 10:45. La admin tenía a medio agendar el jueves
/// 12 a las 9:00 para Beatriz.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

final ana = UserModel(
  uid: 'ana',
  email: 'ana@example.com',
  displayName: 'Ana Souza',
  phoneNumber: '+55 41 99111-0000',
);
final bea = UserModel(
  uid: 'bea',
  email: 'bea@example.com',
  displayName: 'Beatriz',
  phoneNumber: '+55 41 99222-0000',
);

const spaRef = BookableRef(BookedKind.service, 'spa');

AppointmentModel anaAppointment() => AppointmentModel(
  id: 't1',
  clientId: 'ana',
  clientName: 'Ana Souza',
  clientPhone: '+55 41 99111-0000',
  startTime: fromSalon(at(20, 10)),
  endTime: fromSalon(at(20, 10, 45)),
  status: 'confirmed',
  createdAt: DateTime.utc(2026, 11, 1),
  booked: const BookedServiceModel(
    kind: BookedKind.service,
    id: 'spa',
    name: BilingualText(es: 'Spa de manos', pt: 'Spa das mãos'),
    priceCents: 5500,
    durationMinutes: 45,
  ),
);

/// Lo que la admin tenía a medio agendar.
final halfBooked = BookingSelection(
  day: at(12, 0),
  start: at(12, 9),
  item: spaRef,
);

const slotGone = 'La hora elegida ya no está disponible. Elige otra.';

void main() {
  late FakeBookingRepository bookings;
  final browser = BrowserHistory();

  setUp(() {
    bookings = FakeBookingRepository(
      active: [anaAppointment()],
      busy: [
        BusySlot(
          id: 't1',
          start: fromSalon(at(20, 10)),
          end: fromSalon(at(20, 10, 45)),
        ),
      ],
    );
  });

  List<Override> overrides() => [
    ...bookingScheduleOverrides(bookings: bookings),
    adminSelectedDateProvider.overrideWith((ref) => DateTime(2026, 11, 20)),
    adminAppointmentsProvider.overrideWith(
      (ref) => Stream.value([anaAppointment()]),
    ),
  ];

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settleWeb(tester);
  }

  /// La reserva de la admin con lo que tenía a medio agendar, en
  /// Android/iOS o en Web.
  Future<void> openHalfBooked(WidgetTester tester, {required bool web}) async {
    if (web) browser.record(tester);
    final pump = web ? pumpWebApp : pumpMobileApp;
    await pump(
      tester,
      location: '/booking',
      user: testAdmin,
      userRepository: FakeUserRepository(users: [ana, bea, testAdmin]),
      priceListRepository: FakePriceListRepository(stored: testPriceList()),
      height: 2400,
      overrides: overrides(),
    );
    final container = appContainer(tester);
    container
        .read(bookingRecipientProvider.notifier)
        .restore(AccountRecipient.of(bea));
    container.read(bookingSelectionProvider.notifier).restore(halfBooked);
    await settleWeb(tester);
    expect(container.read(bookingSelectionProvider).selection, halfBooked);
    expect(find.byType(BookingForm), findsOneWidget);
  }

  /// Desde la agenda, "Editar" en el turno de Ana.
  Future<void> openEdit(WidgetTester tester) async {
    webRouter(tester).push('/admin');
    await settleWeb(tester);
    await tap(tester, find.text('EDITAR'));
    expect(find.byType(AdminAppointmentEditView), findsOneWidget);
    expect(appContainer(tester).read(adminEditProvider), 't1');
  }

  /// Lo que la admin tenía a medio agendar, otra vez en Reservas.
  void expectHalfBooked(WidgetTester tester) {
    final container = appContainer(tester);
    expect(container.read(bookingSelectionProvider).selection, halfBooked);
    expect(
      container.read(bookingRecipientProvider).recipient,
      AccountRecipient.of(bea),
    );
    expect(container.read(adminEditProvider), isNull);
    expect(container.read(editTargetProvider), isNull);
  }

  group('Android/iOS', () {
    testWidgets('la pestaña Reservas sigue montada debajo y, tras guardar, '
        'conserva lo que tenía a medio agendar (RF-33)', (tester) async {
      await openHalfBooked(tester, web: false);
      await openEdit(tester);
      // La edición y, debajo, la pestaña Reservas con su formulario.
      expect(find.byType(BookingForm, skipOffstage: false), findsNWidgets(2));

      await tap(tester, find.text('11:00'));
      await tap(tester, find.text('GUARDAR CAMBIOS'));
      await tap(
        tester,
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.text('CONFIRMAR'),
        ),
      );
      expect(bookings.adminEdits.single.start, fromSalon(at(20, 11)));
      expect(find.byType(AdminDashboardView), findsOneWidget);
      expect(find.text(slotGone), findsNothing);

      webRouter(tester).pop();
      await settleWeb(tester);
      expect(find.byType(BookingForm), findsOneWidget);
      expectHalfBooked(tester);
    });

    testWidgets('un aviso de la edición sale una sola vez, aunque Reservas '
        'esté montada debajo', (tester) async {
      await openHalfBooked(tester, web: false);
      await openEdit(tester);
      await tap(tester, find.text('11:00'));

      // Otra persona reserva las 11:00 mientras la admin edita.
      bookings.emitBusy([
        ...bookings.busy,
        BusySlot(
          id: 'otro',
          start: fromSalon(at(20, 11)),
          end: fromSalon(at(20, 12)),
        ),
      ]);
      await settleWeb(tester);
      expect(find.text(slotGone), findsOneWidget);

      // Cuando se va, no vuelve a salir.
      await tester.pump(const Duration(seconds: 5));
      await settleWeb(tester);
      expect(find.text(slotGone), findsNothing);
    });
  });

  group('Web', () {
    testWidgets('la edición tiene su dirección; "atrás" del navegador sale sin '
        'guardar y Reservar muestra lo que tenía (RF-33, RF-35)', (
      tester,
    ) async {
      await openHalfBooked(tester, web: true);
      webRouter(tester).go('/admin');
      await settleWeb(tester);
      await tap(tester, find.text('EDITAR'));
      expect(webLocation(tester).path, '/admin/appointments/t1/edit');
      expect(find.byType(AdminAppointmentEditView), findsOneWidget);

      // Una hora que pisa la original: al salir, su tiempo ocupado vuelve a
      // contar, y no tiene que avisarse como perdida.
      await tap(tester, find.text('10:30'));
      await browser.goTo(tester, '/admin');

      expect(webLocation(tester).path, '/admin');
      expect(find.byType(AdminDashboardView), findsOneWidget);
      expect(bookings.adminEdits, isEmpty);
      expect(find.text(slotGone), findsNothing);

      webRouter(tester).go('/booking');
      await settleWeb(tester);
      expect(find.byType(BookingForm), findsOneWidget);
      expectHalfBooked(tester);
    });
  });
}
