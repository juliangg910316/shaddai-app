// Qué aviso genera un cambio en un turno y qué dice (spec 011, RF-1 a RF-5,
// RF-7 a RF-11, RNF-4; plan D-2, D-4, D-6).
//
// Esta lógica no importa Firebase: recibe el turno antes y después del
// cambio, ya leído. `notice_store.ts` lo lee de Firestore; los tests lo
// escriben a mano.
import { createHash } from 'node:crypto';

/** Los tres avisos de la admin. */
export type NoticeKind = 'created' | 'edited' | 'cancelled';

/** Lo que importa de un turno (`appointments/{id}`) para avisar. */
export interface NoticeAppointment {
  /** `null` si es de una persona sin cuenta (spec 007). */
  clientId: string | null;
  clientName: string;
  status: string;
  start: Date;
  end: Date;
  /** Lo reservado, serializado de forma estable, solo para compararlo. */
  bookedKey: string;
  /** El nombre en español de lo reservado, o `null` si no hay (RF-11). */
  serviceName: string | null;
  createdByAdmin: boolean;
  cancelledByClient: boolean;
  accountDeleted: boolean;
}

const ACTIVE = new Set(['waiting_confirmation', 'confirmed']);

/**
 * El aviso que genera pasar de [before] a [after], o `null` si no hay aviso.
 * `null` en [before] es que el turno se crea; en [after], que se borra.
 *
 * Se decide por los datos, porque las reglas ya garantizan quién puede hacer
 * cada cambio (plan D-2):
 * - solo la clienta crea un turno sin la marca de la admin (RF-1);
 * - solo la clienta deja su turno esperando confirmación con otras horas o
 *   lo reservado: la edición de la admin queda confirmada (RF-2);
 * - solo la clienta (o el borrado de su cuenta) cancela con
 *   `cancelledBy: 'client'` (RF-3).
 * Nada de lo que hace la admin cumple ninguna de las tres (RF-4).
 */
export function noticeKind(
  before: NoticeAppointment | null,
  after: NoticeAppointment | null,
): NoticeKind | null {
  if (after === null) return null;
  if (before === null) {
    return !after.createdByAdmin &&
      after.clientId !== null &&
      after.status === 'waiting_confirmation'
      ? 'created'
      : null;
  }
  if (!ACTIVE.has(before.status)) return null;
  if (after.status === 'cancelled' && after.cancelledByClient) {
    return 'cancelled';
  }
  if (
    after.status === 'waiting_confirmation' &&
    (before.start.getTime() !== after.start.getTime() ||
      before.end.getTime() !== after.end.getTime() ||
      before.bookedKey !== after.bookedKey)
  ) {
    return 'edited';
  }
  return null;
}

/** Curitiba está en UTC−3 todo el año, como en la app (spec 005). */
const SALON_OFFSET_MS = -3 * 3_600_000;

/** [instant] con la fecha y la hora de Curitiba en sus campos UTC. */
const toSalon = (instant: Date) =>
  new Date(instant.getTime() + SALON_OFFSET_MS);

const pad = (n: number) => String(n).padStart(2, '0');

/** El día del salón de [start], como `YYYY-MM-DD` (RF-12). */
export function salonDay(start: Date): string {
  const salon = toSalon(start);
  return `${salon.getUTCFullYear()}-${pad(salon.getUTCMonth() + 1)}-${pad(
    salon.getUTCDate(),
  )}`;
}

// A mano, para no depender de los datos de idioma de Node (plan D-6).
const WEEKDAYS = [
  'domingo',
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
];
const MONTHS = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

/** "sábado 21 de noviembre, 10:00", en hora del salón (RF-8 a RF-10). */
function salonDateTime(start: Date): string {
  const salon = toSalon(start);
  return (
    `${WEEKDAYS[salon.getUTCDay()]} ${salon.getUTCDate()} de ` +
    `${MONTHS[salon.getUTCMonth()]}, ` +
    // Como `DateFormat.Hm('es')` en la app: "9:05".
    `${salon.getUTCHours()}:${pad(salon.getUTCMinutes())}`
  );
}

/**
 * El título y el texto del aviso, siempre en español (RF-7). Solo lleva el
 * nombre de la clienta y los datos del turno: nunca su WhatsApp, su correo ni
 * su foto (RNF-4).
 */
export function noticeText(
  kind: NoticeKind,
  appointment: NoticeAppointment,
): { title: string; body: string } {
  const name = appointment.clientName.trim() || 'Una clienta';
  const when = salonDateTime(appointment.start);
  const service =
    appointment.serviceName === null ? '' : ` · ${appointment.serviceName}`;

  switch (kind) {
    case 'created':
      return {
        title: 'Turno nuevo',
        body: `${name} · ${when}${service}. Espera tu confirmación.`,
      };
    case 'edited':
      return {
        title: 'Turno modificado',
        body: `${name} lo cambió a ${when}${service}. Espera tu confirmación.`,
      };
    case 'cancelled':
      return {
        title: 'Turno cancelado',
        body: appointment.accountDeleted
          ? `${name} eliminó su cuenta y se canceló su turno del ${when}. ` +
            'La hora queda libre.'
          : `${name} canceló su turno del ${when}. La hora queda libre.`,
      };
  }
}

/**
 * Los FID (Firebase Installation ID) de [devices] sin repetir, en el orden
 * en que aparecen: la misma admin o dos admins en un mismo teléfono reciben
 * un solo aviso (RF-5, plan D-15).
 */
export function uniqueFids(
  devices: readonly { uid: string; fid: string }[],
): string[] {
  return [...new Set(devices.map((device) => device.fid))];
}

/**
 * La etiqueta del aviso de un evento: si la plataforma lo entregara dos
 * veces, el segundo sustituye al primero en el teléfono (RF-5, plan D-4).
 * 32 caracteres, dentro del límite de `apns-collapse-id` (64 bytes).
 */
export function noticeTag(eventId: string): string {
  return createHash('sha256').update(eventId).digest('hex').slice(0, 32);
}
