import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/platform/platform_provider.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/landing/landing_content.dart';
import 'package:shaddai/features/landing/presentation/sections/prices_section.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';

import '../../helpers/fake_price_list.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';
import '../../helpers/recording_link_launcher.dart';

Finder _inPrices(Finder finder) =>
    find.descendant(of: find.byType(PricesSection), matching: finder);

/// La lista de precios sola, en una página con scroll, con [repository].
Future<RecordingLinkLauncher> _pumpPrices(
  WidgetTester tester,
  FakePriceListRepository repository, {
  String theme = 'light',
  Duration timeout = const Duration(seconds: 8),
}) async {
  await loadAppFonts();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(412, 900);
  addTearDown(tester.view.reset);

  final links = RecordingLinkLauncher();
  await pumpApp(
    tester,
    stored: {'theme': theme, 'language': 'es'},
    home: const Scaffold(body: SingleChildScrollView(child: PricesSection())),
    priceListRepository: repository,
    overrides: [
      links.override,
      isWebProvider.overrideWithValue(false),
      priceListLoadTimeoutProvider.overrideWithValue(timeout),
    ],
  );
  await tester.pump();
  return links;
}

void main() {
  testWidgets('mientras carga, un indicador con su etiqueta (RF-7)', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await _pumpPrices(tester, FakePriceListRepository(autoEmit: false));

    expect(_inPrices(find.byType(CircularProgressIndicator)), findsOneWidget);
    expect(find.bySemanticsLabel('Cargando precios'), findsOneWidget);
    // La cabecera de la sección se ve siempre.
    expect(_inPrices(find.text('Lista de precios')), findsOne);
    semantics.dispose();
  });

  group('sin poder cargar (RF-8, RF-9, RNF-6)', () {
    testWidgets('aviso con "Reintentar" y WhatsApp, sin el error en crudo', (
      tester,
    ) async {
      final repository = FakePriceListRepository(autoEmit: false);
      await _pumpPrices(tester, repository);

      repository.emitError(Exception('permission-denied: detalle técnico'));
      await tester.pump();

      expect(
        _inPrices(find.text('No se pudieron cargar los precios.')),
        findsOneWidget,
      );
      expect(_inPrices(find.text('REINTENTAR')), findsOneWidget);
      expect(_inPrices(find.textContaining('WHATSAPP')), findsOneWidget);
      expect(find.textContaining('permission-denied'), findsNothing);
      expect(find.textContaining('detalle técnico'), findsNothing);
    });

    testWidgets('sin respuesta, el aviso sale al pasar el tiempo límite', (
      tester,
    ) async {
      final repository = FakePriceListRepository(autoEmit: false);
      await _pumpPrices(
        tester,
        repository,
        timeout: const Duration(seconds: 2),
      );

      repository.emit(const PriceListSnapshot(list: null, fromCache: true));
      await tester.pump();
      expect(_inPrices(find.byType(CircularProgressIndicator)), findsOne);

      await tester.pump(const Duration(seconds: 3));
      expect(_inPrices(find.text('REINTENTAR')), findsOneWidget);
    });

    testWidgets('"Reintentar" vuelve a escuchar y muestra la lista', (
      tester,
    ) async {
      final repository = FakePriceListRepository(autoEmit: false);
      await _pumpPrices(tester, repository);
      repository.emitError(Exception('unavailable'));
      await tester.pump();

      await tester.tap(_inPrices(find.text('REINTENTAR')));
      await tester.pump();
      expect(repository.watchCalls, 2);
      expect(_inPrices(find.byType(CircularProgressIndicator)), findsOne);

      repository.change(testPriceList());
      await tester.pump();
      expect(_inPrices(find.text('Spa de manos')), findsOneWidget);
    });

    testWidgets('el enlace abre el WhatsApp del salón', (tester) async {
      final repository = FakePriceListRepository(autoEmit: false);
      final links = await _pumpPrices(tester, repository);
      repository.emitError(Exception('unavailable'));
      await tester.pump();

      await tester.tap(_inPrices(find.textContaining('WHATSAPP')));
      await tester.pump();
      expect(links.opened, [Uri.parse(LandingContent.whatsappUrl)]);
    });
  });

  testWidgets('sin categorías que mostrar, aviso de WhatsApp (RF-10)', (
    tester,
  ) async {
    final links = await _pumpPrices(tester, FakePriceListRepository());

    expect(
      _inPrices(find.text('Consulta los precios por WhatsApp.')),
      findsOneWidget,
    );
    expect(_inPrices(find.text('REINTENTAR')), findsNothing);

    await tester.tap(_inPrices(find.textContaining('AGENDA POR WHATSAPP')));
    await tester.pump();
    expect(links.opened, [Uri.parse(LandingContent.whatsappUrl)]);
  });

  testWidgets('sin conexión, se ven los datos guardados en el dispositivo '
      '(RF-40)', (tester) async {
    final repository = FakePriceListRepository(autoEmit: false);
    await _pumpPrices(tester, repository);

    repository.emit(PriceListSnapshot(list: testPriceList(), fromCache: true));
    await tester.pump();

    expect(_inPrices(find.text('Spa de manos')), findsOneWidget);
  });

  for (final theme in ['light', 'dark']) {
    testWidgets('los avisos cumplen el contraste y el tamaño táctil, tema '
        '$theme (RNF-4)', (tester) async {
      final semantics = tester.ensureSemantics();
      final repository = FakePriceListRepository(autoEmit: false);
      await _pumpPrices(tester, repository, theme: theme);

      repository.emitError(Exception('unavailable'));
      await tester.pump();
      for (final guideline in [
        textContrastGuideline,
        androidTapTargetGuideline,
        labeledTapTargetGuideline,
      ]) {
        await expectLater(tester, meetsGuideline(guideline));
      }

      repository.change(null);
      await tester.pump();
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
