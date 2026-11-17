/// Turno activo de una persona y comprobación antes de guardar el turno que
/// agenda la admin, sin Flutter ni Firebase (spec 007, RF-11, RF-14, RF-15,
/// RF-18; plan § 4.3).
library;

import '../../../data/models/appointment_model.dart';
import '../../../data/models/calendar_settings_model.dart';
import '../../../data/models/user_model.dart';
import 'booking_rules.dart';
import 'free_slots.dart';
import 'recipient.dart';
import 'salon_time.dart';
import 'whatsapp.dart';

AppointmentTimes _timesOf(AppointmentModel appointment) => (
  start: appointment.startTime,
  end: appointment.endTime,
  status: appointment.status,
);

/// El turno activo de una persona en el instante [now]: entre los de su
/// cuenta [uid] (si tiene) y los que llevan su WhatsApp [phone], el que
/// empieza antes de los que terminan después de [now] y están esperando
/// confirmación o confirmados, como en la spec 005. `null` si no hay ninguno
/// (spec 007, "Turno activo de una persona").
AppointmentModel? activeAppointmentOfPerson(
  Iterable<AppointmentModel> appointments, {
  required String? uid,
  required String phone,
  required DateTime now,
}) => activeAppointment(
  appointments.where(
    (a) =>
        (uid != null && a.clientId == uid) ||
        sameWhatsApp(a.clientPhone, phone),
  ),
  times: _timesOf,
  now: now,
);

/// Resultado de la comprobación antes de guardar el turno de la admin.
sealed class AdminBookingCheck {
  const AdminBookingCheck();
}

class AdminCheckOk extends AdminBookingCheck {
  const AdminCheckOk();
}

/// La clienta elegida está bloqueada, ya no existe o ya no es clienta, o la
/// persona sin cuenta tiene el WhatsApp de una bloqueada (RF-11, RF-15).
class AdminCheckRecipientBlocked extends AdminBookingCheck {
  const AdminCheckRecipientBlocked();
}

/// La persona ya tiene un turno activo (RF-14): [appointment].
class AdminCheckPersonActive extends AdminBookingCheck {
  const AdminCheckPersonActive(this.appointment);

  final AppointmentModel appointment;
}

/// La hora ya no es libre: ocupada, pasada o fuera de la rejilla (RF-18).
class AdminCheckSlotTaken extends AdminBookingCheck {
  const AdminCheckSlotTaken();
}

/// El servicio ya no cabe en la hora (RF-18).
class AdminCheckDoesNotFit extends AdminBookingCheck {
  const AdminCheckDoesNotFit();
}

/// Comprueba otra vez, justo antes de guardar, el turno de la admin para
/// [recipient] que empieza en [start] (hora de pared) y dura
/// [durationMinutes] (RF-18). En este orden:
///
/// 1. [recipientUser] (la ficha de la clienta leída del servidor, `null` si
///    no existe) no está bloqueada y es clienta; o, sin cuenta, su WhatsApp
///    no es el de una clienta bloqueada de [users] (RF-11, RF-15).
/// 2. La persona no tiene un turno activo entre [active] (RF-14). Con
///    cuenta, se busca también por el WhatsApp actual de su ficha.
/// 3. La hora sigue libre y el servicio cabe, con [busy] ese día (RF-18).
AdminBookingCheck checkAdminBeforeSave({
  required DateTime start,
  required int durationMinutes,
  required CalendarSettingsModel settings,
  required Iterable<BusyRange> busy,
  Iterable<BusyRange> closures = const [],
  required Iterable<AppointmentModel> active,
  required Recipient recipient,
  required UserModel? recipientUser,
  required Iterable<UserModel> users,
  required DateTime nowSalon,
}) {
  final problem = checkRecipient(
    recipient: recipient,
    recipientUser: recipientUser,
    users: users,
    active: active,
    nowSalon: nowSalon,
  );
  if (problem != null) return problem;

  return switch (checkSlot(
    start: start,
    durationMinutes: durationMinutes,
    settings: settings,
    busy: busy,
    closures: closures,
    nowSalon: nowSalon,
  )) {
    BookingCheck.slotTaken => const AdminCheckSlotTaken(),
    BookingCheck.doesNotFit => const AdminCheckDoesNotFit(),
    BookingCheck.ok || BookingCheck.alreadyActive => const AdminCheckOk(),
  };
}

/// Los pasos 1 y 2 de [checkAdminBeforeSave]: la persona está bloqueada
/// ([AdminCheckRecipientBlocked]) o ya tiene un turno activo entre [active]
/// ([AdminCheckPersonActive]); `null` si puede tener el turno. La edición de
/// la admin la reutiliza sin el turno que edita (spec 008, RF-25, RF-29).
AdminBookingCheck? checkRecipient({
  required Recipient recipient,
  required UserModel? recipientUser,
  required Iterable<UserModel> users,
  required Iterable<AppointmentModel> active,
  required DateTime nowSalon,
}) {
  final String? uid;
  final String phone;
  switch (recipient) {
    case AccountRecipient(uid: final id):
      if (recipientUser == null ||
          recipientUser.role != 'cliente' ||
          recipientUser.isBlocked) {
        return const AdminCheckRecipientBlocked();
      }
      uid = id;
      phone = recipientUser.phoneNumber ?? recipient.phone;
    case GuestRecipient(phone: final guestPhone):
      if (accountWithPhone(users, guestPhone)?.isBlocked ?? false) {
        return const AdminCheckRecipientBlocked();
      }
      uid = null;
      phone = guestPhone;
  }

  final existing = activeAppointmentOfPerson(
    active,
    uid: uid,
    phone: phone,
    now: fromSalon(nowSalon),
  );
  if (existing != null) return AdminCheckPersonActive(existing);
  return null;
}
