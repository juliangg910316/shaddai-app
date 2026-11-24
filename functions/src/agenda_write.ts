// Los casos de uso que escriben en la agenda (spec 012, plan § 4): reservar,
// editar y guardar un cierre. Deciden quién es la persona,
// quién puede escribir y con qué estado y marca, y aplican las reglas puras
// (`agenda_rules.ts`, `booked_catalog.ts`) dentro de una transacción que
// lee el candado de la agenda (D-3): dos escrituras a la vez se ordenan, y
// la segunda vuelve a leer lo que guardó la primera (RF-3, RF-8).
//
// Sin Firebase: el almacén es una interfaz (`agenda_store.ts` la implementa
// con `firebase-admin`; los tests, en memoria). "Ahora" llega como
// parámetro.

import {
  ACTIVE_STATUSES,
  ADMIN_BOOKING_WINDOW_DAYS,
  activeAppointmentOfPerson,
  checkSlotRules,
  editTimesRules,
  isValidWhatsApp,
  overlaps,
  readCalendarSettings,
  salonDay,
  sameWhatsApp,
  toSalon,
} from './agenda_rules.ts';
import type { Person, Range } from './agenda_rules.ts';
import { bookedKey, checkBooked, readBooked, readPriceList } from './booked_catalog.ts';
import type { Booked, BookableRef } from './booked_catalog.ts';

/** Por qué no se escribe (`details.reason`, plan § 6). */
export type AgendaReason =
  | 'slot_taken'
  | 'closed'
  | 'outside_hours'
  | 'outside_window'
  | 'past'
  | 'does_not_fit'
  | 'already_active'
  | 'person_active'
  | 'recipient_blocked'
  | 'item_unavailable'
  | 'item_changed'
  | 'not_active'
  | 'changed'
  | 'not_editable'
  | 'blocked'
  | 'conflicts'
  | 'invalid'
  | 'no_profile'
  | 'forbidden';

/**
 * Un rechazo de la agenda. El adaptador lo devuelve como `HttpsError` con
 * [code] y el motivo en `details.reason`.
 */
export class AgendaError extends Error {
  readonly reason: AgendaReason;
  readonly code: 'failed-precondition' | 'permission-denied';
  readonly details: Record<string, unknown>;

  constructor(
    reason: AgendaReason,
    code: 'failed-precondition' | 'permission-denied' = 'failed-precondition',
    details: Record<string, unknown> = {},
  ) {
    super(reason);
    this.name = 'AgendaError';
    this.reason = reason;
    this.code = code;
    this.details = details;
  }
}

/** Lo que se lee de una ficha (`users/{uid}`). */
export interface UserProfile {
  uid: string;
  displayName: string;
  phoneNumber: string | null;
  photoUrl: string | null;
  role: string;
  isBlocked: boolean;
}

/** Un turno que aún no terminó, como lo leen las reglas. */
export interface StoredAppointment {
  id: string;
  clientId: string | null;
  clientPhone: string;
  start: Date;
  end: Date;
  status: string;
}

/** Lo que se escribe en `appointments/{id}`: los campos de `AppointmentModel.toMap`. */
export interface AppointmentWrite {
  clientId: string | null;
  clientName: string;
  clientPhone: string;
  clientPhotoUrl: string | null;
  startTime: Date;
  endTime: Date;
  status: 'waiting_confirmation' | 'confirmed' | 'cancelled';
  createdAt: Date;
  createdByAdmin: boolean;
  booked: Booked;
}

/** Un turno guardado, con todo lo que compara la edición. */
export interface AppointmentRecord {
  id: string;
  clientId: string | null;
  clientName: string;
  clientPhone: string;
  clientPhotoUrl: string | null;
  startTime: Date;
  endTime: Date;
  status: string;
  createdByAdmin: boolean;
  /** La copia guardada, tal cual (RF-13). */
  booked: unknown;
}

