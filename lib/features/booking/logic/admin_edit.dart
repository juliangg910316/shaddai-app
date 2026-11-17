/// La edición de un turno por la admin, sin Flutter ni Firebase (spec 008,
/// RF-19 a RF-31; plan § 4.4). Todos los días y horas son horas de pared del
/// salón, salvo los turnos, que llegan como instantes.
library;

import '../../../data/models/appointment_model.dart';
import '../../../data/models/calendar_settings_model.dart';
import '../../../data/models/user_model.dart';
import 'admin_booking.dart';
import 'bookable_catalog.dart';
import 'booking_edit.dart';
import 'booking_rules.dart';
import 'booking_selection.dart';
import 'free_slots.dart';
import 'recipient.dart';
import 'salon_time.dart';
import 'whatsapp.dart';

/// La persona del turno [original], como la elige la admin al agendar
/// (RF-19). Sin cuenta, con la casilla de que acepta ya marcada (RF-24).
Recipient recipientOf(EditOriginal original) => switch (original.clientId) {
  final uid? => AccountRecipient(
    uid: uid,
    name: original.clientName,
    phone: original.clientPhone,
    photoUrl: original.clientPhotoUrl,
  ),
  null => GuestRecipient(
    name: original.clientName,
    phone: original.clientPhone,
    consent: true,
  ),
};

/// Si [recipient] es otra persona que la del turno [original] (RF-23,
/// RF-24, RF-31). Con cuenta, cuenta el uid: los datos de su ficha pueden
/// haber cambiado. Sin cuenta, el nombre sin espacios alrededor y el
/// WhatsApp aunque tenga otro formato.
bool personChanged(EditOriginal original, Recipient recipient) =>
    switch (recipient) {
      AccountRecipient(:final uid) => original.clientId != uid,
      GuestRecipient(:final name, :final phone) =>
        original.clientId != null ||
            original.clientName.trim() != name.trim() ||
            !sameWhatsApp(original.clientPhone, phone),
    };

/// Lo que cambia la admin en un turno: los valores del antes y el después y
/// si cambia la persona (RF-26, RF-27).
class AdminEditChanges {
  const AdminEditChanges({required this.fields, required this.person});

  final Set<EditField> fields;
  final bool person;

  /// Sin cambios: no se guarda (RF-26).
  bool get isEmpty => fields.isEmpty && !person;
}

/// Lo que cambia de [original] a [recipient] y [selection], con los precios y
/// la duración actuales de [catalog]. Sin servicio que se pueda reservar,
/// cuenta como un cambio de lo reservado.
AdminEditChanges adminEditChanges(
  EditOriginal original,
  Recipient recipient,
  BookingSelection selection,
  BookableCatalog catalog,
) {
  final after = draftOfSelection(selection, catalog);
  return AdminEditChanges(
    fields: after == null
        ? const {EditField.item}
        : changedFields(draftOfOriginal(original), after),
    person: personChanged(original, recipient),
  );
}

/// Si el turno queda marcado como "agendado por la admin" (RF-31): lo
/// conserva si lo tenía y se lo pone si cambió la persona.
bool markAfterEdit(EditOriginal original, Recipient recipient) =>
    original.createdByAdmin || personChanged(original, recipient);

/// Resultado de la comprobación antes de guardar la edición de la admin.
sealed class AdminEditCheck {
  const AdminEditCheck();
}

class AdminEditOk extends AdminEditCheck {
  const AdminEditOk();
}

/// El turno ya no existe, se canceló o terminó (RF-30).
class AdminEditNotActive extends AdminEditCheck {
  const AdminEditNotActive();
}

/// Alguien cambió el turno desde que se abrió la edición (RF-30).
class AdminEditChanged extends AdminEditCheck {
  const AdminEditChanged();
}

/// La persona está bloqueada o ya no es clienta, o, sin cuenta, tiene el
/// WhatsApp de una bloqueada (RF-29).
class AdminEditRecipientBlocked extends AdminEditCheck {
  const AdminEditRecipientBlocked();
}

/// La persona ya tiene otro turno activo (RF-25): [appointment].
class AdminEditPersonActive extends AdminEditCheck {
  const AdminEditPersonActive(this.appointment);

