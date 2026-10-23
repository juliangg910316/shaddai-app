import '../../data/models/price_list_model.dart';
import '../../l10n/app_localizations.dart';

/// Datos de la carga inicial de la lista de precios (spec 004, RF-36, RF-37):
/// los seis bloques y los tres combos que mostraba la landing antes de la
/// spec 004, en el mismo orden. Es el único sitio del código con precios
/// (excepción de RF-12).
///
/// Los textos se leen de los `.arb` en los dos idiomas ([es] y [pt]), así que
/// coinciden con lo que se veía (plan, D-6). Servicios y combos llevan
/// [defaultDurationMinutes] (la duración global del turno) y los servicios,
/// la descripción vacía: la admin los ajusta después. [newId] da el id de
/// cada elemento.
PriceListModel buildInitialPriceList({
  required AppLocalizations es,
  required AppLocalizations pt,
  required int defaultDurationMinutes,
  required String Function() newId,
}) {
  BilingualText text(_Text read) => BilingualText(es: read(es), pt: read(pt));

  PriceCategoryModel category(_Seed seed) => PriceCategoryModel(
    id: newId(),
    name: text(seed.name),
    subtitle: text(seed.subtitle),
    note: text(seed.note),
    items: [
      for (final line in seed.lines)
        PriceItemModel(
          id: newId(),
          kind: seed.addons ? PriceItemKind.addon : PriceItemKind.service,
          name: text(line.name),
          group: line.group == null ? BilingualText.empty : text(line.group!),
          priceCents: line.cents,
          durationMinutes: defaultDurationMinutes,
        ),
    ],
  );

  return PriceListModel(
    categories: [for (final seed in _categories) category(seed)],
    combos: [
      for (final (name, description, cents) in _combos)
        ComboModel(
          id: newId(),
          name: text(name),
          description: text(description),
          priceCents: cents,
          durationMinutes: defaultDurationMinutes,
        ),
    ],
  );
}

typedef _Text = String Function(AppLocalizations l);

class _Line {
  const _Line(this.name, this.cents, {this.group});

  final _Text name;

  /// Precio en céntimos de real.
  final int cents;
  final _Text? group;
}

class _Seed {
  const _Seed({
    required this.name,
    required this.subtitle,
    required this.note,
    required this.lines,
    this.addons = false,
  });

  final _Text name;
  final _Text subtitle;
  final _Text note;
  final List<_Line> lines;

  /// Todas sus líneas son adicionales ("+R$").
  final bool addons;
}

_Line _newApplication(_Text name, int cents) =>
    _Line(name, cents, group: (l) => l.landingServices3GroupNew);

_Line _maintenance(_Text name, int cents) =>
    _Line(name, cents, group: (l) => l.landingServices3GroupMaintenance);

final _categories = <_Seed>[
  _Seed(
    name: (l) => l.landingServices1Title,
    subtitle: (l) => l.landingServices1Subtitle,
    note: (l) => l.landingServices1Note,
    lines: [
      _Line((l) => l.landingServices1Row1, 3000),
      _Line((l) => l.landingServices1Row2, 5500),
      _Line((l) => l.landingServices1Row3, 6000),
      _Line((l) => l.landingServices1Row4, 10000),
      _Line((l) => l.landingServices1Row5, 12000),
    ],
  ),
  _Seed(
    name: (l) => l.landingServices2Title,
    subtitle: (l) => l.landingServices2Subtitle,
    note: (l) => l.landingServices2Note,
    lines: [
      _Line((l) => l.landingServices2Row1, 4000),
      _Line((l) => l.landingServices2Row2, 6000),
      _Line((l) => l.landingServices2Row3, 11000),
      _Line((l) => l.landingServices2Row4, 13000),
      _Line((l) => l.landingServices2Row5, 7000),
    ],
  ),
  _Seed(
    name: (l) => l.landingServices3Title,
    subtitle: (l) => l.landingServices3Subtitle,
    note: (l) => l.landingServices3Note,
    lines: [
      _newApplication((l) => l.landingServices3RowShort, 15000),
      _newApplication((l) => l.landingServices3RowMedium, 16500),
      _newApplication((l) => l.landingServices3RowLong, 18500),
      _newApplication((l) => l.landingServices3RowExtraLong, 22000),
      _maintenance((l) => l.landingServices3RowShort, 12000),
      _maintenance((l) => l.landingServices3RowMedium, 13000),
      _maintenance((l) => l.landingServices3RowLong, 14500),
      _maintenance((l) => l.landingServices3RowExtraLong, 16500),
    ],
  ),
  _Seed(
    name: (l) => l.landingSoftGelTitle,
    subtitle: (l) => l.landingServices4Subtitle,
    note: (l) => l.landingServices4Note,
    lines: [
      _Line((l) => l.landingServices4Row1, 13000),
      _Line((l) => l.landingServices4Row2, 14500),
      // "Mantenimiento / reaplicación · desde": se carga con su nombre de
      // hoy y sin marca "desde", para que se vea igual (RNF-1).
      _Line((l) => l.landingServices4Row3, 11000),
    ],
  ),
  _Seed(
    name: (l) => l.landingServices5Title,
    subtitle: (l) => l.landingServices5Subtitle,
    // Lleva un precio dentro (R$ 30): pasa a ser la nota editable de la
    // categoría.
    note: (l) => l.landingServices5Note,
    lines: [
      _Line((l) => l.landingServices5Row1, 2000),
      _Line((l) => l.landingServices5Row2, 3000),
      _Line((l) => l.landingSoftGelTitle, 3000),
      _Line((l) => l.landingServices5Row3, 4000),
    ],
  ),
  _Seed(
    name: (l) => l.landingServices6Title,
    subtitle: (l) => l.landingServices6Subtitle,
    note: (l) => l.landingServices6Note,
    addons: true,
    lines: [
      _Line((l) => l.landingServices6Row1, 1000),
      _Line((l) => l.landingServices6RowBabyBoomer, 1500),
      _Line((l) => l.landingServices6Row2, 1500),
      _Line((l) => l.landingServices6Row3, 2000),
      _Line((l) => l.landingServices6Row4, 500),
      _Line((l) => l.landingServices6Row5, 1000),
      _Line((l) => l.landingServices6Row6, 1500),
      _Line((l) => l.landingServices6Row7, 600),
      _Line((l) => l.landingServices6RowReversa, 2000),
    ],
  ),
];

final _combos = <(_Text, _Text, int)>[
  ((l) => l.landingCombo1Name, (l) => l.landingCombo1Desc, 6000),
  ((l) => l.landingCombo2Name, (l) => l.landingCombo2Desc, 12000),
  ((l) => l.landingCombo3Name, (l) => l.landingCombo3Desc, 16500),
];
