import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/landing/landing_content.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/preferences/presentation/preferences_section.dart';
import 'package:shaddai/features/profile/presentation/profile_cards.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';
import '../../helpers/recording_link_launcher.dart';

// Horas de pared del salón. "Ahora" es el martes 10/11/2026 a las 7:00
// (bookingTestNow).
DateTime at(int hour, [int minute = 0, int day = 10]) =>
    DateTime.utc(2026, 11, day, hour, minute);

BilingualText text(String es, String pt) => BilingualText(es: es, pt: pt);

/// Manicura con Decoración.
final booked = BookedServiceModel(
  kind: BookedKind.service,
  id: 's1',
  name: text('Manicura', 'Manicure'),
  priceCents: 3000,
  durationMinutes: 45,
  addons: [
    BookedAddonModel(
      id: 'a1',
      name: text('Decoración', 'Decoração'),
      priceCents: 1000,
    ),
  ],
);

/// Su turno: hoy de [start] (9:00) a 45 minutos después.
AppointmentModel appointment({
  DateTime? start,
  String status = 'confirmed',
  BookedServiceModel? withBooked,
  bool noBooked = false,
}) {
  final from = fromSalon(start ?? at(9));
  return AppointmentModel(
    id: 't1',
    clientId: testClient.uid,
    clientName: testClient.displayName,
    clientPhone: testClient.phoneNumber!,
    startTime: from,
    endTime: from.add(const Duration(minutes: 45)),
    status: status,
    createdAt: bookingTestNow,
    booked: noBooked ? null : (withBooked ?? booked),
  );
}

CalendarSettingsModel withMargin(int minutes) {
  final defaults = CalendarSettingsModel.defaultSettings();
  return CalendarSettingsModel(
    openingHours: defaults.openingHours,
    globalSlotDurationMinutes: defaults.globalSlotDurationMinutes,
    blockedDates: defaults.blockedDates,
    editMarginMinutes: minutes,
  );
}

final activeCard = find.byType(ProfileActiveCard);
Finder inCard(Finder finder) =>
    find.descendant(of: activeCard, matching: finder);