  final AppointmentModel appointment;
}

/// La hora ya no es libre (RF-29).
class AdminEditSlotTaken extends AdminEditCheck {
  const AdminEditSlotTaken();
}

/// El servicio ya no cabe en la hora (RF-29).
class AdminEditDoesNotFit extends AdminEditCheck {
  const AdminEditDoesNotFit();
}

/// Si [current] (el turno leído del servidor) es distinto de [original] en
/// lo que la admin vio al abrir la edición: horas, estado, lo reservado, la
/// persona o la marca.
bool _changedSince(EditOriginal original, AppointmentModel current) {
  final now = EditOriginal.of(current);
  return now.start != original.start ||
      now.end != original.end ||
      now.status != original.status ||
      now.booked != original.booked ||
      now.clientId != original.clientId ||
      now.clientName != original.clientName ||
      now.clientPhone != original.clientPhone ||
      now.clientPhotoUrl != original.clientPhotoUrl ||
      now.createdByAdmin != original.createdByAdmin;
}

/// Lo que avisa la edición de la admin si el turno cambia mientras lo edita
/// (RF-30).
enum AdminEditAlert {
  /// Ya no existe, se canceló o terminó.
  notActive,

  /// Alguien lo cambió.
  changed,
}

/// Si el turno [current] (`null` si ya no existe) ya no es el [original] que
/// abrió la admin con "ahora" [nowSalon]: no activo antes que cambiado
/// (RF-30). `null` si sigue igual.
AdminEditAlert? adminEditAlert(
  EditOriginal original,
  AppointmentModel? current,
  DateTime nowSalon,
) {
  if (current == null ||
      !activeStatuses.contains(current.status) ||
      !toSalon(current.endTime).isAfter(nowSalon)) {
    return AdminEditAlert.notActive;
  }
  if (_changedSince(original, current)) return AdminEditAlert.changed;
  return null;
}

/// Comprueba otra vez, justo antes de guardar, la edición de [original] por
/// la admin (RF-28). [current] es el turno leído del servidor (`null` si ya
/// no existe); [recipient], la persona elegida, y [recipientUser], su ficha
/// leída del servidor; [busy], los turnos ocupados del día de [start] sin el
/// propio; [active], los turnos activos. Sin margen de edición (RF-22).
///
/// En este orden, para dar el motivo más útil: no activo, cambiado, persona
/// bloqueada, persona con otro turno activo, hora ocupada y no cabe.
AdminEditCheck checkAdminEditBeforeSave({
  required EditOriginal original,
  required AppointmentModel? current,
  required Recipient recipient,
  required UserModel? recipientUser,
  required Iterable<UserModel> users,
  required DateTime start,
  required int durationMinutes,
  required CalendarSettingsModel settings,
  required Iterable<BusyRange> busy,
  Iterable<BusyRange> closures = const [],
  required Iterable<AppointmentModel> active,
  required DateTime nowSalon,
}) {
  switch (adminEditAlert(original, current, nowSalon)) {
    case AdminEditAlert.notActive:
      return const AdminEditNotActive();
    case AdminEditAlert.changed:
      return const AdminEditChanged();
    case null:
      break;
  }

  switch (checkRecipient(
    recipient: recipient,
    recipientUser: recipientUser,
    users: users,
    active: [
      for (final appointment in active)
        if (appointment.id != original.id) appointment,
    ],
    nowSalon: nowSalon,
  )) {
    case AdminCheckRecipientBlocked():
      return const AdminEditRecipientBlocked();
    case AdminCheckPersonActive(:final appointment):
      return AdminEditPersonActive(appointment);
    case null ||
        AdminCheckOk() ||
        AdminCheckSlotTaken() ||
        AdminCheckDoesNotFit():
      break;
  }

  FreeSlot? slot;
  for (final free in editFreeSlots(
    day: salonDay(start),
    settings: settings,
    busy: [...busy, ...closures],
    nowSalon: nowSalon,
    original: original,
    allowStarted: true,
  )) {
    if (free.start == start) slot = free;
  }
  if (slot == null) return const AdminEditSlotTaken();
  if (!fits(durationMinutes, slot)) return const AdminEditDoesNotFit();
  return const AdminEditOk();
}
