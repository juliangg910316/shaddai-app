import 'dart:async';

import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/closure_model.dart';
import 'package:shaddai/data/repositories/config_repository.dart';

/// El calendario y los cierres en memoria, sin Firebase (spec 008, plan § 9).
///
/// [settings] y [closures] llegan en vivo: [emitSettings] y [emitClosures]
/// los cambian y los envían a quien escucha; [failClosures] envía un error.
/// Como la consulta de Firestore, [watchClosures] y [fetchClosures] solo dan
/// los cierres que terminan en "desde" o después; [fetchClosures] lanza
/// [fetchClosuresError] si lo hay.
///
/// Guardar o borrar lanza [saveError] si lo hay y no cambia nada; si no, lo
/// registra ([created], [deleted], [removedBlockedDates], [margins],
/// [updatedSettings]) y lo envía en vivo. [updateSettings] conserva el
/// margen y las fechas bloqueadas, como `merge` sin esos campos.
class FakeConfigRepository implements ConfigRepository {
  FakeConfigRepository({
    CalendarSettingsModel? settings,
    this.closures = const [],
  }) : settings = settings ?? CalendarSettingsModel.defaultSettings();

  CalendarSettingsModel settings;
  List<ClosureModel> closures;

  final _settingsListeners = <StreamController<CalendarSettingsModel>>[];
  final _closureListeners =
      <({DateTime from, StreamController<List<ClosureModel>> controller})>[];

  /// "Desde" pedido a [watchClosures], en orden.
  final closureRequests = <DateTime>[];

  /// "Desde" pedido a [fetchClosures], en orden.
  final closureFetches = <DateTime>[];
  Object? fetchClosuresError;

  Object? saveError;
  final created = <ClosureModel>[];
  final deleted = <String>[];
  final removedBlockedDates = <String>[];
  final margins = <int>[];
  final updatedSettings = <CalendarSettingsModel>[];

  @override
  Duration get saveTimeout => const Duration(seconds: 15);

  List<ClosureModel> _from(DateTime from) => [
    for (final closure in closures)
      if (!closure.end.isBefore(from)) closure,
  ];

  void emitSettings(CalendarSettingsModel value) {
    settings = value;
    for (final listener in List.of(_settingsListeners)) {
      listener.add(value);
    }
  }

  void emitClosures(List<ClosureModel> value) {
    closures = value;
    for (final listener in List.of(_closureListeners)) {
      listener.controller.add(_from(listener.from));
    }
  }

  void failClosures(Object error) {
    for (final listener in List.of(_closureListeners)) {
      listener.controller.addError(error);
    }
  }

  @override
  Stream<CalendarSettingsModel> getCalendarSettings() {
    late final StreamController<CalendarSettingsModel> controller;
    controller = StreamController(
      onListen: () => controller.add(settings),
      onCancel: () => _settingsListeners.remove(controller),
    );
    _settingsListeners.add(controller);
    return controller.stream;
  }

  @override
  Stream<List<ClosureModel>> watchClosures(DateTime from) {
    closureRequests.add(from);
    late final StreamController<List<ClosureModel>> controller;
    late final ({
      DateTime from,
      StreamController<List<ClosureModel>> controller,
    })
    entry;
    controller = StreamController(
      onListen: () => controller.add(_from(from)),
      onCancel: () => _closureListeners.remove(entry),
    );
    entry = (from: from, controller: controller);
    _closureListeners.add(entry);
    return controller.stream;
  }

  @override
  Future<List<ClosureModel>> fetchClosures(DateTime from) async {
    closureFetches.add(from);
    final error = fetchClosuresError;
    if (error != null) throw error;
    return _from(from);
  }

  void _checkSave() {
    final error = saveError;
    if (error != null) throw error;
  }

  @override
  Future<void> createClosure(ClosureModel closure) async {
    _checkSave();
    created.add(closure);
    emitClosures([...closures, closure]);
  }

  @override
  Future<void> deleteClosure(String id) async {
    _checkSave();
    deleted.add(id);
    emitClosures([
      for (final closure in closures)
        if (closure.id != id) closure,
    ]);
  }

  @override
  Future<void> removeBlockedDate(String key) async {
    _checkSave();
    removedBlockedDates.add(key);
    emitSettings(
      CalendarSettingsModel(
        openingHours: settings.openingHours,
        globalSlotDurationMinutes: settings.globalSlotDurationMinutes,
        blockedDates: [
          for (final date in settings.blockedDates)
            if (date != key) date,
        ],
        editMarginMinutes: settings.editMarginMinutes,
      ),
    );
  }

  @override
  Future<void> updateEditMargin(int minutes) async {
    _checkSave();
    margins.add(minutes);
    emitSettings(
      CalendarSettingsModel(
        openingHours: settings.openingHours,
        globalSlotDurationMinutes: settings.globalSlotDurationMinutes,
        blockedDates: settings.blockedDates,
        editMarginMinutes: minutes,
      ),
    );
  }

  @override
  Future<void> updateSettings(CalendarSettingsModel value) async {
    _checkSave();
    updatedSettings.add(value);
    emitSettings(
      CalendarSettingsModel(
        openingHours: value.openingHours,
        globalSlotDurationMinutes: value.globalSlotDurationMinutes,
        blockedDates: settings.blockedDates,
        editMarginMinutes: settings.editMarginMinutes,
      ),
    );
  }
}
