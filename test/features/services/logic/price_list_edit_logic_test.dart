import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/services/logic/price_list_edit_logic.dart';

BilingualText text(String es) => BilingualText(es: es, pt: es);

PriceItemModel service(String id, {int priceCents = 3000}) => PriceItemModel(
  id: id,
  kind: PriceItemKind.service,
  name: text('Servicio $id'),
  priceCents: priceCents,
);

PriceItemModel addon(String id) => PriceItemModel(
  id: id,
  kind: PriceItemKind.addon,
  name: text('Adicional $id'),
  priceCents: 1500,
);

PriceCategoryModel category(String id, List<PriceItemModel> items) =>
    PriceCategoryModel(id: id, name: text('Categoría $id'), items: items);

ComboModel combo(String id) =>
    ComboModel(id: id, name: text('Combo $id'), priceCents: 9000);

/// Dos categorías con elementos, una vacía y dos combos.
PriceListModel sample() => PriceListModel(
  categories: [
    category('manos', [service('m1'), service('m2'), addon('m3')]),
    category('pies', [service('p1')]),
    category('vacia', const []),
  ],
  combos: [combo('c1'), combo('c2')],
  extra: const {'updatedAt': 'x'},
);

List<String> categoryIds(PriceListModel list) => [
  for (final c in list.categories) c.id,
];

List<String> itemIds(PriceListModel list, String categoryId) => [
  for (final item
      in list.categories.firstWhere((c) => c.id == categoryId).items)
    item.id,
];

List<String> comboIds(PriceListModel list) => [
  for (final c in list.combos) c.id,
];

PriceItemModel item(PriceListModel list, String id) =>
    list.categories.expand((c) => c.items).firstWhere((i) => i.id == id);

