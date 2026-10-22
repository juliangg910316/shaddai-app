import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/presentation/booking_sign_in_prompt.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/home/presentation/home_view.dart';
import 'package:shaddai/features/landing/presentation/sections/about_section.dart';
import 'package:shaddai/features/landing/presentation/sections/catalog_section.dart';
import 'package:shaddai/features/landing/presentation/sections/combos_section.dart';
import 'package:shaddai/features/landing/presentation/sections/contact_section.dart';
import 'package:shaddai/features/landing/presentation/sections/gallery_section.dart';
import 'package:shaddai/features/landing/presentation/sections/hero_section.dart';
import 'package:shaddai/features/landing/presentation/sections/info_section.dart';
import 'package:shaddai/features/landing/presentation/sections/prices_section.dart';
import 'package:shaddai/features/services/presentation/services_view.dart';

import '../helpers/fake_auth.dart';
import '../helpers/fake_session.dart';
import '../helpers/pump_app.dart';
import '../helpers/pump_web_app.dart';

/// Cada pestaña y las partes que se recorren para medirla (las guías solo
/// miden lo que se ve).
final _tabs = <(String, String, Widget, List<Type>)>[
  (
    'Inicio',
    '/home',
    const HomeView(map: SizedBox(height: 220)),
    [HeroSection, GallerySection, AboutSection, ContactSection],
  ),
  (
    'Servicios',
    '/services',
    const ServicesView(),
    [PricesSection, CombosSection, CatalogSection, InfoSection],
  ),
  (
    'el aviso de Reservas',
    '/booking',
    const BookingView(),
    [BookingSignInPrompt],
  ),
];

/// La pestaña sola, sin la barra inferior: así ningún texto queda a medias
/// debajo de ella al desplazarse. La guía de contraste mide el rectángulo
/// entero de cada texto, también la parte tapada, y tomaría el verde de la
/// barra por el fondo del texto. La barra se mide en `mobile_tabs_test`.
Future<void> _pumpTabAlone(
  WidgetTester tester, {
  required Widget view,
  required String theme,
  required double width,
}) async {
  await loadAppFonts();
  tester.platformDispatcher.accessibilityFeaturesTestValue =
      const FakeAccessibilityFeatures(disableAnimations: true);
  addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(width, 900);
  addTearDown(tester.view.reset);

  await pumpApp(
    tester,
    stored: {'theme': theme, 'language': 'es'},
    home: view,
    overrides: [
      ...sessionOverrides(),
      isWebProvider.overrideWithValue(false),
      authRepositoryProvider.overrideWithValue(FakeAuthRepository()),
      userRepositoryProvider.overrideWithValue(FakeUserRepository()),
    ],
  );
  await settleWeb(tester);
}

Future<void> _expectGuidelines(WidgetTester tester, String where) async {
  for (final guideline in [
    textContrastGuideline,
    labeledTapTargetGuideline,
    androidTapTargetGuideline,
  ]) {
    await expectLater(tester, meetsGuideline(guideline), reason: where);
  }
}

/// Recorre la pestaña de arriba abajo, parte por parte.
Future<void> _scrollThrough(
  WidgetTester tester,
  List<Type> parts,
  Future<void> Function(String part) check,
) async {
  for (final part in parts) {
    final finder = find.byType(part);
    await tester.ensureVisible(finder);
    await settleWeb(tester);
    await check('$part');
  }
}

void main() {
  for (final (name, location, view, parts) in _tabs) {
    for (final theme in ['light', 'dark']) {
      for (final width in [320.0, 412.0]) {
        testWidgets('$name cumple contraste y tamaño táctil, tema $theme, '
            '${width.toInt()} px (RNF-2, RNF-3)', (tester) async {
          final semantics = tester.ensureSemantics();
          await _pumpTabAlone(tester, view: view, theme: theme, width: width);

          await _scrollThrough(
            tester,
            parts,
            (part) => _expectGuidelines(tester, '$name / $part'),
          );
          semantics.dispose();
        });
      }
    }

    for (final language in ['es', 'pt']) {
      testWidgets('$name, con el texto al 200 % a 320 px, en $language, no '
          'corta ni solapa texto (RNF-4)', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpMobileApp(
          tester,
          location: location,
          width: 320,
          stored: {'language': language},
        );

        await _scrollThrough(tester, parts, (_) async {});

        expect(tester.takeException(), isNull);
      });
    }
  }

  for (final (language, label) in [
    ('es', 'Diseño 1 — ver más en Instagram'),
    ('pt', 'Design 1 — veja mais no Instagram'),
  ]) {
    testWidgets('las imágenes llevan su descripción en $language (RNF-3)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpMobileApp(tester, stored: {'language': language});

      expect(find.bySemanticsLabel(label), findsOneWidget);
      // La foto de Beidis tiene la misma descripción en los dos idiomas.
      expect(
        find.bySemanticsLabel('Beidis Viera – Studio Shaddai Nail Designer'),
        findsOneWidget,
      );
      semantics.dispose();
    });
  }
}
