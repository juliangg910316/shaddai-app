import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/calendar_settings_model.dart';
import '../../../data/models/price_list_model.dart';
import '../../../data/repositories/config_repository.dart';
import '../../../data/repositories/price_list_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/providers/booking_provider.dart';
// Con prefijo: los métodos del controlador se llaman como las funciones.
import '../../services/logic/price_list_edit_logic.dart' as edit;
import '../../services/providers/price_list_provider.dart';
import '../initial_price_list.dart';

/// Resultado de un cambio de la gestión de servicios. Nunca lleva el error
/// técnico, que va a la consola (RNF-6).
enum AdminServicesResult {
  ok,
  failed,

  /// El elemento ya no existe: otra admin lo borró.
  itemGone,

  /// La categoría tiene elementos: otra admin los añadió entre medias
  /// (RF-30).
  categoryNotEmpty,
}

/// Cambios de la admin en la lista de precios (spec 004, plan § 5).
class AdminServicesController {
  AdminServicesController(
    this._priceList,
    this._config, {
    String Function()? newId,
  }) : _newId = newId ?? const Uuid().v4;

  final PriceListRepository _priceList;
  final ConfigRepository _config;
  final String Function() _newId;

  /// Si el calendario no responde, la carga sigue con la duración por
  /// defecto.
  static const _settingsTimeout = Duration(seconds: 5);

  /// Carga la lista de precios actual, con la duración global del turno en
  /// servicios y combos (RF-36, RF-37). Si otra admin la cargó entre medias,
  /// no se duplica y se da por hecha (RF-38).
  Future<AdminServicesResult> seedInitialList() async {
    int duration;
    try {
      final settings = await _config.getCalendarSettings().first.timeout(
        _settingsTimeout,
      );
      duration = settings.globalSlotDurationMinutes;
    } catch (e) {
      debugPrint('Calendario no disponible para la carga inicial: $e');
      duration =
          CalendarSettingsModel.defaultSettings().globalSlotDurationMinutes;
    }

    final PriceListModel initial = buildInitialPriceList(
      es: lookupAppLocalizations(const Locale('es')),
      pt: lookupAppLocalizations(const Locale('pt')),
      defaultDurationMinutes: duration,
      newId: _newId,
    );
    try {
      await _priceList.seed(initial);
      return AdminServicesResult.ok;
    } on PriceListAlreadySeeded {
      return AdminServicesResult.ok;
    } catch (e) {
      debugPrint('Error en la carga inicial de la lista de precios: $e');
      return AdminServicesResult.failed;
    }
  }

  /// Aplica [transform] a la lista guardada (plan § 5).
  Future<AdminServicesResult> _apply(
    PriceListModel Function(PriceListModel list) transform,
  ) async {
    try {
      await _priceList.update(transform);
      return AdminServicesResult.ok;
    } on edit.ItemGone {
      return AdminServicesResult.itemGone;
    } on edit.CategoryNotEmpty {
      return AdminServicesResult.categoryNotEmpty;
    } catch (e) {
      debugPrint('Error al guardar la lista de precios: $e');
      return AdminServicesResult.failed;
    }
  }

  /// Crea una categoría al final ([id] `null`) o cambia los textos de la
  /// categoría [id], sobre la versión guardada: conserva sus elementos, si
  /// está oculta y sus campos desconocidos (RF-21).
  Future<AdminServicesResult> saveCategory(
    String? id, {
    required BilingualText name,
    required BilingualText subtitle,
    required BilingualText note,
  }) {
    if (id == null) {
      final created = PriceCategoryModel(
        id: _newId(),
        name: name,
        subtitle: subtitle,
        note: note,
      );
      return _apply((list) => edit.upsertCategory(list, created, isNew: true));
    }
    return _apply((list) {
      final saved = list.categories.where((c) => c.id == id).firstOrNull;
      if (saved == null) throw edit.ItemGone(id);
      return edit.upsertCategory(
        list,
        saved.copyWith(name: name, subtitle: subtitle, note: note),
        isNew: false,
      );
    });
  }