/** Lo que cambia una edición: solo esos campos se escriben. */
export interface AppointmentUpdate {
  startTime: Date;
  endTime: Date;
  status: 'waiting_confirmation' | 'confirmed';
  booked: unknown;
  clientId?: string | null;
  clientName?: string;
  clientPhone?: string;
  clientPhotoUrl?: string | null;
  createdByAdmin?: true;
}

/** Una transacción sobre la agenda: lee primero y escribe al final. */
export interface AgendaTransaction {
  /** Lee el candado `locks/agenda`; se lee siempre, antes que nada. */
  readLock(): Promise<void>;
  user(uid: string): Promise<UserProfile | null>;
  /** Las fichas de clienta con el WhatsApp [phone] (normalizado). */
  clientsWithPhone(phone: string): Promise<UserProfile[]>;
  /** `settings/calendar`, o `null` si no existe. */
  calendar(): Promise<Record<string, unknown> | null>;
  /** `settings/priceList`, o `null` si no existe. */
  priceList(): Promise<unknown>;
  /** Los turnos con `endTime >= now`, de cualquier estado. */
  appointmentsEndingFrom(now: Date): Promise<StoredAppointment[]>;
  /** Los cierres con `end >= now`. */
  closuresEndingFrom(now: Date): Promise<Range[]>;
  appointment(id: string): Promise<AppointmentRecord | null>;
  appointmentExists(id: string): Promise<boolean>;
  /** Escribe el turno y su turno ocupado (`busySlots/{id}`). */
  createAppointment(id: string, data: AppointmentWrite): void;
  /** Actualiza esos campos del turno y escribe su turno ocupado con sus horas. */
  updateAppointment(id: string, fields: AppointmentUpdate): void;
  /** Crea `closures/{auto}` y devuelve su id. */
  createClosure(range: Range): string;
  /** Escribe el candado, para que otra transacción que lo leyó se repita. */
  touchLock(now: Date): void;
}

export interface AgendaStore {
  runTransaction<T>(fn: (tx: AgendaTransaction) => Promise<T>): Promise<T>;
}

/** Para quién reserva la admin: una clienta o una persona sin cuenta. */
export type Recipient = { clientId: string } | { name: string; phone: string };

/** Lo que manda la app para reservar. */
export interface BookRequest {
  /** El id del turno (UUID generado en la app). */
  id: string;
  start: Date;
  item: BookableRef;
  addonIds: string[];
  /** La copia de lo reservado que mostraba la app (RF-12). */
  booked: unknown;
  /** Solo la admin: para quién es. */
  recipient?: Recipient;
}

/** Quién tendrá el turno y cómo se guarda. */
interface Holder {
  person: Person;
  fields: Pick<AppointmentWrite, 'clientId' | 'clientName' | 'clientPhone' | 'clientPhotoUrl'>;
}

/** La persona de la admin (spec 007): RF-6, `recipient_blocked`, `invalid`. */
async function adminRecipient(
  tx: AgendaTransaction,
  recipient: Recipient | undefined,
): Promise<Holder> {
  if (recipient === undefined) throw new AgendaError('invalid');
  if ('clientId' in recipient) {
    const user = await tx.user(recipient.clientId);
    if (user === null || user.role !== 'cliente') throw new AgendaError('invalid');
    if (user.isBlocked) throw new AgendaError('recipient_blocked');
    const phone = user.phoneNumber ?? '';
    return {
      person: { uid: user.uid, phone },
      fields: {
        clientId: user.uid,
        clientName: user.displayName,
        clientPhone: phone,
        clientPhotoUrl: user.photoUrl,
      },
    };
  }
  const name = recipient.name.trim();
  const phone = recipient.phone.trim();
  if (name === '' || !isValidWhatsApp(phone)) throw new AgendaError('invalid');
  const accounts = await tx.clientsWithPhone(phone);
  if (accounts.some((u) => u.isBlocked)) throw new AgendaError('recipient_blocked');
  return {
    person: { uid: null, phone },
    fields: { clientId: null, clientName: name, clientPhone: phone, clientPhotoUrl: null },
  };
}

