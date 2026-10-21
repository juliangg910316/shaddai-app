import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/features/preferences/presentation/language_switch.dart';
import 'package:shaddai/features/navigation/presentation/web_top_bar.dart';
import 'package:shaddai/features/preferences/presentation/theme_menu_button.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// En Web, la app real con su barra superior (spec 002); en Android/iOS, la
/// barra inferior, que no tiene selectores.
Future<void> _pumpShell(
  WidgetTester tester, {
  bool isWeb = true,
  Map<String, Object> stored = const {'theme': 'system', 'language': 'es'},
  double width = 1280,
  double height = 900,
  String location = '/',
}) async {
  if (isWeb) {
    await pumpWebApp(
      tester,
      location: location,
      stored: stored,
      width: width,
      height: height,
    );
    return;
  }
  await pumpApp(
    tester,
    stored: stored,
    router: shellRouter(initialLocation: '/home'),
    overrides: [...sessionOverrides(), isWebProvider.overrideWithValue(false)],
  );
  await tester.pumpAndSettle();
}

Brightness _brightness(WidgetTester tester) =>
    Theme.of(tester.element(find.byType(ThemeMenuButton))).brightness;

String _language(WidgetTester tester) => Localizations.localeOf(
  tester.element(find.byType(LanguageSwitch)),
).languageCode;

/// Si el foco del teclado está en [finder] o dentro de él.
bool _hasFocus(WidgetTester tester, Finder finder) {
  final focused = FocusManager.instance.primaryFocus?.context;
  if (focused == null) return false;
  final targets = finder.evaluate().toSet();
  if (targets.contains(focused)) return true;
  var found = false;
  focused.visitAncestorElements((element) {
    found = targets.contains(element);
    return !found;
  });
  return found;
}

/// Pulsa [key] hasta que el foco llegue a [finder] (como mucho [max] veces).
Future<void> _moveFocusTo(
  WidgetTester tester,
  Finder finder,
  LogicalKeyboardKey key, {
  int max = 12,
}) async {
  for (var i = 0; i < max && !_hasFocus(tester, finder); i++) {
    await tester.sendKeyEvent(key);
    await tester.pump();
  }
  expect(_hasFocus(tester, finder), isTrue, reason: 'el foco no llegó');
}

Finder _menuItem(String text) =>
    find.ancestor(of: find.text(text), matching: find.byType(MenuItemButton));

Finder _pill(String code) =>
    find.ancestor(of: find.text(code), matching: find.byType(ChoiceChip));