  /// Crea un servicio o adicional al final de [categoryId] ([id] `null`) o
  /// cambia el elemento [id] sobre su versión guardada, conservando si está
  /// oculto y sus campos desconocidos. Si cambia de categoría, va al final
  /// de la nueva (RF-21, RF-32). Un adicional no guarda descripción, grupo,
  /// duración ni "desde".
  Future<AdminServicesResult> saveItem(
    String? id, {
    required String categoryId,
    required PriceItemKind kind,
    required BilingualText name,
    BilingualText description = BilingualText.empty,
    BilingualText group = BilingualText.empty,
    required int priceCents,
    bool priceFrom = false,
    int durationMinutes = defaultDurationMinutes,
  }) {
    final isService = kind == PriceItemKind.service;
    PriceItemModel fill(PriceItemModel item) => item.copyWith(
      kind: kind,
      name: name,
      description: isService ? description : BilingualText.empty,
      group: isService ? group : BilingualText.empty,
      priceCents: priceCents,
      priceFrom: isService && priceFrom,
      durationMinutes: isService ? durationMinutes : null,
    );

    if (id == null) {
      final created = fill(
        PriceItemModel(id: _newId(), kind: kind, name: name, priceCents: 0),
      );
      return _apply(
        (list) => edit.upsertItem(list, categoryId, created, isNew: true),
      );
    }
    return _apply((list) {
      final saved = list.categories
          .expand((c) => c.items)
          .where((i) => i.id == id)
          .firstOrNull;
      if (saved == null) throw edit.ItemGone(id);
      return edit.upsertItem(list, categoryId, fill(saved), isNew: false);
    });
  }

  /// Crea un combo al final ([id] `null`) o cambia el combo [id] sobre su
  /// versión guardada, conservando si está oculto y sus campos desconocidos
  /// (RF-21).
  Future<AdminServicesResult> saveCombo(
    String? id, {
    required BilingualText name,
    required BilingualText description,
    required int priceCents,
    required int durationMinutes,
  }) {
    ComboModel fill(ComboModel combo) => combo.copyWith(
      name: name,
      description: description,
      priceCents: priceCents,
      durationMinutes: durationMinutes,
    );

    if (id == null) {
      final created = fill(ComboModel(id: _newId(), name: name, priceCents: 0));
      return _apply((list) => edit.upsertCombo(list, created, isNew: true));
    }
    return _apply((list) {
      final saved = list.combos.where((c) => c.id == id).firstOrNull;
      if (saved == null) throw edit.ItemGone(id);
      return edit.upsertCombo(list, fill(saved), isNew: false);
    });
  }

  /// Sube (−1) o baja (+1) una categoría, servicio o combo (RF-26).
  Future<AdminServicesResult> moveCategory(String id, int offset) =>
      _apply((list) => edit.moveCategory(list, id, offset));

  Future<AdminServicesResult> moveItem(String id, int offset) =>
      _apply((list) => edit.moveItem(list, id, offset));

  Future<AdminServicesResult> moveCombo(String id, int offset) =>
      _apply((list) => edit.moveCombo(list, id, offset));

  /// Oculta o muestra sin borrar datos (RF-27).
  Future<AdminServicesResult> setCategoryVisible(String id, bool visible) =>
      _apply((list) => edit.setCategoryVisible(list, id, visible));

  Future<AdminServicesResult> setItemVisible(String id, bool visible) =>
      _apply((list) => edit.setItemVisible(list, id, visible));

  Future<AdminServicesResult> setComboVisible(String id, bool visible) =>
      _apply((list) => edit.setComboVisible(list, id, visible));

  /// Borra un elemento ya confirmado por la admin (RF-29, RF-31).
  Future<AdminServicesResult> deleteCategory(String id) =>
      _apply((list) => edit.deleteCategory(list, id));

  Future<AdminServicesResult> deleteItem(String id) =>
      _apply((list) => edit.deleteItem(list, id));

  Future<AdminServicesResult> deleteCombo(String id) =>
      _apply((list) => edit.deleteCombo(list, id));
}

final adminServicesControllerProvider = Provider(
  (ref) => AdminServicesController(
    ref.watch(priceListRepositoryProvider),
    ref.watch(configRepositoryProvider),
  ),
);
