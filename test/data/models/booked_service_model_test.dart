import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';

void main() {
  const manicure = BookedServiceModel(
    kind: BookedKind.service,
    id: 's1',
    name: BilingualText(es: 'Manicura', pt: 'Manicure'),
    priceCents: 3000,
    priceFrom: true,
    durationMinutes: 45,
    addons: [
      BookedAddonModel(
        id: 'a1',
        name: BilingualText(es: 'Decoración', pt: 'Decoração'),
        priceCents: 1500,
      ),
    ],
  );

  test('ida y vuelta con toMap / fromMap', () {
    final map = manicure.toMap();
    expect(map, {
      'kind': 'service',
      'id': 's1',
      'name': {'es': 'Manicura', 'pt': 'Manicure'},
      'priceCents': 3000,
      'priceFrom': true,
      'durationMinutes': 45,
      'addons': [
        {
          'id': 'a1',
          'name': {'es': 'Decoración', 'pt': 'Decoração'},
          'priceCents': 1500,
        },
      ],
    });
    expect(BookedServiceModel.fromMap(map)!.toMap(), map);
  });

  test('un combo se guarda sin adicionales y sin "desde"', () {
    const combo = BookedServiceModel(
      kind: BookedKind.combo,
      id: 'c1',
      name: BilingualText(es: 'Pies y manos', pt: 'Pés e mãos'),
      priceCents: 7000,
      durationMinutes: 90,
    );
    final read = BookedServiceModel.fromMap(combo.toMap())!;
    expect(read.kind, BookedKind.combo);
    expect(read.priceFrom, isFalse);
    expect(read.addons, isEmpty);
    expect(read.toMap()['addons'], isEmpty);
  });

  test('totalCents suma el servicio y sus adicionales', () {
    expect(manicure.totalCents, 4500);
  });

  group('igualdad por valor (spec 006, RF-12)', () {
    // Una copia con los mismos datos, construida aparte.
    BookedServiceModel copy({
      BookedKind kind = BookedKind.service,
      String id = 's1',
      String es = 'Manicura',
      String pt = 'Manicure',
      int priceCents = 3000,
      bool priceFrom = true,
      int durationMinutes = 45,
      List<BookedAddonModel>? addons,
    }) => BookedServiceModel(
      kind: kind,
      id: id,
      name: BilingualText(es: es, pt: pt),
      priceCents: priceCents,
      priceFrom: priceFrom,
      durationMinutes: durationMinutes,
      addons:
          addons ??
          [
            BookedAddonModel(
              id: 'a1',
              name: BilingualText(es: 'Decoración', pt: 'Decoração'),
              priceCents: 1500,
            ),
          ],
    );

    test('los mismos datos son iguales y tienen el mismo hashCode', () {
      expect(copy(), manicure);
      expect(copy().hashCode, manicure.hashCode);
      expect(BookedServiceModel.fromMap(manicure.toMap()), manicure);
    });

    for (final (label, other) in [
      ('el tipo', copy(kind: BookedKind.combo)),
      ('el id', copy(id: 's2')),
      ('el nombre en español', copy(es: 'Otra')),
      ('el nombre en portugués', copy(pt: 'Outra')),
      ('el precio', copy(priceCents: 3100)),
      ('el "desde"', copy(priceFrom: false)),
      ('la duración', copy(durationMinutes: 60)),
      ('sin adicionales', copy(addons: const [])),
      (
        'otro adicional',
        copy(
          addons: const [
            BookedAddonModel(
              id: 'a2',
              name: BilingualText(es: 'Decoración', pt: 'Decoração'),
              priceCents: 1500,
            ),
          ],
        ),
      ),
    ]) {
      test('cambiar $label los hace distintos', () {
        expect(other, isNot(manicure));
      });
    }

    test('BookedAddonModel: iguales por valor; cambiar el id, el nombre o '
        'el precio los hace distintos', () {
      BookedAddonModel addon({
        String id = 'a1',
        String es = 'Piedras',
        int priceCents = 500,
      }) => BookedAddonModel(
        id: id,
        name: BilingualText(es: es, pt: 'Pedras'),
        priceCents: priceCents,
      );
      expect(addon(), addon());
      expect(addon().hashCode, addon().hashCode);
      expect(addon(id: 'a2'), isNot(addon()));
      expect(addon(es: 'Brillo'), isNot(addon()));
      expect(addon(priceCents: 600), isNot(addon()));
    });
  });

  group('lectura tolerante', () {
    test('los campos que faltan toman su valor por defecto', () {
      final read = BookedServiceModel.fromMap({
        'id': 's1',
        'name': {'es': 'Manicura'},
      })!;
      expect(read.kind, BookedKind.service);
      expect(read.name.of('pt'), 'Manicura');
      expect(read.priceCents, 0);
      expect(read.priceFrom, isFalse);
      expect(read.durationMinutes, defaultDurationMinutes);
      expect(read.addons, isEmpty);
    });

    test('un tipo desconocido se lee como servicio', () {
      expect(
        BookedServiceModel.fromMap({
          'kind': 'otro',
          'id': 's1',
          'name': {'es': 'Manicura'},
        })!.kind,
        BookedKind.service,
      );
    });

    test('un adicional sin nombre o con un precio no válido se omite', () {
      final read = BookedServiceModel.fromMap({
        'id': 's1',
        'name': {'es': 'Manicura'},
        'addons': [
          {
            'id': 'a1',
            'name': {'es': 'Bien'},
            'priceCents': 1000,
          },
          {'id': 'a2', 'priceCents': 1000},
          {
            'id': 'a3',
            'name': {'es': 'Negativo'},
            'priceCents': -5,
          },
          'no es un mapa',
        ],
      })!;
      expect(read.addons.map((a) => a.id), ['a1']);
    });

    test('sin nombre o sin mapa → null', () {
      expect(BookedServiceModel.fromMap(null), isNull);
      expect(BookedServiceModel.fromMap('texto'), isNull);
      expect(BookedServiceModel.fromMap({'id': 's1'}), isNull);
    });
  });
}
