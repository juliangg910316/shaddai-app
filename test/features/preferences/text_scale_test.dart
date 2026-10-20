import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/preferences/presentation/preferences_section.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

/// Pantalla estrecha (320 px) con el texto del sistema al 200 % (RNF-6).
void _narrowAndLargeText(WidgetTester tester) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(320, 800);
  tester.platformDispatcher.textScaleFactorTestValue = 2;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

void main() {
  for (final language in ['es', 'pt']) {
    testWidgets('Perfil sin sesión a 320 px y texto al 200 % no se desborda '
        '($language, RNF-6)', (tester) async {
      _narrowAndLargeText(tester);

      await pumpApp(
        tester,
        stored: {'language': language},
        home: const ProfileView(),
        overrides: sessionOverrides(),
      );
      await tester.pumpAndSettle();

      expect(find.byType(PreferencesSection), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
