import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/active_appointment_view.dart';
import 'package:shaddai/features/booking/presentation/booking_notices.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/landing/landing_content.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/recording_link_launcher.dart';

// Horas de pared del salón. "Ahora" es el martes 10/11/2026 a las 7:00.
DateTime at(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, 10, hour, minute);

/// Su turno activo: hoy de 9:00 a 9:45.
final appointment = AppointmentModel(
  id: 't1',
  clientId: testClient.uid,
  clientName: testClient.displayName,
  clientPhone: testClient.phoneNumber!,
  startTime: fromSalon(at(9)),
  endTime: fromSalon(at(9, 45)),
  status: 'confirmed',
  createdAt: bookingTestNow,
  booked: const BookedServiceModel(
    kind: BookedKind.service,
    id: 's1',
    name: BilingualText(es: 'Manicura', pt: 'Manicure'),
    priceCents: 3000,
    durationMinutes: 45,
  ),
);

/// El calendario por defecto con un margen de edición de [minutes].
CalendarSettingsModel withMargin(int minutes) {
  final defaults = CalendarSettingsModel.defaultSettings();
  return CalendarSettingsModel(
    openingHours: defaults.openingHours,
    globalSlotDurationMinutes: defaults.globalSlotDurationMinutes,
    blockedDates: defaults.blockedDates,
    editMarginMinutes: minutes,
  );
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeBookingRepository bookings;
  late RecordingLinkLauncher links;

  setUp(() {
    bookings = FakeBookingRepository(mine: [appointment]);
    links = RecordingLinkLauncher();
  });

  Future<void> pump(
    WidgetTester tester, {
    int margin = 0,
    String language = 'es',
    Stream<UserModel?> Function()? userStream,
    Stream<DateTime> Function()? nowStream,
    Stream<CalendarSettingsModel> Function()? settingsStream,
    UserModel? user,
  }) async {
    await pumpApp(
      tester,
      stored: {'language': language},
      home: const BookingView(),
      overrides: [
        ...bookingDataOverrides(
          bookings: bookings,
          user: user,
          userStream: userStream,
          nowStream: nowStream,
          settings: withMargin(margin),
          settingsStream: settingsStream,
        ),
        links.override,
      ],
    );
    await settle(tester);
  }

  group('"Editar turno" en el turno activo (RF-1 a RF-3, RF-22)', () {
    testWidgets('con margen 0, se ve el botón', (tester) async {
      await pump(tester);
      expect(find.byType(ActiveAppointmentView), findsOneWidget);
      expect(find.text('EDITAR TURNO'), findsOneWidget);
      expect(find.textContaining('Ya no puedes cambiar'), findsNothing);
    });

    testWidgets('en portugués', (tester) async {
      await pump(tester, language: 'pt');
      expect(find.text('EDITAR HORÁRIO'), findsOneWidget);
    });

    testWidgets('dentro del margen: sin botón, con la explicación y '
        'WhatsApp (RF-2)', (tester) async {
      await pump(tester, margin: 180);
      expect(find.text('EDITAR TURNO'), findsNothing);
      expect(
        find.textContaining('Ya no puedes cambiar este turno'),
        findsOneWidget,
      );
      await tester.tap(find.textContaining('WHATSAPP'));
      expect(links.opened, [Uri.parse(LandingContent.whatsappUrl)]);
    });

    testWidgets('desaparece sin recargar al pasar el tiempo (RF-3)', (
      tester,
    ) async {
      final now = StreamController<DateTime>.broadcast();
      addTearDown(now.close);
      await pump(
        tester,
        nowStream: () async* {
          yield at(7);
          yield* now.stream;
        },
      );
      expect(find.text('EDITAR TURNO'), findsOneWidget);

      now.add(at(9));
      await settle(tester);
      expect(find.text('EDITAR TURNO'), findsNothing);
      expect(
        find.textContaining('Ya no puedes cambiar este turno'),
        findsOneWidget,
      );
    });

    testWidgets('aparece o desaparece al cambiar el margen (RF-3)', (
      tester,
    ) async {
      final calendar = StreamController<CalendarSettingsModel>.broadcast();
      addTearDown(calendar.close);
      await pump(
        tester,
        settingsStream: () async* {
          yield withMargin(0);
          yield* calendar.stream;
        },
      );
      expect(find.text('EDITAR TURNO'), findsOneWidget);

      calendar.add(withMargin(180));
      await settle(tester);
      expect(find.text('EDITAR TURNO'), findsNothing);

      calendar.add(withMargin(30));
      await settle(tester);
      expect(find.text('EDITAR TURNO'), findsOneWidget);
    });

    testWidgets('al bloquearla, solo el aviso de bloqueo (RF-3, D-6)', (
      tester,
    ) async {
      final users = StreamController<UserModel?>.broadcast();
      addTearDown(users.close);
      await pump(
        tester,
        userStream: () async* {
          yield testClient;
          yield* users.stream;
        },
      );
      expect(find.text('EDITAR TURNO'), findsOneWidget);

      users.add(testClient.copyWith(isBlocked: true));
      await settle(tester);
      expect(find.text('EDITAR TURNO'), findsNothing);
      expect(find.byType(BookingBlockedNotice), findsOneWidget);
      expect(find.textContaining('Ya no puedes cambiar'), findsNothing);
    });

    testWidgets('bloqueada dentro del margen: tampoco la explicación (D-6)', (
      tester,
    ) async {
      await pump(
        tester,
        margin: 180,
        user: testClient.copyWith(isBlocked: true),
      );
      expect(find.byType(BookingBlockedNotice), findsOneWidget);
      expect(find.textContaining('Ya no puedes cambiar'), findsNothing);
    });

    testWidgets('si el calendario no se puede leer: sin botón, aviso con '
        '"Reintentar", que vuelve a leerlo (RF-22)', (tester) async {
      var calls = 0;
      await pump(
        tester,
        settingsStream: () => ++calls == 1
            ? Stream<CalendarSettingsModel>.error(Exception('unavailable'))
            : Stream.value(withMargin(0)),
      );
      expect(find.byType(ActiveAppointmentView), findsOneWidget);
      expect(find.text('EDITAR TURNO'), findsNothing);
      expect(find.byType(BookingLoadErrorNotice), findsOneWidget);
      expect(find.textContaining('unavailable'), findsNothing);

      await tester.tap(find.text('REINTENTAR'));
      await settle(tester);
      expect(find.byType(BookingLoadErrorNotice), findsNothing);
      expect(find.text('EDITAR TURNO'), findsOneWidget);
    });
  });
}
