import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/features/auth/presentation/login_view.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';
import 'package:shaddai/features/navigation/presentation/web_shell.dart';
import 'package:shaddai/features/navigation/presentation/web_top_bar.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// Ancho máximo de las páginas de cuenta en Web (RF-30).
const _accountPageMaxWidth = 640.0;

void _expectCenteredAndNarrow(WidgetTester tester, Finder page) {
  final rect = tester.getRect(page);
  expect(rect.width, lessThanOrEqualTo(_accountPageMaxWidth));
  expect(rect.center.dx, 1280 / 2);
}

void main() {
  group('Web', () {
    testWidgets('la dirección principal muestra la landing dentro de la '
        'estructura de Web (RF-1, RF-13)', (tester) async {
      await pumpWebApp(tester);

      expect(webLocation(tester).path, '/');
      expect(
        find.descendant(
          of: find.byType(WebShell),
          matching: find.byType(LandingPage),
        ),
        findsOneWidget,
      );
      expect(find.byType(WebTopBar), findsOneWidget);
    });

    testWidgets('la landing ocupa todo el ancho', (tester) async {
      await pumpWebApp(tester);

      expect(tester.getRect(find.byType(LandingPage)).width, 1280);
    });

    testWidgets('sin barra inferior ni barra provisional (RF-18)', (
      tester,
    ) async {
      await pumpWebApp(tester, user: testClient);

      expect(find.byType(BottomNavigationBar), findsNothing);
      expect(find.byType(AppBar), findsNothing);
    });

    testWidgets('/home lleva a la landing (RF-29)', (tester) async {
      await pumpWebApp(tester, location: '/home');

      expect(webLocation(tester).path, '/');
      expect(find.byType(LandingPage), findsOneWidget);
    });

    testWidgets('/services lleva a la landing en la lista de precios (RF-29)', (
      tester,
    ) async {
      await pumpWebApp(tester, location: '/services');

      expect(webLocation(tester).path, '/');
      expect(webLocation(tester).queryParameters['section'], 'prices');
      expect(find.byType(LandingPage), findsOneWidget);
    });

    testWidgets('el router usa las reglas de Web: la reserva sin sesión pide '
        'iniciarla y vuelve después (RF-19)', (tester) async {
      await pumpWebApp(tester, location: '/booking');

      expect(webLocation(tester).path, '/login');
      expect(webLocation(tester).queryParameters['next'], '/booking');
      expect(find.byType(LoginView), findsOneWidget);
    });

    group('páginas de cuenta (RF-30)', () {
      testWidgets('el inicio de sesión va centrado y con ancho máximo', (
        tester,
      ) async {
        await pumpWebApp(tester, location: '/login');

        _expectCenteredAndNarrow(tester, find.byType(LoginView));
        expect(find.byType(WebTopBar), findsOneWidget);
      });

      testWidgets('el perfil va centrado y con ancho máximo', (tester) async {
        await pumpWebApp(tester, location: '/profile', user: testClient);

        _expectCenteredAndNarrow(tester, find.byType(ProfileView));
        expect(find.byType(WebTopBar), findsOneWidget);
      });
    });
  });

  testWidgets('Android/iOS siguen con la barra inferior y sin la estructura '
      'de Web', (tester) async {
    await pumpApp(
      tester,
      router: shellRouter(initialLocation: '/home'),
      overrides: [
        ...sessionOverrides(),
        isWebProvider.overrideWithValue(false),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(BottomNavigationBar), findsOneWidget);
    expect(find.byType(WebShell), findsNothing);
    expect(find.byType(WebTopBar), findsNothing);
  });
}
