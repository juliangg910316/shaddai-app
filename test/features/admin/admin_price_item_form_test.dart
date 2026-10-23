import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/repositories/config_repository.dart';
import 'package:shaddai/features/admin/presentation/admin_price_item_form_view.dart';
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

List<Override> _adminOverrides() => [
  adminAppointmentsProvider.overrideWith((ref) => Stream.value(const [])),
  configRepositoryProvider.overrideWithValue(_UnusedConfigRepository()),
];

Future<void> _pumpMobile(
  WidgetTester tester,
  FakePriceListRepository repository, {
  String location = '/admin/services',
  double width = 412,
  String language = 'es',
}) => pumpMobileApp(
  tester,
  location: location,
  user: testAdmin,
  width: width,
  stored: {'language': language},
  priceListRepository: repository,
  overrides: _adminOverrides(),
);

Finder _field(String label) => find.widgetWithText(TextField, label);

Future<void> _enter(WidgetTester tester, String label, String text) async {
  await tester.ensureVisible(_field(label));
  await tester.enterText(_field(label), text);
  await tester.pump();
}

Future<void> _tapFinder(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.tap(finder);
  await settleWeb(tester);
}

Future<void> _tapText(WidgetTester tester, String text) =>
    _tapFinder(tester, find.text(text).last);