void main() {
  group('crear y editar (RF-32)', () {
    test('una categoría nueva va al final', () {
      final result = upsertCategory(
        sample(),
        category('cejas', const []),
        isNew: true,
      );
      expect(categoryIds(result), ['manos', 'pies', 'vacia', 'cejas']);
    });

    test('al editar una categoría, se queda en su sitio y conserva sus '
        'elementos', () {
      final edited = PriceCategoryModel(
        id: 'pies',
        name: text('Pies y spa'),
        note: text('Nota'),
      );
      final result = upsertCategory(sample(), edited, isNew: false);

      expect(categoryIds(result), ['manos', 'pies', 'vacia']);
      final pies = result.categories[1];
      expect(pies.name.es, 'Pies y spa');
      expect(pies.note.es, 'Nota');
      expect(pies.items.map((i) => i.id), ['p1']);
    });

    test('un servicio o adicional nuevo va al final de su categoría', () {
      final withService = upsertItem(
        sample(),
        'manos',
        service('m4'),
        isNew: true,
      );
      expect(itemIds(withService, 'manos'), ['m1', 'm2', 'm3', 'm4']);

      final withAddon = upsertItem(
        withService,
        'vacia',
        addon('v1'),
        isNew: true,
      );
      expect(itemIds(withAddon, 'vacia'), ['v1']);
    });

    test('al editar un servicio en su categoría, se queda en su sitio', () {
      final result = upsertItem(
        sample(),
        'manos',
        service('m2', priceCents: 4550),
        isNew: false,
      );
      expect(itemIds(result, 'manos'), ['m1', 'm2', 'm3']);
      expect(item(result, 'm2').priceCents, 4550);
    });

    test('al cambiar de categoría, sale de la vieja y va al final de la '
        'nueva', () {
      final result = upsertItem(
        sample(),
        'pies',
        service('m1', priceCents: 5000),
        isNew: false,
      );
      expect(itemIds(result, 'manos'), ['m2', 'm3']);
      expect(itemIds(result, 'pies'), ['p1', 'm1']);
      expect(item(result, 'm1').priceCents, 5000);
    });

    test('un combo nuevo va al final; uno editado se queda en su sitio', () {
      final added = upsertCombo(sample(), combo('c3'), isNew: true);
      expect(comboIds(added), ['c1', 'c2', 'c3']);

      final edited = upsertCombo(
        sample(),
        ComboModel(id: 'c1', name: text('Nuevo'), priceCents: 1),
        isNew: false,
      );
      expect(comboIds(edited), ['c1', 'c2']);
      expect(edited.combos.first.name.es, 'Nuevo');
    });

    test('los cambios no tocan la lista original ni pierden sus campos '
        'extra', () {
      final original = sample();
      final result = upsertCombo(original, combo('c3'), isNew: true);
      expect(comboIds(original), ['c1', 'c2']);
      expect(result.extra, {'updatedAt': 'x'});
    });
  });

  group('subir y bajar (RF-26)', () {
    test('las categorías intercambian su sitio con la vecina', () {
      expect(categoryIds(moveCategory(sample(), 'pies', -1)), [
        'pies',
        'manos',
        'vacia',
      ]);
      expect(categoryIds(moveCategory(sample(), 'pies', 1)), [
        'manos',
        'vacia',
        'pies',
      ]);
    });

    test('los servicios y adicionales se mueven dentro de su categoría', () {
      expect(itemIds(moveItem(sample(), 'm3', -1), 'manos'), [
        'm1',
        'm3',
        'm2',
      ]);
      expect(itemIds(moveItem(sample(), 'm1', 1), 'manos'), ['m2', 'm1', 'm3']);
    });

    test('los combos también', () {
      expect(comboIds(moveCombo(sample(), 'c2', -1)), ['c2', 'c1']);
    });

    test('en los extremos no hace nada', () {
      expect(categoryIds(moveCategory(sample(), 'manos', -1)), [
        'manos',
        'pies',
        'vacia',
      ]);
      expect(categoryIds(moveCategory(sample(), 'vacia', 1)), [
        'manos',
        'pies',
        'vacia',
      ]);
      expect(itemIds(moveItem(sample(), 'm1', -1), 'manos'), [
        'm1',
        'm2',
        'm3',
      ]);
      expect(itemIds(moveItem(sample(), 'p1', 1), 'pies'), ['p1']);
      expect(comboIds(moveCombo(sample(), 'c2', 1)), ['c1', 'c2']);
    });
  });

  group('ocultar y mostrar (RF-27)', () {
    test('ocultar una categoría no toca sus elementos ni sus datos', () {
      final hidden = setCategoryVisible(sample(), 'manos', false);
      final manos = hidden.categories.first;
      expect(manos.visible, isFalse);
      expect(manos.name.es, 'Categoría manos');
      expect(manos.items.map((i) => i.id), ['m1', 'm2', 'm3']);

      final shown = setCategoryVisible(hidden, 'manos', true);
      expect(shown.categories.first.visible, isTrue);
    });

    test('ocultar un servicio o un combo conserva sus datos', () {
      final hidden = setItemVisible(sample(), 'm2', false);
      expect(item(hidden, 'm2').visible, isFalse);
      expect(item(hidden, 'm2').priceCents, 3000);
      expect(itemIds(hidden, 'manos'), ['m1', 'm2', 'm3']);
      expect(item(setItemVisible(hidden, 'm2', true), 'm2').visible, isTrue);

      final hiddenCombo = setComboVisible(sample(), 'c1', false);
      expect(hiddenCombo.combos.first.visible, isFalse);
      expect(hiddenCombo.combos.first.priceCents, 9000);
    });
  });

  group('borrar (RF-29 a RF-31)', () {
    test('borra un servicio, un adicional o un combo', () {
      expect(itemIds(deleteItem(sample(), 'm2'), 'manos'), ['m1', 'm3']);
      expect(itemIds(deleteItem(sample(), 'm3'), 'manos'), ['m1', 'm2']);
      expect(comboIds(deleteCombo(sample(), 'c1')), ['c2']);
    });

    test('canDeleteCategory dice si la categoría tiene elementos', () {
      expect(
        canDeleteCategory(sample(), 'manos'),
        CategoryDeleteCheck.hasItems,
      );
      expect(canDeleteCategory(sample(), 'vacia'), CategoryDeleteCheck.empty);
    });

    test('una categoría vacía se borra', () {
      expect(categoryIds(deleteCategory(sample(), 'vacia')), ['manos', 'pies']);
    });

    test('una categoría con elementos no se borra', () {
      expect(
        () => deleteCategory(sample(), 'pies'),
        throwsA(isA<CategoryNotEmpty>()),
      );
    });
  });

  group('un id que ya no existe (otra admin lo borró)', () {
    test('lanza ItemGone', () {
      final list = sample();
      final gone = throwsA(isA<ItemGone>());

      expect(
        () => upsertCategory(list, category('x', const []), isNew: false),
        gone,
      );
      expect(() => upsertItem(list, 'manos', service('x'), isNew: false), gone);
      expect(() => upsertItem(list, 'x', service('m1'), isNew: false), gone);
      expect(() => upsertItem(list, 'x', service('n'), isNew: true), gone);
      expect(() => upsertCombo(list, combo('x'), isNew: false), gone);
      expect(() => moveCategory(list, 'x', 1), gone);
      expect(() => moveItem(list, 'x', 1), gone);
      expect(() => moveCombo(list, 'x', 1), gone);
      expect(() => setCategoryVisible(list, 'x', false), gone);
      expect(() => setItemVisible(list, 'x', false), gone);
      expect(() => setComboVisible(list, 'x', false), gone);
      expect(() => deleteItem(list, 'x'), gone);
      expect(() => deleteCombo(list, 'x'), gone);
      expect(() => canDeleteCategory(list, 'x'), gone);
      expect(() => deleteCategory(list, 'x'), gone);
    });
  });
}
