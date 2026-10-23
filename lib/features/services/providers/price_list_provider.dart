import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/price_list_model.dart';
import '../../../data/repositories/price_list_repository.dart';
import '../logic/price_list_view_logic.dart';

/// El único provider del repositorio de la lista de precios; la gestión de la
/// admin también lo usa (spec 004, plan § 5).
final priceListRepositoryProvider = Provider((ref) => PriceListRepository());

/// Tiempo que se espera la respuesta del servidor si la caché no tiene la
/// lista, antes de mostrar el aviso de error (RF-8, D-4).
final priceListLoadTimeoutProvider = Provider<Duration>(
  (ref) => const Duration(seconds: 8),
);

/// Estado de la lista de precios, en vivo (RF-6). "Reintentar" lo invalida
/// para volver a escuchar (RF-9). Nunca termina en error: un error del
/// stream es [PriceListUnavailable], y su detalle va a la consola (RNF-6).
final priceListStateProvider = StreamProvider<PriceListState>((ref) {
  final repository = ref.watch(priceListRepositoryProvider);
  final timeout = ref.watch(priceListLoadTimeoutProvider);
  final states = StreamController<PriceListState>();

  PriceListSnapshot? last;
  var timedOut = false;
  void emit() =>
      states.add(resolvePriceListState(snapshot: last, timedOut: timedOut));

  final timer = Timer(timeout, () {
    timedOut = true;
    emit();
  });
  final subscription = repository.watch().listen(
    (snapshot) {
      last = snapshot;
      emit();
    },
    onError: (Object error) {
      debugPrint('Error al cargar la lista de precios: $error');
      states.add(const PriceListUnavailable());
    },
  );

  ref.onDispose(() {
    timer.cancel();
    subscription.cancel();
    states.close();
  });
  return states.stream;
});

/// [priceListStateProvider] sin el envoltorio de `AsyncValue`: antes del
/// primer estado, y mientras vuelve a cargar tras "Reintentar",
/// [PriceListLoading] (no el estado anterior que Riverpod conserva).
final currentPriceListProvider = Provider<PriceListState>((ref) {
  final state = ref.watch(priceListStateProvider);
  if (state.isLoading) return const PriceListLoading();
  return state.value ?? const PriceListLoading();
});

/// Lo que muestra una vista de la lista de precios: cargando, no disponible
/// o su contenido.
sealed class PriceView<T> {
  const PriceView();
}

class PriceViewLoading<T> extends PriceView<T> {
  const PriceViewLoading();
}

class PriceViewUnavailable<T> extends PriceView<T> {
  const PriceViewUnavailable();
}

class PriceViewReady<T> extends PriceView<T> {
  const PriceViewReady(this.value);

  final T value;
}

PriceView<T> _viewOf<T>(
  PriceListState state,
  T Function(PriceListModel list) build,
) => switch (state) {
  PriceListLoading() => PriceViewLoading<T>(),
  PriceListUnavailable() => PriceViewUnavailable<T>(),
  PriceListReady(:final list) => PriceViewReady<T>(build(list)),
};

/// La lista que ve la clienta, con los grupos comparados en el idioma
/// [languageCode] (RF-1 a RF-5, RF-11).
final publicPriceListProvider =
    Provider.family<PriceView<PublicPriceList>, String>(
      (ref, languageCode) => _viewOf(
        ref.watch(currentPriceListProvider),
        (list) => visiblePriceList(list, languageCode),
      ),
    );

/// El detalle de un servicio o combo, en vivo (RF-14, RF-15, RF-17).
final priceDetailProvider =
    Provider.family<PriceView<DetailResult>, (DetailKind, String)>(
      (ref, key) => _viewOf(
        ref.watch(currentPriceListProvider),
        (list) => findDetail(list, key.$1, key.$2),
      ),
    );
