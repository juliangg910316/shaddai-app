import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

String _capitalized(String text) =>
    text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);

Future<DateTime> _pumpBooking(WidgetTester tester, String language) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 2400);
  addTearDown(tester.view.reset);

  final day = tomorrow();
  final slot = day.add(const Duration(hours: 14));
  await pumpApp(
    tester,
    stored: {'language': language},
    home: const BookingView(),
    overrides: bookingOverrides(day: day, slots: AsyncData([slot])),
  );
  // En la app, el router escucha siempre a la usuaria actual.
  appContainer(tester).listen(currentUserProvider, (_, _) {});
  await tester.pumpAndSettle();
  return slot;
}

Finder _inCalendar(String text) =>
    find.descendant(of: find.byType(TableCalendar), matching: find.text(text));

void main() {
  for (final language in ['es', 'pt']) {
    group('en $language (RF-10, RF-21)', () {
      testWidgets('la cabecera del calendario va en el idioma activo', (
        tester,
      ) async {
        final slot = await _pumpBooking(tester, language);

        final title = _capitalized(DateFormat.yMMMM(language).format(slot));
        expect(_inCalendar(title), findsOneWidget);
        expect(title, contains(' de '));
      });

      testWidgets('la semana empieza en lunes, con iniciales del idioma', (
        tester,
      ) async {
        await _pumpBooking(tester, language);

        // Lunes y domingo: L/D en español, S/D en portugués.
        final monday = language == 'es' ? 'L' : 'S';
        final mondayHeader = _inCalendar(monday).first;
        final sundayHeader = _inCalendar('D').first;
        expect(
          tester.getTopLeft(mondayHeader).dx,
          lessThan(tester.getTopLeft(sundayHeader).dx),
        );
        // Jueves: J en español, Q (quinta) en portugués.
        expect(
          _inCalendar(language == 'es' ? 'J' : 'Q'),
          findsAtLeastNWidgets(1),
        );
      });

      testWidgets('las horas van en formato de 24 horas', (tester) async {
        await _pumpBooking(tester, language);

        expect(find.text('14:00'), findsOneWidget);
      });

      testWidgets('el diálogo de confirmación muestra la fecha larga en el '
          'idioma activo', (tester) async {
        final slot = await _pumpBooking(tester, language);

        await tester.tap(find.text('14:00'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('CONFIRMAR 14:00'));
        await tester.pumpAndSettle();

        final longDate = DateFormat.yMMMMEEEEd(language).format(slot);
        expect(find.textContaining(longDate), findsOneWidget);
      });
    });
  }
}
