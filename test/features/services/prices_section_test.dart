import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/preferences/preferences_logic.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/landing/presentation/sections/prices_section.dart';
import 'package:shaddai/features/preferences/providers/preferences_provider.dart';

import '../../helpers/fake_price_list.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

Finder _inPrices(Finder finder) =>
    find.descendant(of: find.byType(PricesSection), matching: finder);

/// La landing de Web abierta en la lista de precios, con [repository].
Future<void> _pumpWebPrices(
  WidgetTester tester,
  FakePriceListRepository repository, {
  String language = 'es',
}) async {
  await pumpWebApp(
    tester,
    location: '/?section=prices',
    stored: {'language': language},
    priceListRepository: repository,
  );
}

/// Cambia el precio del servicio [id] de [list] a [cents].
PriceListModel _withPrice(PriceListModel list, String id, int cents) =>
    list.copyWith(
      categories: [
        for (final category in list.categories)
          category.copyWith(
            items: [
              for (final item in category.items)
                item.id == id ? item.copyWith(priceCents: cents) : item,
            ],
          ),
      ],
    );

void main() {
  group('lista de precios desde la base de datos (RF-1, RF-2)', () {
    testWidgets('categorías visibles con su número, textos, grupos, '
        'servicios y adicionales', (tester) async {
      await _pumpWebPrices(
        tester,
        FakePriceListRepository(stored: testPriceList()),
      );

      for (final text in [
        '01',
        'Manos',
        'CUIDADO Y ELEGANCIA',
        'Incluye cutículas.',
        'Spa de manos',
        'R\$ 55',
        'NUEVA APLICACIÓN',
        'Corto',
        'R\$ 150',
        'MANTENIMIENTO',
        'desde R\$ 110',
        'Cromado',
        '+R\$ 15',
      ]) {
        expect(_inPrices(find.text(text)), findsOneWidget, reason: text);
      }
      // "Pies" está oculta (RF-28): no hay segunda categoría.
      expect(_inPrices(find.text('Pies')), findsNothing);
      expect(_inPrices(find.text('02')), findsNothing);
    });

    testWidgets('en Android/iOS, la pestaña Servicios muestra la misma '
        'lista', (tester) async {
      await pumpMobileApp(
        tester,
        location: '/services',
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
      );

      expect(_inPrices(find.text('Spa de manos')), findsOneWidget);
      expect(_inPrices(find.text('+R\$ 15')), findsOneWidget);
      expect(_inPrices(find.text('Pies')), findsNothing);
    });

    testWidgets('al cambiar de idioma, los textos cambian sin recargar '
        '(RF-5)', (tester) async {
      final repository = FakePriceListRepository(stored: testPriceList());
      await _pumpWebPrices(tester, repository);

      await appContainer(
        tester,
      ).read(languagePreferenceProvider.notifier).select(AppLanguage.pt);
      await settleWeb(tester);

      expect(_inPrices(find.text('Spa das mãos')), findsOneWidget);
      expect(_inPrices(find.text('NOVA APLICAÇÃO')), findsOneWidget);
      expect(_inPrices(find.text('a partir de R\$ 110')), findsOneWidget);
      expect(repository.watchCalls, 1);
    });

    testWidgets('un cambio de la admin se ve al momento (RF-6)', (
      tester,
    ) async {
      final repository = FakePriceListRepository(stored: testPriceList());
      await _pumpWebPrices(tester, repository);

      repository.change(_withPrice(testPriceList(), 'spa', 6000));
      await tester.pump();
      await tester.pump();

      expect(_inPrices(find.text('R\$ 55')), findsNothing);
      expect(_inPrices(find.text('R\$ 60')), findsOneWidget);
    });
  });

  group('servicios que se pueden abrir (RF-41, RNF-5)', () {
    testWidgets('la flecha sale en cada servicio y no en los adicionales', (
      tester,
    ) async {
      await _pumpWebPrices(
        tester,
        FakePriceListRepository(stored: testPriceList()),
      );

      // Tres servicios visibles en "Manos"; el adicional no lleva flecha.
      expect(_inPrices(find.byIcon(Icons.chevron_right)), findsNWidgets(3));
      expect(_inPrices(find.byType(InkWell)), findsNWidgets(3));
    });

    testWidgets('el lector de pantalla anuncia cada servicio como botón, '
        'con su nombre y su precio', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpWebPrices(
        tester,
        FakePriceListRepository(stored: testPriceList()),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Spa de manos, R\$ 55')),
        isSemantics(isButton: true, hasTapAction: true, hint: 'Ver detalle'),
      );
      expect(
        tester.getSemantics(
          find.bySemanticsLabel('Mantenimiento, desde R\$ 110'),
        ),
        isSemantics(isButton: true, hasTapAction: true),
      );
      semantics.dispose();
    });

    testWidgets('cada servicio mide al menos 48 px de alto', (tester) async {
      await _pumpWebPrices(
        tester,
        FakePriceListRepository(stored: testPriceList()),
      );

      for (final row in tester.widgetList(_inPrices(find.byType(InkWell)))) {
        final size = tester.getSize(find.byWidget(row));
        expect(size.height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('lista inicial (RNF-1)', () {
    testWidgets('en ancho, los seis bloques en dos filas de tres', (
      tester,
    ) async {
      await pumpWebApp(tester, location: '/?section=prices');

      double top(String number) =>
          tester.getTopLeft(_inPrices(find.text(number))).dy;
      expect({top('01'), top('02'), top('03')}, hasLength(1));
      expect({top('04'), top('05'), top('06')}, hasLength(1));
      expect(top('04'), greaterThan(top('01')));
    });

    testWidgets('en estrecho, uno debajo de otro', (tester) async {
      await pumpWebApp(tester, location: '/?section=prices', width: 600);

      final lefts = {
        for (final number in ['01', '02', '03', '04', '05', '06'])
          tester.getTopLeft(_inPrices(find.text(number))).dx,
      };
      expect(lefts, hasLength(1));
    });
  });
}
