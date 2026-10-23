import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/price_list_model.dart';

/// Documento `settings/priceList` completo, tal como lo guarda la app
/// (spec 004, plan § 2).
Map<String, dynamic> fullDocument() => {
  'schemaVersion': 1,
  'categories': [
    {
      'id': 'c1',
      'name': {'es': 'Manos', 'pt': 'Mãos'},
      'subtitle': {'es': 'Cuidado', 'pt': 'Cuidado'},
      'note': {'es': '', 'pt': ''},
      'visible': true,
      'items': [
        {
          'id': 's1',
          'kind': 'service',
          'name': {'es': 'Spa de manos', 'pt': 'Spa das mãos'},
          'description': {'es': 'Exfoliación', 'pt': 'Esfoliação'},
          'group': {'es': '', 'pt': ''},
          'priceCents': 5500,
          'priceFrom': false,
          'durationMinutes': 45,
          'visible': true,
        },
        {
          'id': 'a1',
          'kind': 'addon',
          'name': {'es': 'Cromado', 'pt': 'Cromado'},
          'priceCents': 1500,
          'visible': false,
        },
      ],
    },
  ],
  'combos': [
    {
      'id': 'k1',
      'name': {'es': 'Gel Completo', 'pt': 'Gel Completo'},
      'description': {'es': 'Manos + pies', 'pt': 'Mãos + pés'},
      'priceCents': 12000,
      'durationMinutes': 120,
      'visible': true,
    },
  ],
};

