import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/app_theme.dart';
import 'package:shaddai/features/landing/landing_content.dart';
import 'package:shaddai/features/landing/landing_section.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';
import 'package:shaddai/features/landing/presentation/widgets/landing_image.dart';
import 'package:shaddai/l10n/app_localizations.dart';

import '../../helpers/pump_web_app.dart';
import '../../helpers/recording_link_launcher.dart';

Finder _section(LandingSection section) => find.byWidgetPredicate(
  (widget) => widget is LandingSectionFrame && widget.section == section,
);

Finder _in(LandingSection section, Finder finder) =>
    find.descendant(of: _section(section), matching: finder);

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

/// Descripciones de las nueve páginas del catálogo, en orden.
const _catalogEs = [
  'Studio Shaddai — Catálogo de servicios',
  'Alargamientos',
  'Soft Gel',
  'Mantenimiento de uñas',
  'Decoraciones para uñas',
  'Combos y paquetes especiales',
  'Uñas naturales',
  'Pies y cuidados especiales',
  'Agendamiento de citas',
];

/// Lleva la landing hasta el catálogo y abre la página [description].
Future<void> _openCatalogPage(WidgetTester tester, String description) async {
  final page = find.bySemanticsLabel(description);
  await tester.ensureVisible(page);
  await settleWeb(tester);
  await tester.tap(page);
  await settleWeb(tester);
}

void main() {
  group('combos (RF-3)', () {
    testWidgets('los tres combos con su precio en R\$, en español', (
      tester,
    ) async {
      await pumpWebApp(tester);

      expect(
        _in(LandingSection.combos, find.text('Combos Shaddai')),
        findsOneWidget,
      );
      for (final (price, name) in [
        ('R\$ 60', 'Manos y Pies Tradicional'),
        ('R\$ 120', 'Gel Completo'),
        ('R\$ 165', 'Momento Shaddai'),
      ]) {
        expect(_in(LandingSection.combos, find.text(price)), findsOneWidget);
        expect(_in(LandingSection.combos, find.text(name)), findsOneWidget);
      }
      expect(
        _in(
          LandingSection.combos,
          find.text('Los combos no son acumulables con otras promociones.'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('en portugués cambian los nombres y no los precios', (
      tester,
    ) async {
      await pumpWebApp(tester, stored: {'language': 'pt'});

      expect(
        _in(LandingSection.combos, find.text('Mãos e Pés Tradicional')),
        findsOneWidget,
      );
      for (final price in ['R\$ 60', 'R\$ 120', 'R\$ 165']) {
        expect(_in(LandingSection.combos, find.text(price)), findsOneWidget);
      }
    });
  });

  group('catálogo', () {
    testWidgets('las nueve páginas, cada una con su descripción en español '
        '(RNF-3)', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWebApp(tester);

      // Dentro del catálogo: "Alargamientos" y "Soft Gel" también son títulos
      // de la lista de precios.
      for (final description in _catalogEs) {
        expect(
          _in(LandingSection.catalog, find.bySemanticsLabel(description)),
          findsOneWidget,
          reason: description,
        );
      }
      semantics.dispose();
    });

    testWidgets('las descripciones van en portugués (RNF-3)', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWebApp(tester, stored: {'language': 'pt'});

      for (final description in [
        'Studio Shaddai — Catálogo de serviços',
        'Pés e cuidados especiais',
      ]) {
        expect(
          find.bySemanticsLabel(description),
          findsOneWidget,
          reason: description,
        );
      }
      semantics.dispose();
    });

    for (final (how, close) in <(String, Future<void> Function(WidgetTester))>[
      (
        'con el botón de cerrar',
        (tester) => tester.tap(find.byTooltip('Cerrar')),
      ),
      ('con un clic fuera', (tester) => tester.tapAt(const Offset(8, 450))),
      ('con Esc', (tester) => tester.sendKeyEvent(LogicalKeyboardKey.escape)),
    ]) {
      testWidgets('una página se amplía y se cierra $how, sin mover la '
          'landing (RF-6, RF-7)', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpWebApp(tester);
        await _openCatalogPage(tester, 'Pies y cuidados especiales');
        final scrolled = _landingScroll(tester).pixels;

        // Ampliada: un diálogo con la misma imagen.
        expect(find.byType(Dialog), findsOneWidget);
        expect(
          find.descendant(
            of: find.byType(Dialog),
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is Image &&
                  (widget.image as AssetImage).assetName ==
                      LandingContent.catalogImages[7],
            ),
          ),
          findsOneWidget,
        );

        await close(tester);
        await settleWeb(tester);

        expect(find.byType(Dialog), findsNothing);
        expect(_landingScroll(tester).pixels, scrolled);
        semantics.dispose();
      });
    }

    testWidgets('"Más páginas del catálogo en Instagram" abre Instagram '
        '(RF-8)', (tester) async {
      final links = RecordingLinkLauncher();
      await pumpWebApp(tester, overrides: [links.override]);

      final more = _in(
        LandingSection.catalog,
        find.text('Más páginas del catálogo en Instagram'),
      );
      await tester.ensureVisible(more);
      await settleWeb(tester);
      await tester.tap(more);
      await settleWeb(tester);

      expect(links.opened, [Uri.parse(LandingContent.instagramUrl)]);
    });
  });

  testWidgets('una imagen que no carga muestra un recuadro con su '
      'descripción (caso límite)', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: const Scaffold(
          body: SizedBox(
            width: 200,
            height: 260,
            child: LandingImage(
              asset: 'assets/images/landing/no_existe.jpeg',
              description: 'Pies y cuidados especiales',
            ),
          ),
        ),
      ),
    );
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await tester.pump();

    expect(find.text('Pies y cuidados especiales'), findsOneWidget);
    expect(find.bySemanticsLabel('Pies y cuidados especiales'), findsOneWidget);
    semantics.dispose();
  });

  group('cómo funciona la atención', () {
    for (final (language, titles) in [
      (
        'es',
        ['Reposición', 'Plazo de mantenimiento', 'Retrasos', 'Cancelaciones'],
      ),
      ('pt', ['Reposição', 'Prazo de manutenção', 'Atrasos', 'Cancelamentos']),
    ]) {
      testWidgets('las cuatro normas en $language (RF-2)', (tester) async {
        await pumpWebApp(tester, stored: {'language': language});

        for (final title in titles) {
          expect(
            _in(LandingSection.info, find.text(title)),
            findsOneWidget,
            reason: title,
          );
        }
      });
    }

    testWidgets('título e introducción en español', (tester) async {
      await pumpWebApp(tester);

      expect(
        _in(LandingSection.info, find.text('Cómo funciona la atención')),
        findsOneWidget,
      );
      expect(
        _in(LandingSection.info, find.text('Tu tiempo también importa ♡')),
        findsOneWidget,
      );
    });
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('las tres secciones caben a ${width.toInt()} px', (
      tester,
    ) async {
      await pumpWebApp(tester, width: width);

      expect(tester.takeException(), isNull);
    });
  }
}