/**
 * Reserva un turno (spec 005 y 007; spec 012, RF-1, RF-3, RF-4, RF-6, RF-8
 * a RF-12). La clienta, a su nombre y esperando confirmación; la admin,
 * para otra persona, confirmado y marcado. Lanza [AgendaError] si algo no
 * se cumple.
 */
export async function bookAppointment(
  store: AgendaStore,
  callerUid: string,
  request: BookRequest,
  now: Date,
): Promise<{ id: string }> {
  return store.runTransaction(async (tx) => {
    await tx.readLock();
    const caller = await tx.user(callerUid);
    if (caller === null) throw new AgendaError('no_profile', 'permission-denied');
    const [calendar, priceList, appointments, closures] = await Promise.all([
      tx.calendar(),
      tx.priceList(),
      tx.appointmentsEndingFrom(now),
      tx.closuresEndingFrom(now),
    ]);

    const admin = caller.role === 'admin';
    let holder: Holder;
    if (admin) {
      holder = await adminRecipient(tx, request.recipient);
      if (activeAppointmentOfPerson(appointments, holder.person, now) !== null) {
        throw new AgendaError('person_active');
      }
    } else {
      if (request.recipient !== undefined) throw new AgendaError('invalid');
      if (caller.isBlocked) throw new AgendaError('blocked');
      // Como la app (spec 005): sus turnos, por su cuenta.
      if (activeAppointmentOfPerson(appointments, { uid: callerUid, phone: '' }, now) !== null) {
        throw new AgendaError('already_active');
      }
      holder = {
        person: { uid: callerUid, phone: '' },
        fields: {
          clientId: callerUid,
          clientName: caller.displayName,
          clientPhone: caller.phoneNumber ?? '',
          clientPhotoUrl: caller.photoUrl,
        },
      };
    }

    const booked = checkBooked(readPriceList(priceList), request.item, request.addonIds, request.booked);
    if (!booked.ok) throw new AgendaError(booked.reason);

    const verdict = checkSlotRules({
      settings: readCalendarSettings(calendar ?? {}),
      appointments,
      closures,
      start: request.start,
      durationMinutes: booked.booked.durationMinutes,
      now,
      admin,
    });
    if (verdict !== 'ok') throw new AgendaError(verdict);

    if (await tx.appointmentExists(request.id)) throw new AgendaError('invalid');

    tx.createAppointment(request.id, {
      ...holder.fields,
      startTime: request.start,
      endTime: new Date(request.start.getTime() + booked.booked.durationMinutes * 60_000),
      status: admin ? 'confirmed' : 'waiting_confirmation',
      createdAt: now,
      createdByAdmin: admin,
      booked: booked.booked,
    });
    tx.touchLock(now);
    return { id: request.id };
  });
}

// Editar (spec 006 y 008; spec 012, RF-2, RF-7, RF-13, RF-15) -------------

/** Lo que tenía el turno al abrir la edición, para saber si cambió. */
export type ExpectedAppointment = Omit<AppointmentRecord, 'id'>;

/** Lo que manda la app para editar. */
export interface EditRequest {
  id: string;
  start: Date;
  item: BookableRef;
  addonIds: string[];
  booked: unknown;
  expected: ExpectedAppointment;
  /** Solo la admin: la persona elegida; sin ella, la del turno. */
  recipient?: Recipient;
}

const isActive = (a: { status: string; endTime: Date }, now: Date) =>
  ACTIVE_STATUSES.has(a.status) && a.endTime > now;

/** Lo que la clienta compara (spec 006): horas, estado y lo reservado. */
function sameTimesAndBooked(current: AppointmentRecord, expected: ExpectedAppointment): boolean {
  return (
    current.startTime.getTime() === expected.startTime.getTime() &&
    current.endTime.getTime() === expected.endTime.getTime() &&
    current.status === expected.status &&
    bookedKey(readBooked(current.booked)) === bookedKey(readBooked(expected.booked))
  );
}

