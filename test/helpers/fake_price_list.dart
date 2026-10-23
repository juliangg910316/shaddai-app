import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/repositories/price_list_repository.dart';
import 'package:shaddai/features/admin/initial_price_list.dart';
import 'package:shaddai/l10n/app_localizations.dart';

/// Lista de precios en memoria, sin Firebase (spec 004, plan § 9).
///
/// [stored] es el documento (`null` = no existe). Con [autoEmit], cada
/// escucha recibe al empezar el documento como si viniera del servidor; sin
/// él, el test decide qué llega con [emit] y [emitError].
class FakePriceListRepository implements PriceListRepository {
  FakePriceListRepository({this.stored, this.autoEmit = true});

  PriceListModel? stored;
  final bool autoEmit;

  /// Error que lanzará la próxima llamada a [update] o [seed].
  Object? failNext;

  int watchCalls = 0;
  int updateCalls = 0;
  int seedCalls = 0;

  final _listeners = <StreamController<PriceListSnapshot>>[];

  @override
  Stream<PriceListSnapshot> watch() {
    watchCalls++;
    late final StreamController<PriceListSnapshot> controller;
    controller = StreamController<PriceListSnapshot>(
      onListen: () {
        if (autoEmit) {
          controller.add(PriceListSnapshot(list: stored, fromCache: false));
        }
      },
      onCancel: () => _listeners.remove(controller),
    );
    _listeners.add(controller);
    return controller.stream;
  }

  /// Envía [snapshot] a quien esté escuchando.
  void emit(PriceListSnapshot snapshot) {
    for (final listener in List.of(_listeners)) {
      listener.add(snapshot);
    }
  }

  /// Envía un error a quien esté escuchando.
  void emitError(Object error) {
    for (final listener in List.of(_listeners)) {
      listener.addError(error);
    }
  }

  /// Guarda [list] y la envía como un cambio llegado del servidor.
  void change(PriceListModel? list) {
    stored = list;
    emit(PriceListSnapshot(list: list, fromCache: false));
  }

  void _throwIfFailing() {
    final error = failNext;
    if (error != null) {
      failNext = null;
      throw error;
    }
  }

  @override
  Future<void> update(
    PriceListModel Function(PriceListModel current) transform,
  ) async {
    updateCalls++;
    _throwIfFailing();
    final current = stored;
    if (current == null) throw const PriceListMissing();
    change(transform(current));
  }

  @override
  Future<void> seed(PriceListModel initial) async {
    seedCalls++;
    _throwIfFailing();
    if (stored?.hasContent ?? false) throw const PriceListAlreadySeeded();
    change(initial);
  }
}

BilingualText _text(String es, String pt) => BilingualText(es: es, pt: pt);

/// Lista pequeña para los tests:
/// - "Manos" (visible): un servicio, dos servicios con grupo y un adicional;
/// - "Pies" (oculta): un servicio;
/// - dos combos, uno visible y otro oculto.
PriceListModel testPriceList() => PriceListModel(
  categories: [
    PriceCategoryModel(
      id: 'hands',
      name: _text('Manos', 'Mãos'),
      subtitle: _text('Cuidado y elegancia', 'Cuidado e elegância'),
      note: _text('Incluye cutículas.', 'Inclui cutículas.'),
      items: [
        PriceItemModel(
          id: 'spa',
          kind: PriceItemKind.service,
          name: _text('Spa de manos', 'Spa das mãos'),
          description: _text('Exfoliación e hidratación.', 'Esfoliação.'),
          priceCents: 5500,
          durationMinutes: 45,
        ),
        PriceItemModel(
          id: 'gel-short',
          kind: PriceItemKind.service,
          name: _text('Corto', 'Curto'),
          group: _text('Nueva aplicación', 'Nova aplicação'),
          priceCents: 15000,
          durationMinutes: 120,
        ),
        PriceItemModel(
          id: 'gel-maintenance',
          kind: PriceItemKind.service,
          name: _text('Mantenimiento', 'Manutenção'),
          group: _text('Mantenimiento', 'Manutenção'),
          priceCents: 11000,
          priceFrom: true,
          durationMinutes: 90,
        ),
        PriceItemModel(
          id: 'chrome',
          kind: PriceItemKind.addon,
          name: _text('Cromado', 'Cromado'),
          priceCents: 1500,
        ),
      ],
    ),
    PriceCategoryModel(
      id: 'feet',
      name: _text('Pies', 'Pés'),
      visible: false,
      items: [
        PriceItemModel(
          id: 'pedicure',
          kind: PriceItemKind.service,
          name: _text('Pedicura', 'Pedicure'),
          priceCents: 4000,
        ),
      ],
    ),
  ],
  combos: [
    ComboModel(
      id: 'full-gel',
      name: _text('Gel Completo', 'Gel Completo'),
      description: _text('Manos + pies', 'Mãos + pés'),
      priceCents: 12000,
      durationMinutes: 150,
    ),
    ComboModel(
      id: 'hidden-combo',
      name: _text('Combo oculto', 'Combo oculto'),
      priceCents: 9000,
      visible: false,
    ),
  ],
);

/// La lista de la carga inicial (la que se veía antes de la spec 004), con
/// ids fijos. Es lo que ven por defecto los tests que montan la app.
PriceListModel initialTestPriceList() {
  var next = 0;
  return buildInitialPriceList(
    es: lookupAppLocalizations(const Locale('es')),
    pt: lookupAppLocalizations(const Locale('pt')),
    defaultDurationMinutes: 60,
    newId: () => 'initial-${next++}',
  );
}
