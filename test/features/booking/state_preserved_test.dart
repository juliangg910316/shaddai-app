import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

void main() {
  testWidgets(
    'con fecha y hora elegidas y el diálogo abierto, cambiar tema e idioma no '
    'pierde nada (RF-5, RF-10)',
    (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 2400);
      addTearDown(tester.view.reset);

      final day = tomorrow();
      final slot = day.add(const Duration(hours: 10));
      await pumpApp(
        tester,
        stored: {'theme': 'light', 'language': 'es'},
        home: const BookingView(),
        overrides: bookingOverrides(day: day, slots: AsyncData([slot])),
      );
      final container = appContainer(tester);
      container.listen(currentUserProvider, (_, _) {});
      await tester.pumpAndSettle();

      // Hora elegida y diálogo de confirmación abierto.
      await tester.tap(find.text('10:00'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('CONFIRMAR 10:00'));
      await tester.pumpAndSettle();
      expect(find.byType(AlertDialog), findsOneWidget);

      await container
          .read(themePreferenceProvider.notifier)
          .select(ThemePreference.dark);
      await container
          .read(languagePreferenceProvider.notifier)
          .select(AppLanguage.pt);
      await tester.pumpAndSettle();

      // El diálogo sigue abierto y ya está en portugués.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(
        Theme.of(tester.element(find.byType(AlertDialog))).brightness,
        Brightness.dark,
      );
      expect(find.textContaining('outubro'), findsWidgets);

      // Al cerrarlo, la fecha y la hora elegidas siguen ahí.
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      expect(container.read(selectedDateProvider), day);
      expect(find.text('CONFIRMAR 10:00'), findsOneWidget);
    },
  );
}
