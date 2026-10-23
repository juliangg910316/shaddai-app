/// Cambios de la admin en la lista de precios, sin Flutter ni Firebase
/// (spec 004, plan § 4). Cada función recibe la lista y devuelve una nueva;
/// la original no cambia.
library;

import '../../../data/models/price_list_model.dart';

/// El elemento ya no está en la lista: otra admin lo borró.
class ItemGone implements Exception {
  const ItemGone(this.id);

  final String id;

  @override
  String toString() => 'ItemGone($id)';
}

/// Se intentó borrar una categoría con servicios o adicionales (RF-30).
class CategoryNotEmpty implements Exception {
  const CategoryNotEmpty(this.id);

  final String id;

  @override
  String toString() => 'CategoryNotEmpty($id)';
}

/// Si una categoría se puede borrar (RF-30, RF-31).
enum CategoryDeleteCheck { hasItems, empty }

/// Posición del elemento con [id] en [elements], o [ItemGone].
int _indexOf<T>(List<T> elements, String id, String Function(T) idOf) {
  final index = elements.indexWhere((e) => idOf(e) == id);
  if (index < 0) throw ItemGone(id);
  return index;
}

/// [elements] con el elemento en [index] sustituido por [element].
List<T> _replaced<T>(List<T> elements, int index, T element) => [
  ...elements.sublist(0, index),
  element,
  ...elements.sublist(index + 1),
];

/// [elements] con el elemento [id] intercambiado con su vecino ([offset] −1
/// o +1). En los extremos no cambia nada.
List<T> _moved<T>(
  List<T> elements,
  String id,
  int offset,
  String Function(T) idOf,
) {
  assert(offset == -1 || offset == 1);
  final index = _indexOf(elements, id, idOf);
  final target = index + offset;
  if (target < 0 || target >= elements.length) return elements;
  final result = [...elements];
  result[index] = elements[target];
  result[target] = elements[index];
  return result;
}

String _categoryId(PriceCategoryModel c) => c.id;
String _itemId(PriceItemModel i) => i.id;
String _comboId(ComboModel c) => c.id;

/// Posición de la categoría que contiene el elemento [itemId], o [ItemGone].
int _categoryIndexOfItem(PriceListModel list, String itemId) {
  final index = list.categories.indexWhere(
    (c) => c.items.any((i) => i.id == itemId),
  );
  if (index < 0) throw ItemGone(itemId);
  return index;
}

/// [list] con los elementos de la categoría que contiene [itemId] cambiados
/// por [change].
PriceListModel _changeItemsOf(
  PriceListModel list,
  String itemId,
  List<PriceItemModel> Function(List<PriceItemModel> items) change,
) {
  final index = _categoryIndexOfItem(list, itemId);
  final category = list.categories[index];
  return list.copyWith(
    categories: _replaced(
      list.categories,
      index,
      category.copyWith(items: change(category.items)),
    ),
  );
}

/// Crea ([isNew], al final) o edita en su sitio una categoría. Al editar se
/// conservan sus servicios y adicionales.
PriceListModel upsertCategory(
  PriceListModel list,
  PriceCategoryModel category, {
  required bool isNew,
}) {
  if (isNew) {
    return list.copyWith(categories: [...list.categories, category]);
  }
  final index = _indexOf(list.categories, category.id, _categoryId);
  return list.copyWith(
    categories: _replaced(
      list.categories,
      index,
      category.copyWith(items: list.categories[index].items),
    ),
  );
}

/// Crea ([isNew], al final de [categoryId]) o edita un servicio o adicional.
/// Si al editarlo cambia de categoría, va al final de la nueva (RF-32).
PriceListModel upsertItem(
  PriceListModel list,
  String categoryId,
  PriceItemModel item, {
  required bool isNew,
}) {
  final target = _indexOf(list.categories, categoryId, _categoryId);
  final source = isNew ? null : _categoryIndexOfItem(list, item.id);

  final categories = [...list.categories];
  if (source == target) {
    final items = categories[target].items;
    categories[target] = categories[target].copyWith(
      items: _replaced(items, _indexOf(items, item.id, _itemId), item),
    );
  } else {
    if (source != null) {
      categories[source] = categories[source].copyWith(
        items: [
          for (final i in categories[source].items)
            if (i.id != item.id) i,
        ],
      );
    }
    categories[target] = categories[target].copyWith(
      items: [...categories[target].items, item],
    );
  }
  return list.copyWith(categories: categories);
}

