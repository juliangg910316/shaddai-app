import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show SemanticsNode;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/navigation/presentation/main_scaffold.dart';
import 'package:shaddai/features/navigation/providers/tab_scroll_provider.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

const _tabs = ['Inicio', 'Servicios', 'Turnos', 'Perfil'];

Finder _destination(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byType(NavigationDestination),
);

/// Semántica del destino [label] de la barra inferior.
SemanticsNode _semantics(WidgetTester tester, String label) =>
    tester.getSemantics(find.bySemanticsLabel(RegExp('^$label')).last);

ScrollController _controller(WidgetTester tester, MobileTab tab) =>
    appContainer(tester).read(tabScrollControllerProvider(tab));

void main() {
  for (final (session, user) in [
    ('sin sesión', null),
    ('con sesión', testClient),
  ]) {
    testWidgets('la barra muestra las cuatro pestañas en orden, $session '
        '(RF-1)', (tester) async {
      await pumpMobileApp(tester, user: user);

      expect(find.byType(NavigationBar), findsOneWidget);
      final lefts = [
        for (final tab in _tabs) tester.getTopLeft(_destination(tab)).dx,
      ];
      expect(lefts, orderedEquals([...lefts]..sort()));
      expect(lefts.toSet(), hasLength(4));
    });
  }

  testWidgets('en portugués', (tester) async {
    await pumpMobileApp(tester, stored: {'language': 'pt'});

    for (final tab in ['Início', 'Serviços', 'Horários', 'Perfil']) {
      expect(_destination(tab), findsOneWidget, reason: tab);
    }
  });

  testWidgets('la pestaña activa está marcada y se anuncia como '
      'seleccionada (RF-2)', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpMobileApp(tester);

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
    expect(_semantics(tester, 'Inicio'), isSemantics(isSelected: true));
    expect(_semantics(tester, 'Servicios'), isSemantics(isSelected: false));

    await tester.tap(_destination('Servicios'));
    await settleWeb(tester);

    expect(_semantics(tester, 'Servicios'), isSemantics(isSelected: true));
    expect(_semantics(tester, 'Inicio'), isSemantics(isSelected: false));
    semantics.dispose();
  });

  testWidgets('al volver a una pestaña, sigue en la misma posición de scroll '
      '(RF-3)', (tester) async {
    await pumpMobileApp(tester);
    final home = _controller(tester, MobileTab.home);
    home.jumpTo(300);
    await settleWeb(tester);

    await tester.tap(_destination('Servicios'));
    await settleWeb(tester);
    await tester.tap(_destination('Inicio'));
    await settleWeb(tester);

    expect(home.offset, 300);
  });

  testWidgets('tocar la pestaña activa vuelve a su comienzo (RF-4)', (
    tester,
  ) async {
    await pumpMobileApp(tester);
    final home = _controller(tester, MobileTab.home);
    home.jumpTo(300);
    await settleWeb(tester);

    await tester.tap(_destination('Inicio'));
    await settleWeb(tester);

    expect(home.offset, 0);
  });

  for (final theme in ['light', 'dark']) {
    testWidgets('cada pestaña mide al menos 48 × 48 px y tiene nombre, tema '
        '$theme (RNF-1)', (tester) async {
      final semantics = tester.ensureSemantics();
      // Se empieza en Perfil: la barra se mide con una pestaña que ya cumple.
      // Inicio y Servicios, que cambian en T5 y T6, se prueban en T9.
      await pumpMobileApp(
        tester,
        location: '/profile',
        stored: {'theme': theme, 'language': 'es'},
      );

      for (final tab in _tabs) {
        final size = tester.getSize(_destination(tab));
        expect(size.width, greaterThanOrEqualTo(48), reason: tab);
        expect(size.height, greaterThanOrEqualTo(48), reason: tab);
      }
      final bar = find.byType(NavigationBar);
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      // El contraste se mide en la barra: el resto de las pestañas es de otras
      // tareas.
      expect(bar, findsOneWidget);
      await expectLater(tester, meetsGuideline(textContrastGuideline));
      semantics.dispose();
    });
  }

  testWidgets('con el texto al 200 %, a 320 px, la barra muestra solo los '
      'iconos, con su nombre accesible, y no se desborda (RNF-4)', (
    tester,
  ) async {
    tester.platformDispatcher.textScaleFactorTestValue = 2;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    final semantics = tester.ensureSemantics();
    await pumpMobileApp(tester, location: '/profile', width: 320);

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).labelBehavior,
      NavigationDestinationLabelBehavior.alwaysHide,
    );
    for (final tab in _tabs) {
      expect(find.bySemanticsLabel(RegExp('^$tab')), findsWidgets, reason: tab);
    }
    expect(tester.takeException(), isNull);
    semantics.dispose();
  });

  testWidgets('con el texto normal, se ven las etiquetas', (tester) async {
    await pumpMobileApp(tester);

    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).labelBehavior,
      NavigationDestinationLabelBehavior.alwaysShow,
    );
  });

  testWidgets('la barra es la de Android/iOS: MainScaffold', (tester) async {
    await pumpMobileApp(tester);

    expect(find.byType(MainScaffold), findsOneWidget);
  });
}
