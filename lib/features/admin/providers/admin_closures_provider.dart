import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/appointment_model.dart';
import '../../../data/models/closure_model.dart';
import '../../booking/logic/booking_rules.dart';
import '../../booking/logic/closures.dart';
import '../../booking/logic/free_slots.dart';
import '../../booking/logic/salon_time.dart';
import '../../booking/providers/booking_provider.dart';
import '../logic/admin_agenda.dart';
import 'admin_provider.dart';

/// Los cierres de la agenda que ve la admin y los cambios que hace (spec
/// 008, RF-1 a RF-11; plan § 5).

DateTime _salonNow(Ref ref) =>
    ref.watch(salonNowProvider).value ?? toSalon(ref.read(clockProvider)());

/// Los cierres próximos y las fechas bloqueadas existentes, en orden (RF-1,
/// RF-2, RF-8). Con el error de los cierres o del calendario si falla alguno
/// (RF-10), aunque Riverpod esté reintentando (MEMORY).
final adminClosureEntriesProvider = Provider<AsyncValue<List<ClosureEntry>>>((
  ref,
) {
  final closures = ref.watch(closuresProvider);
  final settings = ref.watch(calendarSettingsProvider);
  if (closures.hasError) {
    return AsyncError(closures.error!, closures.stackTrace!);
  }
  if (settings.hasError) {
    return AsyncError(settings.error!, settings.stackTrace!);
  }
  final stored = closures.value;
  final calendar = settings.value;
  if (stored == null || calendar == null) return const AsyncLoading();
  return AsyncData(
    closureEntries(
      closures: [for (final closure in stored) closure.stored],
      blockedDates: calendar.blockedDates,
      nowSalon: _salonNow(ref),
    ),
  );
});

/// Los cierres que terminan desde el día de la agenda, en vivo: también un
/// día pasado muestra los suyos (RF-9). "Reintentar" lo invalida (RF-10).
final adminAgendaClosuresProvider = StreamProvider<List<ClosureModel>>((ref) {
  final day = ref.watch(adminSelectedDateProvider.select(agendaDay));
  return ref.watch(configRepositoryProvider).watchClosures(fromSalon(day));
});

/// Los cierres y las fechas bloqueadas que se cruzan con el día de la agenda,
/// ordenados por su inicio (RF-9). Con el error si falla (RF-10).
final adminDayClosuresProvider = Provider<AsyncValue<List<ClosureEntry>>>((
  ref,
) {
  final day = agendaDay(ref.watch(adminSelectedDateProvider));
  final closures = ref.watch(adminAgendaClosuresProvider);
  final settings = ref.watch(calendarSettingsProvider);
  if (closures.hasError) {
    return AsyncError(closures.error!, closures.stackTrace!);
  }
  if (settings.hasError) {
    return AsyncError(settings.error!, settings.stackTrace!);
  }
  final stored = closures.value;
  final calendar = settings.value;
  if (stored == null || calendar == null) return const AsyncLoading();
  final entries = closureEntries(
    closures: [for (final closure in stored) closure.stored],
    blockedDates: calendar.blockedDates,
    // Desde las 0:00 del día: lo que ya terminó ese día también se ve.
    nowSalon: day,
  );
  return AsyncData(closuresOfDay(entries, day));
});

/// Cómo terminó "Guardar" un cierre.
sealed class ClosureSaveResult {
  const ClosureSaveResult();
}

/// Lo elegido está mal (RF-4).
class ClosureSaveInvalid extends ClosureSaveResult {
  const ClosureSaveInvalid(this.errors);

  final Set<ClosureError> errors;
}

/// Hay turnos que chocan: no se guardó (RF-5).
class ClosureSaveConflicts extends ClosureSaveResult {
  const ClosureSaveConflicts(this.appointments);

  /// Ordenados por su inicio.
  final List<AppointmentModel> appointments;
}

/// Se guardó (RF-6).
class ClosureSaveOk extends ClosureSaveResult {
  const ClosureSaveOk();
}

/// No se pudo leer o guardar (RF-11).
class ClosureSaveFailed extends ClosureSaveResult {
  const ClosureSaveFailed();
}

AppointmentTimes _timesOf(AppointmentModel appointment) => (
  start: appointment.startTime,
  end: appointment.endTime,
  status: appointment.status,
);

/// Guarda y quita cierres (RF-3 a RF-8, RF-11).
class ClosureController {
  ClosureController(this._ref);

  final Ref _ref;

  /// Comprueba [draft] y, si vale, lee del servidor los turnos activos justo
  /// antes de guardar: si alguno choca, los devuelve sin guardar (RF-5,
  /// RF-6, plan D-4).
  Future<ClosureSaveResult> save(ClosureDraft draft) async {
    final now = _ref.read(clockProvider)();
    final nowSalon = toSalon(now);
    final errors = closureErrors(draft, nowSalon: nowSalon);
    if (errors.isNotEmpty) return ClosureSaveInvalid(errors);

    final range = closureRange(draft);
    try {
      final conflicts = await _fetchConflicts(range, now);
      if (conflicts.isNotEmpty) return ClosureSaveConflicts(conflicts);
      await _ref
          .read(configRepositoryProvider)
          .createClosure(
            ClosureModel(
              id: const Uuid().v4(),
              start: fromSalon(range.start),
              end: fromSalon(range.end),
            ),
          );
    } catch (error) {
      debugPrint('No se pudo guardar el cierre: $error');
      return const ClosureSaveFailed();
    }
    return const ClosureSaveOk();
  }

  /// Los turnos activos que chocan ahora con [draft], leídos del servidor,
  /// sin guardar nada: el formulario los vuelve a pedir al terminar la
  /// edición de uno (spec 008, Navegación). `null` si [draft] no vale o no
  /// se pueden leer.
  Future<List<AppointmentModel>?> conflicts(ClosureDraft draft) async {
    final now = _ref.read(clockProvider)();
    if (closureErrors(draft, nowSalon: toSalon(now)).isNotEmpty) return null;
    try {
      return await _fetchConflicts(closureRange(draft), now);
    } catch (error) {
      debugPrint('No se pudieron comprobar los choques del cierre: $error');
      return null;
    }
  }

  Future<List<AppointmentModel>> _fetchConflicts(
    BusyRange range,
    DateTime now,
  ) async {
    final active = await _ref
        .read(bookingRepositoryProvider)
        .fetchActiveAppointments(now);
    return closureConflicts(
      range,
      active,
      times: _timesOf,
      nowSalon: toSalon(now),
    );
  }

  /// Quita [entry]: borra el cierre o quita la fecha bloqueada existente
  /// (RF-7, RF-8). `false` si falla (RF-11).
  Future<bool> delete(ClosureEntry entry) async {
    final config = _ref.read(configRepositoryProvider);
    try {
      switch (entry.source) {
        case StoredClosureSource(:final id):
          await config.deleteClosure(id);
        case BlockedDateSource(:final key):
          await config.removeBlockedDate(key);
      }
    } catch (error) {
      debugPrint('No se pudo quitar el cierre: $error');
      return false;
    }
    return true;
  }
}

final closureControllerProvider = Provider(ClosureController.new);
