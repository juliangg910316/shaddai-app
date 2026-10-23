import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/booking/presentation/booking_sign_in_prompt.dart';
import 'package:shaddai/features/landing/presentation/sections/prices_section.dart';
import 'package:shaddai/features/navigation/providers/tab_scroll_provider.dart';
import 'package:shaddai/features/services/presentation/price_detail_view.dart';

import '../../helpers/fake_price_list.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

Finder _inDetail(Finder finder) =>
    find.descendant(of: find.byType(PriceDetailView), matching: finder);

Finder _tab(String label) =>
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label));

ScrollController _servicesScroll(WidgetTester tester) =>
    appContainer(tester).read(tabScrollControllerProvider(MobileTab.services));

Future<void> _tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settleWeb(tester);
  await tester.tap(finder);
  await settleWeb(tester);
}

/// Pestaña Servicios con la lista de prueba, y el detalle de "Corto" (más
/// abajo en la lista, para que la lista quede desplazada) abierto.
Future<double> _openDetailFromServices(WidgetTester tester) async {
  await pumpMobileApp(
    tester,
    location: '/services',
    priceListRepository: FakePriceListRepository(stored: testPriceList()),
  );
  final row = find.descendant(
    of: find.byType(PricesSection),
    matching: find.text('Corto'),
  );
  await tester.ensureVisible(row);
  await settleWeb(tester);
  final offset = _servicesScroll(tester).offset;
  await tester.tap(row);
  await settleWeb(tester);
  return offset;
}

void main() {
  testWidgets('el detalle se abre dentro de Servicios, con la barra inferior '
      'visible (RF-13, RF-14)', (tester) async {
    await _openDetailFromServices(tester);

    expect(webLocation(tester).path, '/services/service/gel-short');
    expect(find.byType(NavigationBar), findsOneWidget);
    for (final text in ['MANOS', 'Corto', 'R\$ 150', '2 h', 'RESERVAR CITA']) {
      expect(_inDetail(find.text(text)), findsOneWidget, reason: text);
    }
    // En Android/iOS se vuelve con la flecha atrás, no con un botón propio.
    expect(_inDetail(find.text('VOLVER A LA LISTA DE PRECIOS')), findsNothing);
    expect(_inDetail(find.byType(BackButton)), findsOneWidget);
  });

  testWidgets('un combo también se abre dentro de Servicios (RF-15)', (
    tester,
  ) async {
    await pumpMobileApp(
      tester,
      location: '/services',
      priceListRepository: FakePriceListRepository(stored: testPriceList()),
    );

    await _tapVisible(tester, find.text('Gel Completo'));

    expect(webLocation(tester).path, '/services/combo/full-gel');
    expect(_inDetail(find.text('2 h 30 min')), findsOneWidget);
  });

  testWidgets('la flecha atrás vuelve a la lista en la misma posición', (
    tester,
  ) async {
    final offset = await _openDetailFromServices(tester);

    await tester.tap(_inDetail(find.byType(BackButton)));
    await settleWeb(tester);

    expect(find.byType(PriceDetailView), findsNothing);
    expect(_servicesScroll(tester).offset, offset);
  });

  testWidgets('tocar Servicios con el detalle abierto lo cierra y la lista '
      'sigue donde estaba; un segundo toque sube al comienzo (RF-45)', (
    tester,
  ) async {
    final offset = await _openDetailFromServices(tester);
    expect(offset, greaterThan(0));

    await tester.tap(_tab('Servicios'));
    await settleWeb(tester);
    expect(find.byType(PriceDetailView), findsNothing);
    expect(webLocation(tester).path, '/services');
    expect(_servicesScroll(tester).offset, offset);

    await tester.tap(_tab('Servicios'));
    await settleWeb(tester);
    expect(_servicesScroll(tester).offset, 0);
  });

  testWidgets('"Ver lista de precios" en Inicio cierra el detalle y abre la '
      'lista desde el comienzo (RF-46)', (tester) async {
    await _openDetailFromServices(tester);

    await tester.tap(_tab('Inicio'));
    await settleWeb(tester);
    await _tapVisible(tester, find.text('VER LISTA DE PRECIOS'));

    expect(webLocation(tester).path, '/services');
    expect(find.byType(PriceDetailView), findsNothing);
    expect(_servicesScroll(tester).offset, 0);
  });

  testWidgets('cambiar de pestaña y volver mantiene el detalle abierto '
      '(RF-47)', (tester) async {
    await _openDetailFromServices(tester);

    await tester.tap(_tab('Perfil'));
    await settleWeb(tester);
    expect(find.byType(PriceDetailView), findsNothing);

    await tester.tap(_tab('Servicios'));
    await settleWeb(tester);
    expect(find.byType(PriceDetailView), findsOneWidget);
    expect(webLocation(tester).path, '/services/service/gel-short');
  });

  testWidgets('"Reservar cita" abre la pestaña Reservas (RF-16)', (
    tester,
  ) async {
    await _openDetailFromServices(tester);

    await _tapVisible(tester, _inDetail(find.text('RESERVAR CITA')));

    expect(webLocation(tester).path, '/booking');
    expect(find.byType(BookingSignInPrompt), findsOneWidget);
  });

  testWidgets('un servicio que no existe muestra el aviso y su botón vuelve '
      'a la lista (RF-17)', (tester) async {
    await pumpMobileApp(
      tester,
      location: '/services/service/no-existe',
      priceListRepository: FakePriceListRepository(stored: testPriceList()),
    );

    expect(
      _inDetail(find.text('Este servicio ya no está disponible.')),
      findsOneWidget,
    );
    await _tapVisible(
      tester,
      _inDetail(find.text('VOLVER A LA LISTA DE PRECIOS')),
    );

    expect(find.byType(PriceDetailView), findsNothing);
    expect(webLocation(tester).path, '/services');
    expect(find.byType(PricesSection), findsOneWidget);
  });

  for (final language in ['es', 'pt']) {
    testWidgets('con el texto al 200 % a 320 px, en $language, sin desbordes '
        '(RNF-4)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await pumpMobileApp(
        tester,
        location: '/services/service/gel-maintenance',
        width: 320,
        stored: {'language': language},
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
      );

      expect(find.byType(PriceDetailView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  for (final theme in ['light', 'dark']) {
    testWidgets('contraste y tamaño táctil, tema $theme (RNF-4)', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpMobileApp(
        tester,
        location: '/services/service/gel-maintenance',
        stored: {'theme': theme, 'language': 'es'},
        priceListRepository: FakePriceListRepository(stored: testPriceList()),
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
}
