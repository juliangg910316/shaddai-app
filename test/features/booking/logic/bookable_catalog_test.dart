import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';

BilingualText text(String es, [String? pt]) =>
    BilingualText(es: es, pt: pt ?? '$es (pt)');

PriceItemModel service(
  String id, {
  bool visible = true,
  int priceCents = 3000,
  bool priceFrom = false,
  int duration = 45,
}) => PriceItemModel(
  id: id,
  kind: PriceItemKind.service,
  name: text('Servicio $id'),
  priceCents: priceCents,
  priceFrom: priceFrom,
  durationMinutes: duration,
  visible: visible,
);

PriceItemModel addon(String id, {bool visible = true, int priceCents = 1500}) =>
    PriceItemModel(
      id: id,
      kind: PriceItemKind.addon,
      name: text('Adicional $id'),
      priceCents: priceCents,
      visible: visible,
    );

PriceCategoryModel category(
  String id,
  List<PriceItemModel> items, {
  bool visible = true,
}) => PriceCategoryModel(
  id: id,
  name: text('Categoría $id'),
  items: items,
  visible: visible,
);

ComboModel combo(String id, {bool visible = true}) => ComboModel(
  id: id,
  name: text('Combo $id'),
  priceCents: 7000,
  durationMinutes: 90,
  visible: visible,
);

final list = PriceListModel(
  categories: [
    category('manos', [
      service('s1', priceFrom: true),
      addon('a1'),
      service('s2', visible: false),
      addon('a2', visible: false),
      addon('a3', priceCents: 500),
    ]),
    category('pies', [service('s3'), addon('a4')]),
    category('oculta', [service('s4')], visible: false),
    category('solo-adicionales', [addon('a5')]),
    category('vacia', []),
  ],
  combos: [combo('c1'), combo('c2', visible: false)],
);

void main() {
  final catalog = bookableCatalog(list);

  group('bookableCatalog (RF-10, RF-11)', () {
    test('categorías visibles con algún servicio visible, en su orden', () {
      expect(catalog.categories.map((c) => c.category.id), ['manos', 'pies']);
    });

    test('solo los servicios visibles, sin adicionales sueltos', () {
      expect(catalog.categories.first.services.map((s) => s.id), ['s1']);
      expect(catalog.categories.last.services.map((s) => s.id), ['s3']);
    });

    test('los adicionales visibles de cada categoría', () {
      expect(catalog.categories.first.addons.map((a) => a.id), ['a1', 'a3']);
    });

    test('los combos visibles', () {
      expect(catalog.combos.map((c) => c.id), ['c1']);
    });

    test('una lista vacía da un catálogo vacío', () {
      final empty = bookableCatalog(const PriceListModel());
      expect(empty.isEmpty, isTrue);
      expect(catalog.isEmpty, isFalse);
    });
  });

  group('findBookable', () {
    test('un servicio visible, con su categoría', () {
      final found = findBookable(
        catalog,
        const BookableRef(BookedKind.service, 's1'),
      );
      expect(found, isA<BookableService>());
      found as BookableService;
      expect(found.item.id, 's1');
      expect(found.category.id, 'manos');
      expect(found.durationMinutes, 45);
      expect(found.priceFrom, isTrue);
    });

    test('un combo visible', () {
      final found = findBookable(
        catalog,
        const BookableRef(BookedKind.combo, 'c1'),
      );
      expect(found, isA<BookableCombo>());
      expect(found!.durationMinutes, 90);
      expect(found.priceFrom, isFalse);
    });

    final missing = {
      'servicio oculto': const BookableRef(BookedKind.service, 's2'),
      'servicio de una categoría oculta': const BookableRef(
        BookedKind.service,
        's4',
      ),
      'un adicional pedido como servicio': const BookableRef(
        BookedKind.service,
        'a1',
      ),
      'servicio que no existe': const BookableRef(BookedKind.service, 'x'),
      'combo oculto': const BookableRef(BookedKind.combo, 'c2'),
      'un servicio pedido como combo': const BookableRef(
        BookedKind.combo,
        's1',
      ),
    };
    missing.forEach((name, ref) {
      test('$name → null', () => expect(findBookable(catalog, ref), isNull));
    });
  });

  group('availableAddons (RF-18, RF-19)', () {
    test('los adicionales visibles de la categoría del servicio', () {
      expect(
        availableAddons(
          catalog,
          const BookableRef(BookedKind.service, 's3'),
        ).map((a) => a.id),
        ['a4'],
      );
    });

    test('un combo no tiene adicionales', () {
      expect(
        availableAddons(catalog, const BookableRef(BookedKind.combo, 'c1')),
        isEmpty,
      );
    });

    test('un servicio que no está disponible no tiene adicionales', () {
      expect(
        availableAddons(catalog, const BookableRef(BookedKind.service, 's2')),
        isEmpty,
      );
    });
  });

  group('totalPrice (RF-22)', () {
    final s1 = findBookable(
      catalog,
      const BookableRef(BookedKind.service, 's1'),
    )!;
    final addons = catalog.categories.first.addons; // a1 (1500) y a3 (500)

    test('el servicio más sus adicionales, con "desde"', () {
      expect(totalPrice(s1, addons), (cents: 5000, from: true));
    });

    test('sin adicionales', () {
      expect(totalPrice(s1, const []), (cents: 3000, from: true));
    });

    test('un combo nunca es "desde"', () {
      final c1 = findBookable(
        catalog,
        const BookableRef(BookedKind.combo, 'c1'),
      )!;
      expect(totalPrice(c1, const []), (cents: 7000, from: false));
    });
  });

  group('snapshotOf (RF-27)', () {
    test('copia nombres en los dos idiomas, precios y duración', () {
      final s1 = findBookable(
        catalog,
        const BookableRef(BookedKind.service, 's1'),
      )!;
      final snapshot = snapshotOf(s1, [catalog.categories.first.addons.last]);
      expect(snapshot.toMap(), {
        'kind': 'service',
        'id': 's1',
        'name': {'es': 'Servicio s1', 'pt': 'Servicio s1 (pt)'},
        'priceCents': 3000,
        'priceFrom': true,
        'durationMinutes': 45,
        'addons': [
          {
            'id': 'a3',
            'name': {'es': 'Adicional a3', 'pt': 'Adicional a3 (pt)'},
            'priceCents': 500,
          },
        ],
      });
    });

    test('un combo sin adicionales', () {
      final c1 = findBookable(
        catalog,
        const BookableRef(BookedKind.combo, 'c1'),
      )!;
      final snapshot = snapshotOf(c1, const []);
      expect(snapshot.kind, BookedKind.combo);
      expect(snapshot.name.of('es'), 'Combo c1');
      expect(snapshot.priceCents, 7000);
      expect(snapshot.durationMinutes, 90);
      expect(snapshot.addons, isEmpty);
    });
  });

  test('BookableRef se compara por valor', () {
    expect(
      const BookableRef(BookedKind.service, 's1'),
      const BookableRef(BookedKind.service, 's1'),
    );
    expect(
      const BookableRef(BookedKind.service, 's1'),
      isNot(const BookableRef(BookedKind.combo, 's1')),
    );
  });
}
