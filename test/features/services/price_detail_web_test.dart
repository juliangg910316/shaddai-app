import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/landing/landing_content.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';
import 'package:shaddai/features/landing/presentation/sections/prices_section.dart';
import 'package:shaddai/features/landing/presentation/widgets/whatsapp_float_button.dart';
import 'package:shaddai/features/services/presentation/price_detail_view.dart';

import '../../helpers/fake_price_list.dart';
import '../../helpers/pump_web_app.dart';
import '../../helpers/recording_link_launcher.dart';

Finder _inDetail(Finder finder) =>
    find.descendant(of: find.byType(PriceDetailView), matching: finder);

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

/// [list] sin el servicio [id].
PriceListModel _without(PriceListModel list, String id) => list.copyWith(
  categories: [
    for (final category in list.categories)
      category.copyWith(
        items: [
          for (final item in category.items)
            if (item.id != id) item,
        ],
      ),
  ],
);

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settleWeb(tester);
  await tester.tap(finder);
  await settleWeb(tester);
}

void main() {
  group('abrir el detalle desde la lista (RF-13, RF-14, RF-15)', () {
    testWidgets('un servicio muestra su categoría, nombre, precio, duración, '
        'descripción y la nota de su categoría', (tester) async {
      await pumpWebApp(
        tester,
        location: '/?section=prices',
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
      );

      await _tapVisible(
        tester,
        find.descendant(
          of: find.byType(PricesSection),
          matching: find.text('Spa de manos'),
        ),
      );

      expect(webLocation(tester).path, '/services/service/spa');
      for (final text in [
        'MANOS',
        'Spa de manos',
        'R\$ 55',
        'Duración',
        '45 min',
        'Exfoliación e hidratación.',
        'Incluye cutículas.',
        'RESERVAR CITA',
        'VOLVER A LA LISTA DE PRECIOS',
      ]) {
        expect(_inDetail(find.text(text)), findsOneWidget, reason: text);
      }
    });

    testWidgets('el precio "desde" se muestra con su texto', (tester) async {
      await pumpWebApp(
        tester,
        location: '/services/service/gel-maintenance',
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
      );

      expect(_inDetail(find.text('desde R\$ 110')), findsOneWidget);
      expect(_inDetail(find.text('1 h 30 min')), findsOneWidget);
    });

    testWidgets('un combo muestra su nombre, precio, duración y descripción', (
      tester,
    ) async {
      await pumpWebApp(
        tester,
        location: '/?section=combos',
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
      );

      await _tapVisible(tester, find.text('Gel Completo'));

      expect(webLocation(tester).path, '/services/combo/full-gel');
      for (final text in ['Gel Completo', 'R\$ 120', '2 h 30 min']) {
        expect(_inDetail(find.text(text)), findsOneWidget, reason: text);
      }
      expect(_inDetail(find.text('Manos + pies')), findsOneWidget);
    });

    testWidgets('"atrás" vuelve a la landing en la misma posición', (
      tester,
    ) async {
      await pumpWebApp(
        tester,
        location: '/?section=prices',
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
      );
      final row = find.descendant(
        of: find.byType(PricesSection),
        matching: find.text('Corto'),
      );
      await tester.ensureVisible(row);
      await settleWeb(tester);
      final before = _landingScroll(tester).pixels;

      await tester.tap(row);
      await settleWeb(tester);
      expect(find.byType(PriceDetailView), findsOneWidget);

      webRouter(tester).pop();
      await settleWeb(tester);
      expect(find.byType(PriceDetailView), findsNothing);
      expect(_landingScroll(tester).pixels, before);
    });
  });

  group('abrir por su dirección (RF-43, RF-44)', () {
    testWidgets('sin sesión se ve el detalle, con la barra superior y el '
        'botón flotante de WhatsApp', (tester) async {
      final links = RecordingLinkLauncher();
      await pumpWebApp(
        tester,
        location: '/services/service/spa',
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
        overrides: [links.override],
      );

      expect(webLocation(tester).path, '/services/service/spa');
      expect(_inDetail(find.text('Spa de manos')), findsOneWidget);
      expect(find.text('RESERVAR'), findsOneWidget, reason: 'barra superior');

      await tester.tap(find.byType(WhatsappFloatButton));
      await tester.pump();
      expect(links.opened, [Uri.parse(LandingContent.whatsappUrl)]);
    });

    testWidgets('"Volver a la lista de precios" abre la landing en la lista', (
      tester,
    ) async {
      await pumpWebApp(
        tester,
        location: '/services/service/spa',
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
      );

      await _tapVisible(
        tester,
        _inDetail(find.text('VOLVER A LA LISTA DE PRECIOS')),
      );

      expect(find.byType(PriceDetailView), findsNothing);
      expect(find.byType(LandingPage), findsOneWidget);
      expect(_landingScroll(tester).pixels, greaterThan(0));
      final pricesTop = tester.getTopLeft(find.byType(PricesSection)).dy;
      expect(pricesTop, lessThan(200), reason: 'la lista queda arriba');
      expect(pricesTop, greaterThanOrEqualTo(0));
    });

    testWidgets('desde la lista, "Volver a la lista de precios" cierra el '
        'detalle y deja la landing en la lista', (tester) async {
      await pumpWebApp(
        tester,
        location: '/?section=prices',
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
      );
      await _tapVisible(tester, find.text('Spa de manos'));

      await _tapVisible(
        tester,
        _inDetail(find.text('VOLVER A LA LISTA DE PRECIOS')),
      );

      expect(find.byType(PriceDetailView), findsNothing);
      expect(webLocation(tester).path, '/');
      final pricesTop = tester.getTopLeft(find.byType(PricesSection)).dy;
      expect(pricesTop, lessThan(200));
    });

    testWidgets('"Reservar cita" sin sesión pide iniciar sesión y vuelve a la '
        'reserva (RF-16)', (tester) async {
      await pumpWebApp(
        tester,
        location: '/services/service/spa',
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
      );

      await _tapVisible(tester, _inDetail(find.text('RESERVAR CITA')));

      expect(webLocation(tester).toString(), '/login?next=%2Fbooking');
    });
  });

  group('no disponible (RF-17)', () {
    testWidgets('un id que no existe muestra el aviso y su botón', (
      tester,
    ) async {
      await pumpWebApp(
        tester,
        location: '/services/service/no-existe',
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
      );

      expect(
        _inDetail(find.text('Este servicio ya no está disponible.')),
        findsOneWidget,
      );
      expect(
        _inDetail(find.text('VOLVER A LA LISTA DE PRECIOS')),
        findsOneWidget,
      );
      expect(_inDetail(find.text('RESERVAR CITA')), findsNothing);
    });

    testWidgets('un tipo de detalle desconocido también', (tester) async {
      await pumpWebApp(
        tester,
        location: '/services/otro/spa',
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
      );

      expect(
        _inDetail(find.text('Este servicio ya no está disponible.')),
        findsOneWidget,
      );
    });

    testWidgets('si la admin lo borra con el detalle abierto, aparece el '
        'aviso al momento', (tester) async {
      final repository = FakePriceListRepository(stored: testPriceList());
      await pumpWebApp(
        tester,
        location: '/services/service/spa',
        priceListRepository: repository,
      );
      expect(_inDetail(find.text('Spa de manos')), findsOneWidget);

      repository.change(_without(testPriceList(), 'spa'));
      await tester.pump();
      await tester.pump();

      expect(
        _inDetail(find.text('Este servicio ya no está disponible.')),
        findsOneWidget,
      );
      expect(_inDetail(find.text('Spa de manos')), findsNothing);
    });

    testWidgets('un cambio de precio con el detalle abierto se ve al momento '
        '(RF-6)', (tester) async {
      final repository = FakePriceListRepository(stored: testPriceList());
      await pumpWebApp(
        tester,
        location: '/services/combo/full-gel',
        priceListRepository: repository,
      );

      final list = testPriceList();
      repository.change(
        list.copyWith(
          combos: [
            list.combos.first.copyWith(priceCents: 13000),
            ...list.combos.skip(1),
          ],
        ),
      );
      await tester.pump();
      await tester.pump();

      expect(_inDetail(find.text('R\$ 130')), findsOneWidget);
    });
  });

  testWidgets('sin poder cargar, el detalle muestra el aviso con '
      '"Reintentar" (RF-8, RNF-6)', (tester) async {
    final repository = FakePriceListRepository(autoEmit: false);
    await pumpWebApp(
      tester,
      location: '/services/service/spa',
      priceListRepository: repository,
    );

    repository.emitError(Exception('permission-denied'));
    await tester.pump();
    await tester.pump();

    expect(_inDetail(find.text('REINTENTAR')), findsOneWidget);
    expect(find.textContaining('permission-denied'), findsNothing);
  });

  group('diseño y accesibilidad (RNF-4)', () {
    for (final width in [600.0, 1280.0]) {
      testWidgets('a ${width.toInt()} px, sin desbordes y con la página '
          'centrada', (tester) async {
        await pumpWebApp(
          tester,
          location: '/services/service/spa',
          width: width,
          priceListRepository: FakePriceListRepository(stored: testPriceList()),
        );

        expect(tester.takeException(), isNull);
        expect(
          tester.getSize(find.byType(PriceDetailView)).width,
          lessThanOrEqualTo(640),
        );
      });
    }

    for (final theme in ['light', 'dark']) {
      testWidgets('contraste y tamaño táctil, tema $theme', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpWebApp(
          tester,
          location: '/services/service/gel-maintenance',
          stored: {'theme': theme, 'language': 'es'},
          priceListRepository: FakePriceListRepository(stored: testPriceList()),
          overrides: [showLandingFloatButtonProvider.overrideWithValue(false)],
        );

        for (final guideline in [
          textContrastGuideline,
          androidTapTargetGuideline,
          labeledTapTargetGuideline,
        ]) {
          await expectLater(tester, meetsGuideline(guideline));
        }
        semantics.dispose();
      });
    }
  });

  testWidgets('en portugués, el detalle cambia de idioma', (tester) async {
    await pumpWebApp(
      tester,
      location: '/services/service/spa',
      stored: {'language': 'pt'},
      priceListRepository: FakePriceListRepository(stored: testPriceList()),
    );

    for (final text in ['Spa das mãos', 'Duração', 'MÃOS']) {
      expect(_inDetail(find.text(text)), findsOneWidget, reason: text);
    }
  });
}
