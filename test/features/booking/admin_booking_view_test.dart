import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

/// La vista de reserva de la admin (spec 007). "Ahora" es el martes
/// 10/11/2026 a las 7:00 del salón.
final admin = UserModel(
  uid: 'admin1',
  email: 'beidis@example.com',
  displayName: 'Beidis Viera',
  phoneNumber: '+55 41 98000-0000',
  role: 'admin',
);

/// Deja llegar los streams: sesión, turnos, fichas y "ahora".
Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeBookingRepository bookings;
  late FakeUserRepository users;

  setUp(() {
    bookings = FakeBookingRepository();
    users = FakeUserRepository();
  });

  Future<void> pump(
    WidgetTester tester, {
    UserModel? user,
    CalendarSettingsModel? settings,
  }) async {
    await pumpApp(
      tester,
      stored: const {'language': 'es'},
      home: const BookingView(),
      overrides: [
        ...bookingDataOverrides(
          bookings: bookings,
          user: user ?? admin,
          settings: settings,
        ),
        userRepositoryProvider.overrideWithValue(users),
      ],
    );
    await settle(tester);
  }

  TableCalendar<dynamic> calendar(WidgetTester tester) =>
      tester.widget<TableCalendar<dynamic>>(find.byType(TableCalendar));

  group('ventana del calendario (RF-12, RF-13)', () {
    testWidgets('la admin llega a 365 días; cerrados y bloqueados no', (
      tester,
    ) async {
      final defaults = CalendarSettingsModel.defaultSettings();
      await pump(
        tester,
        settings: CalendarSettingsModel(
          openingHours: defaults.openingHours,
          globalSlotDurationMinutes: defaults.globalSlotDurationMinutes,
          // 2027-06-01 es martes.
          blockedDates: const ['2027-06-01'],
        ),
      );

      final table = calendar(tester);
      expect(table.lastDay, DateTime.utc(2027, 11, 10));
      final enabled = table.enabledDayPredicate!;
      // Viernes 28/5/2027, a 199 días.
      expect(enabled(DateTime(2027, 5, 28)), isTrue);
      expect(enabled(DateTime(2027, 11, 10)), isTrue);
      expect(enabled(DateTime(2027, 6, 1)), isFalse);
      // Domingo 30/5/2027: cerrado en el horario por defecto.
      expect(defaults.openingHours['sunday']!.isClosed, isTrue);
      expect(enabled(DateTime(2027, 5, 30)), isFalse);
    });

    testWidgets('la clienta sigue en 60 días', (tester) async {
      await pump(tester, user: testClient);
      final table = calendar(tester);
      expect(table.lastDay, DateTime.utc(2027, 1, 9));
      expect(table.enabledDayPredicate!(DateTime(2027, 5, 28)), isFalse);
    });
  });
}
