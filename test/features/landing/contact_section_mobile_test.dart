import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/app_theme.dart';
import 'package:shaddai/features/home/presentation/google_map_container.dart';
import 'package:shaddai/features/landing/landing_content.dart';
import 'package:shaddai/features/landing/presentation/sections/contact_section.dart';
import 'package:shaddai/l10n/app_localizations.dart';

import '../../helpers/pump_web_app.dart';
import '../../helpers/recording_link_launcher.dart';

const _mapKey = Key('mapa');

Future<RecordingLinkLauncher> _pumpContact(
  WidgetTester tester, {
  required ContactSection contact,
  String language = 'es',
}) async {
  await loadAppFonts();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 900);
  addTearDown(tester.view.reset);

  final links = RecordingLinkLauncher();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [links.override],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: Locale(language),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: contact)),
      ),
    ),
  );
  return links;
}

const _mobileContact = ContactSection(
  map: SizedBox(key: _mapKey, height: 220),
  showSocialLinks: true,
);

void main() {
  group('en Android/iOS, con mapa y redes', () {
    testWidgets('muestra el mapa con su nombre accesible (RF-10)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await _pumpContact(tester, contact: _mobileContact);

      expect(find.byKey(_mapKey), findsOneWidget);
      expect(
        find.bySemanticsLabel('Mapa con la ubicación del estudio'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('el nombre del mapa va en portugués', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpContact(tester, contact: _mobileContact, language: 'pt');

      expect(
        find.bySemanticsLabel('Mapa com a localização do estúdio'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    for (final (name, url) in LandingContent.socialLinks) {
      testWidgets('${name.toUpperCase()} abre su red (RF-11)', (tester) async {
        final links = await _pumpContact(tester, contact: _mobileContact);

        // "INSTAGRAM" también es la etiqueta de su fila en los datos.
        final link = find.widgetWithText(TextButton, name.toUpperCase());
        await tester.ensureVisible(link);
        await tester.pump();
        await tester.tap(link);
        await tester.pump();

        expect(links.opened, [Uri.parse(url)]);
      });
    }

    testWidgets('las redes van después de los datos de contacto y el mapa, '
        'después de las redes', (tester) async {
      await _pumpContact(tester, contact: _mobileContact);

      final instagram = tester.getTopLeft(
        find.text(LandingContent.instagramHandle),
      );
      final tiktok = tester.getTopLeft(find.text('TIKTOK'));
      final map = tester.getTopLeft(find.byKey(_mapKey));
      expect(tiktok.dy, greaterThan(instagram.dy));
      expect(map.dy, greaterThan(tiktok.dy));
      expect(tester.takeException(), isNull);
    });
  });

  testWidgets('sin parámetros, el contacto es el de Web: sin mapa ni redes', (
    tester,
  ) async {
    await _pumpContact(tester, contact: const ContactSection());

    expect(find.text('TIKTOK'), findsNothing);
    expect(find.text('YOUTUBE'), findsNothing);
    expect(find.byKey(_mapKey), findsNothing);
  });

  test('el mapa del salón mide 220 px de alto (D-7)', () {
    expect(GoogleMapContainer.height, 220);
  });
}
