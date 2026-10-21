import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/landing/landing_content.dart';
import 'package:shaddai/features/landing/landing_section.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';
import 'package:shaddai/features/navigation/presentation/web_top_bar.dart';

import '../../helpers/pump_web_app.dart';
import '../../helpers/recording_link_launcher.dart';

Finder _section(LandingSection section) => find.byWidgetPredicate(
  (widget) => widget is LandingSectionFrame && widget.section == section,
);

Finder _in(LandingSection section, Finder finder) =>
    find.descendant(of: _section(section), matching: finder);

/// Importes de la lista de precios de shaddai-web, en orden (RF-3).
const _expectedPrices = [
  // 01 Manos
  'R\$ 30', 'R\$ 55', 'R\$ 60', 'R\$ 100', 'R\$ 120',
  // 02 Pies
  'R\$ 40', 'R\$ 60', 'R\$ 110', 'R\$ 130', 'R\$ 70',
  // 03 Alargamientos: nueva aplicación y mantenimiento
  'R\$ 150', 'R\$ 165', 'R\$ 185', 'R\$ 220',
  'R\$ 120', 'R\$ 130', 'R\$ 145', 'R\$ 165',
  // 04 Soft Gel
  'R\$ 130', 'R\$ 145', 'R\$ 110',
  // 05 Retiradas
  'R\$ 20', 'R\$ 30', 'R\$ 30', 'R\$ 40',
  // 06 Decoración y adicionales
  '+R\$ 10', '+R\$ 15', '+R\$ 15', '+R\$ 20', '+R\$ 5',
  '+R\$ 10', '+R\$ 15', '+R\$ 6', '+R\$ 20',
];

final _amount = RegExp(r'^\+?R\$ \d+$');

/// Importes que se ven en la lista de precios, de arriba abajo y de izquierda
/// a derecha.
List<String> _shownPrices(WidgetTester tester) {
  final texts = tester
      .widgetList<Text>(_in(LandingSection.prices, find.byType(Text)))
      // Solo los importes, no las notas que mencionan un precio.
      .where((text) => _amount.hasMatch(text.data ?? ''))
      .map((text) => text.data!)
      .toList();
  return texts;
}

void main() {
  group('hero', () {
    testWidgets('textos, cifras y foto en español (RF-2)', (tester) async {
      await pumpWebApp(tester);

      for (final text in [
        'NAIL DESIGNER · CAPÃO DA IMBUIA, CURITIBA',
        'Un tiempo para ti.',
        'Más que uñas,',
        'momentos de bienestar.',
        'RESERVAR CITA',
        'VER LISTA DE PRECIOS',
        '30+',
        '1.1K',
        '24h',
        'SERVICIOS',
        'SEGUIDORAS',
        LandingContent.addressFull,
      ]) {
        expect(
          _in(LandingSection.hero, find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
      expect(
        _in(LandingSection.hero, find.textContaining('1ª visita')),
        findsOneWidget,
      );
      expect(
        _in(
          LandingSection.hero,
          find.byWidgetPredicate(
            (widget) =>
                widget is Image &&
                widget.image is AssetImage &&
                (widget.image as AssetImage).assetName ==
                    LandingContent.heroPhoto,
          ),
        ),
        findsOneWidget,
      );
    });

    testWidgets('textos en portugués; las cifras no cambian (RF-2, RNF-6)', (
      tester,
    ) async {
      await pumpWebApp(tester, stored: {'language': 'pt'});

      for (final text in [
        'Mais que unhas,',
        'AGENDAR HORÁRIO',
        'VER TABELA DE PREÇOS',
        '30+',
        '1.1K',
        '24h',
      ]) {
        expect(
          _in(LandingSection.hero, find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
    });

    testWidgets('la dirección abre la ubicación en Google Maps (RF-9)', (
      tester,
    ) async {
      final links = RecordingLinkLauncher();
      await pumpWebApp(tester, overrides: [links.override]);

      final address = _in(
        LandingSection.hero,
        find.text(LandingContent.addressFull),
      );
      await tester.ensureVisible(address);
      await settleWeb(tester);
      await tester.tap(address);
      await settleWeb(tester);

      expect(links.opened, [Uri.parse(LandingContent.mapsUrl)]);
    });

    testWidgets('"Ver lista de precios" lleva a la lista de precios, justo '
        'debajo de la barra (RF-5)', (tester) async {
      await pumpWebApp(tester);

      await tester.tap(
        _in(LandingSection.hero, find.text('VER LISTA DE PRECIOS')),
      );
      await settleWeb(tester);

      expect(
        tester.getTopLeft(_section(LandingSection.prices)).dy,
        moreOrLessEquals(
          tester.getBottomLeft(find.byType(WebTopBar)).dy,
          epsilon: 1,
        ),
      );
    });

    testWidgets('"Reservar cita" lleva a la reserva (RF-19)', (tester) async {
      await pumpWebApp(tester);

      await tester.tap(_in(LandingSection.hero, find.text('RESERVAR CITA')));
      await settleWeb(tester);

      expect(webLocation(tester).path, '/login');
      expect(webLocation(tester).queryParameters['next'], '/booking');
    });
  });

  group('franja de servicios', () {
    double offset(WidgetTester tester) => tester
        .state<ScrollableState>(
          _in(LandingSection.marquee, find.byType(Scrollable)),
        )
        .position
        .pixels;

    testWidgets('se desplaza sola', (tester) async {
      await pumpWebApp(tester, reduceMotion: false);
      final start = offset(tester);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(offset(tester), greaterThan(start));
    });

    testWidgets('se detiene si el sistema pide reducir las animaciones', (
      tester,
    ) async {
      await pumpWebApp(tester, reduceMotion: true);
      final start = offset(tester);

      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));

      expect(offset(tester), start);
    });

    testWidgets('es decorativa: el lector de pantalla no la lee', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpWebApp(tester);

      expect(find.bySemanticsLabel(RegExp('ESMALTADO EN GEL')), findsNothing);
      semantics.dispose();
    });
  });

  group('lista de precios (RF-3)', () {
    for (final width in [360.0, 1280.0]) {
      testWidgets('los seis bloques, con sus títulos (${width.toInt()} px)', (
        tester,
      ) async {
        await pumpWebApp(tester, width: width);

        for (final title in [
          'Manos',
          'Pies',
          'Alargamientos',
          'Retiradas',
          'Decoración y adicionales',
        ]) {
          expect(
            _in(LandingSection.prices, find.text(title)),
            findsOneWidget,
            reason: title,
          );
        }
        // "Soft Gel" es el título del bloque 04 y una línea de "Retiradas".
        expect(
          _in(LandingSection.prices, find.text('Soft Gel')),
          findsNWidgets(2),
        );
        for (final number in ['01', '02', '03', '04', '05', '06']) {
          expect(_in(LandingSection.prices, find.text(number)), findsOneWidget);
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('los importes en R\$ son los de referencia y no cambian con '
        'el idioma', (tester) async {
      await pumpWebApp(tester);
      final es = _shownPrices(tester);

      await pumpWebApp(tester, stored: {'language': 'pt'});
      final pt = _shownPrices(tester);

      expect(es, _expectedPrices);
      expect(pt, _expectedPrices);
    });

    testWidgets('en portugués, los títulos de los bloques cambian', (
      tester,
    ) async {
      await pumpWebApp(tester, stored: {'language': 'pt'});

      for (final title in ['Mãos', 'Pés', 'Remoções']) {
        expect(
          _in(LandingSection.prices, find.text(title)),
          findsOneWidget,
          reason: title,
        );
      }
    });
  });
}
