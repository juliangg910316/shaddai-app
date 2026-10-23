/// Lista de precios del salón: el documento `settings/priceList` (spec 004,
/// plan § 2). La lectura es tolerante con documentos editados a mano o de
/// versiones futuras (constitución, principio 5):
/// - un campo que falta toma su valor por defecto;
/// - un elemento sin nombre, sin id o con un precio que no es un entero ≥ 0
///   se omite y se avisa con `onInvalid`;
/// - los campos desconocidos se conservan al volver a guardar.
library;

/// Avisa de un elemento que no se puede leer y se omite.
typedef InvalidEntryCallback = void Function(String message);

/// Texto con su versión en español y en portugués.
class BilingualText {
  const BilingualText({required this.es, required this.pt});

  static const empty = BilingualText(es: '', pt: '');

  final String es;
  final String pt;

  /// Vacío si los dos idiomas están vacíos o en blanco.
  bool get isEmpty => es.trim().isEmpty && pt.trim().isEmpty;

  /// El texto en [languageCode] (`es` o `pt`); si está vacío, el del otro
  /// idioma. Un idioma desconocido usa el español.
  String of(String languageCode) {
    final preferred = languageCode == 'pt' ? pt : es;
    final other = languageCode == 'pt' ? es : pt;
    return preferred.trim().isEmpty ? other : preferred;
  }

  factory BilingualText.fromMap(Object? data) {
    if (data is! Map) return empty;
    String read(String key) {
      final value = data[key];
      return value is String ? value : '';
    }

    return BilingualText(es: read('es'), pt: read('pt'));
  }

  Map<String, dynamic> toMap() => {'es': es, 'pt': pt};
}

/// Tipo de línea de una categoría.
enum PriceItemKind {
  /// Se puede reservar y tiene detalle.
  service,

  /// Se suma a un servicio: sin detalle ni reserva propia.
  addon;

  /// Un valor desconocido o ausente se lee como servicio.
  static PriceItemKind fromName(Object? value) =>
      value == 'addon' ? addon : service;
}

/// Duración por defecto si un documento no la tiene.
const defaultDurationMinutes = 60;

/// Un precio válido en céntimos: un entero ≥ 0 (también guardado como
/// decimal sin parte fraccionaria, como hace a veces la consola).
int? _readPriceCents(Object? value) {
  if (value is! num || value < 0 || value != value.roundToDouble()) return null;
  return value.toInt();
}

int _readDuration(Object? value) {
  if (value is num && value > 0 && value == value.roundToDouble()) {
    return value.toInt();
  }
  return defaultDurationMinutes;
}

String? _readId(Object? value) =>
    value is String && value.isNotEmpty ? value : null;

/// Los campos de [data] que no están en [known], para conservarlos.
Map<String, dynamic> _extra(Map<dynamic, dynamic> data, Set<String> known) => {
  for (final entry in data.entries)
    if (!known.contains(entry.key)) entry.key.toString(): entry.value,
};

/// Un servicio o un adicional de una categoría.
class PriceItemModel {
  const PriceItemModel({
    required this.id,
    required this.kind,
    required this.name,
    this.description = BilingualText.empty,
    this.group = BilingualText.empty,
    required this.priceCents,
    this.priceFrom = false,
    this.durationMinutes = defaultDurationMinutes,
    this.visible = true,
    this.extra = const {},
  });

  final String id;
  final PriceItemKind kind;
  final BilingualText name;

  /// Solo servicios.
  final BilingualText description;

  /// Solo servicios. Vacío = sin grupo.
  final BilingualText group;

  /// Precio en céntimos de real: 3050 = R$ 30,50.
  final int priceCents;

  /// Solo servicios: precio "desde".
  final bool priceFrom;

  /// Solo servicios.
  final int durationMinutes;

  final bool visible;

  /// Campos desconocidos del documento.
  final Map<String, dynamic> extra;

  bool get isService => kind == PriceItemKind.service;

  static const _known = {
    'id',
    'kind',
    'name',
    'description',
    'group',
    'priceCents',
    'priceFrom',
    'durationMinutes',
    'visible',
  };