/** Lo que la admin compara (spec 008, `_changedSince`): además, la persona y la marca. */
function sameForAdmin(current: AppointmentRecord, expected: ExpectedAppointment): boolean {
  return (
    sameTimesAndBooked(current, expected) &&
    current.clientId === expected.clientId &&
    current.clientName === expected.clientName &&
    current.clientPhone === expected.clientPhone &&
    (current.clientPhotoUrl ?? null) === (expected.clientPhotoUrl ?? null) &&
    current.createdByAdmin === expected.createdByAdmin
  );
}

/** Si la admin cambia la persona del turno (`personChanged`). */
function personChanged(current: AppointmentRecord, recipient: Recipient): boolean {
  if ('clientId' in recipient) return current.clientId !== recipient.clientId;
  return (
    current.clientId !== null ||
    current.clientName.trim() !== recipient.name.trim() ||
    !sameWhatsApp(current.clientPhone, recipient.phone)
  );
}

/** El margen de edición en minutos: entero ≥ 0, o 0 (spec 006). */
function editMarginOf(calendar: Record<string, unknown> | null): number {
  const value = calendar?.editMarginMinutes;
  return typeof value === 'number' && Number.isInteger(value) && value >= 0 ? value : 0;
}

/**
 * Lo reservado tras la edición (RF-12, RF-13): si no cambia (mismo
 * servicio, mismos adicionales y la copia guardada), la copia guardada,
 * aunque la lista haya cambiado; si cambia, la de la lista vigente.
 */
function bookedAfterEdit(
  current: AppointmentRecord,
  request: EditRequest,
  priceList: unknown,
): { booked: unknown; durationMinutes: number } {
  const stored = readBooked(current.booked);
  const shown = readBooked(request.booked);
  const sameAddons = (a: string[], b: string[]) =>
    new Set(a).size === new Set(b).size && a.every((id) => b.includes(id));
  if (
    stored !== null &&
    shown !== null &&
    bookedKey(stored) === bookedKey(shown) &&
    request.item.kind === stored.kind &&
    request.item.id === stored.id &&
    sameAddons(request.addonIds, stored.addons.map((a) => a.id))
  ) {
    return { booked: current.booked, durationMinutes: stored.durationMinutes };
  }
  const checked = checkBooked(readPriceList(priceList), request.item, request.addonIds, request.booked);
  if (!checked.ok) throw new AgendaError(checked.reason);
  return { booked: checked.booked, durationMinutes: checked.booked.durationMinutes };
}

/**
 * Edita un turno activo (spec 006 y 008; spec 012, RF-2, RF-7, RF-13,
 * RF-15). La clienta, el suyo, fuera del margen y sin estar bloqueada: vuelve
 * a esperar confirmación. La admin, cualquiera, también en curso: queda
 * confirmado, y si cambia la persona se escribe la nueva con la marca.
 * Solo se escriben los campos que cambian, como las transacciones de hoy.
 */
