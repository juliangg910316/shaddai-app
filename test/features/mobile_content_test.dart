import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/home/presentation/home_view.dart';
import 'package:shaddai/features/services/presentation/services_view.dart';

import '../helpers/pump_web_app.dart';

/// Claves de los textos de ejemplo de la plantilla original: Inicio y la carta
/// de Servicios de antes de la spec 003.
const _sampleKeys = [
  'appTitle',
  'bookAction',
  'categoryAcrylicGel',
  'categoryManicure',
  'categoryPedicure',
  'duration45Min',
  'duration60Min',
  'duration75Min',
  'duration90Min',
  'findUsTitle',
  'guestFallbackName',
  'heroSubtitle',
  'heroTitle',
  'ourServicesTitle',
  'ourWorkTitle',
  'popularServicesTitle',
  'salonAddress',
  'salonName',
  'salonPhotoPlaceholder',
  'serviceAcrylicFullName',
  'serviceAcrylicSetDesc',
  'serviceAcrylicSetName',
  'serviceAcrylicTouchupDesc',
  'serviceAcrylicTouchupName',
  'serviceJellyPedicureDesc',
  'serviceJellyPedicureName',
  'serviceManicureClassicDesc',
  'serviceManicureClassicName',
  'serviceManicureSemipermDesc',
  'serviceManicureSemipermName',
  'servicePedicureSpaDesc',
  'servicePedicureSpaName',
  'servicesMenuEyebrow',
  'viewAllAction',
  'welcomeBack',
  'welcomeGreeting',
];

Set<String> _keys(String arb) => {
  for (final key in (jsonDecode(File(arb).readAsStringSync()) as Map).keys)
    if (!(key as String).startsWith('@')) key,
};

void main() {
  for (final arb in ['lib/l10n/app_es.arb', 'lib/l10n/app_pt.arb']) {
    test('$arb ya no tiene los textos de ejemplo (RF-20)', () {
      final keys = _keys(arb);
      expect(_sampleKeys.where(keys.contains), isEmpty);
    });
  }

  test('español y portugués tienen las mismas claves (RF-21)', () {
    expect(_keys('lib/l10n/app_es.arb'), _keys('lib/l10n/app_pt.arb'));
  });

  for (final (tab, location, view) in [
    ('Inicio', '/home', HomeView),
    ('Servicios', '/services', ServicesView),
  ]) {
    testWidgets('$tab no carga imágenes de la red: se ve sin conexión, salvo '
        'el mapa (RNF-5)', (tester) async {
      await pumpMobileApp(tester, location: location);

      final networkImages = find.descendant(
        of: find.byType(view),
        matching: find.byWidgetPredicate(
          (widget) =>
              (widget is Image && widget.image is NetworkImage) ||
              (widget is Container &&
                  widget.decoration is BoxDecoration &&
                  (widget.decoration as BoxDecoration).image?.image
                      is NetworkImage),
        ),
      );
      expect(networkImages, findsNothing);
      expect(
        find.descendant(of: find.byType(view), matching: find.byType(Image)),
        findsWidgets,
        reason: 'las imágenes son de la app',
      );
    });
  }
}
