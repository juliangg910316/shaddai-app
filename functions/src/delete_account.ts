// Borrar la cuenta de una clienta (spec 009, RF-34, RF-35, RF-39, RF-40,
// RF-42; plan D-8, D-10).
//
// Esta lógica no importa Firebase: recibe un almacén (`AccountStore`) y
// "ahora". `index.ts` lo conecta con `firebase-admin`; los tests, con uno en
// memoria. Cada paso se puede repetir sin romper nada: si algo falla a mitad,
// volver a llamarla escribe los mismos valores y borra lo que falte (RF-39).

/** La ficha de `users/{uid}`, en lo que importa para borrar. */
export interface StoredUser {
  role: string;
  isBlocked: boolean;
}

/** Un turno de `appointments`, en lo que importa para borrar. */
export interface StoredAppointment {
  id: string;
  status: string;
  endTime: Date;
}

/** Los campos que se cambian en un turno. */
export interface AppointmentChanges {
  status?: 'cancelled';
  cancelledBy?: 'client';
  clientPhotoUrl: null;
  accountDeleted: true;
}

/** Una escritura de un lote: cambiar un turno o borrar su turno ocupado. */
export type Write =
  | { kind: 'updateAppointment'; id: string; data: AppointmentChanges }
  | { kind: 'deleteBusySlot'; id: string };

/** Lo que la función necesita de Firebase. */
export interface AccountStore {
  /** La ficha de [uid], o `null` si ya no existe. */
  getUser(uid: string): Promise<StoredUser | null>;
  /** Todos los turnos con `clientId == uid`. */
  appointmentsOf(uid: string): Promise<StoredAppointment[]>;
  /** Escribe [writes] en un solo lote: o todas o ninguna. */
  commit(writes: Write[]): Promise<void>;
  /** Borra `users/{uid}`; si ya no existe, no es error. */
  deleteUser(uid: string): Promise<void>;
  /** Borra la cuenta de Auth; si ya no existe, no es error. */
  deleteAuthUser(uid: string): Promise<void>;
}

export type AccountDeletionCode =
  | 'unauthenticated'
  | 'permission-denied'
  | 'failed-precondition';

/** Un motivo por el que no se borra la cuenta, antes de tocar nada. */
export class AccountDeletionError extends Error {
  readonly code: AccountDeletionCode;
  readonly reason?: 'blocked';

  constructor(code: AccountDeletionCode, reason?: 'blocked') {
    super(reason ?? code);
    this.name = 'AccountDeletionError';
    this.code = code;
    this.reason = reason;
  }
}

/** Escrituras por lote, por debajo del máximo de 500 de Firestore. */
export const BATCH_LIMIT = 400;

const ACTIVE = new Set(['waiting_confirmation', 'confirmed']);

/**
 * Borra la cuenta de [uid] (el de la sesión, nunca uno enviado por la app;
 * RF-42) en este orden:
 * 1. sin sesión, la admin o una clienta bloqueada → error, sin tocar nada
 *    (RF-40, RF-42); si la ficha ya no existe, sigue (RF-39);
 * 2. su turno activo se cancela por la clienta y se borra su turno ocupado,
 *    sin mirar el margen (RF-34); todos sus turnos pierden la foto y quedan
 *    marcados como de una cuenta borrada, con nombre y WhatsApp (RF-35);
 * 3. borra la ficha y, al final, la cuenta de Auth (RF-36).
 */
export async function deleteAccount(
  store: AccountStore,
  uid: string | undefined,
  now: Date,
): Promise<{ ok: true }> {
  if (!uid) throw new AccountDeletionError('unauthenticated');

  const user = await store.getUser(uid);
  if (user?.role === 'admin') {
    throw new AccountDeletionError('permission-denied');
  }
  if (user?.isBlocked) {
    throw new AccountDeletionError('failed-precondition', 'blocked');
  }

  // Cada turno da un grupo de escrituras que va entero en el mismo lote: el
  // activo cambia a la vez que se borra su turno ocupado.
  const groups: Write[][] = [];
  for (const appointment of await store.appointmentsOf(uid)) {
    const active =
      ACTIVE.has(appointment.status) &&
      appointment.endTime.getTime() > now.getTime();
    if (active) {
      groups.push([
        {
          kind: 'updateAppointment',
          id: appointment.id,
          data: {
            status: 'cancelled',
            cancelledBy: 'client',
            clientPhotoUrl: null,
            accountDeleted: true,
          },
        },
        { kind: 'deleteBusySlot', id: appointment.id },
      ]);
    } else {
      groups.push([
        {
          kind: 'updateAppointment',
          id: appointment.id,
          data: { clientPhotoUrl: null, accountDeleted: true },
        },
      ]);
    }
  }

  let batch: Write[] = [];
  for (const group of groups) {
    if (batch.length + group.length > BATCH_LIMIT) {
      await store.commit(batch);
      batch = [];
    }
    batch.push(...group);
  }
  if (batch.length > 0) await store.commit(batch);

  await store.deleteUser(uid);
  await store.deleteAuthUser(uid);
  return { ok: true };
}
