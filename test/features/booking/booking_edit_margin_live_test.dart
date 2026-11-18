import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_web_app.dart';

/// El margen que guarda la admin llega a la clienta sin recargar (spec 008,
/// RF-40; spec 006, RF-21).
///
/// "Ahora" es el martes 10/11/2026 a las 7:00 del salón; su turno empieza
/// hoy a las 10:00, dentro de 3 horas.
void main() {
  for (final web in [false, true]) {
    testWidgets('"Editar turno" aparece y desaparece al cambiar el margen '
        '(${web ? 'Web' : 'Android/iOS'})', (tester) async {
      final config = FakeConfigRepository(
        settings: CalendarSettingsModel(
          openingHours: CalendarSettingsModel.defaultSettings().openingHours,
          globalSlotDurationMinutes: 30,
          blockedDates: const [],
        ),
      );
      final pump = web ? pumpWebApp : pumpMobileApp;
      await pump(
        tester,
        location: '/booking',
        user: testClient,
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
        appointments: [
          testAppointment(fromSalon(DateTime.utc(2026, 11, 10, 10))),
        ],
        height: 1600,
        overrides: bookingScheduleOverrides(
          bookings: FakeBookingRepository(),
          config: config,
          settingsStream: config.getCalendarSettings,
        ),
      );
      expect(find.text('EDITAR TURNO'), findsOneWidget);

      // La admin, desde otro dispositivo: 6 horas.
      await config.updateEditMargin(360);
      await settleWeb(tester);
      expect(find.text('EDITAR TURNO'), findsNothing);

      // Y luego 2 horas: el turno vuelve a estar fuera del margen.
      await config.updateEditMargin(120);
      await settleWeb(tester);
      expect(find.text('EDITAR TURNO'), findsOneWidget);
    });
  }
}
