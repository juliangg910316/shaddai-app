import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/external_links.dart';
import 'package:shaddai/core/widgets/brand_logo.dart';
import 'package:shaddai/features/landing/landing_content.dart';
import 'package:shaddai/features/landing/landing_section.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';
import 'package:url_launcher/url_launcher.dart' show LaunchMode;

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

final _floatButton = find.byTooltip('Reservar por WhatsApp');

/// Desplaza la landing hasta [finder] y lo pulsa.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settleWeb(tester);
  await tester.tap(finder);
  await settleWeb(tester);
}

void main() {
  late RecordingLinkLauncher links;

  setUp(() => links = RecordingLinkLauncher());

  group('galería (RF-8, RNF-3)', () {
    testWidgets('nueve fotos, cada una con su descripción', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWebApp(tester);

      for (var n = 1; n <= 9; n++) {
        expect(
          find.bySemanticsLabel('Diseño $n — ver más en Instagram'),
          findsOneWidget,
          reason: 'foto $n',
        );
      }
      semantics.dispose();
    });

    testWidgets('las descripciones van en portugués', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWebApp(tester, stored: {'language': 'pt'});

      expect(
        find.bySemanticsLabel('Design 1 — veja mais no Instagram'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('cada foto abre Instagram', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpWebApp(tester, overrides: [links.override]);

      for (final n in [1, 5, 9]) {
        await _tapVisible(
          tester,
          find.bySemanticsLabel('Diseño $n — ver más en Instagram'),
        );
      }

      expect(
        links.opened,
        List.filled(3, Uri.parse(LandingContent.instagramUrl)),
      );
      semantics.dispose();
    });

    testWidgets('"Ver más en Instagram" abre Instagram', (tester) async {
      await pumpWebApp(tester, overrides: [links.override]);

      await _tapVisible(
        tester,
        _in(LandingSection.gallery, find.text('Ver más en Instagram →')),
      );

      expect(links.opened, [Uri.parse(LandingContent.instagramUrl)]);
    });
  });

  group('sobre mí', () {
    for (final (language, texts) in [
      ('es', ['Soy Beidis', '“La belleza también es cuidarte a ti.”']),
      ('pt', ['Sou Beidis', '“A beleza também é cuidar de você.”']),
    ]) {
      testWidgets('textos en $language (RF-2)', (tester) async {
        await pumpWebApp(tester, stored: {'language': language});

        for (final text in texts) {
          expect(
            _in(LandingSection.about, find.text(text)),
            findsOneWidget,
            reason: text,
          );
        }
        expect(
          _in(LandingSection.about, find.text('BEIDIS · NAIL DESIGNER')),
          findsOneWidget,
        );
      });
    }
  });

  group('contacto', () {
    for (final (text, url) in [
      (LandingContent.phoneDisplay, LandingContent.phoneUri),
      (LandingContent.emailDisplay, LandingContent.emailUri),
      (LandingContent.addressDisplay, LandingContent.mapsUrl),
      (LandingContent.instagramHandle, LandingContent.instagramUrl),
      ('AGENDA POR WHATSAPP ♡', LandingContent.whatsappUrl),
    ]) {
      testWidgets('"$text" abre su enlace (RF-9, RF-10, RF-12)', (
        tester,
      ) async {
        await pumpWebApp(tester, overrides: [links.override]);

        await _tapVisible(tester, _in(LandingSection.contact, find.text(text)));

        expect(links.opened, [Uri.parse(url)]);
      });
    }

    group('"Reservar cita" (RF-32)', () {
      for (final (language, reserve, whatsapp) in [
        ('es', 'RESERVAR CITA', 'AGENDA POR WHATSAPP ♡'),
        ('pt', 'AGENDAR HORÁRIO', 'AGENDE PELO WHATSAPP ♡'),
      ]) {
        testWidgets('es la acción principal y WhatsApp la secundaria, en '
            '$language', (tester) async {
          await pumpWebApp(tester, stored: {'language': language});

          expect(
            _in(
              LandingSection.contact,
              find.widgetWithText(ElevatedButton, reserve),
            ),
            findsOneWidget,
          );
          expect(
            _in(
              LandingSection.contact,
              find.widgetWithText(OutlinedButton, whatsapp),
            ),
            findsOneWidget,
          );
        });
      }

      testWidgets('sin sesión lleva al inicio de sesión y después a la '
          'reserva (RF-19)', (tester) async {
        await pumpWebApp(tester, overrides: [links.override]);

        await _tapVisible(
          tester,
          _in(LandingSection.contact, find.text('RESERVAR CITA')),
        );

        expect(webLocation(tester).path, '/login');
        expect(webLocation(tester).queryParameters['next'], '/booking');
        expect(links.opened, isEmpty, reason: 'no abre WhatsApp');
      });
    });

    testWidgets('textos en portugués; los datos de contacto no cambian', (
      tester,
    ) async {
      await pumpWebApp(tester, stored: {'language': 'pt'});

      for (final text in [
        'Marque seu horário',
        'AGENDE PELO WHATSAPP ♡',
        'TELEFONE',
        LandingContent.phoneDisplay,
        LandingContent.emailDisplay,
      ]) {
        expect(
          _in(LandingSection.contact, find.text(text)),
          findsOneWidget,
          reason: text,
        );
      }
    });
  });

  group('pie', () {
    for (final (name, url) in LandingContent.socialLinks) {
      testWidgets('${name.toUpperCase()} abre su red (RF-10)', (tester) async {
        await pumpWebApp(tester, overrides: [links.override]);

        await _tapVisible(
          tester,
          _in(LandingSection.footer, find.text(name.toUpperCase())),
        );

        expect(links.opened, [Uri.parse(url)]);
      });
    }

    testWidgets('logotipo, nombre, lema y copyright', (tester) async {
      await pumpWebApp(tester);

      expect(
        _in(LandingSection.footer, find.byType(BrandLogo)),
        findsOneWidget,
      );
      expect(
        _in(LandingSection.footer, find.text('STUDIO SHADDAI')),
        findsOneWidget,
      );
      expect(
        _in(LandingSection.footer, find.text(LandingContent.copyright)),
        findsOneWidget,
      );
    });
  });

  group('WhatsApp flotante', () {
    testWidgets('se ve arriba y al final de la landing (RF-11)', (
      tester,
    ) async {
      await pumpWebApp(tester);
      expect(_floatButton.hitTestable(), findsOneWidget);

      final scroll = _landingScroll(tester);
      scroll.jumpTo(scroll.maxScrollExtent);
      await settleWeb(tester);

      expect(_floatButton.hitTestable(), findsOneWidget);
      expect(
        tester.getRect(_floatButton).bottom,
        lessThanOrEqualTo(900),
        reason: 'dentro de la ventana',
      );
    });

    testWidgets('abre WhatsApp (RF-12)', (tester) async {
      await pumpWebApp(tester, overrides: [links.override]);

      await tester.tap(_floatButton);
      await settleWeb(tester);

      expect(links.opened, [Uri.parse(LandingContent.whatsappUrl)]);
    });

    testWidgets('en portugués, su etiqueta cambia', (tester) async {
      await pumpWebApp(tester, stored: {'language': 'pt'});

      expect(find.byTooltip('Agendar pelo WhatsApp'), findsOneWidget);
    });

    testWidgets('no aparece en las páginas de cuenta', (tester) async {
      await pumpWebApp(tester, location: '/login');

      expect(_floatButton, findsNothing);
    });
  });

  testWidgets('si el navegador no abre el enlace, no hay error y la página '
      'sigue igual (D-12)', (tester) async {
    await pumpWebApp(
      tester,
      overrides: [
        externalLinkLauncherProvider.overrideWithValue(
          externalLinkLauncher(
            launch:
                (url, {mode = LaunchMode.platformDefault, webOnlyWindowName}) =>
                    throw Exception('pestaña bloqueada'),
          ),
        ),
      ],
    );

    await tester.tap(_floatButton);
    await settleWeb(tester);

    expect(tester.takeException(), isNull);
    expect(webLocation(tester).toString(), '/');
    expect(find.byType(LandingPage), findsOneWidget);
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('las secciones caben a ${width.toInt()} px', (tester) async {
      await pumpWebApp(tester, width: width);

      expect(tester.takeException(), isNull);
    });
  }
}
