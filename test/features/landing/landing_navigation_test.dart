import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/core/widgets/brand_logo.dart';
import 'package:shaddai/features/landing/landing_section.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';
import 'package:shaddai/features/navigation/presentation/web_top_bar.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

Finder _section(LandingSection section) => find.byWidgetPredicate(
  (widget) => widget is LandingSectionFrame && widget.section == section,
);

Finder _inBar(Finder finder) =>
    find.descendant(of: find.byType(WebTopBar), matching: finder);

/// Distancia del comienzo de [section] al borde inferior de la barra: 0 si la
/// sección empieza justo debajo de ella (RF-4).
double _offsetBelowBar(WidgetTester tester, LandingSection section) =>
    tester.getTopLeft(_section(section)).dy -
    tester.getBottomLeft(find.byType(WebTopBar)).dy;

/// Scroll vertical de la landing.
ScrollPosition _landingScroll(WidgetTester tester) => tester
    .state<ScrollableState>(
      find
          .descendant(
            of: find.byType(LandingPage),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Scrollable &&
                  widget.axisDirection == AxisDirection.down,
            ),
          )
          .first,
    )
    .position;

void main() {
  group('desde la barra, en ancho amplio (RF-4)', () {
    for (final (link, section) in [
      ('SERVICIOS', LandingSection.prices),
      ('CATÁLOGO', LandingSection.catalog),
      ('SOBRE MÍ', LandingSection.about),
    ]) {
      testWidgets('"$link" deja ${section.name} justo debajo de la barra', (
        tester,
      ) async {
        await pumpWebApp(tester);

        await tester.tap(_inBar(find.text(link)));
        await settleWeb(tester);

        expect(
          _offsetBelowBar(tester, section),
          moreOrLessEquals(0, epsilon: 1),
        );
        // Sin cambiar de página ni de dirección.
        expect(webLocation(tester).toString(), '/');
      });
    }

    testWidgets('de una sección a otra, hacia arriba también', (tester) async {
      await pumpWebApp(tester);
      await tester.tap(_inBar(find.text('SOBRE MÍ')));
      await settleWeb(tester);

      await tester.tap(_inBar(find.text('SERVICIOS')));
      await settleWeb(tester);

      expect(
        _offsetBelowBar(tester, LandingSection.prices),
        moreOrLessEquals(0, epsilon: 1),
      );
    });
  });

  testWidgets('desde el menú lateral, en ancho estrecho, lleva a la sección '
      'y se cierra (RF-16)', (tester) async {
    await pumpWebApp(tester, width: 360);

    await tester.tap(find.byTooltip('Abrir menú'));
    await settleWeb(tester);
    await tester.tap(
      find.descendant(of: find.byType(Drawer), matching: find.text('SOBRE MÍ')),
    );
    await settleWeb(tester);

    expect(find.byType(Drawer), findsNothing);
    expect(
      _offsetBelowBar(tester, LandingSection.about),
      moreOrLessEquals(0, epsilon: 1),
    );
  });

  testWidgets('el logotipo vuelve al comienzo de la landing (RF-14)', (
    tester,
  ) async {
    await pumpWebApp(tester);
    await tester.tap(_inBar(find.text('SOBRE MÍ')));
    await settleWeb(tester);
    expect(_landingScroll(tester).pixels, greaterThan(0));

    await tester.tap(_inBar(find.byType(BrandLogo)));
    await settleWeb(tester);

    expect(_landingScroll(tester).pixels, 0);
  });

  group('con la sección en la dirección (RF-17, RF-29)', () {
    testWidgets('/?section=about abre la landing en "Sobre mí"', (
      tester,
    ) async {
      await pumpWebApp(tester, location: '/?section=about');

      expect(
        _offsetBelowBar(tester, LandingSection.about),
        moreOrLessEquals(0, epsilon: 1),
      );
    });

    testWidgets('una sección desconocida abre la landing arriba', (
      tester,
    ) async {
      await pumpWebApp(tester, location: '/?section=nada');

      expect(_landingScroll(tester).pixels, 0);
    });

    testWidgets('/services abre la landing en la lista de precios', (
      tester,
    ) async {
      await pumpWebApp(tester, location: '/services');

      expect(webLocation(tester).queryParameters['section'], 'prices');
      expect(
        _offsetBelowBar(tester, LandingSection.prices),
        moreOrLessEquals(0, epsilon: 1),
      );
    });

    testWidgets('"Catálogo" desde el perfil vuelve a la landing en el '
        'catálogo', (tester) async {
      await pumpWebApp(tester, location: '/profile', user: testClient);

      await tester.tap(_inBar(find.text('CATÁLOGO')));
      await settleWeb(tester);

      expect(find.byType(LandingPage), findsOneWidget);
      expect(
        _offsetBelowBar(tester, LandingSection.catalog),
        moreOrLessEquals(0, epsilon: 1),
      );
    });
  });

  testWidgets('cambiar el tema y el idioma a media página no mueve la landing '
      '(caso límite, spec 001 RF-5)', (tester) async {
    await pumpWebApp(tester, stored: {'theme': 'light', 'language': 'es'});
    await tester.tap(_inBar(find.text('CATÁLOGO')));
    await settleWeb(tester);
    final scrolled = _landingScroll(tester).pixels;

    final container = appContainer(tester);
    await container
        .read(themePreferenceProvider.notifier)
        .select(ThemePreference.dark);
    await container
        .read(languagePreferenceProvider.notifier)
        .select(AppLanguage.pt);
    await settleWeb(tester);

    expect(
      Theme.of(tester.element(find.byType(LandingPage))).brightness,
      Brightness.dark,
    );
    expect(_inBar(find.text('SOBRE MIM')), findsOneWidget);
    expect(_landingScroll(tester).pixels, scrolled);
  });
}