  /// `null` si no tiene id, nombre en algún idioma o un precio válido.
  static PriceItemModel? fromMap(Map<dynamic, dynamic> data) {
    final id = _readId(data['id']);
    final name = BilingualText.fromMap(data['name']);
    final priceCents = _readPriceCents(data['priceCents']);
    if (id == null || name.isEmpty || priceCents == null) return null;

    return PriceItemModel(
      id: id,
      kind: PriceItemKind.fromName(data['kind']),
      name: name,
      description: BilingualText.fromMap(data['description']),
      group: BilingualText.fromMap(data['group']),
      priceCents: priceCents,
      priceFrom: data['priceFrom'] == true,
      durationMinutes: _readDuration(data['durationMinutes']),
      visible: data['visible'] != false,
      extra: _extra(data, _known),
    );
  }

  /// Los adicionales solo guardan sus campos propios.
  Map<String, dynamic> toMap() => {
    ...extra,
    'id': id,
    'kind': kind.name,
    'name': name.toMap(),
    if (isService) ...{
      'description': description.toMap(),
      'group': group.toMap(),
    },
    'priceCents': priceCents,
    if (isService) ...{
      'priceFrom': priceFrom,
      'durationMinutes': durationMinutes,
    },
    'visible': visible,
  };

  PriceItemModel copyWith({
    PriceItemKind? kind,
    BilingualText? name,
    BilingualText? description,
    BilingualText? group,
    int? priceCents,
    bool? priceFrom,
    int? durationMinutes,
    bool? visible,
  }) => PriceItemModel(
    id: id,
    kind: kind ?? this.kind,
    name: name ?? this.name,
    description: description ?? this.description,
    group: group ?? this.group,
    priceCents: priceCents ?? this.priceCents,
    priceFrom: priceFrom ?? this.priceFrom,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    visible: visible ?? this.visible,
    extra: extra,
  );
}

/// Un bloque de la lista de precios, con sus servicios y adicionales en
/// orden.
class PriceCategoryModel {
  const PriceCategoryModel({
    required this.id,
    required this.name,
    this.subtitle = BilingualText.empty,
    this.note = BilingualText.empty,
    this.visible = true,
    this.items = const [],
    this.extra = const {},
  });

  final String id;
  final BilingualText name;
  final BilingualText subtitle;
  final BilingualText note;
  final bool visible;
  final List<PriceItemModel> items;

  /// Campos desconocidos del documento.
  final Map<String, dynamic> extra;

  static const _known = {'id', 'name', 'subtitle', 'note', 'visible', 'items'};

  /// `null` si no tiene id o nombre en algún idioma. Las líneas inválidas se
  /// omiten y se avisa de cada una con [onInvalid].
  static PriceCategoryModel? fromMap(
    Map<dynamic, dynamic> data, {
    InvalidEntryCallback? onInvalid,
  }) {
    final id = _readId(data['id']);
    final name = BilingualText.fromMap(data['name']);
    if (id == null || name.isEmpty) return null;

    final rawItems = data['items'];
    final items = <PriceItemModel>[];
    if (rawItems is List) {
      for (final raw in rawItems) {
        final item = raw is Map ? PriceItemModel.fromMap(raw) : null;
        if (item == null) {
          onInvalid?.call('Línea de precio no válida en "$id": $raw');
        } else {
          items.add(item);
        }
      }
    }

    return PriceCategoryModel(
      id: id,
      name: name,
      subtitle: BilingualText.fromMap(data['subtitle']),
      note: BilingualText.fromMap(data['note']),
      visible: data['visible'] != false,
      items: items,
      extra: _extra(data, _known),
    );
  }

  Map<String, dynamic> toMap() => {
    ...extra,
    'id': id,
    'name': name.toMap(),
    'subtitle': subtitle.toMap(),
    'note': note.toMap(),
    'visible': visible,
    'items': [for (final item in items) item.toMap()],
  };

  PriceCategoryModel copyWith({
    BilingualText? name,
    BilingualText? subtitle,
    BilingualText? note,
    bool? visible,
    List<PriceItemModel>? items,
  }) => PriceCategoryModel(
    id: id,
    name: name ?? this.name,
    subtitle: subtitle ?? this.subtitle,
    note: note ?? this.note,
    visible: visible ?? this.visible,
    items: items ?? this.items,
    extra: extra,
  );
}

/// Varios servicios a un precio conjunto.
class ComboModel {
  const ComboModel({
    required this.id,
    required this.name,
    this.description = BilingualText.empty,
    required this.priceCents,
    this.durationMinutes = defaultDurationMinutes,
    this.visible = true,
    this.extra = const {},
  });

  final String id;
  final BilingualText name;
  final BilingualText description;

