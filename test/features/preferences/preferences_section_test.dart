import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shaddai/features/preferences/presentation/preferences_section.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

Future<GoRouter> _pumpProfile(
  WidgetTester tester, {
  bool loggedIn = false,
  Map<String, Object> stored = const {'language': 'es'},
}) async {
  final router = shellRouter();
  await pumpApp(
    tester,
    stored: stored,
    router: router,
    overrides: sessionOverrides(user: loggedIn ? testClient : null),
  );
  await tester.pumpAndSettle();
  return router;
}

String _path(GoRouter router) =>
    router.routerDelegate.currentConfiguration.uri.path;

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(PreferencesSection))).brightness;

void main() {
  group('sin sesión', () {
    testWidgets('la barra inferior muestra Perfil (RF-24)', (tester) async {
      await _pumpProfile(tester);

      final bar = find.byType(NavigationBar);
      expect(
        find.descendant(of: bar, matching: find.text('Perfil')),
        findsOneWidget,
      );
    });

    testWidgets('Perfil muestra Preferencias y el botón de iniciar sesión '
        '(RF-17, RF-25)', (tester) async {
      await _pumpProfile(tester);

      expect(find.byType(PreferencesSection), findsOneWidget);
      expect(find.text('Preferencias'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('"Iniciar sesión" abre la pantalla de inicio de sesión '
        '(RF-26)', (tester) async {
      final router = await _pumpProfile(tester);

      await tester.tap(find.text('Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(_path(router), '/login');
      expect(find.text('page:/login'), findsOneWidget);
    });

    testWidgets('elegir Oscuro cambia el tema sin salir de Perfil (RF-17)', (
      tester,
    ) async {
      final router = await _pumpProfile(tester);
      expect(_brightness(tester), Brightness.light);

      await tester.tap(find.text('Oscuro'));
      await tester.pump();

      expect(_brightness(tester), Brightness.dark);
      expect(_path(router), '/profile');
    });

    testWidgets('elegir Português cambia el idioma sin salir de Perfil '
        '(RF-17)', (tester) async {
      final router = await _pumpProfile(tester);

      await tester.tap(find.text('Português'));
      await tester.pump();

      expect(find.text('Preferências'), findsOneWidget);
      expect(find.text('Entrar'), findsOneWidget);
      expect(_path(router), '/profile');
    });

    testWidgets('la opción activa se marca y se anuncia como seleccionada '
        '(RF-18, RF-19, RNF-4)', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpProfile(tester, stored: {'theme': 'dark', 'language': 'es'});

      // Una marca ✓ por selector: no depende solo del color.
      expect(
        find.descendant(
          of: find.byType(PreferencesSection),
          matching: find.byIcon(Icons.check),
        ),
        findsNWidgets(2),
      );
      expect(
        tester.getSemantics(find.text('Oscuro')),
        isSemantics(isSelected: true),
      );
      expect(
        tester.getSemantics(find.text('Claro')),
        isSemantics(isSelected: false),
      );
      expect(
        tester.getSemantics(find.text('Español')),
        isSemantics(isSelected: true),
      );
      semantics.dispose();
    });

    testWidgets('sin idioma guardado marca el idioma efectivo (RF-19)', (
      tester,
    ) async {
      tester.platformDispatcher.localesTestValue = const [Locale('pt', 'BR')];
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      final semantics = tester.ensureSemantics();

      await _pumpProfile(tester, stored: const {});

      expect(
        tester.getSemantics(find.text('Português')),
        isSemantics(isSelected: true),
      );
      semantics.dispose();
    });

    testWidgets('cumple las guías de tamaño táctil y de etiquetas (RNF-4)', (
      tester,
    ) async {
      // Solo Perfil, sin la barra inferior: sus pestañas (46 px de alto) son
      // de la spec 003 y RNF-4 se refiere a los selectores.
      final semantics = tester.ensureSemantics();
      await pumpApp(
        tester,
        stored: {'language': 'es'},
        home: const ProfileView(),
        overrides: sessionOverrides(),
      );
      await tester.pumpAndSettle();

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      semantics.dispose();
    });
  });

  group('con sesión', () {
    testWidgets('Perfil mantiene lo de antes y añade Preferencias (RF-24)', (
      tester,
    ) async {
      await _pumpProfile(tester, loggedIn: true);

      expect(find.text('Ana Herrera'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsNothing);

      await tester.scrollUntilVisible(
        find.byType(PreferencesSection),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byType(PreferencesSection), findsOneWidget);
    });
  });
}
