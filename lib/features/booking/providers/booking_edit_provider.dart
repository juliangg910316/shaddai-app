import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/appointment_model.dart';
import '../../services/providers/price_list_provider.dart';
import '../logic/bookable_catalog.dart';
import '../logic/booking_edit.dart';
import '../logic/booking_rules.dart';
import '../logic/salon_time.dart';
import 'booking_provider.dart';

export 'booking_provider.dart' show EditTargetController, editTargetProvider;

/// Qué se ve bajo el turno activo (spec 006, RF-1 a RF-3, RF-22): el botón
/// "Editar turno", el aviso de que ya no se puede cambiar, el del error del
/// calendario o, si está bloqueada, nada más que su aviso. `null` sin turno
/// activo. Cambia en vivo con la ficha, el calendario y "ahora".
final editAvailabilityProvider = Provider<EditAvailability?>((ref) {
  final screen = ref.watch(bookingScreenProvider);
  final (appointment, isBlocked) = switch (screen) {
    BookingScreenActive(:final appointment, :final isBlocked) => (
      appointment,
      isBlocked,
    ),
    BookingScreenEditing(:final appointment) => (appointment, false),
    _ => (null, false),
  };
  if (appointment == null) return null;
  final settings = ref.watch(calendarSettingsProvider);
  final now =
      ref.watch(salonNowProvider).value ?? toSalon(ref.read(clockProvider)());
  return editAvailability(
    isBlocked: isBlocked,
    settingsError: settings.hasError,
    marginMinutes: settings.value?.editMarginMinutes,
    start: appointment.startTime,
    now: fromSalon(now),
  );
});

/// Cómo terminó "Guardar cambios" (RF-12 a RF-17).
enum EditSaveOutcome {
  ok,
  slotTaken,
  doesNotFit,
  notEditable,
  notActive,
  changed,
  failed,
}

/// El resultado de guardar la edición. Con [EditSaveOutcome.ok], [changes]
/// son los valores que cambiaron (vacío si no cambió nada, RF-17).
class EditSaveResult {
  const EditSaveResult(this.outcome, [this.changes = const {}]);

  final EditSaveOutcome outcome;
  final Set<EditField> changes;
}

/// Guarda la edición del turno tras comprobarla en el servidor (plan D-5).
class BookingEditor {
  BookingEditor(this._ref);

  final Ref _ref;

  /// Comprueba y guarda lo elegido. Con la hora ocupada o sin sitio, quita la
  /// hora y conserva lo demás (RF-14). Si el turno ya no es editable, no
  /// está activo o cambió, termina la edición (RF-15), igual que al guardar.
  /// Si falla, no toca nada para poder reintentar (RF-16).
  Future<EditSaveResult> save() async {
    const failed = EditSaveResult(EditSaveOutcome.failed);
    final original = _ref.read(editTargetProvider);
    final selection = _ref.read(bookingSelectionProvider).selection;
    final start = selection.start;
    final item = selection.item;
    final settings = _ref.read(calendarSettingsProvider).value;
    final catalog = switch (_ref.read(bookableCatalogProvider)) {
      PriceViewReady(:final value) => value,
      _ => null,
    };
    final bookable = item == null || catalog == null
        ? null
        : findBookable(catalog, item);
    if (original == null ||
        start == null ||
        bookable == null ||
        settings == null) {
      return failed;
    }

    final repository = _ref.read(bookingRepositoryProvider);
    final selector = _ref.read(bookingSelectionProvider.notifier);
    final target = _ref.read(editTargetProvider.notifier);
    final day = salonDay(start);
    final EditSaveOutcome outcome;
    try {
      final data = await repository.fetchEditCheck(
        appointmentId: original.id,
        from: fromSalon(day),
        to: fromSalon(day.add(const Duration(days: 1))),
      );
      final closures = await fetchClosureRanges(_ref, day);
      final check = checkEditBeforeSave(
        original: original,
        current: data.appointment,
        start: start,
        durationMinutes: bookable.durationMinutes,
        settings: settings,
        busy: [
          for (final slot in data.busy)
            if (slot.id != original.id)
              (start: toSalon(slot.start), end: toSalon(slot.end)),
        ],
        closures: closures,
        nowSalon: toSalon(_ref.read(clockProvider)()),
        marginMinutes: settings.editMarginMinutes,
      );
      if (check != EditCheck.ok) {
        outcome = switch (check) {
          EditCheck.slotTaken => EditSaveOutcome.slotTaken,
          EditCheck.doesNotFit => EditSaveOutcome.doesNotFit,
          EditCheck.notEditable => EditSaveOutcome.notEditable,
          EditCheck.notActive => EditSaveOutcome.notActive,
          EditCheck.changed || EditCheck.ok => EditSaveOutcome.changed,
        };
      } else {
        final addons = [
          for (final addon in availableAddons(catalog!, item!))
            if (selection.addonIds.contains(addon.id)) addon,
        ];
        final startTime = fromSalon(start);
        final saved = await repository
            .updateEditedAppointment(
              id: original.id,
              expected: (current) =>
                  current != null && _same(current, original),
              start: startTime,
              end: startTime.add(Duration(minutes: bookable.durationMinutes)),
              booked: snapshotOf(bookable, addons),
            )
            .timeout(repository.saveTimeout);
        outcome = saved ? EditSaveOutcome.ok : EditSaveOutcome.changed;
      }
    } catch (error) {
      debugPrint('No se pudo guardar la edición del turno: $error');
      return failed;
    }

    switch (outcome) {
      case EditSaveOutcome.slotTaken || EditSaveOutcome.doesNotFit:
        selector.dropSlot();
      case EditSaveOutcome.ok:
        final changes = changedFields(
          draftOfOriginal(original),
          draftOfSelection(selection, catalog!)!,
        );
        target.end();
        return EditSaveResult(outcome, changes);
      case EditSaveOutcome.notEditable ||
          EditSaveOutcome.notActive ||
          EditSaveOutcome.changed:
        target.end();
      case EditSaveOutcome.failed:
        break;
    }
    return EditSaveResult(outcome);
  }

  /// Si [current] sigue como al abrir la edición (RF-12).
  static bool _same(AppointmentModel current, EditOriginal original) {
    final now = EditOriginal.of(current);
    return now.start == original.start &&
        now.end == original.end &&
        now.status == original.status &&
        now.booked == original.booked;
  }
}

final bookingEditSaveProvider = Provider(BookingEditor.new);
