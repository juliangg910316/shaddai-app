import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/widgets/brand_logo.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';
import 'package:shaddai/features/navigation/presentation/web_top_bar.dart';
import 'package:shaddai/features/preferences/presentation/language_switch.dart';
import 'package:shaddai/features/preferences/presentation/theme_menu_button.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_web_app.dart';

final _bar = find.byType(WebTopBar);

Finder _inBar(Finder finder) => find.descendant(of: _bar, matching: finder);

Finder _menuButton() => find.byTooltip('Abrir menú');

/// Abre el menú lateral (ancho estrecho).
Future<void> _openMenu(WidgetTester tester) async {
  await tester.tap(_menuButton());
  await settleWeb(tester);
}

/// Cambia el ancho de la ventana de la app ya montada.
Future<void> _resize(WidgetTester tester, double width) async {
  tester.view.physicalSize = Size(width, 900);
  await settleWeb(tester);
}

void main() {
  group('ancho amplio (1280 px)', () {
    testWidgets('logotipo con nombre, enlaces, selectores y "Reservar" '
        '(RF-13)', (tester) async {
      await pumpWebApp(tester);

      expect(_inBar(find.byType(BrandLogo)), findsOneWidget);
      expect(_inBar(find.text('Studio Shaddai')), findsOneWidget);
      for (final link in ['SERVICIOS', 'CATÁLOGO', 'SOBRE MÍ']) {
        expect(_inBar(find.text(link)), findsOneWidget, reason: link);
      }
      expect(_inBar(find.byType(ThemeMenuButton)), findsOneWidget);
      expect(_inBar(find.byType(LanguageSwitch)), findsOneWidget);
      expect(_inBar(find.text('RESERVAR')), findsOneWidget);
      expect(_menuButton(), findsNothing);
    });

    testWidgets('los textos de la barra van en portugués', (tester) async {
      await pumpWebApp(tester, stored: {'language': 'pt'});

      for (final text in ['SERVIÇOS', 'CATÁLOGO', 'SOBRE MIM', 'AGENDAR']) {
        expect(_inBar(find.text(text)), findsOneWidget, reason: text);
      }
    });

    testWidgets('un enlace de sección desde una página de cuenta vuelve a la '
        'landing en esa sección (RF-17)', (tester) async {
      await pumpWebApp(tester, location: '/login');

      await tester.tap(_inBar(find.text('SOBRE MÍ')));
      await settleWeb(tester);

      expect(webLocation(tester).path, '/');
      expect(webLocation(tester).queryParameters['section'], 'about');
      expect(find.byType(LandingPage), findsOneWidget);
    });
  });

  group('ancho estrecho (360 px)', () {
    testWidgets('logotipo sin nombre, "Reservar" y menú, sin enlaces ni '
        'selectores (RF-15)', (tester) async {
      await pumpWebApp(tester, width: 360);

      expect(_inBar(find.byType(BrandLogo)), findsOneWidget);
      expect(_inBar(find.text('Studio Shaddai')), findsNothing);
      for (final link in ['SERVICIOS', 'CATÁLOGO', 'SOBRE MÍ']) {
        expect(_inBar(find.text(link)), findsNothing, reason: link);
      }
      expect(_inBar(find.byType(ThemeMenuButton)), findsNothing);
      expect(_inBar(find.byType(LanguageSwitch)), findsNothing);
      expect(_inBar(find.text('RESERVAR')), findsOneWidget);
      expect(_menuButton(), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('el menú lateral muestra los selectores y los tres enlaces '
        '(RF-15)', (tester) async {
      await pumpWebApp(tester, width: 360);
      await _openMenu(tester);

      final drawer = find.byType(Drawer);
      expect(
        find.descendant(of: drawer, matching: find.byType(ThemeMenuButton)),
        findsOneWidget,
      );
      expect(
        find.descendant(of: drawer, matching: find.byType(LanguageSwitch)),
        findsOneWidget,
      );
      for (final link in ['SERVICIOS', 'CATÁLOGO', 'SOBRE MÍ']) {
        expect(
          find.descendant(of: drawer, matching: find.text(link)),
          findsOneWidget,
          reason: link,
        );
      }
      expect(find.byTooltip('Cerrar menú'), findsOneWidget);
    });

    testWidgets('elegir una sección cierra el menú y lleva a ella (RF-16)', (
      tester,
    ) async {
      await pumpWebApp(tester, location: '/login', width: 360);
      await _openMenu(tester);

      await tester.tap(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('CATÁLOGO'),
        ),
      );
      await settleWeb(tester);

      expect(find.byType(Drawer), findsNothing);
      expect(webLocation(tester).path, '/');
      expect(webLocation(tester).queryParameters['section'], 'catalog');
    });

    testWidgets('cambiar el idioma desde el menú lo aplica y deja el menú '
        'abierto', (tester) async {
      await pumpWebApp(tester, width: 360);
      await _openMenu(tester);

      await tester.tap(
        find.descendant(of: find.byType(Drawer), matching: find.text('PT')),
      );
      await settleWeb(tester);

      expect(find.byType(Drawer), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(Drawer),
          matching: find.text('SOBRE MIM'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('el botón de cerrar cierra el menú', (tester) async {
      await pumpWebApp(tester, width: 360);
      await _openMenu(tester);

      await tester.tap(find.byTooltip('Cerrar menú'));
      await settleWeb(tester);

      expect(find.byType(Drawer), findsNothing);
    });

    testWidgets('al pasar a ancho amplio con el menú abierto, el menú se '
        'cierra y la barra se adapta', (tester) async {
      await pumpWebApp(tester, width: 360);
      await _openMenu(tester);
      expect(find.byType(Drawer), findsOneWidget);

      await _resize(tester, 1280);

      expect(find.byType(Drawer), findsNothing);
      expect(_inBar(find.text('SOBRE MÍ')), findsOneWidget);
      expect(_menuButton(), findsNothing);
    });
  });

  group('en todas las páginas', () {
    for (final location in ['/login', '/profile']) {
      testWidgets('el logotipo lleva a la landing desde $location (RF-14)', (
        tester,
      ) async {
        // Con sesión, /login ya lleva a la landing: ahí se prueba sin sesión.
        await pumpWebApp(
          tester,
          location: location,
          user: location == '/profile' ? testClient : null,
        );

        await tester.tap(_inBar(find.byType(BrandLogo)));
        await settleWeb(tester);

        expect(webLocation(tester).toString(), '/');
        expect(find.byType(LandingPage), findsOneWidget);
      });
    }

    testWidgets('"Reservar" lleva a la reserva: sin sesión, al inicio de '
        'sesión (RF-19)', (tester) async {
      await pumpWebApp(tester);

      await tester.tap(_inBar(find.text('RESERVAR')));
      await settleWeb(tester);

      expect(webLocation(tester).path, '/login');
      expect(webLocation(tester).queryParameters['next'], '/booking');
    });

    testWidgets('la barra queda fuera del scroll: siempre visible (RF-13)', (
      tester,
    ) async {
      await pumpWebApp(tester);

      expect(
        find.ancestor(of: _bar, matching: find.byType(Scrollable)),
        findsNothing,
      );
    });

    for (final width in [360.0, 1280.0]) {
      testWidgets('todo lo pulsable mide al menos 48 px y tiene etiqueta '
          '(${width.toInt()} px, RNF-2)', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpWebApp(tester, width: width);

        final tappables = [
          _inBar(find.byType(BrandLogo)),
          _inBar(find.text('RESERVAR')),
          if (width < 900) _menuButton(),
          if (width >= 900) _inBar(find.text('SOBRE MÍ')),
        ];
        for (final tappable in tappables) {
          final target = find.ancestor(
            of: tappable,
            matching: find.byWidgetPredicate(
              (widget) => widget is InkWell || widget is ButtonStyleButton,
            ),
          );
          final size = tester.getSize(
            target.evaluate().isEmpty ? tappable : target.first,
          );
          expect(size.height, greaterThanOrEqualTo(48));
          expect(size.width, greaterThanOrEqualTo(48));
        }
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        semantics.dispose();
      });
    }

    testWidgets('el logotipo se anuncia como enlace al inicio', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWebApp(tester);

      expect(
        find.bySemanticsLabel('Studio Shaddai, ir al inicio'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  });
}