void main() {
  group('BilingualText', () {
    test('of devuelve el texto del idioma pedido', () {
      const text = BilingualText(es: 'Manos', pt: 'Mãos');
      expect(text.of('es'), 'Manos');
      expect(text.of('pt'), 'Mãos');
    });

    test('of usa el otro idioma si el pedido está vacío', () {
      expect(const BilingualText(es: 'Manos', pt: '').of('pt'), 'Manos');
      expect(const BilingualText(es: ' ', pt: 'Mãos').of('es'), 'Mãos');
    });

    test('un idioma desconocido usa el español', () {
      expect(const BilingualText(es: 'Manos', pt: 'Mãos').of('en'), 'Manos');
    });

    test('isEmpty solo si los dos idiomas están vacíos o en blanco', () {
      expect(const BilingualText(es: '', pt: ' ').isEmpty, isTrue);
      expect(const BilingualText(es: 'Manos', pt: '').isEmpty, isFalse);
    });

    test('fromMap tolera valores que faltan o no son texto', () {
      expect(BilingualText.fromMap(null).isEmpty, isTrue);
      expect(BilingualText.fromMap('Manos').isEmpty, isTrue);
      final text = BilingualText.fromMap({'es': 'Manos', 'pt': 3});
      expect(text.es, 'Manos');
      expect(text.pt, '');
    });
  });

  group('PriceListModel.fromMap/toMap', () {
    test('ida y vuelta sin cambios', () {
      final document = fullDocument();
      expect(PriceListModel.fromMap(document).toMap(), document);
    });

    test('lee categorías, servicios, adicionales y combos', () {
      final list = PriceListModel.fromMap(fullDocument());

      expect(list.schemaVersion, 1);
      final category = list.categories.single;
      expect(category.name.of('pt'), 'Mãos');
      expect(category.items, hasLength(2));

      final service = category.items.first;
      expect(service.kind, PriceItemKind.service);
      expect(service.priceCents, 5500);
      expect(service.durationMinutes, 45);
      expect(service.description.of('es'), 'Exfoliación');

      final addon = category.items.last;
      expect(addon.kind, PriceItemKind.addon);
      expect(addon.visible, isFalse);

      expect(list.combos.single.priceCents, 12000);
    });

    test('un documento vacío da una lista vacía', () {
      final list = PriceListModel.fromMap({});
      expect(list.schemaVersion, 1);
      expect(list.categories, isEmpty);
      expect(list.combos, isEmpty);
    });
  });

  group('valores por defecto de los campos que faltan', () {
    test('visible → true, kind → service, durationMinutes → 60', () {
      final list = PriceListModel.fromMap({
        'categories': [
          {
            'id': 'c1',
            'name': {'es': 'Manos', 'pt': 'Mãos'},
            'items': [
              {
                'id': 's1',
                'name': {'es': 'Spa', 'pt': 'Spa'},
                'priceCents': 5500,
              },
            ],
          },
        ],
        'combos': [
          {
            'id': 'k1',
            'name': {'es': 'Combo', 'pt': 'Combo'},
            'priceCents': 6000,
          },
        ],
      });

      final category = list.categories.single;
      expect(category.visible, isTrue);
      expect(category.subtitle.isEmpty, isTrue);
      final item = category.items.single;
      expect(item.kind, PriceItemKind.service);
      expect(item.visible, isTrue);
      expect(item.durationMinutes, 60);
      expect(item.priceFrom, isFalse);
      expect(item.group.isEmpty, isTrue);
      final combo = list.combos.single;
      expect(combo.visible, isTrue);
      expect(combo.durationMinutes, 60);
    });

    test('un kind desconocido se lee como servicio', () {
      final item = PriceItemModel.fromMap({
        'id': 's1',
        'kind': 'otro',
        'name': {'es': 'Spa', 'pt': 'Spa'},
        'priceCents': 100,
      });
      expect(item!.kind, PriceItemKind.service);
    });

    test('un precio guardado como número decimal entero se acepta', () {
      final item = PriceItemModel.fromMap({
        'id': 's1',
        'name': {'es': 'Spa', 'pt': 'Spa'},
        'priceCents': 5500.0,
      });
      expect(item!.priceCents, 5500);
    });
  });

  group('elementos inválidos', () {
    Map<String, dynamic> item(Map<String, dynamic> overrides) => {
      'id': 's1',
      'name': {'es': 'Spa', 'pt': 'Spa'},
      'priceCents': 5500,
      ...overrides,
    };

    test('sin nombre en ningún idioma no se lee', () {
      expect(
        PriceItemModel.fromMap(
          item({
            'name': {'es': ' ', 'pt': ''},
          }),
        ),
        isNull,
      );
    });

    test('con un precio que no es un entero ≥ 0 no se lee', () {
      for (final price in [null, -100, 30.5, '3000']) {
        expect(
          PriceItemModel.fromMap(item({'priceCents': price})),
          isNull,
          reason: 'priceCents: $price',
        );
      }
    });

    test('sin id no se lee', () {
      expect(PriceItemModel.fromMap(item({'id': null})), isNull);
    });

    test('se omiten de la lista y se avisa de cada uno', () {
      final warnings = <String>[];
      final list = PriceListModel.fromMap({
        'categories': [
          {
            'id': 'c1',
            'name': {'es': 'Manos', 'pt': 'Mãos'},
            'items': [
              item({}),
              item({'id': 's2', 'priceCents': -1}),
              'no es un mapa',
            ],
          },
          {
            'id': 'c2',
            'name': {'es': '', 'pt': ''},
          },
        ],
        'combos': [
          {
            'id': 'k1',
            'name': {'es': 'Combo', 'pt': 'Combo'},
            'priceCents': 'gratis',
          },
        ],
      }, onInvalid: warnings.add);

      expect(list.categories.single.items.single.id, 's1');
      expect(list.combos, isEmpty);
      expect(warnings, hasLength(4));
    });
  });

  group('campos desconocidos', () {
    test('se conservan al volver a guardar', () {
      final document = fullDocument()
        ..['futureField'] = 'x'
        ..['updatedAt'] = 'marca';
      final category = (document['categories'] as List).first as Map;
      category['color'] = 'gold';
      ((category['items'] as List).first as Map)['photoUrl'] = 'p.jpg';
      ((document['combos'] as List).first as Map)['tag'] = 'promo';

      expect(PriceListModel.fromMap(document).toMap(), document);
    });

    test('copyWith los mantiene', () {
      final list = PriceListModel.fromMap(fullDocument()..['futureField'] = 1);
      final category = list.categories.single;
      final renamed = category.copyWith(
        name: const BilingualText(es: 'Uñas', pt: 'Unhas'),
      );
      final updated = list.copyWith(categories: [renamed]);

      expect(updated.toMap()['futureField'], 1);
      expect((updated.toMap()['categories'] as List).single['name'], {
        'es': 'Uñas',
        'pt': 'Unhas',
      });
    });
  });

  group('copyWith', () {
    test('de un servicio cambia solo lo indicado', () {
      final item = PriceListModel.fromMap(
        fullDocument(),
      ).categories.single.items.first;
      final changed = item.copyWith(priceCents: 6000, visible: false);

      expect(changed.priceCents, 6000);
      expect(changed.visible, isFalse);
      expect(changed.id, item.id);
      expect(changed.name.of('es'), item.name.of('es'));
      expect(changed.durationMinutes, item.durationMinutes);
    });

    test('de un combo cambia solo lo indicado', () {
      final combo = PriceListModel.fromMap(fullDocument()).combos.single;
      final changed = combo.copyWith(durationMinutes: 90);

      expect(changed.durationMinutes, 90);
      expect(changed.priceCents, combo.priceCents);
    });
  });

  group('hasContent (RF-35, RF-38)', () {
    test('sin categorías ni combos, no tiene contenido', () {
      expect(const PriceListModel().hasContent, isFalse);
    });

    test('con alguna categoría o algún combo, sí', () {
      final list = PriceListModel.fromMap(fullDocument());
      expect(list.hasContent, isTrue);
      expect(list.copyWith(categories: []).hasContent, isTrue);
      expect(list.copyWith(combos: []).hasContent, isTrue);
    });
  });
}
