import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

String _capitalized(String text) => text[0].toUpperCase() + text.substring(1);

void main() {
  final start = DateTime(2026, 11, 4, 15, 30);

  for (final language in ['es', 'pt']) {
    testWidgets('las fechas de mis turnos van en el idioma activo '
        '($language, RF-10, RF-21)', (tester) async {
      await pumpApp(
        tester,
        stored: {'language': language},
        home: const ProfileView(),
        overrides: sessionOverrides(
          user: testClient,
          appointments: [testAppointment(start)],
        ),
      );
      await tester.pumpAndSettle();

      final weekday = _capitalized(DateFormat.EEEE(language).format(start));
      final month = DateFormat.MMM(language).format(start).toUpperCase();
      expect(find.text('$weekday · 15:30'), findsOneWidget);
      expect(find.text(month), findsOneWidget);
      expect(find.text('04'), findsOneWidget);
    });
  }

  testWidgets('un turno cancelado no baja la opacidad de su texto (RNF-1)', (
    tester,
  ) async {
    // Con opacidad 0,72 su texto quedaba en 3,02:1 en tema claro. La guía de
    // contraste de flutter_test no tiene en cuenta la opacidad, por eso se
    // comprueba aparte.
    await pumpApp(
      tester,
      stored: {'language': 'es'},
      home: const ProfileView(),
      overrides: sessionOverrides(
        user: testClient,
        appointments: [testAppointment(start, status: 'cancelled')],
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('CANCELADA'), findsOneWidget);
    expect(
      find.ancestor(of: find.text('CANCELADA'), matching: find.byType(Opacity)),
      findsNothing,
    );
  });
}
