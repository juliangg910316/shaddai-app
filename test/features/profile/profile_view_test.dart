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
}
