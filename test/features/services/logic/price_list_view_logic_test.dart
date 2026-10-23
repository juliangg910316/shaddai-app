import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/services/logic/price_list_view_logic.dart';

BilingualText text(String es, [String? pt]) =>
    BilingualText(es: es, pt: pt ?? es);

PriceItemModel service(
  String id, {
  String? group,
  bool visible = true,
  int priceCents = 3000,
}) => PriceItemModel(
  id: id,
  kind: PriceItemKind.service,
  name: text('Servicio $id'),
  group: group == null ? BilingualText.empty : text(group),
  priceCents: priceCents,
  visible: visible,
);

PriceItemModel addon(String id, {bool visible = true}) => PriceItemModel(
  id: id,
  kind: PriceItemKind.addon,
  name: text('Adicional $id'),
  priceCents: 1500,
  visible: visible,
);

PriceCategoryModel category(
  String id,
  List<PriceItemModel> items, {
  bool visible = true,
}) => PriceCategoryModel(
  id: id,
  name: text('Categoría $id'),
  visible: visible,
  items: items,
);

ComboModel combo(String id, {bool visible = true}) => ComboModel(
  id: id,
  name: text('Combo $id'),
  priceCents: 6000,
  visible: visible,
);

void main() {
  group('resolvePriceListState (RF-7, RF-8, RF-10, RF-40)', () {
    final list = PriceListModel(
      categories: [
        category('c1', [service('s1')]),
      ],
    );

    test('documento del servidor → Ready con la lista', () {
      final state = resolvePriceListState(
        snapshot: PriceListSnapshot(list: list, fromCache: false),
      );
      expect(state, isA<PriceListReady>());
      expect((state as PriceListReady).list, same(list));
    });

    test('documento de la caché → Ready, también con el tiempo agotado', () {
      for (final timedOut in [false, true]) {
        final state = resolvePriceListState(
          snapshot: PriceListSnapshot(list: list, fromCache: true),
          timedOut: timedOut,
        );
        expect(state, isA<PriceListReady>(), reason: 'timedOut: $timedOut');
      }
    });

    test('sin documento según el servidor → Ready con la lista vacía', () {
      final state = resolvePriceListState(
        snapshot: const PriceListSnapshot(list: null, fromCache: false),
      );
      expect(state, isA<PriceListReady>());
      expect((state as PriceListReady).list.categories, isEmpty);
      expect(state.list.combos, isEmpty);
    });

    test('sin documento en la caché y sin tiempo agotado → Loading', () {
      expect(
        resolvePriceListState(
          snapshot: const PriceListSnapshot(list: null, fromCache: true),
        ),
        isA<PriceListLoading>(),
      );
    });

    test('sin documento en la caché con el tiempo agotado → Unavailable', () {
      expect(
        resolvePriceListState(
          snapshot: const PriceListSnapshot(list: null, fromCache: true),
          timedOut: true,
        ),
        isA<PriceListUnavailable>(),
      );
    });

    test('sin snapshot → Loading, o Unavailable con el tiempo agotado', () {
      expect(resolvePriceListState(), isA<PriceListLoading>());
      expect(
        resolvePriceListState(timedOut: true),
        isA<PriceListUnavailable>(),
      );
    });
  });

  group('visiblePriceList (RF-1, RF-3, RF-4, RF-11, RF-28)', () {
    test('omite las categorías ocultas y las que no tienen nada visible', () {
      final result = visiblePriceList(
        PriceListModel(
          categories: [
            category('c1', [service('s1')], visible: false),
            category('c2', [service('s2', visible: false)]),
            category('c3', []),
            category('c4', [service('s4')]),
          ],
        ),
        'es',
      );
      expect(result.categories.map((c) => c.category.id), ['c4']);
    });

    test('una categoría con solo adicionales visibles sí aparece', () {
      final result = visiblePriceList(
        PriceListModel(
          categories: [
            category('c1', [addon('a1')]),
          ],
        ),
        'es',
      );
      expect(result.categories.single.category.id, 'c1');
    });

    test('numera las categorías mostradas sin huecos, con dos cifras', () {
      final result = visiblePriceList(
        PriceListModel(
          categories: [
            category('c1', [service('s1')]),
            category('c2', [service('s2')], visible: false),
            category('c3', [service('s3', visible: false)]),
            category('c4', [service('s4')]),
          ],
        ),
        'es',
      );
      expect(result.categories.map((c) => c.number), ['01', '02']);
    });

    test('quita los servicios y adicionales ocultos, en su orden', () {
      final result = visiblePriceList(
        PriceListModel(
          categories: [
            category('c1', [
              service('s1'),
              addon('a1', visible: false),
              service('s2', visible: false),
              addon('a2'),
            ]),
          ],
        ),
        'es',
      );
      final items = result.categories.single.blocks
          .expand((b) => b.items)
          .map((i) => i.id);
      expect(items, ['s1', 'a2']);
    });

    test('agrupa en bloques los servicios seguidos con el mismo grupo', () {
      final result = visiblePriceList(
        PriceListModel(
          categories: [
            category('c1', [
              service('s1', group: 'Nueva'),
              service('s2', group: 'Nueva'),
              service('s3', group: 'Mantenimiento'),
              service('s4', group: 'Mantenimiento'),
            ]),
          ],
        ),
        'es',
      );
      final blocks = result.categories.single.blocks;
      expect(blocks.map((b) => b.group.of('es')), ['Nueva', 'Mantenimiento']);
      expect(blocks.first.items.map((i) => i.id), ['s1', 's2']);
      expect(blocks.last.items.map((i) => i.id), ['s3', 's4']);
    });

    test('sin grupo, todo va en un bloque sin título', () {
      final result = visiblePriceList(
        PriceListModel(
          categories: [
            category('c1', [service('s1'), addon('a1')]),
          ],
        ),
        'es',
      );
      final block = result.categories.single.blocks.single;
      expect(block.group.isEmpty, isTrue);
      expect(block.items, hasLength(2));
    });

    test('un grupo partido por otro elemento repite su título', () {
      final result = visiblePriceList(
        PriceListModel(
          categories: [
            category('c1', [
              service('s1', group: 'Nueva'),
              service('s2'),
              service('s3', group: 'Nueva'),
            ]),
          ],
        ),
        'es',
      );
      expect(result.categories.single.blocks.map((b) => b.group.of('es')), [
        'Nueva',
        '',
        'Nueva',
      ]);
    });

    test('los grupos se comparan en el idioma activo', () {
      final list = PriceListModel(
        categories: [
          category('c1', [
            service('s1').copyWith(group: text('Nueva', 'Nova')),
            service('s2').copyWith(group: text('Nueva', 'Nova aplicação')),
          ]),
        ],
      );
      expect(
        visiblePriceList(list, 'es').categories.single.blocks,
        hasLength(1),
      );
      expect(
        visiblePriceList(list, 'pt').categories.single.blocks,
        hasLength(2),
      );
    });

    test('un grupo oculto no parte los bloques', () {
      final result = visiblePriceList(
        PriceListModel(
          categories: [
            category('c1', [
              service('s1', group: 'Nueva'),
              service('s2', visible: false),
              service('s3', group: 'Nueva'),
            ]),
          ],
        ),
        'es',
      );
      expect(result.categories.single.blocks, hasLength(1));
    });

    test('quita los combos ocultos, en su orden', () {
      final result = visiblePriceList(
        PriceListModel(
          combos: [combo('k1'), combo('k2', visible: false), combo('k3')],
        ),
        'es',
      );
      expect(result.combos.map((c) => c.id), ['k1', 'k3']);
    });

    test('isEmpty sin categorías que mostrar, aunque haya combos', () {
      expect(visiblePriceList(const PriceListModel(), 'es').isEmpty, isTrue);
      expect(
        visiblePriceList(
          PriceListModel(
            categories: [
              category('c1', [service('s1', visible: false)]),
            ],
            combos: [combo('k1')],
          ),
          'es',
        ).isEmpty,
        isTrue,
      );
      expect(
        visiblePriceList(
          PriceListModel(
            categories: [
              category('c1', [service('s1')]),
            ],
          ),
          'es',
        ).isEmpty,
        isFalse,
      );
    });
  });

  group('findDetail (RF-14, RF-15, RF-17, RF-18)', () {
    final list = PriceListModel(
      categories: [
        category('c1', [
          service('s1'),
          service('s2', visible: false),
          addon('a1'),
        ]),
        category('c2', [service('s3')], visible: false),
      ],
      combos: [combo('k1'), combo('k2', visible: false)],
    );

    test('un servicio visible devuelve el servicio y su categoría', () {
      final result = findDetail(list, DetailKind.service, 's1');
      expect(result, isA<ServiceDetail>());
      result as ServiceDetail;
      expect(result.item.id, 's1');
      expect(result.category.id, 'c1');
    });

    test('un servicio oculto no está disponible', () {
      expect(
        findDetail(list, DetailKind.service, 's2'),
        isA<DetailNotAvailable>(),
      );
    });

    test('un servicio de una categoría oculta no está disponible', () {
      expect(
        findDetail(list, DetailKind.service, 's3'),
        isA<DetailNotAvailable>(),
      );
    });

    test('un servicio que no existe no está disponible', () {
      expect(
        findDetail(list, DetailKind.service, 'borrado'),
        isA<DetailNotAvailable>(),
      );
    });

    test('un adicional no tiene detalle', () {
      expect(
        findDetail(list, DetailKind.service, 'a1'),
        isA<DetailNotAvailable>(),
      );
    });

    test('un combo visible devuelve el combo', () {
      final result = findDetail(list, DetailKind.combo, 'k1');
      expect(result, isA<ComboDetail>());
      expect((result as ComboDetail).combo.id, 'k1');
    });

    test('un combo oculto o que no existe no está disponible', () {
      expect(
        findDetail(list, DetailKind.combo, 'k2'),
        isA<DetailNotAvailable>(),
      );
      expect(
        findDetail(list, DetailKind.combo, 'k9'),
        isA<DetailNotAvailable>(),
      );
    });

    test('el id de un servicio no abre un combo, ni al revés', () {
      expect(
        findDetail(list, DetailKind.combo, 's1'),
        isA<DetailNotAvailable>(),
      );
      expect(
        findDetail(list, DetailKind.service, 'k1'),
        isA<DetailNotAvailable>(),
      );
    });

    test('DetailKind se lee de la ruta', () {
      expect(DetailKind.fromPath('service'), DetailKind.service);
      expect(DetailKind.fromPath('combo'), DetailKind.combo);
      expect(DetailKind.fromPath('otro'), isNull);
    });
  });

  group('formatPrice', () {
    test('entero sin céntimos y con céntimos con coma', () {
      expect(formatPrice(3000), 'R\$ 30');
      expect(formatPrice(3050), 'R\$ 30,50');
      expect(formatPrice(3005), 'R\$ 30,05');
      expect(formatPrice(0), 'R\$ 0');
    });

    test('miles con punto', () {
      expect(formatPrice(120000), 'R\$ 1.200');
      expect(formatPrice(9999999), 'R\$ 99.999,99');
    });

    test('adicional con "+"', () {
      expect(formatPrice(1500, addon: true), '+R\$ 15');
      expect(formatPrice(0, addon: true), '+R\$ 0');
    });

    test('precio "desde" con el texto del idioma', () {
      expect(
        formatPrice(11000, from: (price) => 'desde $price'),
        'desde R\$ 110',
      );
    });
  });

  group('formatDuration', () {
    test('por debajo de una hora, en minutos', () {
      expect(formatDuration(45), '45 min');
      expect(formatDuration(5), '5 min');
    });

    test('desde una hora, en horas y minutos', () {
      expect(formatDuration(60), '1 h');
      expect(formatDuration(90), '1 h 30 min');
      expect(formatDuration(480), '8 h');
    });
  });
}