void main() {
  late FakeBookingRepository bookings;
  late RecordingLinkLauncher links;

  setUp(() {
    bookings = FakeBookingRepository(mine: [appointment()]);
    links = RecordingLinkLauncher();
  });

  /// La app de Android/iOS en Perfil, con los turnos de [bookings].
  Future<void> mobile(
    WidgetTester tester, {
    int margin = 0,
    String language = 'es',
    Stream<DateTime> Function()? nowStream,
  }) => pumpMobileApp(
    tester,
    location: '/profile',
    user: testClient,
    stored: {'language': language},
    appointments: null,
    overrides: [
      ...bookingScheduleOverrides(
        bookings: bookings,
        settings: withMargin(margin),
        nowStream: nowStream,
      ),
      links.override,
    ],
  );

  /// Lleva [finder] a la vista y lo toca.
  Future<void> tap(WidgetTester tester, Finder finder) async {
    await tester.ensureVisible(finder);
    await tester.pump();
    await tester.tap(finder);
    await settleWeb(tester);
  }

  group('su turno activo (RF-1, RF-2, RF-44)', () {
    testWidgets('con el día, la fecha, la franja en hora del salón, el '
        'servicio, los adicionales y el estado', (tester) async {
      await mobile(tester);

      expect(find.text('Tu próximo turno'), findsOneWidget);
      expect(activeCard, findsOneWidget);
      expect(
        inCard(find.text('Martes, 10 de noviembre de 2026')),
        findsOneWidget,
      );
      // En hora del salón, esté donde esté el dispositivo (RF-2). Para verlo
      // en rojo: TZ=Europe/Lisbon flutter test …
      expect(inCard(find.text('9:00 – 9:45')), findsOneWidget);
      expect(inCard(find.text('Manicura')), findsOneWidget);
      expect(inCard(find.textContaining('Decoración')), findsOneWidget);
      expect(inCard(find.text('CONFIRMADA')), findsOneWidget);
    });

    testWidgets('en portugués', (tester) async {
      await mobile(tester, language: 'pt');
      expect(find.text('Seu próximo horário'), findsOneWidget);
      expect(
        inCard(find.text('Terça-feira, 10 de novembro de 2026')),
        findsOneWidget,
      );
      expect(inCard(find.text('09:00 – 09:45')), findsOneWidget);
      expect(inCard(find.text('Manicure')), findsOneWidget);
    });

    testWidgets('esperando confirmación', (tester) async {
      bookings.mine = [appointment(status: 'waiting_confirmation')];
      await mobile(tester);
      expect(inCard(find.text('EN REVISIÓN')), findsOneWidget);
    });

    testWidgets('un turno antiguo sin servicio se muestra sin servicio '
        '(RF-44)', (tester) async {
      bookings.mine = [appointment(noBooked: true)];
      await mobile(tester);
      expect(activeCard, findsOneWidget);
      expect(inCard(find.text('9:00 – 9:45')), findsOneWidget);
      expect(inCard(find.text('Manicura')), findsNothing);
    });
  });

  group('editar y cancelar (RF-3, RF-4, RF-7, RF-8)', () {
    testWidgets('"Editar turno" abre la edición en Reservas (Android/iOS)', (
      tester,
    ) async {
      await mobile(tester);
      await tap(tester, inCard(find.text('EDITAR TURNO')));

      expect(webLocation(tester).path, '/booking');
      expect(find.byType(BookingView), findsOneWidget);
      expect(appContainer(tester).read(editTargetProvider)?.id, 't1');
    });

    testWidgets('"Editar turno" abre la edición en /booking (Web)', (
      tester,
    ) async {
      await pumpWebApp(
        tester,
        location: '/profile',
        user: testClient,
        appointments: null,
        overrides: bookingScheduleOverrides(
          bookings: bookings,
          settings: withMargin(0),
        ),
      );
      await tap(tester, inCard(find.text('EDITAR TURNO')));

      expect(webLocation(tester).path, '/booking');
      expect(find.byType(BookingView), findsOneWidget);
      expect(appContainer(tester).read(editTargetProvider)?.id, 't1');
    });

    testWidgets('"Cancelar turno" abre el mismo diálogo que en Reservas', (
      tester,
    ) async {
      await mobile(tester);
      await tester.ensureVisible(inCard(find.text('CANCELAR TURNO')));
      await tester.pump();
      await tester.tap(inCard(find.text('CANCELAR TURNO')));
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('¿Cancelar tu turno?'), findsOneWidget);
      await tester.tap(find.text('Sí, cancelar'));
      await settleWeb(tester);

      expect(bookings.cancelled, ['t1']);
      expect(activeCard, findsNothing);
      expect(find.text('No tienes turnos próximos.'), findsOneWidget);
    });

    testWidgets('al llegar el margen, los botones dan paso al aviso con '
        'WhatsApp sin recargar (RF-4, RF-7)', (tester) async {
      final now = StreamController<DateTime>.broadcast();
      addTearDown(now.close);
      await mobile(
        tester,
        margin: 60,
        nowStream: () async* {
          yield at(7);
          yield* now.stream;
        },
      );
      expect(inCard(find.text('EDITAR TURNO')), findsOneWidget);
      expect(inCard(find.text('CANCELAR TURNO')), findsOneWidget);

      now.add(at(8));
      await settleWeb(tester);

      expect(inCard(find.text('EDITAR TURNO')), findsNothing);
      expect(inCard(find.text('CANCELAR TURNO')), findsNothing);
      expect(
        inCard(find.textContaining('Ya no puedes cambiar este turno')),
        findsOneWidget,
      );
      await tap(tester, inCard(find.textContaining('WHATSAPP')));
      expect(links.opened, [Uri.parse(LandingContent.whatsappUrl)]);
    });
  });

  group('sin turno activo (RF-5)', () {
    testWidgets('dice que no tiene turnos próximos y ofrece reservar', (
      tester,
    ) async {
      bookings.mine = [appointment(status: 'cancelled')];
      await mobile(tester);

      expect(activeCard, findsNothing);
      expect(find.text('No tienes turnos próximos.'), findsOneWidget);
      await tap(tester, find.byKey(const ValueKey('profile-book')));
      expect(webLocation(tester).path, '/booking');
    });
  });

  testWidgets('el perfil cambia sin recargar cuando cambia el turno (RF-6)', (
    tester,
  ) async {
    bookings.mine = [appointment(status: 'waiting_confirmation')];
    await mobile(tester);
    expect(inCard(find.text('EN REVISIÓN')), findsOneWidget);

    // La admin lo confirma.
    bookings.emitMine([appointment()]);
    await settleWeb(tester);
    expect(inCard(find.text('CONFIRMADA')), findsOneWidget);

    // La admin lo mueve al jueves.
    bookings.emitMine([appointment(start: at(9, 0, 12))]);
    await settleWeb(tester);
    expect(
      inCard(find.text('Jueves, 12 de noviembre de 2026')),
      findsOneWidget,
    );

    // La admin lo cancela.
    bookings.emitMine([appointment(status: 'cancelled')]);
    await settleWeb(tester);
    expect(activeCard, findsNothing);
    expect(find.text('No tienes turnos próximos.'), findsOneWidget);
    expect(find.byType(ProfileView), findsOneWidget);
  });

  group('historial (RF-20 a RF-23)', () {
    /// Un turno pasado o cancelado del día [day] a las 15:00 del salón.
    AppointmentModel past(
      String id,
      int day,
      String status, {
      bool byClient = false,
    }) {
      final from = fromSalon(at(15, 0, day));
      return AppointmentModel(
        id: id,
        clientId: testClient.uid,
        clientName: testClient.displayName,
        clientPhone: testClient.phoneNumber!,
        startTime: from,
        endTime: from.add(const Duration(minutes: 45)),
        status: status,
        createdAt: bookingTestNow,
        booked: booked,
        cancelledByClient: byClient,
      );
    }

    final history = find.byType(ProfileHistoryCard);

    testWidgets('del más reciente al más antiguo, cada uno con su etiqueta y '
        'sin acciones', (tester) async {
      bookings.mine = [
        appointment(),
        past('realizado', 3, 'confirmed'),
        past('por-ti', 12, 'cancelled', byClient: true),
        past('por-el-salon', 1, 'cancelled'),
        past('sin-confirmar', 2, 'waiting_confirmation'),
      ];
      await mobile(tester);

      expect(find.text('Historial'), findsOneWidget);
      expect(activeCard, findsOneWidget);
      expect(history, findsNWidgets(4));
      final labels = [
        for (final card in tester.widgetList<ProfileHistoryCard>(history))
          card.appointment.id,
      ];
      expect(labels, ['por-ti', 'realizado', 'sin-confirmar', 'por-el-salon']);
      Finder label(String id, String text) => find.descendant(
        of: find.byKey(ValueKey('history-$id')),
        matching: find.text(text),
      );
      expect(label('por-ti', 'CANCELADO POR TI'), findsOneWidget);
      expect(label('realizado', 'REALIZADO'), findsOneWidget);
      expect(label('sin-confirmar', 'NO CONFIRMADO'), findsOneWidget);
      expect(label('por-el-salon', 'CANCELADO POR EL SALÓN'), findsOneWidget);
      // En hora del salón y con el servicio (RF-20).
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('history-realizado')),
          matching: find.text('Martes · 15:00'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(of: history.first, matching: find.text('Manicura')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: history,
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
        findsNothing,
      );
    });

    testWidgets('en portugués', (tester) async {
      bookings.mine = [
        past('por-ti', 3, 'cancelled', byClient: true),
        past('realizado', 2, 'confirmed'),
      ];
      await mobile(tester, language: 'pt');
      expect(find.text('Histórico'), findsOneWidget);
      expect(find.text('CANCELADO POR VOCÊ'), findsOneWidget);
      expect(find.text('REALIZADO'), findsOneWidget);
    });

    testWidgets('sin historial no hay sección (RF-22)', (tester) async {
      await mobile(tester);
      expect(activeCard, findsOneWidget);
      expect(find.text('Historial'), findsNothing);
      expect(history, findsNothing);
    });
  });

  group('estructura del perfil (RF-24, RF-43; D-12)', () {
    testWidgets('si los turnos no cargan: texto y "Reintentar", que los vuelve '
        'a pedir, y las preferencias siguen ahí (RF-24)', (tester) async {
      var requests = 0;
      await pumpMobileApp(
        tester,
        location: '/profile',
        user: testClient,
        appointments: null,
        overrides: [
          ...bookingScheduleOverrides(bookings: bookings),
          myAppointmentsProvider.overrideWith((ref) {
            requests++;
            return Stream.error(Exception('permission-denied'));
          }),
        ],
      );

      expect(
        find.text('No pudimos cargar tus reservas. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining('permission'), findsNothing);
      expect(find.byType(PreferencesSection), findsOneWidget);
      expect(find.byIcon(Icons.logout), findsOneWidget);

      final before = requests;
      await tap(tester, find.text('REINTENTAR'));
      expect(requests, greaterThan(before));
    });

    testWidgets('"Reservar" solo sin turno activo (RF-43)', (tester) async {
      await mobile(tester);
      expect(activeCard, findsOneWidget);
      expect(find.byKey(const ValueKey('profile-book')), findsNothing);
      expect(find.textContaining('RESERVAR OTRO TURNO'), findsNothing);
    });

    testWidgets('la admin ve el acceso al panel (RF-43)', (tester) async {
      bookings.mine = [];
      await pumpMobileApp(
        tester,
        location: '/profile',
        user: UserModel(
          uid: 'admin',
          email: 'beidis@example.com',
          displayName: 'Beidis Viera',
          phoneNumber: '+55 41 98888-0000',
          role: 'admin',
        ),
        appointments: null,
        overrides: bookingScheduleOverrides(bookings: bookings),
      );
      expect(find.text('PANEL DE ADMINISTRADOR'), findsOneWidget);
    });

    testWidgets('"Cerrar sesión" es un botón con nombre (RNF-2)', (
      tester,
    ) async {
      await mobile(tester);
      final logout = find.byTooltip('Cerrar sesión');
      expect(logout, findsOneWidget);
      expect(
        find.ancestor(
          of: find.byIcon(Icons.logout),
          matching: find.byType(IconButton),
        ),
        findsOneWidget,
      );
    });

    testWidgets('todo el perfil está en una sola lista con desplazamiento '
        '(D-12)', (tester) async {
      await mobile(tester);
      final list = find.byType(Scrollable).first;
      for (final part in [
        find.byIcon(Icons.logout),
        find.text(testClient.displayName),
        activeCard,
        find.byType(PreferencesSection),
      ]) {
        expect(
          find.ancestor(of: part, matching: list),
          findsOneWidget,
          reason: '$part',
        );
      }
    });
  });
}
