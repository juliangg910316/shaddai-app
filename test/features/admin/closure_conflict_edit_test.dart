import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/presentation/admin_closure_form_view.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/admin/presentation/admin_edit_view.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';

import '../../helpers/browser_history.dart';
import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_web_app.dart';

/// "Editar" en un turno que choca con un cierre (spec 008, Navegación,
/// RF-5, RF-28, RF-35): al guardar o salir de la edición, la admin vuelve al
/// cierre que estaba creando, con lo que había elegido, y no al panel.
///
/// "Ahora" es el martes 10/11/2026 a las 7:00 del salón. El cierre por
/// defecto del formulario es hoy de 9:00 a 10:00, y el turno de Ana, hoy de
/// 9:30 a 10:15, choca con él.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

final ana = UserModel(
  uid: 'ana',
  email: 'ana@example.com',
  displayName: 'Ana Souza',
  phoneNumber: '+55 41 99111-0000',
);

AppointmentModel anaAppointment() => AppointmentModel(
  id: 'a1',
  clientId: 'ana',
  clientName: 'Ana Souza',
  clientPhone: '+55 41 99111-0000',
  startTime: fromSalon(at(10, 9, 30)),
  endTime: fromSalon(at(10, 10, 15)),
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

void main() {
  late FakeBookingRepository bookings;
  late FakeConfigRepository config;
  final browser = BrowserHistory();

  setUp(() {
    bookings = FakeBookingRepository(
      active: [anaAppointment()],
      busy: [
        BusySlot(
          id: 'a1',
          start: fromSalon(at(10, 9, 30)),
          end: fromSalon(at(10, 10, 15)),
        ),
      ],
    );
    config = FakeConfigRepository(
      settings: CalendarSettingsModel.defaultSettings(),
    );
  });

  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.tap(finder);
    await settleWeb(tester);
  }

  Finder conflict() => find.byKey(const ValueKey('closure-conflict-a1'));

  /// El formulario del cierre, con el turno de Ana chocando, y "Editar" en
  /// ese turno.
  Future<void> openEditFromConflict(
    WidgetTester tester, {
    required bool web,
  }) async {
    if (web) browser.record(tester);
    final pump = web ? pumpWebApp : pumpMobileApp;
    await pump(
      tester,
      location: '/admin/closures',
      user: testAdmin,
      userRepository: FakeUserRepository(users: [ana, testAdmin]),
      priceListRepository: FakePriceListRepository(stored: testPriceList()),
      height: 2400,
      overrides: bookingScheduleOverrides(bookings: bookings, config: config),
    );
    await settleWeb(tester);
    await tap(tester, find.text('NUEVO CIERRE').first);
    expect(find.byType(AdminClosureFormView), findsOneWidget);
    await tap(tester, find.text('GUARDAR'));
    expect(conflict(), findsOneWidget);

    await tap(
      tester,
      find.descendant(of: conflict(), matching: find.text('EDITAR')),
    );
    expect(find.byType(AdminAppointmentEditView), findsOneWidget);
  }

  /// De vuelta en el cierre, no en el panel.
  void expectBackOnClosure(WidgetTester tester) {
    expect(find.byType(AdminClosureFormView), findsOneWidget);
    expect(find.byType(AdminAppointmentEditView), findsNothing);
    expect(find.byType(AdminDashboardView), findsNothing);
  }

  for (final web in [false, true]) {
    final platform = web ? 'Web' : 'Android/iOS';
    group(platform, () {
      testWidgets('al guardar la edición, vuelve al cierre; el turno ya no '
          'choca y el cierre se guarda', (tester) async {
        await openEditFromConflict(tester, web: web);
        await tap(tester, find.text('11:00'));
        await tap(tester, find.text('GUARDAR CAMBIOS'));
        await tap(
          tester,
          find.descendant(
            of: find.byType(AlertDialog),
            matching: find.text('CONFIRMAR'),
          ),
        );

        expect(bookings.adminEdits.single.start, fromSalon(at(10, 11)));
        expectBackOnClosure(tester);
        if (web) {
          expect(webLocation(tester).path, '/admin/closures/new');
        }
        // La lista de turnos que chocan se actualiza: Ana ya no está.
        expect(conflict(), findsNothing);

        await tap(tester, find.text('GUARDAR'));
        expect(config.created, hasLength(1));
        expect(config.created.single.start, fromSalon(at(10, 9)));
      });

      testWidgets('al salir sin guardar, vuelve al cierre con el turno aún '
          'en la lista', (tester) async {
        await openEditFromConflict(tester, web: web);
        await tap(tester, find.text('CANCELAR'));

        expect(bookings.adminEdits, isEmpty);
        expectBackOnClosure(tester);
        expect(conflict(), findsOneWidget);
      });
    });
  }

  testWidgets('Web: "atrás" del navegador también vuelve al cierre', (
    tester,
  ) async {
    await openEditFromConflict(tester, web: true);
    await browser.goTo(tester, '/admin/closures/new');

    expect(bookings.adminEdits, isEmpty);
    expectBackOnClosure(tester);
    expect(conflict(), findsOneWidget);
  });
}
