/// Lo reservado en un turno: una copia del servicio o combo y de sus
/// adicionales tal como estaban al reservar (spec 005, RF-27, RF-28; plan
/// § 2). No cambia aunque la admin edite o borre después la lista de precios.
///
/// La lectura es tolerante, como la de la lista de precios (constitución,
/// principio 5): un campo que falta toma su valor por defecto y un adicional
/// que no se puede leer se omite.
library;

import 'price_list_model.dart';

/// Si lo reservado es un servicio o un combo.
enum BookedKind {
  service,
  combo;

  /// Un valor desconocido o ausente se lee como servicio.
  static BookedKind fromName(Object? value) =>
      value == 'combo' ? combo : service;
}

/// Un precio válido en céntimos: un entero ≥ 0 (también guardado como
/// decimal sin parte fraccionaria).
int? _readCents(Object? value) {
  if (value is! num || value < 0 || value != value.roundToDouble()) return null;
  return value.toInt();
}

int _readDuration(Object? value) {
  if (value is num && value > 0 && value == value.roundToDouble()) {
    return value.toInt();
  }
  return defaultDurationMinutes;
}

String _readId(Object? value) => value is String ? value : '';

/// Un adicional reservado.
class BookedAddonModel {
  const BookedAddonModel({
    required this.id,
    required this.name,
    required this.priceCents,
  });

  final String id;
  final BilingualText name;
  final int priceCents;

  /// `null` si no tiene nombre en ningún idioma o un precio válido.
  static BookedAddonModel? fromMap(Object? data) {
    if (data is! Map) return null;
    final name = BilingualText.fromMap(data['name']);
    final priceCents = _readCents(data['priceCents']);
    if (name.isEmpty || priceCents == null) return null;
    return BookedAddonModel(
      id: _readId(data['id']),
      name: name,
      priceCents: priceCents,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'name': name.toMap(),
    'priceCents': priceCents,
  };
}

/// El servicio o combo reservado, con sus adicionales.
class BookedServiceModel {
  const BookedServiceModel({
    required this.kind,
    required this.id,
    required this.name,
    required this.priceCents,
    this.priceFrom = false,
    required this.durationMinutes,
    this.addons = const [],
  });

  final BookedKind kind;

  /// Id en la lista de precios, solo como referencia.
  final String id;
  final BilingualText name;

  /// Precio en céntimos de real.
  final int priceCents;

  /// Precio "desde". Siempre `false` en un combo.
  final bool priceFrom;
  final int durationMinutes;

  /// Vacío en un combo.
  final List<BookedAddonModel> addons;

  /// El precio del servicio más el de sus adicionales.
  int get totalCents =>
      addons.fold(priceCents, (total, addon) => total + addon.priceCents);

  /// `null` si no es un mapa o no tiene nombre en ningún idioma. Los
  /// adicionales que no se pueden leer se omiten.
  static BookedServiceModel? fromMap(Object? data) {
    if (data is! Map) return null;
    final name = BilingualText.fromMap(data['name']);
    if (name.isEmpty) return null;

    final rawAddons = data['addons'];
    return BookedServiceModel(
      kind: BookedKind.fromName(data['kind']),
      id: _readId(data['id']),
      name: name,
      priceCents: _readCents(data['priceCents']) ?? 0,
      priceFrom: data['priceFrom'] == true,
      durationMinutes: _readDuration(data['durationMinutes']),
      addons: [
        if (rawAddons is List)
          for (final raw in rawAddons) ?BookedAddonModel.fromMap(raw),
      ],
    );
  }

  Map<String, dynamic> toMap() => {
    'kind': kind.name,
    'id': id,
    'name': name.toMap(),
    'priceCents': priceCents,
    'priceFrom': priceFrom,
    'durationMinutes': durationMinutes,
    'addons': [for (final addon in addons) addon.toMap()],
  };
}