String _fieldText(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

Future<void> _openEdit(WidgetTester tester, String itemId) => _tapFinder(
  tester,
  find.descendant(
    of: find.byKey(ValueKey('admin-services-row-$itemId')),
    matching: find.byTooltip('Editar'),
  ),
);

Future<void> _add(WidgetTester tester, String kind, String categoryId) =>
    _tapFinder(
      tester,
      find.byKey(ValueKey('admin-services-add-$kind-$categoryId')),
    );

PriceCategoryModel _category(PriceListModel list, String id) =>
    list.categories.firstWhere((c) => c.id == id);

void main() {
  testWidgets('servicio nuevo: todos los campos, "desde", al final de su '
      'categoría (RF-21, RF-34)', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpMobile(tester, repository);

    await _add(tester, 'service', 'hands');
    expect(find.byType(AdminPriceItemFormView), findsOneWidget);
    expect(find.text('Nuevo servicio'), findsOneWidget);

    await _enter(tester, 'Nombre en español', 'Francesa');
    await _enter(tester, 'Nombre en portugués', 'Francesinha');
    await _enter(tester, 'Descripción en español', 'Punta blanca.');
    await _enter(tester, 'Descripción en portugués', 'Ponta branca.');
    await _enter(tester, 'Grupo en español', 'Diseños');
    await _enter(tester, 'Grupo en portugués', 'Desenhos');
    await _enter(tester, 'Precio (R\$)', ' 45,5 ');
    await _enter(tester, 'Duración (minutos)', '50');
    await _tapFinder(tester, find.text('Precio «desde»'));
    await _tapText(tester, 'GUARDAR');

    final created = _category(repository.stored!, 'hands').items.last;
    expect(created.kind, PriceItemKind.service);
    expect(created.name.pt, 'Francesinha');
    expect(created.description.es, 'Punta blanca.');
    expect(created.group.pt, 'Desenhos');
    expect(created.priceCents, 4550);
    expect(created.priceFrom, isTrue);
    expect(created.durationMinutes, 50);
    expect(created.visible, isTrue);

    expect(find.byType(AdminServicesView), findsOneWidget);
    expect(find.text('Cambios guardados'), findsOneWidget);
  });

  testWidgets('editar un servicio trae sus datos; cambiar de categoría lo '
      'pone al final de la nueva (RF-32)', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpMobile(tester, repository);

    await _openEdit(tester, 'gel-maintenance');
    expect(find.text('Editar servicio'), findsOneWidget);
    expect(_fieldText(tester, 'Nombre en español'), 'Mantenimiento');
    expect(_fieldText(tester, 'Grupo en portugués'), 'Manutenção');
    expect(_fieldText(tester, 'Precio (R\$)'), '110');
    expect(_fieldText(tester, 'Duración (minutos)'), '90');
    expect(
      tester.widget<CheckboxListTile>(find.byType(CheckboxListTile)).value,
      isTrue,
    );

    await _tapFinder(tester, find.text('Manos').last);
    await _tapText(tester, 'Pies');
    await _enter(tester, 'Precio (R\$)', '120,90');
    await _tapText(tester, 'GUARDAR');

    final list = repository.stored!;
    expect(
      _category(list, 'hands').items.map((i) => i.id),
      isNot(contains('gel-maintenance')),
    );
    final moved = _category(list, 'feet').items;
    expect(moved.map((i) => i.id), ['pedicure', 'gel-maintenance']);
    expect(moved.last.priceCents, 12090);
    expect(moved.last.priceFrom, isTrue);
  });

  testWidgets('adicional: sin descripción, grupo, duración ni "desde"; '
      'precio 0 válido', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpMobile(tester, repository);

    await _add(tester, 'addon', 'hands');
    expect(find.text('Nuevo adicional'), findsOneWidget);
    for (final label in [
      'Descripción en español',
      'Grupo en español',
      'Duración (minutos)',
    ]) {
      expect(_field(label), findsNothing, reason: label);
    }
    expect(find.text('Precio «desde»'), findsNothing);

    await _enter(tester, 'Nombre en español', 'Brillo');
    await _enter(tester, 'Nombre en portugués', 'Brilho');
    await _enter(tester, 'Precio (R\$)', '0');
    await _tapText(tester, 'GUARDAR');

    final created = _category(repository.stored!, 'hands').items.last;
    expect(created.kind, PriceItemKind.addon);
    expect(created.name.es, 'Brillo');
    expect(created.priceCents, 0);

    await _openEdit(tester, 'chrome');
    expect(find.text('Editar adicional'), findsOneWidget);
    expect(_fieldText(tester, 'Precio (R\$)'), '15');
  });

  testWidgets('errores de precio y de duración: no se guarda (RF-24, '
      'RF-25)', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpMobile(tester, repository);

    await _add(tester, 'service', 'hands');
    await _enter(tester, 'Nombre en español', 'Francesa');
    await _enter(tester, 'Nombre en portugués', 'Francesinha');
    await _enter(tester, 'Precio (R\$)', '30,505');
    await _enter(tester, 'Duración (minutos)', '481');
    await _tapText(tester, 'GUARDAR');

    expect(repository.updateCalls, 0);
    expect(find.text('Precio no válido (hasta 2 decimales)'), findsOneWidget);
    expect(find.text('Entre 5 y 480 minutos'), findsOneWidget);
  });

  testWidgets('si falla, se conserva lo escrito y se puede reintentar '
      '(RF-33)', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList())
      ..failNext = Exception('unavailable: detalle técnico');
    await _pumpMobile(tester, repository);

    await _openEdit(tester, 'spa');
    await _enter(tester, 'Precio (R\$)', '60');
    await _tapText(tester, 'GUARDAR');

    expect(find.text('No se pudieron guardar los cambios.'), findsOneWidget);
    expect(find.textContaining('detalle técnico'), findsNothing);
    expect(find.byType(AdminPriceItemFormView), findsOneWidget);
    expect(_fieldText(tester, 'Precio (R\$)'), '60');

    await tester.tap(find.text('REINTENTAR'));
    await settleWeb(tester);

    expect(_category(repository.stored!, 'hands').items.first.priceCents, 6000);
    expect(find.byType(AdminServicesView), findsOneWidget);
  });

  testWidgets('"Cancelar" vuelve sin guardar', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpMobile(tester, repository);

    await _openEdit(tester, 'spa');
    await _enter(tester, 'Precio (R\$)', '1');
    await _tapText(tester, 'CANCELAR');

    expect(repository.updateCalls, 0);
    expect(find.byType(AdminServicesView), findsOneWidget);
  });

  for (final language in ['es', 'pt']) {
    testWidgets('con el texto al 200 % a 320 px, en $language, sin desbordes '
        '(RNF-4)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpMobile(
        tester,
        FakePriceListRepository(stored: testPriceList()),
        location: '/admin/services/category/hands/item/gel-maintenance',
        width: 320,
        language: language,
      );

      expect(find.byType(AdminPriceItemFormView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('en Web, la dirección abre el formulario y al guardar vuelve '
      'a la gestión', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await pumpWebApp(
      tester,
      location: '/admin/services/category/hands/item/new?kind=addon',
      user: testAdmin,
      priceListRepository: repository,
      overrides: _adminOverrides(),
    );

    expect(find.text('Nuevo adicional'), findsOneWidget);
    await _enter(tester, 'Nombre en español', 'Brillo');
    await _enter(tester, 'Nombre en portugués', 'Brilho');
    await _enter(tester, 'Precio (R\$)', '10');
    await _tapText(tester, 'GUARDAR');

    expect(
      _category(repository.stored!, 'hands').items.last.kind,
      PriceItemKind.addon,
    );
    expect(webLocation(tester).path, '/admin/services');
  });
}
