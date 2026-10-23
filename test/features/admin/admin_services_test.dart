import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/repositories/config_repository.dart';
import 'package:shaddai/features/admin/presentation/admin_services_view.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';

import '../../helpers/fake_price_list.dart';
import '../../helpers/pump_web_app.dart';

/// Calendario sin Firebase. Estos cambios no lo leen.
class _UnusedConfigRepository implements ConfigRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Overrides del panel sin Firebase: agenda vacía.
List<Override> _adminOverrides() => [
  adminAppointmentsProvider.overrideWith((ref) => Stream.value(const [])),
  configRepositoryProvider.overrideWithValue(_UnusedConfigRepository()),
];

/// Gestión de servicios en Android/iOS, con la admin y [repository].
Future<void> _pumpServices(
  WidgetTester tester,
  FakePriceListRepository repository, {
  String theme = 'light',
}) => pumpMobileApp(
  tester,
  location: '/admin/services',
  user: testAdmin,
  stored: {'theme': theme, 'language': 'es'},
  priceListRepository: repository,
  overrides: _adminOverrides(),
);

/// La fila de la categoría, servicio, adicional o combo [id].
Finder _row(String id) => find.byKey(ValueKey('admin-services-row-$id'));

/// El botón [tooltip] de la fila [id].
Finder _action(String id, String tooltip) =>
    find.descendant(of: _row(id), matching: find.byTooltip(tooltip));

Future<void> _tap(WidgetTester tester, String id, String tooltip) async {
  await tester.ensureVisible(_action(id, tooltip));
  await tester.tap(_action(id, tooltip));
  await settleWeb(tester);
}

bool _enabled(WidgetTester tester, String id, String tooltip) =>
    tester
        .widget<IconButton>(
          find.ancestor(
            of: _action(id, tooltip),
            matching: find.byType(IconButton),
          ),
        )
        .onPressed !=
    null;

PriceCategoryModel _category(PriceListModel list, String id) =>
    list.categories.firstWhere((c) => c.id == id);

PriceItemModel _item(PriceListModel list, String id) =>
    list.categories.expand((c) => c.items).firstWhere((i) => i.id == id);

List<String> _itemIds(PriceListModel list, String categoryId) => [
  for (final item in _category(list, categoryId).items) item.id,
];

