// Los casos de uso que escriben en la agenda (spec 012, plan § 4): reservar
// (aquí), editar y guardar un cierre (T4). Deciden quién es la persona,
// quién puede escribir y con qué estado y marca, y aplican las reglas puras
// (`agenda_rules.ts`, `booked_catalog.ts`) dentro de una transacción que
// lee el candado de la agenda (D-3): dos escrituras a la vez se ordenan, y
// la segunda vuelve a leer lo que guardó la primera (RF-3, RF-8).
//
// Sin Firebase: el almacén es una interfaz (`agenda_store.ts` la implementa
// con `firebase-admin`; los tests, en memoria). "Ahora" llega como
// parámetro.

import {
  activeAppointmentOfPerson,
  checkSlotRules,
  isValidWhatsApp,
  readCalendarSettings,
} from './agenda_rules.ts';
import type { Person, Range } from './agenda_rules.ts';
import { checkBooked, readPriceList } from './booked_catalog.ts';
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
  | 'no_profile';

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
  appointmentExists(id: string): Promise<boolean>;
  /** Escribe el turno y su turno ocupado (`busySlots/{id}`). */
  createAppointment(id: string, data: AppointmentWrite): void;
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
