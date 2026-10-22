import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/landing/landing_content.dart';
import 'package:shaddai/features/landing/presentation/sections/about_section.dart';
import 'package:shaddai/features/landing/presentation/sections/contact_section.dart';
import 'package:shaddai/features/landing/presentation/sections/gallery_section.dart';
import 'package:shaddai/features/landing/presentation/sections/hero_section.dart';
import 'package:shaddai/features/navigation/providers/tab_scroll_provider.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';
import '../../helpers/recording_link_launcher.dart';

/// Desplaza Inicio hasta [finder] y lo pulsa.
Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settleWeb(tester);
  await tester.tap(finder);
  await settleWeb(tester);
}

Finder _in(Type section, Finder finder) =>
    find.descendant(of: find.byType(section), matching: finder);

void main() {
  late RecordingLinkLauncher links;

  setUp(() => links = RecordingLinkLauncher());

  for (final language in ['es', 'pt']) {
    testWidgets('Inicio muestra presentación, galería, sobre mí y contacto, '
        'en orden, en $language (RF-5)', (tester) async {
      await pumpMobileApp(tester, stored: {'language': language});

      final tops = [
        for (final section in [
          HeroSection,
          GallerySection,
          AboutSection,
          ContactSection,
        ])
          tester.getTopLeft(find.byType(section)).dy,
      ];
      expect(tops, orderedEquals([...tops]..sort()));
      expect(tops.toSet(), hasLength(4));
      expect(
        find.text(language == 'es' ? 'Más que uñas,' : 'Mais que unhas,'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('no queda contenido de ejemplo de la plantilla (RF-20)', (
    tester,
  ) async {
    await pumpMobileApp(tester);

    for (final sample in [
      '\$25',
      'Servicios populares',
      'Nuestros trabajos',
      'VER TODO',
      'Shaddai\nNail Salon',
    ]) {
      expect(find.textContaining(sample), findsNothing, reason: sample);
    }
  });

  for (final where in [HeroSection, ContactSection]) {
    testWidgets(
      '"Reservar cita" de ${where == HeroSection ? 'la presentación' : 'contacto'} '
      'abre la pestaña Reservas (RF-6)',
      (tester) async {
        await pumpMobileApp(tester);

        await _tapVisible(tester, _in(where, find.text('RESERVAR CITA')));

        expect(webLocation(tester).path, '/booking');
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          2,
        );
      },
    );
  }

  testWidgets('"Ver lista de precios" abre Servicios desde su comienzo '
      '(RF-7)', (tester) async {
    await pumpMobileApp(tester, location: '/services');
    final services = appContainer(
      tester,
    ).read(tabScrollControllerProvider(MobileTab.services));
    if (services.hasClients) services.jumpTo(200);
    await tester.tap(find.text('Inicio'));
    await settleWeb(tester);

    await _tapVisible(tester, find.text('VER LISTA DE PRECIOS'));

    expect(webLocation(tester).path, '/services');
    if (services.hasClients) expect(services.offset, 0);
  });

  group('enlaces externos (RF-8, RF-9, RF-11)', () {
    // Los buscadores son funciones: los de semántica se crean dentro del
    // test, con la semántica ya activada.
    for (final (description, finder, url)
        in <(String, Finder Function(), String)>[
          (
            'una foto de la galería',
            () => find.bySemanticsLabel('Diseño 3 — ver más en Instagram'),
            LandingContent.instagramUrl,
          ),
          (
            '"Ver más en Instagram"',
            () => find.text('Ver más en Instagram →'),
            LandingContent.instagramUrl,
          ),
          (
            'la dirección de la presentación',
            () => _in(HeroSection, find.text(LandingContent.addressFull)),
            LandingContent.mapsUrl,
          ),
          (
            'la dirección del contacto',
            () => _in(ContactSection, find.text(LandingContent.addressDisplay)),
            LandingContent.mapsUrl,
          ),
          (
            '"Agenda por WhatsApp"',
            () => find.text('AGENDA POR WHATSAPP ♡'),
            LandingContent.whatsappUrl,
          ),
          (
            'el teléfono',
            () => find.text(LandingContent.phoneDisplay),
            LandingContent.phoneUri,
          ),
          (
            'el correo',
            () => find.text(LandingContent.emailDisplay),
            LandingContent.emailUri,
          ),
          (
            'Instagram del contacto',
            () => find.text(LandingContent.instagramHandle),
            LandingContent.instagramUrl,
          ),
          (
            'TikTok',
            () => find.widgetWithText(TextButton, 'TIKTOK'),
            LandingContent.tiktokUrl,
          ),
          (
            'YouTube',
            () => find.widgetWithText(TextButton, 'YOUTUBE'),
            LandingContent.youtubeUrl,
          ),
        ]) {
      testWidgets('$description abre su enlace', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpMobileApp(tester, overrides: [links.override]);

        await _tapVisible(tester, finder());

        expect(links.opened, [Uri.parse(url)]);
        semantics.dispose();
      });
    }
  });

  testWidgets('el contacto muestra el mapa del salón (RF-10)', (tester) async {
    await pumpMobileApp(tester);

    expect(
      _in(ContactSection, find.byKey(const Key('salon-map'))),
      findsOneWidget,
    );
  });

  testWidgets('la galería va en dos columnas', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpMobileApp(tester);

    final first = tester.getTopLeft(
      find.bySemanticsLabel('Diseño 1 — ver más en Instagram'),
    );
    final second = tester.getTopLeft(
      find.bySemanticsLabel('Diseño 2 — ver más en Instagram'),
    );
    final third = tester.getTopLeft(
      find.bySemanticsLabel('Diseño 3 — ver más en Instagram'),
    );
    expect(second.dy, first.dy);
    expect(third.dy, greaterThan(first.dy));
    semantics.dispose();
  });
}
