import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/features/landing/landing_section.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';
import 'package:shaddai/features/landing/presentation/widgets/whatsapp_float_button.dart';
import 'package:shaddai/features/navigation/presentation/web_top_bar.dart';

import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

Finder _section(LandingSection section) => find.byWidgetPredicate(
  (widget) => widget is LandingSectionFrame && widget.section == section,
);

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

/// La landing sola, sin la barra superior: así ningún texto queda a medias
/// debajo de ella al desplazarse. La guía de contraste mide el rectángulo
/// entero de cada texto, también la parte tapada, y tomaría los colores de la
/// barra por los del fondo del texto.
Future<void> _pumpLandingAlone(
  WidgetTester tester, {
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
    home: const Scaffold(body: LandingPage()),
    overrides: [
      isWebProvider.overrideWithValue(true),
      // El botón flotante es opaco y tapa el texto que pasa por debajo: la
      // guía lo mediría como texto ilegible. Se prueba aparte.
      showLandingFloatButtonProvider.overrideWithValue(false),
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

void main() {
  for (final theme in ['light', 'dark']) {
    for (final width in [360.0, 1280.0]) {
      testWidgets('contraste y tamaño táctil de cada sección, tema $theme, '
          '${width.toInt()} px (RNF-1, RNF-2)', (tester) async {
        final semantics = tester.ensureSemantics();
        await _pumpLandingAlone(tester, theme: theme, width: width);

        // Las guías solo miden lo que se ve: se recorre la landing.
        for (final section in LandingSection.values) {
          await tester.ensureVisible(_section(section));
          await settleWeb(tester);
          await _expectGuidelines(tester, section.name);
        }
        semantics.dispose();
      });

      testWidgets('contraste y tamaño táctil de la barra, tema $theme, '
          '${width.toInt()} px (RNF-1, RNF-2)', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpWebApp(
          tester,
          width: width,
          stored: {'theme': theme, 'language': 'es'},
          overrides: [showLandingFloatButtonProvider.overrideWithValue(false)],
        );

        // Con la landing arriba, ningún texto queda a medias bajo la barra.
        await _expectGuidelines(tester, 'barra');
        semantics.dispose();
      });
    }
  }

  testWidgets('con el teclado, Tab llega a "Reservar" desde la landing e Intro '
      'lo activa (RNF-2)', (tester) async {
    await pumpWebApp(tester);
    final reserve = find.descendant(
      of: find.byType(WebTopBar),
      matching: find.widgetWithText(ElevatedButton, 'RESERVAR'),
    );

    final whatsapp = find.byType(WhatsappFloatButton);
    var whatsappVisits = 0;

    // Tab recorre el contenido de la landing, después el botón flotante y
    // luego la barra.
    for (var i = 0; i < 150 && !_hasFocus(tester, reserve); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      if (_hasFocus(tester, whatsapp)) whatsappVisits++;
    }
    expect(_hasFocus(tester, reserve), isTrue, reason: 'el foco no llegó');
    expect(whatsappVisits, 1, reason: 'el botón flotante, una sola vez');

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await settleWeb(tester);

    expect(webLocation(tester).path, '/login');
  });

  testWidgets('con el teclado, Tab recorre también el contenido de la landing '
      'y la desplaza hasta lo enfocado (RNF-2)', (tester) async {
    await pumpWebApp(tester);
    final contactWhatsapp = find.descendant(
      of: _section(LandingSection.contact),
      matching: find.byType(OutlinedButton),
    );

    for (var i = 0; i < 120 && !_hasFocus(tester, contactWhatsapp); i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
    }
    await settleWeb(tester);

    expect(_hasFocus(tester, contactWhatsapp), isTrue);
    final rect = tester.getRect(contactWhatsapp);
    expect(
      rect.top,
      greaterThanOrEqualTo(tester.getBottomLeft(find.byType(WebTopBar)).dy),
    );
    expect(rect.bottom, lessThanOrEqualTo(900));
  });

  for (final width in [360.0, 1280.0]) {
    testWidgets('con el texto al 200 %, los botones de la barra siguen '
        'midiendo al menos 48 px (${width.toInt()} px, RNF-2, RNF-4)', (
      tester,
    ) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      final semantics = tester.ensureSemantics();
      await pumpWebApp(tester, width: width);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      semantics.dispose();
    });
  }
}
