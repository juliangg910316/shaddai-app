import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/foundation.dart';

import '../models/appointment_model.dart';
import '../models/booked_service_model.dart';

/// Por qué el servidor no escribió en la agenda (spec 012, plan § 6). La
/// app traduce cada motivo al aviso que ya da su propia comprobación.
enum AgendaRejection {
  /// Otro turno ocupa esa hora (RF-1 a RF-3).
  slotTaken,

  /// Un cierre o una fecha bloqueada (RF-4).
  closed,

  /// Fuera del horario o de la rejilla de horas (RF-9).
  outsideHours,

  /// Fuera de la ventana de reserva (RF-10).
  outsideWindow,

  /// La hora ya pasó.
  past,

  /// El servicio no cabe hasta el siguiente turno o el cierre (RF-9, RF-11).
  doesNotFit,

  /// La clienta ya tiene un turno activo (RF-6, RF-8).
  alreadyActive,

  /// La persona de la admin ya tiene un turno activo (RF-6, RF-7).
  personActive,

  /// La clienta destinataria está bloqueada.
  recipientBlocked,

  /// El servicio, el combo o un adicional ya no se ofrece (RF-12).
  itemUnavailable,

  /// Cambió el nombre, el precio o la duración en la lista (RF-12).
  itemChanged,

  /// La edición encontró el turno cancelado, terminado o borrado.
  notActive,

  /// Alguien cambió el turno desde que se abrió la edición.
  changed,

  /// El turno ya no se puede editar (margen, bloqueo u otra dueña).
  notEditable,

  /// La clienta está bloqueada.
  blocked,

  /// El cierre pisa turnos activos: sus ids en `conflictIds` (RF-5).
  conflicts,

  /// Los datos no tienen la forma que espera el servidor.
  invalid,

  /// Sin ficha, o sin ser la admin.
  notAllowed,

  /// Sin conexión u otro fallo: se puede reintentar (RF-17).
  failed,
}

const _reasons = {
  'slot_taken': AgendaRejection.slotTaken,
  'closed': AgendaRejection.closed,
  'outside_hours': AgendaRejection.outsideHours,
  'outside_window': AgendaRejection.outsideWindow,
  'past': AgendaRejection.past,
  'does_not_fit': AgendaRejection.doesNotFit,
  'already_active': AgendaRejection.alreadyActive,
  'person_active': AgendaRejection.personActive,
  'recipient_blocked': AgendaRejection.recipientBlocked,
  'item_unavailable': AgendaRejection.itemUnavailable,
  'item_changed': AgendaRejection.itemChanged,
  'not_active': AgendaRejection.notActive,
  'changed': AgendaRejection.changed,
  'not_editable': AgendaRejection.notEditable,
  'blocked': AgendaRejection.blocked,
  'conflicts': AgendaRejection.conflicts,
  'invalid': AgendaRejection.invalid,
};

/// Lo que respondió una función de la agenda.
class AgendaWriteResult {
  const AgendaWriteResult.ok(String this.id)
    : rejection = null,
      conflictIds = const [];

  const AgendaWriteResult.rejected(
    AgendaRejection this.rejection, {
    this.conflictIds = const [],
  }) : id = null;

  /// El id del turno o del cierre guardado.
  final String? id;

  /// Por qué no se guardó; `null` si se guardó.
  final AgendaRejection? rejection;

  /// Con [AgendaRejection.conflicts], los turnos que pisa el cierre.
  final List<String> conflictIds;

  bool get isOk => rejection == null;
}

/// Para quién reserva la admin (spec 007).
sealed class AgendaRecipient {
  const AgendaRecipient();

  Map<String, Object?> toMap();
}

/// Una clienta con cuenta: el servidor lee su ficha.
class AgendaAccountRecipient extends AgendaRecipient {
  const AgendaAccountRecipient(this.clientId);

  final String clientId;

  @override
  Map<String, Object?> toMap() => {'clientId': clientId};
}

/// Una persona sin cuenta.
class AgendaGuestRecipient extends AgendaRecipient {
  const AgendaGuestRecipient({required this.name, required this.phone});

  final String name;
  final String phone;

  @override
  Map<String, Object?> toMap() => {'name': name, 'phone': phone};
}

