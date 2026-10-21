import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:shaddai/features/admin/presentation/admin_dashboard_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';

import '../../helpers/pump_app.dart';

String _capitalized(String text) => text[0].toUpperCase() + text.substring(1);

void main() {
  final day = DateTime(2026, 8, 15);

  Future<void> pumpDashboard(WidgetTester tester, String language) async {
    await pumpApp(
      tester,
      stored: {'language': language},
      home: const AdminDashboardView(),
      overrides: [
        adminSelectedDateProvider.overrideWith((ref) => day),
        adminAppointmentsProvider.overrideWith((ref) => Stream.value(const [])),
      ],
    );
    await tester.pumpAndSettle();
  }

  for (final language in ['es', 'pt']) {
    testWidgets('la fecha del panel va en el idioma activo '
        '($language, RF-10, RF-21)', (tester) async {
      await pumpDashboard(tester, language);

      final expected = _capitalized(
        DateFormat.yMMMMEEEEd(language).format(day),
      );
      expect(find.text(expected), findsOneWidget);
    });
  }

  testWidgets('la cabecera verde pone iconos claros en la barra de estado '
      '(RF-23)', (tester) async {
    await pumpDashboard(tester, 'es');

    // El AnnotatedRegion de la cabecera es el más interno (el último).
    final style = tester
        .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
        )
        .last
        .value;
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark);
  });
}
