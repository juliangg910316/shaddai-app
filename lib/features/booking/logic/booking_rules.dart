/// Turno activo, comprobación antes de guardar y qué muestra la pantalla de
/// reserva, sin Flutter ni Firebase (spec 005, plan § 4.6).
///
/// Las funciones son genéricas sobre el tipo de turno: lo leen con `times`.
/// Así la lógica no depende del modelo de datos.
library;

import '../../../data/models/calendar_settings_model.dart';
import 'free_slots.dart';
import 'salon_time.dart';

/// Inicio y fin (instantes) y estado de un turno.
typedef AppointmentTimes = ({DateTime start, DateTime end, String status});

/// Estados de un turno que ocupa su hora.
const activeStatuses = {'waiting_confirmation', 'confirmed'};

/// El turno activo de [mine] en el instante [now]: el que empieza antes de
/// entre los que terminan después de [now] y están esperando confirmación o
/// confirmados. También mientras está en curso. `null` si no hay ninguno.
T? activeAppointment<T>(
  Iterable<T> mine, {
  required AppointmentTimes Function(T appointment) times,
  required DateTime now,
}) {
  T? active;
  DateTime? activeStart;
  for (final appointment in mine) {
    final t = times(appointment);
    if (!activeStatuses.contains(t.status) || !t.end.isAfter(now)) continue;
    if (activeStart == null || t.start.isBefore(activeStart)) {
      active = appointment;
      activeStart = t.start;
    }
  }
  return active;
}

/// Resultado de la comprobación antes de guardar.
enum BookingCheck {
  ok,

  /// La clienta ya tiene un turno activo (RF-36).
  alreadyActive,

  /// La hora ya no es libre: ocupada o pasada (RF-29).
  slotTaken,

  /// El servicio ya no cabe en la hora (RF-30).
  doesNotFit,
}

/// Comprueba otra vez, justo antes de guardar, un turno que empieza en
/// [start] (hora de pared) y dura [durationMinutes] (RF-26). [busy] son los
/// turnos ocupados de ese día y [mine], los turnos de la clienta.
BookingCheck checkBeforeSave<T>({
  required DateTime start,
  required int durationMinutes,
  required CalendarSettingsModel settings,
  required Iterable<BusyRange> busy,
  required Iterable<T> mine,
  required AppointmentTimes Function(T appointment) times,
  required DateTime nowSalon,
}) {
  if (activeAppointment(mine, times: times, now: fromSalon(nowSalon)) != null) {
    return BookingCheck.alreadyActive;
  }
  FreeSlot? slot;
  for (final free in freeSlots(
    day: salonDay(start),
    settings: settings,
    busy: busy,
    nowSalon: nowSalon,
  )) {
    if (free.start == start) slot = free;
  }
  if (slot == null) return BookingCheck.slotTaken;
  if (!fits(durationMinutes, slot)) return BookingCheck.doesNotFit;
  return BookingCheck.ok;
}

/// Lo que la reserva necesita saber de la ficha de la usuaria.
typedef BookingUser = ({bool isAdmin, bool isBlocked});

/// Qué muestra la pantalla de reserva.
sealed class BookingScreen<T> {
  const BookingScreen();
}

class BookingScreenLoading<T> extends BookingScreen<T> {
  const BookingScreenLoading();
}

/// Sin sesión (o sin ficha): el aviso para iniciarla (spec 003).
class BookingScreenSignedOut<T> extends BookingScreen<T> {
  const BookingScreenSignedOut();
}

/// No se pudo saber si está bloqueada o si tiene un turno activo (RF-49).
class BookingScreenError<T> extends BookingScreen<T> {
  const BookingScreenError();
}

/// La sesión es de la admin (RF-39).
class BookingScreenAdmin<T> extends BookingScreen<T> {
  const BookingScreenAdmin();
}

/// Su turno activo, en lugar de la vista de reserva (RF-33). Si está
/// bloqueada, también el aviso de RF-37.
class BookingScreenActive<T> extends BookingScreen<T> {
  const BookingScreenActive(this.appointment, {required this.isBlocked});

  final T appointment;
  final bool isBlocked;
}

/// Bloqueada, sin turno activo (RF-37).
class BookingScreenBlocked<T> extends BookingScreen<T> {
  const BookingScreenBlocked();
}

/// La vista de reserva.
class BookingScreenBooking<T> extends BookingScreen<T> {
  const BookingScreenBooking();
}

/// Decide qué muestra la pantalla, en este orden: la ficha cargando, sin
/// sesión, error de la ficha, admin (sin esperar a sus turnos), sus turnos
/// cargando o con error, turno activo, bloqueada y la vista de reserva.
///
/// [user] es `null` sin sesión o sin ficha. [mine] es `null` mientras sus
/// turnos cargan.
BookingScreen<T> bookingScreen<T>({
  required bool userLoading,
  required bool userError,
  required BookingUser? user,
  required List<T>? mine,
  required bool mineError,
  required AppointmentTimes Function(T appointment) times,
  required DateTime now,
}) {
  if (userLoading) return BookingScreenLoading<T>();
  if (userError) return BookingScreenError<T>();
  if (user == null) return BookingScreenSignedOut<T>();
  if (user.isAdmin) return BookingScreenAdmin<T>();
  if (mineError) return BookingScreenError<T>();
  if (mine == null) return BookingScreenLoading<T>();

  final active = activeAppointment(mine, times: times, now: now);
  if (active != null) {
    return BookingScreenActive<T>(active, isBlocked: user.isBlocked);
  }
  if (user.isBlocked) return BookingScreenBlocked<T>();
  return BookingScreenBooking<T>();
}
