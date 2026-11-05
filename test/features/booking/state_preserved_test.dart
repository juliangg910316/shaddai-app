import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';

import '../../helpers/booking_steps.dart';
import '../../helpers/fake_booking.dart';
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

      // El día que abre la reserva con "ahora" el martes 10/11/2026.
      final day = DateTime.utc(2026, 11, 10);
      await pumpApp(
        tester,
        stored: {'theme': 'light', 'language': 'es'},
        home: const BookingView(),
        overrides: bookingDataOverrides(bookings: FakeBookingRepository()),
      );
      final container = appContainer(tester);
      container.listen(currentUserProvider, (_, _) {});
      await tester.pumpAndSettle();

      // Hora y servicio elegidos y diálogo de confirmación abierto.
      await openBookingConfirmation(tester);
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
      // El mes del día elegido, en portugués.
      expect(
        find.textContaining(DateFormat.MMMM('pt').format(day)),
        findsWidgets,
      );

      // Al cerrarlo, la fecha y la hora elegidas siguen ahí.
      await tester.tap(find.text('CANCELAR'));
      await tester.pumpAndSettle();
      final selection = container.read(bookingSelectionProvider).selection;
      expect(selection.day, day);
      expect(selection.start, DateTime.utc(2026, 11, 10, 10));
      expect(selection.item, isNotNull);
    },
  );
}
