import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/landing/landing_section.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_web_app.dart';

Finder _section(LandingSection section) => find.byWidgetPredicate(
  (widget) => widget is LandingSectionFrame && widget.section == section,
);

/// Recorre la landing de arriba abajo, para que se dibuje entera.
Future<void> _scrollThrough(WidgetTester tester) async {
  for (final section in LandingSection.values) {
    await tester.ensureVisible(_section(section));
    await settleWeb(tester);
  }
}

void main() {
  for (final width in [320.0, 360.0, 1280.0]) {
    for (final language in ['es', 'pt']) {
      testWidgets('a ${width.toInt()} px, en $language, nada se desborda '
          '(RNF-5)', (tester) async {
        await pumpWebApp(tester, width: width, stored: {'language': language});
        await _scrollThrough(tester);

        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final width in [360.0, 1280.0]) {
    for (final language in ['es', 'pt']) {
      testWidgets('con el texto al 200 %, a ${width.toInt()} px, en '
          '$language, nada se corta ni se solapa (RNF-4)', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await pumpWebApp(tester, width: width, stored: {'language': language});
        await _scrollThrough(tester);

        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('con sesión, a 320 px, la barra tampoco se desborda', (
    tester,
  ) async {
    await pumpWebApp(tester, width: 320, user: testClient);

    expect(tester.takeException(), isNull);
  });

  testWidgets('la página solo se desplaza en vertical: el único scroll '
      'horizontal es el carrusel del catálogo (RNF-5)', (tester) async {
    await pumpWebApp(tester, width: 320);

    final horizontal = find.byWidgetPredicate(
      (widget) =>
          widget is Scrollable &&
          (widget.axisDirection == AxisDirection.right ||
              widget.axisDirection == AxisDirection.left),
    );
    final allowed = <Finder>[
      // Carrusel del catálogo: se desplaza con la rueda, el dedo y el foco.
      find.descendant(
        of: _section(LandingSection.catalog),
        matching: horizontal,
      ),
      // Franja decorativa: se mueve sola y no se puede desplazar a mano.
      find.descendant(
        of: _section(LandingSection.marquee),
        matching: horizontal,
      ),
    ];
    final allowedElements = {
      for (final finder in allowed) ...finder.evaluate(),
    };

    expect(
      horizontal.evaluate().where((e) => !allowedElements.contains(e)),
      isEmpty,
    );
    // Y la landing cabe a lo ancho: ninguna sección es más ancha que la
    // ventana.
    for (final section in LandingSection.values) {
      expect(
        tester.getSize(_section(section)).width,
        lessThanOrEqualTo(320),
        reason: section.name,
      );
    }
    expect(find.byType(LandingPage), findsOneWidget);
  });
}