export async function editAppointment(
  store: AgendaStore,
  callerUid: string,
  request: EditRequest,
  now: Date,
): Promise<{ id: string }> {
  return store.runTransaction(async (tx) => {
    await tx.readLock();
    const caller = await tx.user(callerUid);
    if (caller === null) throw new AgendaError('no_profile', 'permission-denied');
    const [calendar, priceList, appointments, closures, current] = await Promise.all([
      tx.calendar(),
      tx.priceList(),
      tx.appointmentsEndingFrom(now),
      tx.closuresEndingFrom(now),
      tx.appointment(request.id),
    ]);
    if (current === null) throw new AgendaError('not_active');

    const admin = caller.role === 'admin';
    const update: AppointmentUpdate = {
      startTime: request.start,
      endTime: request.start,
      status: admin ? 'confirmed' : 'waiting_confirmation',
      booked: null,
    };
    if (admin) {
      if (!isActive(current, now)) throw new AgendaError('not_active');
      if (!sameForAdmin(current, request.expected)) throw new AgendaError('changed');
      if (request.recipient !== undefined && personChanged(current, request.recipient)) {
        const holder = await adminRecipient(tx, request.recipient);
        if (activeAppointmentOfPerson(appointments, holder.person, now, current.id) !== null) {
          throw new AgendaError('person_active');
        }
        Object.assign(update, holder.fields, { createdByAdmin: true });
      }
    } else {
      if (request.recipient !== undefined) throw new AgendaError('invalid');
      if (current.clientId !== callerUid) throw new AgendaError('not_editable');
      if (!isActive(current, now)) throw new AgendaError('not_active');
      if (!sameTimesAndBooked(current, request.expected)) throw new AgendaError('changed');
      const limit = current.startTime.getTime() - editMarginOf(calendar) * 60_000;
      if (caller.isBlocked || !(now.getTime() < limit)) throw new AgendaError('not_editable');
    }

    const { booked, durationMinutes } = bookedAfterEdit(current, request, priceList);
    const verdict = editTimesRules({
      settings: readCalendarSettings(calendar ?? {}),
      appointments,
      closures,
      start: request.start,
      durationMinutes,
      now,
      admin,
      original: { id: current.id, start: current.startTime, end: current.endTime },
    });
    if (verdict !== 'ok') throw new AgendaError(verdict);

    update.booked = booked;
    update.endTime = new Date(request.start.getTime() + durationMinutes * 60_000);
    tx.updateAppointment(current.id, update);
    tx.touchLock(now);
    return { id: current.id };
  });
}

// Cierres (spec 008; spec 012, RF-5) --------------------------------------

const DAY_MS = 86_400_000;

const isMidnight = (wall: Date) => wall.getTime() === salonDay(wall).getTime();

/**
 * Si el cierre [range] está mal (`closureErrors`): el fin no es posterior al
 * inicio, ya terminó, o algún día queda a más de 365 días de hoy. Además,
 * como solo los crea el formulario, una franja empieza y termina el mismo
 * día; unos días enteros van de las 0:00 a las 0:00.
 */
function closureIsInvalid(range: Range, now: Date): boolean {
  if (!(range.end > range.start) || !(range.end > now)) return true;
  const start = toSalon(range.start);
  const end = toSalon(range.end);
  const days = isMidnight(start) && isMidnight(end);
  const firstDay = salonDay(start);
  const lastDay = days ? new Date(salonDay(end).getTime() - DAY_MS) : salonDay(end);
  if (!days && lastDay.getTime() !== firstDay.getTime()) return true;
  const lastAllowed = salonDay(toSalon(now)).getTime() + ADMIN_BOOKING_WINDOW_DAYS * DAY_MS;
  return firstDay.getTime() > lastAllowed || lastDay.getTime() > lastAllowed;
}

/**
 * Guarda un cierre de la admin (spec 008; spec 012, RF-5). No lo guarda si
 * pisa turnos activos: `conflicts`, con sus ids por orden de inicio. Lee
 * el candado, así que un turno que se guarda a la vez se ordena con él.
 */
export async function saveClosure(
  store: AgendaStore,
  callerUid: string,
  range: Range,
  now: Date,
): Promise<{ id: string }> {
  return store.runTransaction(async (tx) => {
    await tx.readLock();
    const caller = await tx.user(callerUid);
    if (caller === null) throw new AgendaError('no_profile', 'permission-denied');
    if (caller.role !== 'admin') throw new AgendaError('forbidden', 'permission-denied');
    if (closureIsInvalid(range, now)) throw new AgendaError('invalid');

    const conflicts = (await tx.appointmentsEndingFrom(now))
      .filter((a) => ACTIVE_STATUSES.has(a.status) && a.end > now && overlaps(a, range))
      .sort((a, b) => a.start.getTime() - b.start.getTime());
    if (conflicts.length > 0) {
      throw new AgendaError('conflicts', 'failed-precondition', {
        ids: conflicts.map((a) => a.id),
      });
    }

    const id = tx.createClosure(range);
    tx.touchLock(now);
    return { id };
  });
}
