/// Lo que ve la clienta de la lista de precios, sin Flutter ni Firebase
/// (spec 004, plan § 4).
library;

import '../../../data/models/price_list_model.dart';

/// Estado de la lista de precios en pantalla.
sealed class PriceListState {
  const PriceListState();
}

/// Todavía no hay datos y aún pueden llegar (RF-7).
class PriceListLoading extends PriceListState {
  const PriceListLoading();
}

/// No se pudo cargar y no hay datos guardados en el dispositivo (RF-8).
class PriceListUnavailable extends PriceListState {
  const PriceListUnavailable();
}

/// Datos listos, del servidor o de la caché (RF-40). Una lista vacía da el
/// aviso de RF-10.
class PriceListReady extends PriceListState {
  const PriceListReady(this.list);

  final PriceListModel list;
}

/// Decide el estado a partir de la última lectura ([snapshot], `null` si aún
/// no hay ninguna) y de si pasó el tiempo límite de carga ([timedOut]).
///
/// Sin documento en la caché se sigue esperando: al abrir con conexión, la
/// caché vacía responde antes que el servidor (plan, D-4).
PriceListState resolvePriceListState({
  PriceListSnapshot? snapshot,
  bool timedOut = false,
}) {
  final list = snapshot?.list;
  if (list != null) return PriceListReady(list);
  if (snapshot != null && !snapshot.fromCache) {
    return const PriceListReady(PriceListModel());
  }
  return timedOut ? const PriceListUnavailable() : const PriceListLoading();
}

/// Servicios y adicionales seguidos con el mismo grupo. [group] vacío = sin
/// título.
class PriceBlock {
  const PriceBlock({required this.group, required this.items});

  final BilingualText group;
  final List<PriceItemModel> items;
}

/// Una categoría tal como se muestra: su número entre las mostradas ("01")
/// y sus líneas visibles, en bloques por grupo.
class PublicCategory {
  const PublicCategory({
    required this.category,
    required this.number,
    required this.blocks,
  });

  final PriceCategoryModel category;
  final String number;
  final List<PriceBlock> blocks;
}

/// La lista de precios que ve la clienta.
class PublicPriceList {
  const PublicPriceList({required this.categories, required this.combos});

  final List<PublicCategory> categories;
  final List<ComboModel> combos;

  /// Sin ninguna categoría que mostrar: aviso de WhatsApp (RF-10).
  bool get isEmpty => categories.isEmpty;
}

/// Lo visible de [list], con los grupos comparados en [languageCode]:
/// - categorías visibles con alguna línea visible (RF-1, RF-4, RF-28),
///   numeradas sin huecos;
/// - sus líneas visibles, en orden y en bloques por grupo;
/// - los combos visibles (RF-3, RF-11).
PublicPriceList visiblePriceList(PriceListModel list, String languageCode) {
  final categories = <PublicCategory>[];
  for (final category in list.categories) {
    if (!category.visible) continue;
    final items = category.items.where((item) => item.visible).toList();
    if (items.isEmpty) continue;
    categories.add(
      PublicCategory(
        category: category,
        number: (categories.length + 1).toString().padLeft(2, '0'),
        blocks: _blocks(items, languageCode),
      ),
    );
  }

  return PublicPriceList(
    categories: categories,
    combos: list.combos.where((combo) => combo.visible).toList(),
  );
}

List<PriceBlock> _blocks(List<PriceItemModel> items, String languageCode) {
  final blocks = <PriceBlock>[];
  for (final item in items) {
    final title = item.group.of(languageCode).trim();
    final last = blocks.isEmpty ? null : blocks.last;
    if (last != null && last.group.of(languageCode).trim() == title) {
      last.items.add(item);
    } else {
      blocks.add(PriceBlock(group: item.group, items: [item]));
    }
  }
  return blocks;
}

/// Qué se abre en un detalle.
enum DetailKind {
  service,
  combo;

  /// Segmento de la ruta (`/services/service/:id`), o `null` si no es válido.
  static DetailKind? fromPath(String? segment) {
    for (final kind in values) {
      if (kind.name == segment) return kind;
    }
    return null;
  }
}

/// Resultado de buscar un detalle.
sealed class DetailResult {
  const DetailResult();
}

/// Un servicio visible de una categoría visible (RF-14).
class ServiceDetail extends DetailResult {
  const ServiceDetail({required this.item, required this.category});

  final PriceItemModel item;
  final PriceCategoryModel category;
}

/// Un combo visible (RF-15).
class ComboDetail extends DetailResult {
  const ComboDetail(this.combo);

  final ComboModel combo;
}

/// Borrado, oculto, de una categoría oculta, inexistente o un adicional
/// (RF-17, RF-18).
class DetailNotAvailable extends DetailResult {
  const DetailNotAvailable();
}

/// Busca el detalle [kind] con [id] en [list]. Tampoco la admin ve los
/// ocultos aquí: no hay vista previa (plan, D-9).
DetailResult findDetail(PriceListModel list, DetailKind kind, String id) {
  switch (kind) {
    case DetailKind.service:
      for (final category in list.categories) {
        for (final item in category.items) {
          if (item.id != id) continue;
          if (!item.isService || !item.visible || !category.visible) {
            return const DetailNotAvailable();
          }
          return ServiceDetail(item: item, category: category);
        }
      }
    case DetailKind.combo:
      for (final combo in list.combos) {
        if (combo.id == id && combo.visible) return ComboDetail(combo);
      }
  }
  return const DetailNotAvailable();
}

/// Precio en reales: "R$ 30", "R$ 30,50", "R$ 1.200"; "+R$ 15" si es un
/// adicional. Con [from], el precio "desde" en el idioma activo
/// ("desde R$ 110"). Igual en español y en portugués.
String formatPrice(
  int cents, {
  bool addon = false,
  String Function(String price)? from,
}) {
  final reais = _thousands(cents ~/ 100);
  final rest = cents % 100;
  final amount = rest == 0
      ? reais
      : '$reais,${rest.toString().padLeft(2, '0')}';
  final price = '${addon ? '+' : ''}R\$ $amount';
  return from == null ? price : from(price);
}

String _thousands(int value) {
  final digits = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write('.');
    buffer.write(digits[i]);
  }
  return buffer.toString();
}

/// Duración: "45 min", "1 h", "1 h 30 min". Igual en español y en
/// portugués.
String formatDuration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final hours = minutes ~/ 60;
  final rest = minutes % 60;
  return rest == 0 ? '$hours h' : '$hours h $rest min';
}
