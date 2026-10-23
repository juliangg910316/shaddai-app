import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/landing/landing_content.dart';
import 'package:shaddai/features/landing/presentation/sections/catalog_section.dart';
import 'package:shaddai/features/landing/presentation/sections/combos_section.dart';
import 'package:shaddai/features/landing/presentation/sections/info_section.dart';
import 'package:shaddai/features/landing/presentation/sections/prices_section.dart';
import 'package:shaddai/features/navigation/providers/tab_scroll_provider.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';
import '../../helpers/recording_link_launcher.dart';

final _amount = RegExp(r'^\+?R\$ \d+$');

/// Importes que se ven en la lista de precios, en orden.
List<String> _shownPrices(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(PricesSection),
        matching: find.byType(Text),
      ),
    )
    .map((text) => text.data ?? '')
    .where(_amount.hasMatch)
    .toList();

/// Los importes de la lista inicial, en orden: los mismos que la landing de
/// Web, porque las dos leen la misma lista (RF-21; spec 004).
const _landingPrices = [
  'R\$ 30', 'R\$ 55', 'R\$ 60', 'R\$ 100', 'R\$ 120', // Manos
  'R\$ 40', 'R\$ 60', 'R\$ 110', 'R\$ 130', 'R\$ 70', // Pies
  'R\$ 150', 'R\$ 165', 'R\$ 185', 'R\$ 220', // Alargamientos: nueva
  'R\$ 120', 'R\$ 130', 'R\$ 145', 'R\$ 165', // y mantenimiento
  'R\$ 130', 'R\$ 145', 'R\$ 110', // Soft Gel
  'R\$ 20', 'R\$ 30', 'R\$ 30', 'R\$ 40', // Retiradas
  '+R\$ 10', '+R\$ 15', '+R\$ 15', '+R\$ 20', '+R\$ 5', // Decoración
  '+R\$ 10', '+R\$ 15', '+R\$ 6', '+R\$ 20',
];

ScrollController _services(WidgetTester tester) =>
    appContainer(tester).read(tabScrollControllerProvider(MobileTab.services));

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settleWeb(tester);
  await tester.tap(finder);
  await settleWeb(tester);
}

/// Abre la página "Pies y cuidados especiales" del catálogo.
Future<void> _openCatalogPage(WidgetTester tester) async {
  final page = find.descendant(
    of: find.byType(CatalogSection),
    matching: find.bySemanticsLabel('Pies y cuidados especiales'),
  );
  await _tapVisible(tester, page);
  expect(find.byType(Dialog), findsOneWidget);
}

void main() {
  testWidgets('Servicios muestra "Reservar cita", precios, combos, catálogo y '
      'atención, en orden (RF-12, RF-15)', (tester) async {
    await pumpMobileApp(tester, location: '/services');

    final tops = [
      tester.getTopLeft(find.text('RESERVAR CITA')).dy,
      for (final section in [
        PricesSection,
        CombosSection,
        CatalogSection,
        InfoSection,
      ])
        tester.getTopLeft(find.byType(section)).dy,
    ];
    expect(tops, orderedEquals([...tops]..sort()));
    expect(tops.toSet(), hasLength(5));
    expect(tester.takeException(), isNull);
  });

  for (final language in ['es', 'pt']) {
    testWidgets('los 34 importes en R\$ son los de la landing, en $language '
        '(RF-12, RF-21)', (tester) async {
      await pumpMobileApp(
        tester,
        location: '/services',
        stored: {'language': language},
      );

      expect(_landingPrices, hasLength(34));
      expect(_shownPrices(tester), _landingPrices);
    });
  }

  testWidgets('no queda la carta de ejemplo de la plantilla (RF-20)', (
    tester,
  ) async {
    await pumpMobileApp(tester, location: '/services');

    for (final sample in ['\$', 'CARTA SHADDAI', 'Manicure Clásica']) {
      expect(
        find.byWidgetPredicate(
          (widget) =>
              widget is Text &&
              (widget.data ?? '').contains(sample) &&
              !(widget.data ?? '').contains('R\$'),
        ),
        findsNothing,
        reason: sample,
      );
    }
  });

  group('catálogo (RF-13)', () {
    for (final (how, close) in <(String, Future<void> Function(WidgetTester))>[
      ('con su botón', (tester) => tester.tap(find.byTooltip('Cerrar'))),
      ('tocando fuera', (tester) => tester.tapAt(const Offset(4, 300))),
      (
        'con el "atrás" del sistema',
        (tester) => tester.binding.handlePopRoute(),
      ),
    ]) {
      testWidgets('una página ampliada se cierra $how y Servicios sigue en '
          'la misma posición', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpMobileApp(tester, location: '/services');
        await _openCatalogPage(tester);
        final offset = _services(tester).offset;

        await close(tester);
        await settleWeb(tester);

        expect(find.byType(Dialog), findsNothing);
        expect(webLocation(tester).path, '/services');
        expect(_services(tester).offset, offset);
        semantics.dispose();
      });
    }
  });

  testWidgets('la tarjeta de más páginas del catálogo abre Instagram '
      '(RF-14)', (tester) async {
    final links = RecordingLinkLauncher();
    await pumpMobileApp(
      tester,
      location: '/services',
      overrides: [links.override],
    );

    await _tapVisible(
      tester,
      find.text('Más páginas del catálogo en Instagram'),
    );

    expect(links.opened, [Uri.parse(LandingContent.instagramUrl)]);
  });

  testWidgets('"Reservar cita" abre la pestaña Reservas (RF-15)', (
    tester,
  ) async {
    await pumpMobileApp(tester, location: '/services');

    await _tapVisible(tester, find.text('RESERVAR CITA'));

    expect(webLocation(tester).path, '/booking');
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      2,
    );
  });

  testWidgets('en portugués, "Reservar cita" es "Agendar horário"', (
    tester,
  ) async {
    await pumpMobileApp(
      tester,
      location: '/services',
      stored: {'language': 'pt'},
    );

    expect(find.text('AGENDAR HORÁRIO'), findsOneWidget);
  });
}