/// Escribe en la agenda llamando a las funciones del servidor (spec 012,
/// plan D-1): turnos y cierres solo se crean y editan así. Las fechas
/// viajan como texto ISO 8601 en UTC. No toca Firestore.
class AgendaFunctions {
  AgendaFunctions({
    FirebaseFunctions? functions,
    this.timeout = const Duration(seconds: 15),
  }) : _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'southamerica-east1');

  final FirebaseFunctions _functions;

  /// Tiempo máximo de cada llamada, como el de guardar hasta ahora.
  final Duration timeout;

  static String _instant(DateTime time) => time.toUtc().toIso8601String();

  /// Lo elegido: el servicio y los adicionales salen de la copia [booked].
  static Map<String, Object?> _selection(
    String id,
    DateTime start,
    BookedServiceModel booked,
  ) => {
    'id': id,
    'start': _instant(start),
    'item': {'kind': booked.kind.name, 'id': booked.id},
    'addonIds': [for (final addon in booked.addons) addon.id],
    'booked': booked.toMap(),
  };

  /// Reserva el turno [id] (spec 005; la admin, con [recipient], spec 007).
  Future<AgendaWriteResult> book({
    required String id,
    required DateTime start,
    required BookedServiceModel booked,
    AgendaRecipient? recipient,
  }) => _call('bookAppointment', {
    ..._selection(id, start, booked),
    'recipient': ?recipient?.toMap(),
  });

  /// Edita el turno [id], que tenía [expected] al abrir la edición (spec
  /// 006 y 008). La admin pasa [recipient] con la persona elegida.
  Future<AgendaWriteResult> edit({
    required String id,
    required DateTime start,
    required BookedServiceModel booked,
    required AppointmentModel expected,
    AgendaRecipient? recipient,
  }) => _call('editAppointment', {
    ..._selection(id, start, booked),
    'expected': {
      'startTime': _instant(expected.startTime),
      'endTime': _instant(expected.endTime),
      'status': expected.status,
      'booked': expected.booked?.toMap(),
      'clientId': expected.clientId,
      'clientName': expected.clientName,
      'clientPhone': expected.clientPhone,
      'clientPhotoUrl': expected.clientPhotoUrl,
      'createdByAdmin': expected.createdByAdmin,
    },
    'recipient': ?recipient?.toMap(),
  });

  /// Guarda un cierre de [start] a [end] (spec 008).
  Future<AgendaWriteResult> saveClosure({
    required DateTime start,
    required DateTime end,
  }) => _call('saveClosure', {'start': _instant(start), 'end': _instant(end)});

  /// Llama a [name]. Un rechazo o un fallo llegan como resultado; si no
  /// responde a tiempo, lanza `TimeoutException`.
  Future<AgendaWriteResult> _call(
    String name,
    Map<String, Object?> data,
  ) async {
    try {
      final result = await _functions
          .httpsCallable(name, options: HttpsCallableOptions(timeout: timeout))
          .call<Object?>(data)
          .timeout(timeout);
      final response = result.data;
      final id = response is Map ? response['id'] : null;
      return AgendaWriteResult.ok(id is String ? id : '');
    } on TimeoutException {
      rethrow;
    } on FirebaseFunctionsException catch (error) {
      debugPrint('Error en $name: ${error.code} ${error.message}');
      if (error.code == 'deadline-exceeded') {
        throw TimeoutException('$name no respondió', timeout);
      }
      return _rejection(error);
    } catch (error) {
      debugPrint('Error en $name: $error');
      return const AgendaWriteResult.rejected(AgendaRejection.failed);
    }
  }

  static AgendaWriteResult _rejection(FirebaseFunctionsException error) {
    final details = error.details;
    final reason = details is Map ? details['reason'] : null;
    switch (error.code) {
      case 'permission-denied':
        return const AgendaWriteResult.rejected(AgendaRejection.notAllowed);
      case 'invalid-argument':
        return const AgendaWriteResult.rejected(AgendaRejection.invalid);
      case 'failed-precondition':
        final rejection = _reasons[reason];
        if (rejection == null) break;
        final ids = details is Map ? details['ids'] : null;
        return AgendaWriteResult.rejected(
          rejection,
          conflictIds: [
            if (ids is List)
              for (final id in ids)
                if (id is String) id,
          ],
        );
    }
    return const AgendaWriteResult.rejected(AgendaRejection.failed);
  }
}
