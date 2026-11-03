/// Lo que se puede reservar de la lista de precios, el precio total y la
/// copia de lo reservado, sin Flutter ni Firebase (spec 005, plan § 4.4).
library;

import '../../../data/models/booked_service_model.dart';
import '../../../data/models/price_list_model.dart';

/// Referencia a un servicio o combo de la lista de precios.
class BookableRef {
  const BookableRef(this.kind, this.id);

  final BookedKind kind;
  final String id;

  @override
  bool operator ==(Object other) =>
      other is BookableRef && other.kind == kind && other.id == id;

  @override
  int get hashCode => Object.hash(kind, id);

  @override
  String toString() => 'BookableRef(${kind.name}, $id)';
}

/// Una categoría tal como se ofrece en la reserva: sus servicios y sus
/// adicionales visibles, en orden.
class BookableCategory {
  const BookableCategory({
    required this.category,
    required this.services,
    required this.addons,
  });

  final PriceCategoryModel category;
  final List<PriceItemModel> services;
  final List<PriceItemModel> addons;
}

/// Todo lo que se puede reservar.
class BookableCatalog {
  const BookableCatalog({required this.categories, required this.combos});

  final List<BookableCategory> categories;
  final List<ComboModel> combos;

  bool get isEmpty => categories.isEmpty && combos.isEmpty;
}

/// Un servicio o combo que se puede reservar.
sealed class Bookable {
  const Bookable();

  BookableRef get ref;
  BilingualText get name;
  int get priceCents;
  bool get priceFrom;
  int get durationMinutes;
}

class BookableService extends Bookable {
  const BookableService({required this.item, required this.category});

  final PriceItemModel item;
  final PriceCategoryModel category;

  @override
  BookableRef get ref => BookableRef(BookedKind.service, item.id);
  @override
  BilingualText get name => item.name;
  @override
  int get priceCents => item.priceCents;
  @override
  bool get priceFrom => item.priceFrom;
  @override
  int get durationMinutes => item.durationMinutes;
}

class BookableCombo extends Bookable {
  const BookableCombo(this.combo);

  final ComboModel combo;

  @override
  BookableRef get ref => BookableRef(BookedKind.combo, combo.id);
  @override
  BilingualText get name => combo.name;
  @override
  int get priceCents => combo.priceCents;
  @override
  bool get priceFrom => false;
  @override
  int get durationMinutes => combo.durationMinutes;
}

/// Lo que se ofrece en la reserva (RF-10, RF-11): las categorías visibles con
/// algún servicio visible, con sus servicios y adicionales visibles, y los
/// combos visibles. Los adicionales sueltos no se reservan.
BookableCatalog bookableCatalog(PriceListModel list) {
  final categories = <BookableCategory>[];
  for (final category in list.categories) {
    if (!category.visible) continue;
    final visible = category.items.where((item) => item.visible);
    final services = visible.where((item) => item.isService).toList();
    if (services.isEmpty) continue;
    categories.add(
      BookableCategory(
        category: category,
        services: services,
        addons: visible.where((item) => !item.isService).toList(),
      ),
    );
  }
  return BookableCatalog(
    categories: categories,
    combos: list.combos.where((combo) => combo.visible).toList(),
  );
}

/// El servicio o combo de [ref] si se puede reservar; si no, `null` (RF-17).
Bookable? findBookable(BookableCatalog catalog, BookableRef ref) {
  switch (ref.kind) {
    case BookedKind.service:
      for (final entry in catalog.categories) {
        for (final item in entry.services) {
          if (item.id == ref.id) {
            return BookableService(item: item, category: entry.category);
          }
        }
      }
    case BookedKind.combo:
      for (final combo in catalog.combos) {
        if (combo.id == ref.id) return BookableCombo(combo);
      }
  }
  return null;
}

/// Los adicionales que se pueden añadir a [ref]: los visibles de su
/// categoría (RF-18). Un combo no tiene categoría ni adicionales (RF-19).
List<PriceItemModel> availableAddons(BookableCatalog catalog, BookableRef ref) {
  if (findBookable(catalog, ref) case BookableService(:final category)) {
    for (final entry in catalog.categories) {
      if (entry.category.id == category.id) return entry.addons;
    }
  }
  return const [];
}

/// El precio de [bookable] más el de [addons], en céntimos, y si es "desde"
/// (RF-22).
({int cents, bool from}) totalPrice(
  Bookable bookable,
  List<PriceItemModel> addons,
) => (
  cents: addons.fold(
    bookable.priceCents,
    (total, addon) => total + addon.priceCents,
  ),
  from: bookable.priceFrom,
);

/// La copia de lo reservado que se guarda en el turno (RF-27).
BookedServiceModel snapshotOf(Bookable bookable, List<PriceItemModel> addons) =>
    BookedServiceModel(
      kind: bookable.ref.kind,
      id: bookable.ref.id,
      name: bookable.name,
      priceCents: bookable.priceCents,
      priceFrom: bookable.priceFrom,
      durationMinutes: bookable.durationMinutes,
      addons: [
        for (final addon in addons)
          BookedAddonModel(
            id: addon.id,
            name: addon.name,
            priceCents: addon.priceCents,
          ),
      ],
    );