/// Crea ([isNew], al final) o edita en su sitio un combo.
PriceListModel upsertCombo(
  PriceListModel list,
  ComboModel combo, {
  required bool isNew,
}) {
  if (isNew) return list.copyWith(combos: [...list.combos, combo]);
  final index = _indexOf(list.combos, combo.id, _comboId);
  return list.copyWith(combos: _replaced(list.combos, index, combo));
}

/// Sube (−1) o baja (+1) una categoría (RF-26).
PriceListModel moveCategory(PriceListModel list, String id, int offset) =>
    list.copyWith(categories: _moved(list.categories, id, offset, _categoryId));

/// Sube (−1) o baja (+1) un servicio o adicional dentro de su categoría
/// (RF-26). No tiene en cuenta los grupos.
PriceListModel moveItem(PriceListModel list, String id, int offset) =>
    _changeItemsOf(list, id, (items) => _moved(items, id, offset, _itemId));

/// Sube (−1) o baja (+1) un combo (RF-26).
PriceListModel moveCombo(PriceListModel list, String id, int offset) =>
    list.copyWith(combos: _moved(list.combos, id, offset, _comboId));

/// Oculta o muestra una categoría sin tocar sus datos (RF-27).
PriceListModel setCategoryVisible(
  PriceListModel list,
  String id,
  bool visible,
) {
  final index = _indexOf(list.categories, id, _categoryId);
  return list.copyWith(
    categories: _replaced(
      list.categories,
      index,
      list.categories[index].copyWith(visible: visible),
    ),
  );
}

/// Oculta o muestra un servicio o adicional sin tocar sus datos (RF-27).
PriceListModel setItemVisible(PriceListModel list, String id, bool visible) =>
    _changeItemsOf(list, id, (items) {
      final index = _indexOf(items, id, _itemId);
      return _replaced(items, index, items[index].copyWith(visible: visible));
    });

/// Oculta o muestra un combo sin tocar sus datos (RF-27).
PriceListModel setComboVisible(PriceListModel list, String id, bool visible) {
  final index = _indexOf(list.combos, id, _comboId);
  return list.copyWith(
    combos: _replaced(
      list.combos,
      index,
      list.combos[index].copyWith(visible: visible),
    ),
  );
}

/// Borra un servicio o adicional (RF-29).
PriceListModel deleteItem(PriceListModel list, String id) => _changeItemsOf(
  list,
  id,
  (items) => [
    for (final i in items)
      if (i.id != id) i,
  ],
);

/// Borra un combo (RF-29).
PriceListModel deleteCombo(PriceListModel list, String id) {
  _indexOf(list.combos, id, _comboId);
  return list.copyWith(
    combos: [
      for (final c in list.combos)
        if (c.id != id) c,
    ],
  );
}

/// Si la categoría [id] se puede borrar (RF-30, RF-31).
CategoryDeleteCheck canDeleteCategory(PriceListModel list, String id) {
  final category = list.categories[_indexOf(list.categories, id, _categoryId)];
  return category.items.isEmpty
      ? CategoryDeleteCheck.empty
      : CategoryDeleteCheck.hasItems;
}

/// Borra una categoría vacía. Con elementos lanza [CategoryNotEmpty], aunque
/// la interfaz ya lo impide (RF-30).
PriceListModel deleteCategory(PriceListModel list, String id) {
  if (canDeleteCategory(list, id) == CategoryDeleteCheck.hasItems) {
    throw CategoryNotEmpty(id);
  }
  return list.copyWith(
    categories: [
      for (final c in list.categories)
        if (c.id != id) c,
    ],
  );
}
