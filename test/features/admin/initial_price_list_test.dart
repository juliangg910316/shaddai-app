import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/admin/initial_price_list.dart';
import 'package:shaddai/l10n/app_localizations.dart';

typedef _Text = String Function(AppLocalizations l);

/// Una línea esperada: su texto en los `.arb`, su precio de hoy en céntimos
/// y, si lo tiene, su grupo.
class _Line {
  const _Line(this.name, this.cents, {this.group});

  final _Text name;
  final int cents;
  final _Text? group;
}

class _Category {
  const _Category(
    this.name,
    this.subtitle,
    this.note,
    this.lines, {
    this.addons = false,
  });

  final _Text name;
  final _Text subtitle;
  final _Text note;
  final List<_Line> lines;
  final bool addons;
}

/// La lista de precios de hoy (spec 002, `LandingContent` antes de la
/// spec 004), escrita a mano para comprobar la carga inicial (RNF-1).
final _expected = <_Category>[
  _Category(
    (l) => l.landingServices1Title,
    (l) => l.landingServices1Subtitle,
    (l) => l.landingServices1Note,
    [
      _Line((l) => l.landingServices1Row1, 3000),
      _Line((l) => l.landingServices1Row2, 5500),
      _Line((l) => l.landingServices1Row3, 6000),
      _Line((l) => l.landingServices1Row4, 10000),
      _Line((l) => l.landingServices1Row5, 12000),
    ],
  ),
  _Category(
    (l) => l.landingServices2Title,
    (l) => l.landingServices2Subtitle,
    (l) => l.landingServices2Note,
    [
      _Line((l) => l.landingServices2Row1, 4000),
      _Line((l) => l.landingServices2Row2, 6000),
      _Line((l) => l.landingServices2Row3, 11000),
      _Line((l) => l.landingServices2Row4, 13000),
      _Line((l) => l.landingServices2Row5, 7000),
    ],
  ),
  _Category(
    (l) => l.landingServices3Title,
    (l) => l.landingServices3Subtitle,
    (l) => l.landingServices3Note,
    [
      for (final (row, cents) in <(_Text, int)>[
        ((l) => l.landingServices3RowShort, 15000),
        ((l) => l.landingServices3RowMedium, 16500),
        ((l) => l.landingServices3RowLong, 18500),
        ((l) => l.landingServices3RowExtraLong, 22000),
      ])
        _Line(row, cents, group: (l) => l.landingServices3GroupNew),
      for (final (row, cents) in <(_Text, int)>[
        ((l) => l.landingServices3RowShort, 12000),
        ((l) => l.landingServices3RowMedium, 13000),
        ((l) => l.landingServices3RowLong, 14500),
        ((l) => l.landingServices3RowExtraLong, 16500),
      ])
        _Line(row, cents, group: (l) => l.landingServices3GroupMaintenance),
    ],
  ),
  _Category(
    (l) => l.landingSoftGelTitle,
    (l) => l.landingServices4Subtitle,
    (l) => l.landingServices4Note,
    [
      _Line((l) => l.landingServices4Row1, 13000),
      _Line((l) => l.landingServices4Row2, 14500),
      _Line((l) => l.landingServices4Row3, 11000),
    ],
  ),
  _Category(
    (l) => l.landingServices5Title,
    (l) => l.landingServices5Subtitle,
    (l) => l.landingServices5Note,
    [
      _Line((l) => l.landingServices5Row1, 2000),
      _Line((l) => l.landingServices5Row2, 3000),
      _Line((l) => l.landingSoftGelTitle, 3000),
      _Line((l) => l.landingServices5Row3, 4000),
    ],
  ),
  _Category(
    (l) => l.landingServices6Title,
    (l) => l.landingServices6Subtitle,
    (l) => l.landingServices6Note,
    [
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
    addons: true,
  ),
];

final _expectedCombos = <(_Text, _Text, int)>[
  ((l) => l.landingCombo1Name, (l) => l.landingCombo1Desc, 6000),
  ((l) => l.landingCombo2Name, (l) => l.landingCombo2Desc, 12000),
  ((l) => l.landingCombo3Name, (l) => l.landingCombo3Desc, 16500),
];

void main() {
  final es = lookupAppLocalizations(const Locale('es'));
  final pt = lookupAppLocalizations(const Locale('pt'));

  var counter = 0;
  PriceListModel build({int duration = 60}) {
    counter = 0;
    return buildInitialPriceList(
      es: es,
      pt: pt,
      defaultDurationMinutes: duration,
      newId: () => 'id-${counter++}',
    );
  }

  void expectText(BilingualText actual, _Text expected, String what) {
    expect(actual.es, expected(es), reason: '$what (es)');
    expect(actual.pt, expected(pt), reason: '$what (pt)');
  }

  test('6 categorías y 3 combos, visibles y en el orden de hoy', () {
    final list = build();
    expect(list.categories, hasLength(_expected.length));
    expect(list.combos, hasLength(_expectedCombos.length));
    expect(list.categories.every((c) => c.visible), isTrue);
    expect(list.combos.every((c) => c.visible), isTrue);
  });

  test('cada categoría tiene los textos de los .arb en ES y PT', () {
    final list = build();
    for (var i = 0; i < _expected.length; i++) {
      final actual = list.categories[i];
      final expected = _expected[i];
      expectText(actual.name, expected.name, 'nombre de la categoría $i');
      expectText(actual.subtitle, expected.subtitle, 'subtítulo $i');
      expectText(actual.note, expected.note, 'nota $i');
    }
  });

  test('cada línea tiene su texto, su grupo y su precio de hoy', () {
    final list = build();
    for (var i = 0; i < _expected.length; i++) {
      final items = list.categories[i].items;
      final lines = _expected[i].lines;
      expect(items, hasLength(lines.length), reason: 'categoría $i');

      for (var j = 0; j < lines.length; j++) {
        final item = items[j];
        final line = lines[j];
        expectText(item.name, line.name, 'línea $i.$j');
        expect(item.priceCents, line.cents, reason: 'precio $i.$j');
        expect(item.visible, isTrue);
        expect(item.priceFrom, isFalse, reason: 'como hoy, sin "desde"');
        final group = line.group;
        if (group == null) {
          expect(item.group.isEmpty, isTrue, reason: 'grupo $i.$j');
        } else {
          expectText(item.group, group, 'grupo $i.$j');
        }
      }
    }
  });

  test('Decoración solo tiene adicionales; el resto, solo servicios', () {
    final list = build();
    for (var i = 0; i < _expected.length; i++) {
      final kind = _expected[i].addons
          ? PriceItemKind.addon
          : PriceItemKind.service;
      expect(
        list.categories[i].items.every((item) => item.kind == kind),
        isTrue,
        reason: 'categoría $i',
      );
    }
  });

  test('la nota de Retiradas, con su precio, pasa a la categoría', () {
    final retiradas = build().categories[4];
    expect(retiradas.note.es, contains('R\$ 30'));
    expect(retiradas.note.pt, contains('R\$ 30'));
  });

  test('los combos tienen su nombre, descripción y precio de hoy', () {
    final combos = build().combos;
    for (var i = 0; i < _expectedCombos.length; i++) {
      final (name, description, cents) = _expectedCombos[i];
      expectText(combos[i].name, name, 'combo $i');
      expectText(combos[i].description, description, 'descripción combo $i');
      expect(combos[i].priceCents, cents, reason: 'precio combo $i');
    }
  });

  test('servicios y combos con la duración indicada (RF-37)', () {
    final list = build(duration: 45);
    final services = list.categories
        .expand((c) => c.items)
        .where((item) => item.isService);
    expect(services.every((item) => item.durationMinutes == 45), isTrue);
    expect(list.combos.every((combo) => combo.durationMinutes == 45), isTrue);
  });

  test('los servicios tienen la descripción vacía (RF-37)', () {
    final items = build().categories.expand((c) => c.items);
    expect(items.every((item) => item.description.isEmpty), isTrue);
  });

  test('todos los ids son distintos', () {
    final list = build();
    final ids = [
      for (final category in list.categories) ...[
        category.id,
        for (final item in category.items) item.id,
      ],
      for (final combo in list.combos) combo.id,
    ];
    expect(ids.toSet(), hasLength(ids.length));
  });

  test('el documento resultante se vuelve a leer igual', () {
    final list = build();
    expect(PriceListModel.fromMap(list.toMap()).toMap(), list.toMap());
  });
}
