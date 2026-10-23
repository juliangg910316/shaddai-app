import 'package:flutter/material.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/repositories/config_repository.dart';
import 'package:shaddai/features/admin/presentation/admin_combo_form_view.dart';
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

Future<void> _openEdit(WidgetTester tester, String comboId) => _tapFinder(
  tester,
  find.descendant(
    of: find.byKey(ValueKey('admin-services-row-$comboId')),
    matching: find.byTooltip('Editar'),
  ),
);

void main() {
  testWidgets('crear: "Añadir combo" abre el formulario y el nuevo va al '
      'final (RF-21, RF-34)', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpMobile(tester, repository);

    await _tapText(tester, 'AÑADIR COMBO');
    expect(find.byType(AdminComboFormView), findsOneWidget);
    expect(find.text('Nuevo combo'), findsOneWidget);

    await _enter(tester, 'Nombre en español', 'Spa completo');
    await _enter(tester, 'Nombre en portugués', 'Spa completo');
    await _enter(tester, 'Descripción en español', 'Manos y pies.');
    await _enter(tester, 'Descripción en portugués', 'Mãos e pés.');
    await _enter(tester, 'Precio (R\$)', '99,90');
    await _enter(tester, 'Duración (minutos)', '120');
    await _tapText(tester, 'GUARDAR');

    final combos = repository.stored!.combos;
    expect(combos.map((c) => c.id).take(2), ['full-gel', 'hidden-combo']);
    final created = combos.last;
    expect(combos, hasLength(3));
    expect(created.name.es, 'Spa completo');
    expect(created.description.pt, 'Mãos e pés.');
    expect(created.priceCents, 9990);
    expect(created.durationMinutes, 120);
    expect(created.visible, isTrue);

    expect(find.byType(AdminServicesView), findsOneWidget);
    expect(find.text('Cambios guardados'), findsOneWidget);
  });

  testWidgets('editar: trae sus datos y se guarda en su sitio, oculto como '
      'estaba', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpMobile(tester, repository);

    await _openEdit(tester, 'full-gel');
    expect(find.text('Editar combo'), findsOneWidget);
    expect(_fieldText(tester, 'Nombre en español'), 'Gel Completo');
    expect(_fieldText(tester, 'Descripción en portugués'), 'Mãos + pés');
    expect(_fieldText(tester, 'Precio (R\$)'), '120');
    expect(_fieldText(tester, 'Duración (minutos)'), '150');

    await _enter(tester, 'Precio (R\$)', '130');
    await _tapText(tester, 'GUARDAR');
    expect(repository.stored!.combos.first.priceCents, 13000);

    await _openEdit(tester, 'hidden-combo');
    await _enter(tester, 'Nombre en portugués', 'Combo escondido');
    await _tapText(tester, 'GUARDAR');

    final hidden = repository.stored!.combos.last;
    expect(hidden.id, 'hidden-combo');
    expect(hidden.name.pt, 'Combo escondido');
    expect(hidden.visible, isFalse);
  });

  testWidgets('los errores se marcan por campo y no se guarda (RF-22 a '
      'RF-25)', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpMobile(tester, repository);

    await _tapText(tester, 'AÑADIR COMBO');
    await _enter(tester, 'Nombre en español', 'Spa completo');
    await _enter(tester, 'Descripción en portugués', 'Mãos e pés.');
    await _enter(tester, 'Precio (R\$)', '-5');
    await _enter(tester, 'Duración (minutos)', '4');
    await _tapText(tester, 'GUARDAR');

    expect(repository.updateCalls, 0);
    expect(find.byType(AdminComboFormView), findsOneWidget);
    expect(find.text('Obligatorio'), findsOneWidget);
    expect(find.text('Escríbelo también en este idioma'), findsOneWidget);
    expect(find.text('Precio no válido (hasta 2 decimales)'), findsOneWidget);
    expect(find.text('Entre 5 y 480 minutos'), findsOneWidget);
  });

  testWidgets('si falla, se conserva lo escrito y se puede reintentar '
      '(RF-33)', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList())
      ..failNext = Exception('unavailable: detalle técnico');
    await _pumpMobile(tester, repository);

    await _openEdit(tester, 'full-gel');
    await _enter(tester, 'Duración (minutos)', '160');
    await _tapText(tester, 'GUARDAR');

    expect(find.text('No se pudieron guardar los cambios.'), findsOneWidget);
    expect(find.textContaining('detalle técnico'), findsNothing);
    expect(find.byType(AdminComboFormView), findsOneWidget);
    expect(_fieldText(tester, 'Duración (minutos)'), '160');

    await tester.tap(find.text('REINTENTAR'));
    await settleWeb(tester);

    expect(repository.stored!.combos.first.durationMinutes, 160);
    expect(find.byType(AdminServicesView), findsOneWidget);
  });

  testWidgets('"Cancelar" vuelve sin guardar', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await _pumpMobile(tester, repository);

    await _openEdit(tester, 'full-gel');
    await _enter(tester, 'Precio (R\$)', '1');
    await _tapText(tester, 'CANCELAR');

    expect(repository.updateCalls, 0);
    expect(find.byType(AdminServicesView), findsOneWidget);
  });

  testWidgets('un combo que ya no existe muestra su aviso', (tester) async {
    await _pumpMobile(
      tester,
      FakePriceListRepository(stored: testPriceList()),
      location: '/admin/services/combo/borrado',
    );

    expect(find.text('Este elemento ya no existe.'), findsOneWidget);
  });

  for (final language in ['es', 'pt']) {
    testWidgets('con el texto al 200 % a 320 px, en $language, sin desbordes '
        '(RNF-4)', (tester) async {
      tester.platformDispatcher.textScaleFactorTestValue = 2;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await _pumpMobile(
        tester,
        FakePriceListRepository(stored: testPriceList()),
        location: '/admin/services/combo/full-gel',
        width: 320,
        language: language,
      );

      expect(find.byType(AdminComboFormView), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('en Web, la dirección abre el formulario y al guardar vuelve '
      'a la gestión', (tester) async {
    final repository = FakePriceListRepository(stored: testPriceList());
    await pumpWebApp(
      tester,
      location: '/admin/services/combo/full-gel',
      user: testAdmin,
      priceListRepository: repository,
      overrides: _adminOverrides(),
    );

    expect(find.byType(AdminComboFormView), findsOneWidget);
    await _enter(tester, 'Nombre en español', 'Gel total');
    await _tapText(tester, 'GUARDAR');

    expect(repository.stored!.combos.first.name.es, 'Gel total');
    expect(webLocation(tester).path, '/admin/services');
  });
}
