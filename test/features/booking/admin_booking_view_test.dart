import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/recipient.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/admin_booking_provider.dart';
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

UserModel client(
  String uid,
  String name, {
  String phone = '41 99999-0000',
  bool blocked = false,
  String role = 'cliente',
}) => UserModel(
  uid: uid,
  email: '$uid@example.com',
  displayName: name,
  phoneNumber: phone,
  isBlocked: blocked,
  role: role,
);

final ana = client('ana', 'Ana Souza', phone: '+55 41 99111-0000');
final joana = client('joana', 'Joana Conceição', phone: '41 99222-0000');
final carla = client('carla', 'Carla Bloqueada', blocked: true);
final otherAdmin = client('admin2', 'Ana Admin', role: 'admin');

/// Turno de Ana del viernes 20/11/2026 de 9:00 a 10:30, con un adicional.
AppointmentModel anaActive() => AppointmentModel(
  id: 'de-ana',
  clientId: 'ana',
  clientName: 'Ana Souza',
  clientPhone: '+55 41 99111-0000',
  startTime: fromSalon(DateTime.utc(2026, 11, 20, 9)),
  endTime: fromSalon(DateTime.utc(2026, 11, 20, 10, 30)),
  status: 'confirmed',
  createdAt: DateTime.utc(2026, 11, 1),
  booked: const BookedServiceModel(
    kind: BookedKind.service,
    id: 's1',
    name: BilingualText(es: 'Manicura rusa', pt: 'Manicure russa'),
    priceCents: 7000,
    durationMinutes: 90,
    addons: [
      BookedAddonModel(
        id: 'a1',
        name: BilingualText(es: 'Decoración', pt: 'Decoração'),
        priceCents: 1000,
      ),
    ],
  ),
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
    users = FakeUserRepository(users: [ana, joana, carla, otherAdmin, admin]);
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

  RecipientState recipientState(WidgetTester tester) =>
      appContainer(tester).read(bookingRecipientProvider);

  Future<void> search(WidgetTester tester, String text) async {
    await tester.enterText(
      find.widgetWithText(TextField, 'Nombre o WhatsApp de la clienta'),
      text,
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

  group('buscar y elegir a una clienta (RF-3 a RF-6, RF-14)', () {
    testWidgets('con menos de 2 caracteres, solo la indicación', (
      tester,
    ) async {
      await pump(tester);
      expect(find.text('Escribe al menos 2 caracteres'), findsOneWidget);

      await search(tester, 'a');
      expect(find.text('Ana Souza'), findsNothing);
      expect(find.text('Escribe al menos 2 caracteres'), findsOneWidget);
    });

    testWidgets('por nombre sin acentos ni mayúsculas, y por WhatsApp', (
      tester,
    ) async {
      await pump(tester);

      await search(tester, 'CONCEICAO');
      expect(find.text('Joana Conceição'), findsOneWidget);
      expect(find.text('41 99222-0000'), findsOneWidget);
      expect(find.text('Ana Souza'), findsNothing);

      await search(tester, '99111');
      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('Joana Conceição'), findsNothing);
    });

    testWidgets('sin bloqueadas ni admins', (tester) async {
      await pump(tester);
      await search(tester, 'ana');
      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('Joana Conceição'), findsOneWidget);
      expect(find.text('Ana Admin'), findsNothing);

      await search(tester, 'bloq');
      expect(find.text('Carla Bloqueada'), findsNothing);
    });

    testWidgets('sin resultados: lo dice y ofrece "Persona sin cuenta" '
        '(RF-5)', (tester) async {
      await pump(tester);
      await search(tester, 'zz');
      expect(
        find.text('No hay clientas con ese nombre o WhatsApp.'),
        findsOneWidget,
      );
      expect(find.text('PERSONA SIN CUENTA'), findsOneWidget);

      await tester.tap(find.text('PERSONA SIN CUENTA'));
      await settle(tester);
      expect(recipientState(tester).recipient, GuestRecipient.empty);
      expect(find.text('BUSCAR CLIENTA'), findsOneWidget);

      await tester.tap(find.text('BUSCAR CLIENTA'));
      await settle(tester);
      expect(recipientState(tester).recipient, isNull);
    });

    testWidgets('si no se cargan las clientas: aviso, "Reintentar" y '
        '"Persona sin cuenta" (RF-6)', (tester) async {
      await pump(tester);
      users.failUsers(Exception('permission-denied'));
      await settle(tester);

      expect(find.text('No se pudieron cargar las clientas.'), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsNothing);
      expect(find.text('PERSONA SIN CUENTA'), findsOneWidget);

      await tester.tap(find.text('REINTENTAR'));
      await settle(tester);
      expect(find.text('No se pudieron cargar las clientas.'), findsNothing);
      await search(tester, 'ana');
      expect(find.text('Ana Souza'), findsOneWidget);
    });

    testWidgets('elegirla muestra su tarjeta; "Cambiar" vuelve a buscar', (
      tester,
    ) async {
      await pump(tester);
      await search(tester, 'souza');
      await tester.tap(find.text('Ana Souza'));
      await settle(tester);

      expect(recipientState(tester).recipient, AccountRecipient.of(ana));
      expect(
        find.widgetWithText(TextField, 'Nombre o WhatsApp de la clienta'),
        findsNothing,
      );
      expect(find.text('Ana Souza'), findsOneWidget);
      expect(find.text('+55 41 99111-0000'), findsOneWidget);

      await tester.tap(find.text('CAMBIAR'));
      await settle(tester);
      expect(recipientState(tester).recipient, isNull);
      expect(
        find.widgetWithText(TextField, 'Nombre o WhatsApp de la clienta'),
        findsOneWidget,
      );
      expect(recipientState(tester).query, '');
    });

    testWidgets('si tiene un turno activo, lo dice con su fecha, su hora y '
        'lo reservado (RF-14)', (tester) async {
      bookings.active = [anaActive()];
      await pump(tester);
      await search(tester, 'ana s');
      await tester.tap(find.text('Ana Souza'));
      await settle(tester);

      expect(
        find.text(
          'Ya tiene un turno el viernes, 20 de noviembre de 2026 a las 9:00: '
          'Manicura rusa, Decoración. No se le puede agendar otro.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('en portugués', (tester) async {
      bookings.active = [anaActive()];
      await pumpApp(
        tester,
        stored: const {'language': 'pt'},
        home: const BookingView(),
        overrides: [
          ...bookingDataOverrides(bookings: bookings, user: admin),
          userRepositoryProvider.overrideWithValue(users),
        ],
      );
      await settle(tester);
      expect(find.text('Para quem'), findsOneWidget);
      expect(find.text('Digite pelo menos 2 caracteres'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, 'Nome ou WhatsApp da cliente'),
        'zz',
      );
      await settle(tester);
      expect(
        find.text('Não há clientes com esse nome ou WhatsApp.'),
        findsOneWidget,
      );
      expect(find.text('PESSOA SEM CONTA'), findsOneWidget);
    });
  });
}
