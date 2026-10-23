import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/app_theme.dart';
import 'package:shaddai/features/landing/presentation/landing_layout.dart';
import 'package:shaddai/features/landing/presentation/sections/prices_section.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';
import 'package:shaddai/l10n/app_localizations.dart';

import '../../helpers/fake_price_list.dart';
import '../../helpers/pump_web_app.dart';

/// La lista de precios sola, en una ventana de 1280 px (como una tableta en
/// horizontal), con un [LandingLayout] encima si se pasa [wide].
Future<void> _pumpPrices(WidgetTester tester, {bool? wide}) async {
  await loadAppFonts();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(1280, 900);
  addTearDown(tester.view.reset);

  const prices = PricesSection();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        priceListRepositoryProvider.overrideWithValue(
          FakePriceListRepository(stored: initialTestPriceList()),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        locale: const Locale('es'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SingleChildScrollView(
            child: wide == null
                ? prices
                : LandingLayout(wide: wide, child: prices),
          ),
        ),
      ),
    ),
  );
  // La lista de precios llega de la base de datos (falsa) tras el primer
  // fotograma (spec 004).
  await tester.pump();
}

/// Los tres primeros bloques ("01", "02" y "03"), en la misma fila.
bool _firstRowSideBySide(WidgetTester tester) {
  final tops = [
    for (final number in ['01', '02', '03'])
      tester.getTopLeft(find.text(number)).dy,
  ];
  return tops.toSet().length == 1;
}

void main() {
  testWidgets('sin LandingLayout, la sección va en estrecho aunque la '
      'ventana mida 1280 px (móvil, también en tableta)', (tester) async {
    await _pumpPrices(tester);

    expect(_firstRowSideBySide(tester), isFalse);
    expect(
      tester.getTopLeft(find.text('01')).dx,
      tester.getTopLeft(find.text('02')).dx,
      reason: 'uno debajo de otro',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('con LandingLayout(wide: true), la sección va en ancho', (
    tester,
  ) async {
    await _pumpPrices(tester, wide: true);

    expect(_firstRowSideBySide(tester), isTrue);
  });

  testWidgets('con LandingLayout(wide: false), en estrecho', (tester) async {
    await _pumpPrices(tester, wide: false);

    expect(_firstRowSideBySide(tester), isFalse);
  });

  testWidgets('landingIsWide lee el LandingLayout más cercano', (tester) async {
    late bool outside;
    late bool inside;
    await tester.pumpWidget(
      Builder(
        builder: (context) {
          outside = landingIsWide(context);
          return LandingLayout(
            wide: true,
            child: Builder(
              builder: (context) {
                inside = landingIsWide(context);
                return const SizedBox();
              },
            ),
          );
        },
      ),
    );

    expect(outside, isFalse);
    expect(inside, isTrue);
  });
}
