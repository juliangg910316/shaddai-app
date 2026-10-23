import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/repositories/config_repository.dart';
import 'package:shaddai/features/admin/presentation/admin_category_form_view.dart';
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

Future<void> _tapText(WidgetTester tester, String text) async {
  await tester.ensureVisible(find.text(text).last);
  await tester.tap(find.text(text).last);
  await settleWeb(tester);
}

String _fieldText(WidgetTester tester, String label) =>
    tester.widget<TextField>(_field(label)).controller!.text;

Future<void> _openEdit(WidgetTester tester, String categoryId) async {
  final edit = find.descendant(
    of: find.byKey(ValueKey('admin-services-row-$categoryId')),
    matching: find.byTooltip('Editar'),
  );
  await tester.ensureVisible(edit);
  await tester.tap(edit);
  await settleWeb(tester);
}

void main() {
  testWidgets('crear: "Añadir categoría" abre el formulario y la nueva va '
      'al final (RF-21, RF-34)', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpMobile(tester, repository);

    await _tapText(tester, 'AÑADIR CATEGORÍA');
    expect(find.byType(AdminCategoryFormView), findsOneWidget);
    expect(find.text('Nueva categoría'), findsOneWidget);

    await _enter(tester, 'Nombre en español', ' Cejas ');
    await _enter(tester, 'Nombre en portugués', 'Sobrancelhas');
    await _enter(tester, 'Subtítulo en español', 'Diseño');
    await _enter(tester, 'Subtítulo en portugués', 'Design');
    await _enter(tester, 'Nota en español', 'Con cita previa.');
    await _enter(tester, 'Nota en portugués', 'Com hora marcada.');
    await _tapText(tester, 'GUARDAR');

    final categories = repository.stored!.categories;
    expect(categories, hasLength(3));
    final created = categories.last;
    expect(created.id, isNotEmpty);
    expect(created.name.es, 'Cejas');
    expect(created.name.pt, 'Sobrancelhas');
    expect(created.subtitle.pt, 'Design');
    expect(created.note.es, 'Con cita previa.');
    expect(created.visible, isTrue);
    expect(created.items, isEmpty);

    expect(find.byType(AdminCategoryFormView), findsNothing);
    expect(find.byType(AdminServicesView), findsOneWidget);
    expect(find.text('Cambios guardados'), findsOneWidget);
  });

  testWidgets('editar: el formulario trae los textos y se guarda en su sitio, '
      'con sus elementos y oculta como estaba', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpMobile(tester, repository);

    await _openEdit(tester, 'hands');
    expect(find.text('Editar categoría'), findsOneWidget);
    expect(_fieldText(tester, 'Nombre en español'), 'Manos');
    expect(_fieldText(tester, 'Nombre en portugués'), 'Mãos');
    expect(_fieldText(tester, 'Subtítulo en español'), 'Cuidado y elegancia');
    expect(_fieldText(tester, 'Nota en portugués'), 'Inclui cutículas.');

    await _enter(tester, 'Nombre en español', 'Manos y uñas');
    await _tapText(tester, 'GUARDAR');

    final hands = repository.stored!.categories.first;
    expect(hands.id, 'hands');
    expect(hands.name.es, 'Manos y uñas');
    expect(hands.items, hasLength(4));
    expect(find.byType(AdminServicesView), findsOneWidget);

    await _openEdit(tester, 'feet');
    await _enter(tester, 'Nombre en portugués', 'Pés e spa');
    await _tapText(tester, 'GUARDAR');

    final feet = repository.stored!.categories[1];
    expect(feet.name.pt, 'Pés e spa');
    expect(feet.visible, isFalse);
  });

  testWidgets('los errores se marcan por campo y no se guarda (RF-22, '
      'RF-23)', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpMobile(tester, repository);

    await _tapText(tester, 'AÑADIR CATEGORÍA');
    await _enter(tester, 'Nombre en español', 'Cejas');
    await _enter(tester, 'Subtítulo en español', 'Diseño');
    await _enter(tester, 'Nota en español', 'a' * 601);
    await _enter(tester, 'Nota en portugués', 'Nota');
    await _tapText(tester, 'GUARDAR');

    expect(repository.updateCalls, 0);
    expect(find.byType(AdminCategoryFormView), findsOneWidget);
    expect(find.text('Obligatorio'), findsOneWidget);
    expect(find.text('Escríbelo también en este idioma'), findsOneWidget);
    expect(find.text('Máximo 600 caracteres'), findsOneWidget);
  });

  testWidgets('si falla, se conserva lo escrito y se puede reintentar '
      '(RF-33)', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList())
      ..failNext = Exception('unavailable: detalle técnico');
    await _pumpMobile(tester, repository);

    await _tapText(tester, 'AÑADIR CATEGORÍA');
    await _enter(tester, 'Nombre en español', 'Cejas');
    await _enter(tester, 'Nombre en portugués', 'Sobrancelhas');
    await _tapText(tester, 'GUARDAR');

    expect(find.text('No se pudieron guardar los cambios.'), findsOneWidget);
    expect(find.textContaining('detalle técnico'), findsNothing);
    expect(find.byType(AdminCategoryFormView), findsOneWidget);
    expect(_fieldText(tester, 'Nombre en español'), 'Cejas');
    expect(repository.stored!.categories, hasLength(2));

    await tester.tap(find.text('REINTENTAR'));
    await settleWeb(tester);

    expect(repository.stored!.categories, hasLength(3));
    expect(find.byType(AdminServicesView), findsOneWidget);
  });

  testWidgets('"Cancelar" vuelve sin guardar', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpMobile(tester, repository);

    await _openEdit(tester, 'hands');
    await _enter(tester, 'Nombre en español', 'Otra cosa');
    await _tapText(tester, 'CANCELAR');

    expect(repository.updateCalls, 0);
    expect(repository.stored!.categories.first.name.es, 'Manos');
    expect(find.byType(AdminServicesView), findsOneWidget);
  });

  testWidgets('una categoría que ya no existe muestra su aviso', (
    tester,
  ) async {
    await _pumpMobile(
      tester,
      FakePriceListRepository(stored: testPriceList()),
      location: '/admin/services/category/borrada',
    );

    expect(find.text('Este elemento ya no existe.'), findsOneWidget);
    expect(_field('Nombre en español'), findsNothing);
  });

  for (final language in ['es', 'pt']) {
    testWidgets('con el texto al 200 % a 320 px, en $language, sin desbordes '
        '(RNF-4)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpMobile(
        tester,
        FakePriceListRepository(stored: testPriceList()),
        location: '/admin/services/category/hands',
        width: 320,
        language: language,
      );

      expect(find.byType(AdminCategoryFormView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('en Web, la dirección abre el formulario y al guardar vuelve '
      'a la gestión', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await pumpWebApp(
      tester,
      location: '/admin/services/category/hands',
      user: testAdmin,
      priceListRepository: repository,
      overrides: _adminOverrides(),
    );

    expect(find.byType(AdminCategoryFormView), findsOneWidget);
    await _enter(tester, 'Nombre en español', 'Manos y uñas');
    await _tapText(tester, 'GUARDAR');

    expect(repository.stored!.categories.first.name.es, 'Manos y uñas');
    expect(webLocation(tester).path, '/admin/services');
    expect(find.byType(AdminServicesView), findsOneWidget);
  });
}
