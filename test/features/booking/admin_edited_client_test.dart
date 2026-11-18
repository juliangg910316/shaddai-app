import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/data/repositories/booking_repository.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/active_appointment_view.dart';
import 'package:shaddai/features/booking/presentation/booking_form.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_web_app.dart';

/// Lo que ve la clienta cuando la admin edita su turno desde otro
/// dispositivo (spec 008, RF-32): el cambio llega sin recargar, en Reservas y
/// en Perfil; si cambia la persona, la anterior deja de verlo y la nueva lo
/// ve como su turno activo.
///
/// "Ahora" es el martes 10/11/2026 a las 7:00 del salón. El turno de Ana
/// ([testClient]) es el viernes 20, de 10:00 a 10:45.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);

final bea = UserModel(
  uid: 'bea',
  email: 'bea@example.com',
  displayName: 'Beatriz',
  phoneNumber: '+55 41 99222-0000',
);

const spa = BookedServiceModel(
  kind: BookedKind.service,
  id: 'spa',
  name: BilingualText(es: 'Spa de manos', pt: 'Spa das mãos'),
  priceCents: 5500,
  durationMinutes: 45,
);

AppointmentModel anaAppointment() => AppointmentModel(
  id: 't1',
  clientId: testClient.uid,
  clientName: testClient.displayName,
  clientPhone: testClient.phoneNumber!,
  startTime: fromSalon(at(20, 10)),
  endTime: fromSalon(at(20, 10, 45)),
  status: 'waiting_confirmation',
  createdAt: DateTime.utc(2026, 11, 1),
  booked: spa,
);

/// La línea de Perfil del turno que empieza a la hora de pared [hour] del
/// viernes 20: Perfil da la hora tal como llega del repositorio.
String profileLine(int hour) =>
    'Viernes · ${DateFormat.Hm('es').format(fromSalon(at(20, hour)))}';

void main() {
  late FakeBookingRepository bookings;

  setUp(() {
    bookings = FakeBookingRepository(
      mine: [anaAppointment()],
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

  /// La app de [user], en Android/iOS o en Web, en [location]. Sus turnos
  /// llegan en vivo del repositorio.
  Future<void> open(
    WidgetTester tester, {
    required UserModel user,
    required String location,
    bool web = false,
  }) async {
    final pump = web ? pumpWebApp : pumpMobileApp;
    await pump(
      tester,
      location: location,
      user: user,
      priceListRepository: FakePriceListRepository(stored: testPriceList()),
      appointments: null,
      height: 1600,
      overrides: bookingScheduleOverrides(bookings: bookings),
    );
  }

  /// La admin, desde otro dispositivo, pasa el turno a las 11:00 y, con
  /// [person], a otra persona.
  Future<void> adminEdits(
    WidgetTester tester, {
    AppointmentPerson? person,
  }) async {
    final saved = await bookings.updateAppointmentByAdmin(
      id: 't1',
      expected: (_) => true,
      start: fromSalon(at(20, 11)),
      end: fromSalon(at(20, 11, 45)),
      booked: spa,
      person: person,
    );
    expect(saved, isTrue);
    await settleWeb(tester);
  }

  for (final web in [false, true]) {
    final platform = web ? 'Web' : 'Android/iOS';

    testWidgets('en Reservas, la clienta ve la hora nueva y que está '
        'confirmado, sin recargar ($platform)', (tester) async {
      await open(tester, user: testClient, location: '/booking', web: web);
      expect(find.byType(ActiveAppointmentView), findsOneWidget);
      expect(find.text('10:00 – 10:45'), findsOneWidget);

      await adminEdits(tester);

      expect(find.byType(ActiveAppointmentView), findsOneWidget);
      expect(find.text('11:00 – 11:45'), findsOneWidget);
      expect(find.text('10:00 – 10:45'), findsNothing);
      expect(find.text('CONFIRMADA'), findsOneWidget);
    });
  }

  testWidgets('en Perfil, la clienta ve la hora nueva sin recargar', (
    tester,
  ) async {
    await open(tester, user: testClient, location: '/profile');
    expect(find.text(profileLine(10)), findsOneWidget);

    await adminEdits(tester);

    expect(find.text(profileLine(11)), findsOneWidget);
    expect(find.text(profileLine(10)), findsNothing);
  });

  group('si cambia la persona', () {
    const toBea = (
      clientId: 'bea',
      clientName: 'Beatriz',
      clientPhone: '+55 41 99222-0000',
      clientPhotoUrl: null,
    );

    testWidgets('la clienta anterior deja de verlo en Reservas y en Perfil', (
      tester,
    ) async {
      await open(tester, user: testClient, location: '/booking');
      expect(find.byType(ActiveAppointmentView), findsOneWidget);

      await adminEdits(tester, person: toBea);

      expect(find.byType(ActiveAppointmentView), findsNothing);
      expect(find.byType(BookingForm), findsOneWidget);
      webRouter(tester).go('/profile');
      await settleWeb(tester);
      expect(find.text('Todavía no tienes reservas.'), findsOneWidget);
    });

    testWidgets('la nueva lo ve como su turno activo', (tester) async {
      await open(tester, user: bea, location: '/booking');
      expect(find.byType(BookingForm), findsOneWidget);

      await adminEdits(tester, person: toBea);

      expect(find.byType(ActiveAppointmentView), findsOneWidget);
      expect(find.text('11:00 – 11:45'), findsOneWidget);
      webRouter(tester).go('/profile');
      await settleWeb(tester);
      expect(find.text(profileLine(11)), findsOneWidget);
    });
  });
}
