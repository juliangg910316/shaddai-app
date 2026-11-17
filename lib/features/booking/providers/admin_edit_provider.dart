import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/appointment_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../admin/providers/admin_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../services/providers/price_list_provider.dart';
import '../logic/admin_edit.dart';
import '../logic/bookable_catalog.dart';
import '../logic/booking_edit.dart';
import '../logic/booking_selection.dart';
import '../logic/recipient.dart';
import '../logic/salon_time.dart';
import 'admin_booking_provider.dart';
import 'booking_provider.dart';

/// La edición de un turno por la admin (spec 008, RF-19 a RF-35; plan § 5).
///
/// Reutiliza la selección de la reserva y "Para quién" (plan D-2): al abrir
/// la edición guarda aparte lo que la admin tenía a medias para agendar, y al
/// cerrarla se lo devuelve.

/// El turno [id] en vivo, o `null` si no existe (RF-19, RF-30).
final adminEditAppointmentProvider =
    StreamProvider.family<AppointmentModel?, String>(
      (ref, id) => ref.watch(bookingRepositoryProvider).watchAppointment(id),
    );

/// El id del turno que edita la admin, o `null`.
class AdminEditController extends Notifier<String?> {
  /// Lo que la admin tenía elegido para agendar al abrir la edición (RF-33).
  BookingSelection? _savedSelection;
  Recipient? _savedRecipient;

  @override
  String? build() => null;

  /// Abre la edición de [appointment]: guarda aparte la selección y "Para
  /// quién", pone la persona del turno y carga su día, su hora y lo reservado
  /// (RF-19, RF-24).
  void start(AppointmentModel appointment) {
    if (state == null) {
      _savedSelection = ref.read(bookingSelectionProvider).selection;
      _savedRecipient = ref.read(bookingRecipientProvider).recipient;
    }
    ref
        .read(bookingRecipientProvider.notifier)
        .restore(recipientOf(EditOriginal.of(appointment)));
    ref.read(editTargetProvider.notifier).start(appointment);
    state = appointment.id;
  }

  /// Cierra la edición y devuelve lo que la admin tenía a medias, ajustado a
  /// los datos de ahora (RF-33, RF-35). Sin edición abierta, no hace nada.
  void end() {
    if (state == null) return;
    ref.read(editTargetProvider.notifier).end();
    ref
        .read(bookingSelectionProvider.notifier)
        .restore(_savedSelection ?? BookingSelection.empty);
    ref.read(bookingRecipientProvider.notifier).restore(_savedRecipient);
    _savedSelection = null;
    _savedRecipient = null;
    state = null;
  }

  static const _failed = AdminEditResult(AdminEditOutcome.failed);