  /// Precio en céntimos de real.
  final int priceCents;
  final int durationMinutes;
  final bool visible;

  /// Campos desconocidos del documento.
  final Map<String, dynamic> extra;

  static const _known = {
    'id',
    'name',
    'description',
    'priceCents',
    'durationMinutes',
    'visible',
  };

  /// `null` si no tiene id, nombre en algún idioma o un precio válido.
  static ComboModel? fromMap(Map<dynamic, dynamic> data) {
    final id = _readId(data['id']);
    final name = BilingualText.fromMap(data['name']);
    final priceCents = _readPriceCents(data['priceCents']);
    if (id == null || name.isEmpty || priceCents == null) return null;

    return ComboModel(
      id: id,
      name: name,
      description: BilingualText.fromMap(data['description']),
      priceCents: priceCents,
      durationMinutes: _readDuration(data['durationMinutes']),
      visible: data['visible'] != false,
      extra: _extra(data, _known),
    );
  }

  Map<String, dynamic> toMap() => {
    ...extra,
    'id': id,
    'name': name.toMap(),
    'description': description.toMap(),
    'priceCents': priceCents,
    'durationMinutes': durationMinutes,
    'visible': visible,
  };

  ComboModel copyWith({
    BilingualText? name,
    BilingualText? description,
    int? priceCents,
    int? durationMinutes,
    bool? visible,
  }) => ComboModel(
    id: id,
    name: name ?? this.name,
    description: description ?? this.description,
    priceCents: priceCents ?? this.priceCents,
    durationMinutes: durationMinutes ?? this.durationMinutes,
    visible: visible ?? this.visible,
    extra: extra,
  );
}

/// Lo que devuelve una lectura del documento: la lista (`null` si el
/// documento no existe) y si viene de la caché del dispositivo, sin
/// confirmar con el servidor (RF-40).
class PriceListSnapshot {
  const PriceListSnapshot({required this.list, required this.fromCache});

  final PriceListModel? list;
  final bool fromCache;
}

/// El documento entero: categorías y combos, en el orden en que se muestran.
class PriceListModel {
  const PriceListModel({
    this.schemaVersion = currentSchemaVersion,
    this.categories = const [],
    this.combos = const [],
    this.extra = const {},
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final List<PriceCategoryModel> categories;
  final List<ComboModel> combos;

  /// Campos desconocidos del documento (también `updatedAt`, que pone el
  /// repositorio).
  final Map<String, dynamic> extra;

  static const _known = {'schemaVersion', 'categories', 'combos'};

  /// Tiene alguna categoría o algún combo guardado (RF-35, RF-38).
  bool get hasContent => categories.isNotEmpty || combos.isNotEmpty;

  /// Lee el documento. Las categorías, líneas y combos inválidos se omiten y
  /// se avisa de cada uno con [onInvalid].
  factory PriceListModel.fromMap(
    Map<String, dynamic> data, {
    InvalidEntryCallback? onInvalid,
  }) {
    final categories = <PriceCategoryModel>[];
    final rawCategories = data['categories'];
    if (rawCategories is List) {
      for (final raw in rawCategories) {
        final category = raw is Map
            ? PriceCategoryModel.fromMap(raw, onInvalid: onInvalid)
            : null;
        if (category == null) {
          onInvalid?.call('Categoría no válida: $raw');
        } else {
          categories.add(category);
        }
      }
    }

    final combos = <ComboModel>[];
    final rawCombos = data['combos'];
    if (rawCombos is List) {
      for (final raw in rawCombos) {
        final combo = raw is Map ? ComboModel.fromMap(raw) : null;
        if (combo == null) {
          onInvalid?.call('Combo no válido: $raw');
        } else {
          combos.add(combo);
        }
      }
    }

    final version = data['schemaVersion'];
    return PriceListModel(
      schemaVersion: version is int ? version : currentSchemaVersion,
      categories: categories,
      combos: combos,
      extra: _extra(data, _known),
    );
  }

  Map<String, dynamic> toMap() => {
    ...extra,
    'schemaVersion': schemaVersion,
    'categories': [for (final category in categories) category.toMap()],
    'combos': [for (final combo in combos) combo.toMap()],
  };

  PriceListModel copyWith({
    List<PriceCategoryModel>? categories,
    List<ComboModel>? combos,
  }) => PriceListModel(
    schemaVersion: schemaVersion,
    categories: categories ?? this.categories,
    combos: combos ?? this.combos,
    extra: extra,
  );
}