void main() {
  testWidgets('se ve todo, también lo oculto, con la etiqueta "Oculto" '
      '(RF-20)', (tester) async {
    await _pumpServices(
      tester,
      FakePriceListRepository(stored: testPriceList()),
    );

    for (final name in [
      'Manos',
      'Spa de manos',
      'Cromado',
      'Pies',
      'Pedicura',
      'Gel Completo',
      'Combo oculto',
    ]) {
      expect(
        find.descendant(
          of: find.byType(AdminServicesView),
          matching: find.text(name),
        ),
        findsOneWidget,
        reason: name,
      );
    }

    Finder hiddenIn(String id) =>
        find.descendant(of: _row(id), matching: find.text('Oculto'));
    expect(hiddenIn('feet'), findsOneWidget);
    expect(hiddenIn('hidden-combo'), findsOneWidget);
    expect(hiddenIn('hands'), findsNothing);
    expect(hiddenIn('spa'), findsNothing);
    expect(hiddenIn('full-gel'), findsNothing);
  });

  group('subir y bajar (RF-26)', () {
    testWidgets('los botones de los extremos están desactivados', (
      tester,
    ) async {
      await _pumpServices(
        tester,
        FakePriceListRepository(stored: testPriceList()),
      );

      expect(_enabled(tester, 'hands', 'Subir'), isFalse);
      expect(_enabled(tester, 'hands', 'Bajar'), isTrue);
      expect(_enabled(tester, 'feet', 'Bajar'), isFalse);
      expect(_enabled(tester, 'spa', 'Subir'), isFalse);
      expect(_enabled(tester, 'spa', 'Bajar'), isTrue);
      expect(_enabled(tester, 'chrome', 'Bajar'), isFalse);
      expect(_enabled(tester, 'pedicure', 'Subir'), isFalse);
      expect(_enabled(tester, 'pedicure', 'Bajar'), isFalse);
      expect(_enabled(tester, 'full-gel', 'Subir'), isFalse);
      expect(_enabled(tester, 'hidden-combo', 'Bajar'), isFalse);
    });

    testWidgets('mueven categorías, servicios y combos, y se confirma '
        '(RF-34)', (tester) async {
      final repository = FakePriceListRepository(stored: testPriceList());
      await _pumpServices(tester, repository);

      await _tap(tester, 'gel-short', 'Subir');
      expect(_itemIds(repository.stored!, 'hands'), [
        'gel-short',
        'spa',
        'gel-maintenance',
        'chrome',
      ]);
      expect(find.text('Cambios guardados'), findsOneWidget);

      await _tap(tester, 'hands', 'Bajar');
      expect(repository.stored!.categories.map((c) => c.id), ['feet', 'hands']);

      await _tap(tester, 'hidden-combo', 'Subir');
      expect(repository.stored!.combos.map((c) => c.id), [
        'hidden-combo',
        'full-gel',
      ]);
      expect(repository.updateCalls, 3);
    });
  });

  testWidgets('ocultar y mostrar (RF-27)', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpServices(tester, repository);

    await _tap(tester, 'spa', 'Ocultar');
    expect(_item(repository.stored!, 'spa').visible, isFalse);
    expect(
      find.descendant(of: _row('spa'), matching: find.text('Oculto')),
      findsOneWidget,
    );
    expect(_action('spa', 'Mostrar'), findsOneWidget);

    await _tap(tester, 'feet', 'Mostrar');
    expect(_category(repository.stored!, 'feet').visible, isTrue);

    await _tap(tester, 'full-gel', 'Ocultar');
    expect(repository.stored!.combos.first.visible, isFalse);
  });

  group('borrar (RF-29 a RF-31)', () {
    testWidgets('pide confirmación con el nombre; al cancelar no se borra', (
      tester,
    ) async {
      final repository = FakePriceListRepository(stored: testPriceList());
      await _pumpServices(tester, repository);

      await _tap(tester, 'chrome', 'Borrar');
      expect(find.text('¿Borrar «Cromado»?'), findsOneWidget);
      expect(find.text('No se puede deshacer.'), findsOneWidget);
      await tester.tap(find.text('CANCELAR'));
      await settleWeb(tester);

      expect(repository.updateCalls, 0);
      expect(_itemIds(repository.stored!, 'hands'), contains('chrome'));

      await _tap(tester, 'chrome', 'Borrar');
      await tester.tap(find.text('BORRAR'));
      await settleWeb(tester);

      expect(_itemIds(repository.stored!, 'hands'), isNot(contains('chrome')));
      expect(_row('chrome'), findsNothing);
      expect(find.text('Cambios guardados'), findsOneWidget);
    });

    testWidgets('borra un combo', (tester) async {
      final repository = FakePriceListRepository(stored: testPriceList());
      await _pumpServices(tester, repository);

      await _tap(tester, 'hidden-combo', 'Borrar');
      expect(find.text('¿Borrar «Combo oculto»?'), findsOneWidget);
      await tester.tap(find.text('BORRAR'));
      await settleWeb(tester);

      expect(repository.stored!.combos.map((c) => c.id), ['full-gel']);
    });

    testWidgets('una categoría con elementos no se puede borrar: diálogo '
        'informativo', (tester) async {
      final repository = FakePriceListRepository(stored: testPriceList());
      await _pumpServices(tester, repository);

      await _tap(tester, 'feet', 'Borrar');
      expect(
        find.text(
          'Esta categoría tiene servicios o adicionales. Bórralos o '
          'muévelos a otra categoría antes de borrarla.',
        ),
        findsOneWidget,
      );
      expect(find.text('BORRAR'), findsNothing);
      await tester.tap(find.text('ENTENDIDO'));
      await settleWeb(tester);

      expect(repository.updateCalls, 0);
      expect(repository.stored!.categories, hasLength(2));
    });

    testWidgets('una categoría vacía se borra tras confirmar', (tester) async {
      final list = testPriceList();
      final repository = FakePriceListRepository(
        stored: list.copyWith(
          categories: [
            ...list.categories,
            const PriceCategoryModel(
              id: 'empty',
              name: BilingualText(es: 'Cejas', pt: 'Sobrancelhas'),
            ),
          ],
        ),
      );
      await _pumpServices(tester, repository);

      await _tap(tester, 'empty', 'Borrar');
      expect(find.text('¿Borrar «Cejas»?'), findsOneWidget);
      await tester.tap(find.text('BORRAR'));
      await settleWeb(tester);

      expect(repository.stored!.categories.map((c) => c.id), ['hands', 'feet']);
    });
  });

  group('errores (RF-33, RNF-6)', () {
    testWidgets('un fallo muestra el aviso con "Reintentar", sin el error '
        'técnico', (tester) async {
      final repository = FakePriceListRepository(stored: testPriceList())
        ..failNext = Exception('unavailable: detalle técnico');
      await _pumpServices(tester, repository);

      await _tap(tester, 'spa', 'Ocultar');
      expect(find.text('No se pudieron guardar los cambios.'), findsOneWidget);
      expect(find.textContaining('detalle técnico'), findsNothing);
      expect(_item(repository.stored!, 'spa').visible, isTrue);

      await tester.tap(find.text('REINTENTAR'));
      await settleWeb(tester);

      expect(repository.updateCalls, 2);
      expect(_item(repository.stored!, 'spa').visible, isFalse);
    });

    testWidgets('si otra admin ya lo borró, se avisa', (tester) async {
      final repository = FakePriceListRepository(stored: testPriceList());
      await _pumpServices(tester, repository);

      // Otra admin borra el adicional sin que esta pantalla se entere aún.
      final list = repository.stored!;
      repository.stored = list.copyWith(
        categories: [
          for (final c in list.categories)
            c.copyWith(items: [...c.items.where((i) => i.id != 'chrome')]),
        ],
      );

      await _tap(tester, 'chrome', 'Borrar');
      await tester.tap(find.text('BORRAR'));
      await settleWeb(tester);

      expect(find.text('Este elemento ya no existe.'), findsOneWidget);
      expect(find.text('REINTENTAR'), findsNothing);
    });
  });

  for (final theme in ['light', 'dark']) {
    testWidgets('botones con tooltip, 48 px y contraste, tema $theme '
        '(RNF-4)', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pumpServices(
        tester,
        FakePriceListRepository(stored: testPriceList()),
        theme: theme,
      );

      for (final tooltip in ['Subir', 'Bajar', 'Ocultar', 'Borrar']) {
        expect(_action('spa', tooltip), findsOneWidget, reason: tooltip);
      }
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