void main() {
  group('barra superior de Web (spec 001 RF-27, spec 002 RF-13)', () {
    testWidgets('en Web muestra los dos selectores', (tester) async {
      await _pumpShell(tester);

      expect(find.byType(ThemeMenuButton), findsOneWidget);
      expect(find.byType(LanguageSwitch), findsOneWidget);
    });

    testWidgets('en Android/iOS no hay barra con selectores', (tester) async {
      await _pumpShell(tester, isWeb: false);

      expect(find.byType(ThemeMenuButton), findsNothing);
      expect(find.byType(LanguageSwitch), findsNothing);
    });
  });

  group('menú de tema', () {
    testWidgets('abre las tres opciones con la activa marcada (RF-18)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpShell(tester);

      await tester.tap(find.byType(ThemeMenuButton));
      await tester.pumpAndSettle();

      expect(_menuItem('Claro'), findsOneWidget);
      expect(_menuItem('Oscuro'), findsOneWidget);
      expect(_menuItem('Sistema'), findsOneWidget);
      // Marca ✓ solo en la activa: no depende solo del color (RNF-4).
      expect(
        find.descendant(
          of: _menuItem('Sistema'),
          matching: find.byIcon(Icons.check),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: _menuItem('Claro'),
          matching: find.byIcon(Icons.check),
        ),
        findsNothing,
      );
      expect(
        tester.getSemantics(find.text('Sistema')),
        isSemantics(isSelected: true),
      );
      semantics.dispose();
    });

    testWidgets('elegir una opción cambia el tema y cierra el menú', (
      tester,
    ) async {
      await _pumpShell(tester, stored: {'theme': 'light', 'language': 'es'});

      await tester.tap(find.byType(ThemeMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Oscuro'));
      await tester.pumpAndSettle();

      expect(_brightness(tester), Brightness.dark);
      expect(_menuItem('Claro'), findsNothing);
    });

    testWidgets('el botón tiene el tooltip en el idioma activo (RNF-4)', (
      tester,
    ) async {
      await _pumpShell(tester, stored: {'language': 'pt'});

      expect(find.byTooltip('Alterar tema'), findsOneWidget);
    });

    testWidgets('se maneja con teclado: Tab, Intro, flechas y Esc (RNF-4)', (
      tester,
    ) async {
      // La barra es la misma en todas las páginas. Se empieza en una con
      // contenido enfocable: el teclado en la landing se prueba en la spec
      // 002 (T13), cuando tenga sus secciones.
      await _pumpShell(
        tester,
        stored: {'theme': 'light', 'language': 'es'},
        location: '/login',
      );
      final button = find.byType(ThemeMenuButton);

      await _moveFocusTo(tester, button, LogicalKeyboardKey.tab);

      // Intro abre el menú y Esc lo cierra.
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(_menuItem('Claro'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_menuItem('Claro'), findsNothing);

      // Intro abre, las flechas llegan a "Oscuro" e Intro lo elige.
      await _moveFocusTo(tester, button, LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      await _moveFocusTo(
        tester,
        _menuItem('Oscuro'),
        LogicalKeyboardKey.arrowDown,
        max: 5,
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(_brightness(tester), Brightness.dark);
      expect(_menuItem('Claro'), findsNothing);
    });
  });

  group('selector de idioma', () {
    testWidgets('marca el idioma activo y lo anuncia (RF-19, RNF-4)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpShell(tester);

      expect(
        tester.getSemantics(_pill('ES')),
        isSemantics(isSelected: true, label: 'Cambiar idioma: Español'),
      );
      expect(
        tester.getSemantics(_pill('PT')),
        isSemantics(isSelected: false, label: 'Cambiar idioma: Português'),
      );
      semantics.dispose();
    });

    testWidgets('pulsar PT cambia el idioma', (tester) async {
      await _pumpShell(tester);

      await tester.tap(find.text('PT'));
      await tester.pumpAndSettle();

      expect(_language(tester), 'pt');
      expect(find.byTooltip('Alterar tema'), findsOneWidget);
    });

    testWidgets('se maneja con teclado: Tab y Espacio (RNF-4)', (tester) async {
      await _pumpShell(tester, location: '/login');

      await _moveFocusTo(tester, _pill('PT'), LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pumpAndSettle();

      expect(_language(tester), 'pt');
    });
  });

  testWidgets('los selectores cumplen las guías de tamaño táctil y de '
      'etiquetas (RNF-4)', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pumpShell(tester);

    final bar = find.byType(WebTopBar);
    for (final selector in [
      find.descendant(of: bar, matching: find.byType(IconButton)),
      _pill('ES'),
      _pill('PT'),
    ]) {
      final size = tester.getSize(selector);
      expect(size.width, greaterThanOrEqualTo(48));
      expect(size.height, greaterThanOrEqualTo(48));
    }
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    semantics.dispose();
  });

  testWidgets('con el texto al 200 % y en PT, la barra no se desborda '
      '(RNF-6)', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

    await _pumpShell(
      tester,
      stored: {'language': 'pt'},
      width: 360,
      height: 800,
    );
    // En estrecho, los selectores van en el menú lateral (spec 002, RF-15).
    await tester.tap(find.byTooltip('Abrir menu'));
    await settleWeb(tester);

    expect(find.byType(LanguageSwitch), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
