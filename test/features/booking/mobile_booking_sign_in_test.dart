import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/auth/presentation/phone_capture_view.dart';
import 'package:shaddai/features/auth/presentation/widgets/google_brand_button.dart';
import 'package:shaddai/features/booking/presentation/booking_sign_in_prompt.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// Reservas sin Firebase: el calendario por defecto, sin turnos ocupados,
/// con "ahora" el martes 10/11/2026 a las 7:00 (hay hueco a las 10:00).
List<Override> _bookingOverrides() =>
    bookingScheduleOverrides(bookings: FakeBookingRepository());

/// El calendario de la reserva (con sesión).
final _calendar = find.text('10:00');

Future<void> _tapGoogle(WidgetTester tester) async {
  await tester.tap(find.byType(GoogleBrandButton));
  await settleWeb(tester);
}

void main() {
  for (final (language, title) in [
    ('es', 'Inicia sesión para reservar'),
    ('pt', 'Entre para agendar'),
  ]) {
    testWidgets('sin sesión, Reservas muestra el aviso con la barra inferior '
        'visible, en $language (RF-16)', (tester) async {
      await pumpMobileApp(
        tester,
        location: '/booking',
        stored: {'language': language},
        overrides: _bookingOverrides(),
      );

      expect(find.byType(BookingSignInPrompt), findsOneWidget);
      expect(find.text(title), findsOneWidget);
      expect(find.byType(GoogleBrandButton), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);
      expect(webLocation(tester).path, '/booking');
      expect(_calendar, findsNothing);
    });
  }

  testWidgets('al iniciar sesión, la reserva aparece en la misma pestaña '
      '(RF-17)', (tester) async {
    final session = await pumpMobileApp(
      tester,
      location: '/booking',
      overrides: _bookingOverrides(),
    );

    session.signIn(testClient);
    await settleWeb(tester);

    expect(webLocation(tester).path, '/booking');
    expect(find.byType(BookingSignInPrompt), findsNothing);
    expect(find.byType(BookingView), findsOneWidget);
    expect(_calendar, findsOneWidget);
  });

  testWidgets('sin WhatsApp, lo pide y vuelve a Reservas (RF-17)', (
    tester,
  ) async {
    final session = await pumpMobileApp(
      tester,
      location: '/booking',
      overrides: _bookingOverrides(),
    );

    session.signIn(testClientWithoutPhone);
    await settleWeb(tester);
    expect(find.byType(PhoneCaptureView), findsOneWidget);

    await tester.enterText(find.byType(TextField), '41999990000');
    await tester.tap(find.text('GUARDAR Y CONTINUAR'));
    await settleWeb(tester);

    expect(webLocation(tester).path, '/booking');
    expect(_calendar, findsOneWidget);
  });

  testWidgets('una clienta bloqueada ve su mensaje en el aviso (RF-18)', (
    tester,
  ) async {
    final blocked = testClient.copyWith(isBlocked: true);
    await pumpMobileApp(
      tester,
      location: '/booking',
      authRepository: FakeAuthRepository(
        credential: FakeUserCredential(FakeFirebaseUser(blocked.uid)),
      ),
      userRepository: FakeUserRepository(stored: blocked),
      overrides: _bookingOverrides(),
    );

    await _tapGoogle(tester);

    expect(find.byType(BookingSignInPrompt), findsOneWidget);
    expect(find.textContaining('Tu cuenta está bloqueada'), findsOneWidget);
  });

  testWidgets('si el inicio de sesión falla, muestra el error de la app '
      '(RF-19)', (tester) async {
    await pumpMobileApp(
      tester,
      location: '/booking',
      authRepository: FakeAuthRepository(
        credential: FakeUserCredential(FakeFirebaseUser('u1')),
      ),
      userRepository: FakeUserRepository(error: Exception('unavailable')),
      overrides: _bookingOverrides(),
    );

    await _tapGoogle(tester);

    expect(find.byType(BookingSignInPrompt), findsOneWidget);
    expect(
      find.text('No pudimos iniciar sesión. Inténtalo de nuevo.'),
      findsOneWidget,
    );
    expect(find.textContaining('unavailable'), findsNothing);
  });

  testWidgets('si se cancela, se queda en el aviso sin mensaje (RF-19)', (
    tester,
  ) async {
    await pumpMobileApp(
      tester,
      location: '/booking',
      authRepository: FakeAuthRepository(),
      overrides: _bookingOverrides(),
    );

    await _tapGoogle(tester);

    expect(find.byType(BookingSignInPrompt), findsOneWidget);
    expect(find.textContaining('bloqueada'), findsNothing);
    expect(find.textContaining('No pudimos'), findsNothing);
  });

  testWidgets('al cerrar la sesión con una hora elegida, Reservas vuelve al '
      'aviso (caso límite)', (tester) async {
    final session = await pumpMobileApp(
      tester,
      location: '/booking',
      user: testClient,
      overrides: _bookingOverrides(),
    );
    await tester.tap(_calendar);
    await settleWeb(tester);
    expect(
      appContainer(tester).read(bookingSelectionProvider).selection.start,
      isNotNull,
    );

    session.signOut();
    await settleWeb(tester);

    expect(find.byType(BookingSignInPrompt), findsOneWidget);
    expect(find.byType(NavigationBar), findsOneWidget);
  });

  testWidgets('con sesión iniciada desde Perfil, Reservas muestra la reserva '
      'directamente (caso límite)', (tester) async {
    final session = await pumpMobileApp(
      tester,
      location: '/profile',
      overrides: _bookingOverrides(),
    );
    session.signIn(testClient);
    await settleWeb(tester);

    await tester.tap(find.text('Turnos'));
    await settleWeb(tester);

    expect(find.byType(BookingSignInPrompt), findsNothing);
    expect(_calendar, findsOneWidget);
  });
}
