import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';
import 'package:shaddai/features/preferences/presentation/preferences_section.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

void main() {
  testWidgets('en Web, el perfil no tiene Preferencias: van en la barra '
      '(RF-31)', (tester) async {
    await pumpWebApp(tester, location: '/profile', user: testClient);

    expect(find.byType(ProfileView), findsOneWidget);
    expect(find.byType(PreferencesSection), findsNothing);
  });

  testWidgets('en Web, salir desde el perfil lleva a la landing sin sesión '
      '(RF-28)', (tester) async {
    await pumpWebApp(tester, location: '/profile', user: testClient);

    await tester.tap(
      find.descendant(
        of: find.byType(ProfileView),
        matching: find.byIcon(Icons.logout),
      ),
    );
    await settleWeb(tester);

    expect(webLocation(tester).toString(), '/');
    expect(find.byType(LandingPage), findsOneWidget);
    expect(find.text('Entrar'), findsOneWidget);
  });

  testWidgets('en Android/iOS, el perfil sigue con Preferencias', (
    tester,
  ) async {
    await pumpApp(
      tester,
      home: const ProfileView(),
      overrides: [
        ...sessionOverrides(user: testClient),
        isWebProvider.overrideWithValue(false),
      ],
    );
    await tester.pumpAndSettle();

    expect(find.byType(PreferencesSection), findsOneWidget);
  });
}
