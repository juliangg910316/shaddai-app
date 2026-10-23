import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/services/logic/price_list_view_logic.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';

import '../../helpers/fake_price_list.dart';

const _timeout = Duration(milliseconds: 50);

/// Contenedor con [repository] y un tiempo límite corto. Escucha el estado
/// para que el stream siga abierto durante el test.
ProviderContainer _container(FakePriceListRepository repository) {
  final container = ProviderContainer(
    overrides: [
      priceListRepositoryProvider.overrideWithValue(repository),
      priceListLoadTimeoutProvider.overrideWithValue(_timeout),
    ],
  );
  container.listen(currentPriceListProvider, (_, _) {});
  addTearDown(container.dispose);
  return container;
}

/// Deja pasar los eventos pendientes del stream.
Future<void> _settle() => Future<void>.delayed(Duration.zero);

/// Espera a que pase el tiempo límite de carga.
Future<void> _waitTimeout() => Future<void>.delayed(_timeout * 3);

void main() {
  group('currentPriceListProvider (RF-6 a RF-9, RF-40)', () {
    test('al empezar, Loading', () {
      final container = _container(FakePriceListRepository(autoEmit: false));
      expect(container.read(currentPriceListProvider), isA<PriceListLoading>());
    });

    test('un documento del servidor da Ready con la lista', () async {
      final list = testPriceList();
      final container = _container(FakePriceListRepository(stored: list));
      await _settle();

      final state = container.read(currentPriceListProvider);
      expect(state, isA<PriceListReady>());
      expect((state as PriceListReady).list, same(list));
    });

    test('un cambio posterior llega sin volver a escuchar (RF-6)', () async {
      final repository = FakePriceListRepository(stored: testPriceList());
      final container = _container(repository);
      await _settle();

      final changed = testPriceList().copyWith(combos: []);
      repository.change(changed);
      await _settle();

      final state = container.read(currentPriceListProvider) as PriceListReady;
      expect(state.list, same(changed));
      expect(repository.watchCalls, 1);
    });

    test('datos de la caché se muestran sin esperar (RF-40)', () async {
      final repository = FakePriceListRepository(autoEmit: false);
      final container = _container(repository);
      await _settle();

      repository.emit(
        PriceListSnapshot(list: testPriceList(), fromCache: true),
      );
      await _settle();
      expect(container.read(currentPriceListProvider), isA<PriceListReady>());

      await _waitTimeout();
      expect(container.read(currentPriceListProvider), isA<PriceListReady>());
    });

    test('sin documento en la caché: Loading y, al pasar el tiempo, '
        'Unavailable (RF-8)', () async {
      final repository = FakePriceListRepository(autoEmit: false);
      final container = _container(repository);
      await _settle();

      repository.emit(const PriceListSnapshot(list: null, fromCache: true));
      await _settle();
      expect(container.read(currentPriceListProvider), isA<PriceListLoading>());

      await _waitTimeout();
      expect(
        container.read(currentPriceListProvider),
        isA<PriceListUnavailable>(),
      );
    });

    test('sin ninguna respuesta, Unavailable al pasar el tiempo', () async {
      final container = _container(FakePriceListRepository(autoEmit: false));
      await _waitTimeout();
      expect(
        container.read(currentPriceListProvider),
        isA<PriceListUnavailable>(),
      );
    });

    test('si llegan datos después del tiempo límite, se muestran', () async {
      final repository = FakePriceListRepository(autoEmit: false);
      final container = _container(repository);
      await _waitTimeout();

      repository.change(testPriceList());
      await _settle();
      expect(container.read(currentPriceListProvider), isA<PriceListReady>());
    });

    test('sin documento según el servidor, Ready con la lista vacía '
        '(RF-10)', () async {
      final container = _container(FakePriceListRepository());
      await _settle();

      final state = container.read(currentPriceListProvider) as PriceListReady;
      expect(state.list.categories, isEmpty);
    });

    test('un error del stream da Unavailable', () async {
      final repository = FakePriceListRepository(autoEmit: false);
      final container = _container(repository);
      await _settle();

      repository.emitError(Exception('permission-denied'));
      await _settle();
      expect(
        container.read(currentPriceListProvider),
        isA<PriceListUnavailable>(),
      );
    });

    test('invalidar el estado vuelve a escuchar (Reintentar, RF-9)', () async {
      final repository = FakePriceListRepository(autoEmit: false);
      final container = _container(repository);
      await _settle();
      repository.emitError(Exception('unavailable'));
      await _settle();

      container.invalidate(priceListStateProvider);
      await _settle();

      // Mientras vuelve a cargar, se ve la carga y no el error anterior.
      expect(repository.watchCalls, 2);
      expect(container.read(currentPriceListProvider), isA<PriceListLoading>());

      repository.change(testPriceList());
      await _settle();
      expect(container.read(currentPriceListProvider), isA<PriceListReady>());
    });
  });

  group('publicPriceListProvider', () {
    test('mientras carga, PriceViewLoading', () {
      final container = _container(FakePriceListRepository(autoEmit: false));
      expect(
        container.read(publicPriceListProvider('es')),
        isA<PriceViewLoading<PublicPriceList>>(),
      );
    });

    test('con datos, la lista visible en el idioma pedido', () async {
      final container = _container(
        FakePriceListRepository(stored: testPriceList()),
      );
      await _settle();

      final view = container.read(publicPriceListProvider('pt'));
      expect(view, isA<PriceViewReady<PublicPriceList>>());
      final visible = (view as PriceViewReady<PublicPriceList>).value;
      expect(visible.categories.map((c) => c.category.id), ['hands']);
      expect(visible.combos.map((c) => c.id), ['full-gel']);
    });

    test('sin poder cargar, PriceViewUnavailable', () async {
      final container = _container(FakePriceListRepository(autoEmit: false));
      await _waitTimeout();
      expect(
        container.read(publicPriceListProvider('es')),
        isA<PriceViewUnavailable<PublicPriceList>>(),
      );
    });
  });

  group('priceDetailProvider', () {
    test('encuentra un servicio y se actualiza en vivo', () async {
      final repository = FakePriceListRepository(stored: testPriceList());
      final container = _container(repository);
      container.listen(
        priceDetailProvider((DetailKind.service, 'spa')),
        (_, _) {},
      );
      await _settle();

      final view = container.read(
        priceDetailProvider((DetailKind.service, 'spa')),
      );
      expect(
        (view as PriceViewReady<DetailResult>).value,
        isA<ServiceDetail>(),
      );

      // La admin oculta la categoría con el detalle abierto (RF-17).
      final list = testPriceList();
      repository.change(
        list.copyWith(
          categories: [
            list.categories.first.copyWith(visible: false),
            ...list.categories.skip(1),
          ],
        ),
      );
      await _settle();

      final after = container.read(
        priceDetailProvider((DetailKind.service, 'spa')),
      );
      expect(
        (after as PriceViewReady<DetailResult>).value,
        isA<DetailNotAvailable>(),
      );
    });

    test('mientras carga, PriceViewLoading', () {
      final container = _container(FakePriceListRepository(autoEmit: false));
      expect(
        container.read(priceDetailProvider((DetailKind.combo, 'full-gel'))),
        isA<PriceViewLoading<DetailResult>>(),
      );
    });
  });
}
