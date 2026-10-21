import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/features/auth/presentation/login_view.dart';
import 'package:shaddai/features/auth/presentation/phone_capture_view.dart';
import 'package:shaddai/features/auth/presentation/widgets/google_brand_button.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';
import 'package:shaddai/features/navigation/presentation/web_top_bar.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// Reservas sin Firebase: mañana, con un hueco libre a las 10:00, y las
/// reservas creadas en [bookings].
List<Override> _bookingOverrides(RecordingBookingRepository bookings) {
  final day = tomorrow();
  return [
    calendarSettingsProvider.overrideWith(
      (ref) => Stream.value(CalendarSettingsModel.defaultSettings()),
    ),
    selectedDateProvider.overrideWith((ref) => day),
    availableSlotsProvider.overrideWithValue(
      AsyncData([day.add(const Duration(hours: 10))]),
    ),
    bookingRepositoryProvider.overrideWithValue(bookings),
  ];
}

Future<void> _tapReserve(WidgetTester tester) async {
  await tester.tap(
    find.descendant(
      of: find.byType(WebTopBar),
      matching: find.text('RESERVAR'),
    ),
  );
  await settleWeb(tester);
}

/// Elige las 10:00 y confirma la reserva en el diálogo.
Future<void> _book(WidgetTester tester) async {
  await tester.tap(find.text('10:00'));
  await settleWeb(tester);
  await tester.tap(find.text('CONFIRMAR 10:00'));
  await settleWeb(tester);
  await tester.tap(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text('CONFIRMAR'),
    ),
  );
  await settleWeb(tester);
}

void main() {
  late RecordingBookingRepository bookings;

  setUp(() => bookings = RecordingBookingRepository());

  testWidgets('"Reservar" sin sesión pide iniciarla y, tras ella, abre la '
      'reserva (RF-19, RF-20)', (tester) async {
    final session = await pumpWebApp(
      tester,
      overrides: _bookingOverrides(bookings),
    );

    await _tapReserve(tester);
    expect(find.byType(LoginView), findsOneWidget);

    session.signIn(testClient);
    await settleWeb(tester);

    expect(webLocation(tester).path, '/booking');
    expect(find.byType(BookingView), findsOneWidget);
  });

  testWidgets('sin WhatsApp, pide el WhatsApp antes de la reserva (RF-20)', (
    tester,
  ) async {
    final session = await pumpWebApp(
      tester,
      overrides: _bookingOverrides(bookings),
    );

    await _tapReserve(tester);
    session.signIn(testClientWithoutPhone);
    await settleWeb(tester);
    expect(find.byType(PhoneCaptureView), findsOneWidget);

    await tester.enterText(find.byType(TextField), '41999990000');
    await tester.tap(find.text('GUARDAR Y CONTINUAR'));
    await settleWeb(tester);

    expect(webLocation(tester).path, '/booking');
    expect(find.byType(BookingView), findsOneWidget);
  });

  testWidgets('con sesión y WhatsApp, "Reservar" abre la reserva (RF-21)', (
    tester,
  ) async {
    await pumpWebApp(
      tester,
      user: testClient,
      overrides: _bookingOverrides(bookings),
    );

    await _tapReserve(tester);

    expect(webLocation(tester).path, '/booking');
    expect(find.byType(BookingView), findsOneWidget);
  });

  group('al crear la reserva (RF-22)', () {
    testWidgets('muestra la confirmación y "Volver al inicio" lleva a la '
        'landing', (tester) async {
      await pumpWebApp(
        tester,
        location: '/booking',
        user: testClient,
        overrides: _bookingOverrides(bookings),
      );

      await _book(tester);

      expect(bookings.created, hasLength(1));
      expect(find.text('Reserva creada'), findsOneWidget);
      await tester.tap(find.text('Volver al inicio'));
      await settleWeb(tester);

      expect(webLocation(tester).toString(), '/');
      expect(find.byType(LandingPage), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('"Cerrar" deja a la persona en la reserva', (tester) async {
      await pumpWebApp(
        tester,
        location: '/booking',
        user: testClient,
        overrides: _bookingOverrides(bookings),
      );

      await _book(tester);
      await tester.tap(find.text('Cerrar'));
      await settleWeb(tester);

      expect(webLocation(tester).path, '/booking');
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('en portugués', (tester) async {
      await pumpWebApp(
        tester,
        location: '/booking',
        user: testClient,
        stored: {'language': 'pt'},
        overrides: _bookingOverrides(bookings),
      );

      await tester.tap(find.text('10:00'));
      await settleWeb(tester);
      await tester.tap(find.textContaining('10:00').last);
      await settleWeb(tester);
      await tester.tap(
        find.descendant(
          of: find.byType(AlertDialog),
          matching: find.byType(ElevatedButton),
        ),
      );
      await settleWeb(tester);

      expect(find.text('Agendamento criado'), findsOneWidget);
      expect(find.text('Voltar ao início'), findsOneWidget);
    });

    testWidgets('en Android/iOS sigue el aviso de antes, sin diálogo', (
      tester,
    ) async {
      final day = tomorrow();
      await pumpApp(
        tester,
        home: const BookingView(),
        overrides: [
          ...bookingOverrides(
            day: day,
            slots: AsyncData([day.add(const Duration(hours: 10))]),
          ),
          bookingRepositoryProvider.overrideWithValue(bookings),
          isWebProvider.overrideWithValue(false),
        ],
      );
      appContainer(tester).listen(currentUserProvider, (_, _) {});
      await tester.pumpAndSettle();

      await _book(tester);

      expect(bookings.created, hasLength(1));
      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text('Reserva creada'), findsNothing);
    });
  });

  testWidgets('una clienta bloqueada se queda en el login con su mensaje '
      '(RF-23)', (tester) async {
    final blocked = testClient.copyWith(isBlocked: true);
    await pumpWebApp(
      tester,
      authRepository: FakeAuthRepository(
        credential: FakeUserCredential(FakeFirebaseUser(blocked.uid)),
      ),
      userRepository: FakeUserRepository(stored: blocked),
      overrides: _bookingOverrides(bookings),
    );

    await _tapReserve(tester);
    await tester.tap(find.byType(GoogleBrandButton));
    await settleWeb(tester);

    expect(webLocation(tester).path, '/login');
    expect(find.textContaining('Tu cuenta está bloqueada'), findsOneWidget);
  });
}
