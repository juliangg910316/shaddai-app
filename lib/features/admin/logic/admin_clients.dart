/// La lista de clientas y el bloqueo, sin Flutter ni Firebase (spec 010,
/// plan § 4). Las funciones reciben "ahora" como parámetro.
library;

import '../../../data/models/appointment_model.dart';
import '../../../data/models/user_model.dart';
import '../../booking/logic/booking_rules.dart';
import '../../booking/logic/recipient.dart';

/// Las clientas de [users], sin las admins, por nombre sin distinguir
/// mayúsculas ni acentos; si empatan, por el nombre tal cual y luego por su
/// uid, para que el orden no salte (RF-19, RF-20). Las bloqueadas también.
List<UserModel> clientsForAdmin(Iterable<UserModel> users) {
  final clients = [
    for (final user in users)
      if (user.role == 'cliente') user,
  ];
  clients.sort((a, b) {
    final byFolded = foldText(a.displayName).compareTo(foldText(b.displayName));
    if (byFolded != 0) return byFolded;
    final byName = a.displayName.compareTo(b.displayName);
    return byName != 0 ? byName : a.uid.compareTo(b.uid);
  });
  return clients;
}

/// El turno activo de la clienta con la cuenta [uid] en el instante [now],
/// o `null`. Solo cuentan los de su cuenta, no los que llevan su WhatsApp:
/// el de una persona sin cuenta con su número no es suyo (plan D-6, RF-26).
AppointmentModel? clientActiveAppointment(
  Iterable<AppointmentModel> appointments, {
  required String uid,
  required DateTime now,
}) => activeAppointment(
  appointments.where((a) => a.clientId == uid),
  times: (a) => (start: a.startTime, end: a.endTime, status: a.status),
  now: now,
);

/// Resultado de la comprobación justo antes de bloquear (RF-28).
enum BlockCheck {
  ok,

  /// Su turno activo no es el que mostraba el diálogo.
  changed,
}

/// Compara el turno activo que mostraba el diálogo ([shown], `null` si no
/// tenía) con el que tiene ahora en el servidor ([current]). El estado no
/// cuenta: si solo se confirmó, se bloquea igual y se cancela (plan D-5).
BlockCheck checkBlockBeforeSave({
  required AppointmentModel? shown,
  required AppointmentModel? current,
}) {
  if (shown == null && current == null) return BlockCheck.ok;
  if (shown == null || current == null) return BlockCheck.changed;
  final same =
      shown.id == current.id &&
      shown.startTime.isAtSameMomentAs(current.startTime) &&
      shown.endTime.isAtSameMomentAs(current.endTime) &&
      shown.booked == current.booked;
  return same ? BlockCheck.ok : BlockCheck.changed;
}