  /// Guarda la edición tras comprobarla en el servidor (RF-28, plan § 5).
  /// Con [AdminEditOutcome.ok], cierra la edición.
  Future<AdminEditResult> save() async {
    final original = ref.read(editTargetProvider);
    final selection = ref.read(bookingSelectionProvider).selection;
    final recipient = ref.read(bookingRecipientProvider).recipient;
    if (state == null || original == null) return _failed;
    if (missingParts(selection, admin: true, recipient: recipient).isNotEmpty) {
      return const AdminEditResult(AdminEditOutcome.incomplete);
    }
    final start = selection.start!;
    final settings = ref.read(calendarSettingsProvider).value;
    final catalog = switch (ref.read(bookableCatalogProvider)) {
      PriceViewReady(:final value) => value,
      _ => null,
    };
    final bookable = catalog == null
        ? null
        : findBookable(catalog, selection.item!);
    if (settings == null || bookable == null) return _failed;
    final person = recipient!;
    if (adminEditChanges(original, person, selection, catalog!).isEmpty) {
      return const AdminEditResult(AdminEditOutcome.noChanges);
    }

    final repository = ref.read(bookingRepositoryProvider);
    final selector = ref.read(bookingSelectionProvider.notifier);
    final recipients = ref.read(bookingRecipientProvider.notifier);
    final saving = ref.read(_adminEditSavingProvider.notifier);
    final now = ref.read(clockProvider)();
    final nowSalon = toSalon(now);
    final day = salonDay(start);
    final String name;
    try {
      final data = await repository.fetchAdminEditCheck(
        appointmentId: original.id,
        from: fromSalon(day),
        to: fromSalon(day.add(const Duration(days: 1))),
        now: now,
      );
      final closures = await fetchClosureRanges(ref, day);
      final recipientUser = switch (person) {
        AccountRecipient(:final uid) =>
          await ref.read(userRepositoryProvider).fetchUser(uid),
        GuestRecipient() => null,
      };
      final check = checkAdminEditBeforeSave(
        original: original,
        current: data.appointment,
        recipient: person,
        recipientUser: recipientUser,
        users: ref.read(adminUsersProvider).value ?? const [],
        start: start,
        durationMinutes: bookable.durationMinutes,
        settings: settings,
        // Su propio turno ocupado no cuenta (RF-21).
        busy: [
          for (final slot in data.busy)
            if (slot.id != original.id)
              (start: toSalon(slot.start), end: toSalon(slot.end)),
        ],
        closures: closures,
        active: data.active,
        nowSalon: nowSalon,
      );
      switch (check) {
        case AdminEditNotActive():
          return const AdminEditResult(AdminEditOutcome.notActive);
        case AdminEditChanged():
          return const AdminEditResult(AdminEditOutcome.changed);
        case AdminEditRecipientBlocked():
          // Una clienta bloqueada se quita; la persona sin cuenta se conserva
          // para cambiar su WhatsApp (spec 007, RF-11, RF-15).
          if (person is AccountRecipient) recipients.dropBlocked();
          return const AdminEditResult(AdminEditOutcome.recipientBlocked);
        case AdminEditPersonActive(:final appointment):
          return AdminEditResult(
            AdminEditOutcome.personActive,
            active: appointment,
          );
        case AdminEditSlotTaken():
          selector.dropSlot();
          return const AdminEditResult(AdminEditOutcome.slotTaken);
        case AdminEditDoesNotFit():
          selector.dropSlot();
          return const AdminEditResult(AdminEditOutcome.doesNotFit);
        case AdminEditOk():
          break;
      }

      final AppointmentPerson personNow = switch (person) {
        AccountRecipient(:final uid) => (
          clientId: uid,
          clientName: recipientUser!.displayName,
          clientPhone: recipientUser.phoneNumber ?? person.phone,
          clientPhotoUrl: recipientUser.photoUrl,
        ),
        GuestRecipient(name: final guestName, phone: final guestPhone) => (
          clientId: null,
          clientName: guestName.trim(),
          clientPhone: guestPhone.trim(),
          clientPhotoUrl: null,
        ),
      };
      final addons = [
        for (final addon in availableAddons(catalog, selection.item!))
          if (selection.addonIds.contains(addon.id)) addon,
      ];
      final startTime = fromSalon(start);
      saving.set(true);
      final saved = await repository.updateAppointmentByAdmin(
        id: original.id,
        expected: (current) =>
            adminEditAlert(original, current, nowSalon) == null,
        start: startTime,
        end: startTime.add(Duration(minutes: bookable.durationMinutes)),
        booked: snapshotOf(bookable, addons),
        // La persona solo se escribe si cambió (RF-31).
        person: personChanged(original, person) ? personNow : null,
      );
      if (!saved) return const AdminEditResult(AdminEditOutcome.changed);
      name = personNow.clientName;
      end();
    } catch (error) {
      debugPrint('No se pudo guardar la edición de la admin: $error');
      return _failed;
    } finally {
      saving.set(false);
    }
    return AdminEditResult(AdminEditOutcome.ok, name: name, day: day);
  }
}

final adminEditProvider = NotifierProvider<AdminEditController, String?>(
  AdminEditController.new,
);

/// Cómo terminó "Guardar cambios" de la admin (RF-26, RF-28 a RF-31, RF-34).
enum AdminEditOutcome {
  ok,

  /// No cambió nada: no se guarda (RF-26).
  noChanges,

  /// Falta para quién, la hora o el servicio (RF-34).
  incomplete,
  slotTaken,
  doesNotFit,
  recipientBlocked,
  personActive,
  notActive,
  changed,

  /// Sin conexión o error al leer o guardar.
  failed,
}

class AdminEditResult {
  const AdminEditResult(this.outcome, {this.active, this.name, this.day});

  final AdminEditOutcome outcome;

  /// Con [AdminEditOutcome.personActive], el otro turno activo de la persona.
  final AppointmentModel? active;

  /// Con [AdminEditOutcome.ok], la persona del turno y su día (hora de pared),
  /// para volver a la agenda en ese día con el aviso (RF-28).
  final String? name;
  final DateTime? day;
}

/// Mientras se guarda, la vigilancia calla: el propio guardado cambia el
/// turno.
class _SavingController extends Notifier<bool> {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}

final _adminEditSavingProvider = NotifierProvider<_SavingController, bool>(
  _SavingController.new,
);

/// Si el turno que edita la admin se cancela, termina o cambia mientras lo
/// edita (RF-30). La vista lo avisa y vuelve a la agenda.
final adminEditAlertProvider = Provider<AdminEditAlert?>((ref) {
  final id = ref.watch(adminEditProvider);
  final original = ref.watch(editTargetProvider);
  if (id == null || original == null || original.id != id) return null;
  if (ref.watch(_adminEditSavingProvider)) return null;
  final current = ref.watch(adminEditAppointmentProvider(id));
  if (current.hasError || !current.hasValue) return null;
  final now =
      ref.watch(salonNowProvider).value ?? toSalon(ref.read(clockProvider)());
  return adminEditAlert(original, current.value, now);
});
