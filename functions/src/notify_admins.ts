// Enviar el aviso de un cambio en un turno a todos los dispositivos de las
// admins y borrar los que ya no valen (spec 011, RF-5, RF-12, RF-19, RF-21,
// RF-22, RF-24; plan D-3 a D-5).
//
// Esta lógica no importa Firebase: recibe un almacén (`NoticeStore`).
// `notice_store.ts` lo conecta con `firebase-admin`; los tests, con uno en
// memoria.
import {
  noticeKind,
  noticeTag,
  noticeText,
  salonDay,
  uniqueFids,
} from './appointment_notice.ts';
import type { NoticeAppointment, NoticeKind } from './appointment_notice.ts';

/**
 * Un dispositivo registrado: `users/{uid}/pushDevices/{fid}`, con su FID
 * (Firebase Installation ID, plan D-15).
 */
export interface NoticeDevice {
  uid: string;
  fid: string;
}

/** El aviso que se envía, igual para todos los dispositivos. */
export interface NoticeMessage {
  title: string;
  body: string;
  /** Lo que lee la app al tocarlo (RF-12). */
  data: { kind: NoticeKind; appointmentId: string; day: string };
  /** La etiqueta del evento (plan D-4). */
  tag: string;
}

/** El resultado del envío a un FID. */
export type SendResult = { ok: true } | { ok: false; code: string };

/** Lo que el envío necesita de Firebase. */
export interface NoticeStore {
  /** Los dispositivos de las fichas con `role == 'admin'` (RF-19, RF-22). */
  adminDevices(): Promise<NoticeDevice[]>;
  /** Envía [message] a cada FID; un resultado por FID, en orden. */
  send(fids: string[], message: NoticeMessage): Promise<SendResult[]>;
  /** Borra `users/{uid}/pushDevices/{fid}`. */
  removeDevice(uid: string, fid: string): Promise<void>;
}

/** Un cambio en un turno: el evento y el documento antes y después. */
export interface AppointmentWrite {
  /** El id del evento, el mismo si la plataforma lo entrega dos veces. */
  eventId: string;
  appointmentId: string;
  before: NoticeAppointment | null;
  after: NoticeAppointment | null;
}

/**
 * Errores de FCM que dicen que el FID ya no sirve (plan D-5). FCM responde
 * `UNREGISTERED`, que `firebase-admin` traduce con el nombre de los tokens.
 */
const STALE_DEVICE_CODES = new Set([
  'messaging/registration-token-not-registered',
  'messaging/invalid-registration-token',
]);

/**
 * Qué pasó con un cambio: el aviso (`null` si no tocaba), cuántos
 * dispositivos había, cuántos envíos salieron, cuántos se borraron y los
 * códigos de error de FCM, sin repetir. Sin datos de la clienta (RNF-4).
 */
export interface NoticeResult {
  kind: NoticeKind | null;
  devices: number;
  sent: number;
  removed: number;
  errors: string[];
}

/**
 * Envía el aviso de [write], si lo hay, y borra los dispositivos cuyo FID
 * ya no vale de cada admin que lo tenga (RF-21). Sin dispositivos no envía
 * nada (RF-24). Si el envío falla del todo, lanza: lo recoge
 * [notifyAdminsSafely].
 */
export async function notifyAdmins(
  store: NoticeStore,
  write: AppointmentWrite,
): Promise<NoticeResult> {
  const kind = noticeKind(write.before, write.after);
  const nothing = { devices: 0, sent: 0, removed: 0, errors: [] };
  if (kind === null || write.after === null) return { kind: null, ...nothing };

  const devices = await store.adminDevices();
  const fids = uniqueFids(devices);
  if (fids.length === 0) return { kind, ...nothing };

  const message: NoticeMessage = {
    ...noticeText(kind, write.after),
    data: {
      kind,
      appointmentId: write.appointmentId,
      day: salonDay(write.after.start),
    },
    tag: noticeTag(write.eventId),
  };
  const results = await store.send(fids, message);

  let sent = 0;
  const stale = new Set<string>();
  const errors = new Set<string>();
  results.forEach((result, i) => {
    if (result.ok) {
      sent++;
      return;
    }
    errors.add(result.code);
    if (STALE_DEVICE_CODES.has(result.code)) stale.add(fids[i]);
  });

  let removed = 0;
  for (const device of devices) {
    if (!stale.has(device.fid)) continue;
    await store.removeDevice(device.uid, device.fid);
    removed++;
  }
  return {
    kind,
    devices: fids.length,
    sent,
    removed,
    errors: [...errors].sort(),
  };
}

/** Dónde se escribe el registro: el `logger` de la función. */
export interface NoticeLogger {
  info(message: string, details: object): void;
  error(message: string, details: object): void;
}

/**
 * [notifyAdmins] sin lanzar nunca: el turno ya está guardado y la clienta
 * no ve ningún error (RF-24). El fallo queda en el registro; no se reintenta,
 * para no duplicar avisos (plan D-3). Si va bien, deja una línea con el
 * resultado, también cuando no había aviso o dispositivos, para poder
 * diagnosticar un aviso que no llegó. Devuelve `null` si falló.
 */
export async function notifyAdminsSafely(
  store: NoticeStore,
  write: AppointmentWrite,
  log: NoticeLogger,
): Promise<NoticeResult | null> {
  const ids = { appointmentId: write.appointmentId, eventId: write.eventId };
  try {
    const result = await notifyAdmins(store, write);
    log.info('Aviso a la admin', { ...ids, ...result });
    return result;
  } catch (error) {
    log.error('No se pudo avisar a la admin', { ...ids, error: String(error) });
    return null;
  }
}

// Lectura del documento --------------------------------------------------

type Data = Record<string, unknown>;

const isRecord = (value: unknown): value is Data =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

/** Un `Timestamp` de Firestore (o cualquier cosa con `toDate`). */
function readDate(value: unknown): Date {
  if (isRecord(value) && typeof value.toDate === 'function') {
    const date = (value.toDate as () => unknown)();
    if (date instanceof Date) return date;
  }
  return new Date(0);
}

const readString = (value: unknown) => (typeof value === 'string' ? value : '');

/** JSON con las claves ordenadas, para comparar lo reservado (RF-2). */
function stableJson(value: unknown): string {
  if (Array.isArray(value)) return `[${value.map(stableJson).join(',')}]`;
  if (isRecord(value)) {
    const keys = Object.keys(value).sort();
    return `{${keys
      .map((key) => `${JSON.stringify(key)}:${stableJson(value[key])}`)
      .join(',')}}`;
  }
  return JSON.stringify(value ?? null);
}

/** El nombre de lo reservado en español, o en portugués si falta (RF-11). */
function readServiceName(booked: unknown): string | null {
  if (!isRecord(booked) || !isRecord(booked.name)) return null;
  const es = readString(booked.name.es).trim();
  const pt = readString(booked.name.pt).trim();
  return es || pt || null;
}

/**
 * El turno de un documento de `appointments`, o `null` si no existe. La
 * lectura es tolerante, como en la app (constitución, principio 5): un campo
 * que falta o con otro tipo toma su valor por defecto. No copia el WhatsApp
 * ni la foto: el aviso no los usa (RNF-4).
 */
export function readNoticeAppointment(
  data: Data | undefined,
): NoticeAppointment | null {
  if (data === undefined) return null;
  const clientId = readString(data.clientId);
  return {
    clientId: clientId === '' ? null : clientId,
    clientName: readString(data.clientName),
    status: readString(data.status),
    start: readDate(data.startTime),
    end: readDate(data.endTime),
    bookedKey: stableJson(data.booked),
    serviceName: readServiceName(data.booked),
    createdByAdmin: data.createdByAdmin === true,
    cancelledByClient: data.cancelledBy === 'client',
    accountDeleted: data.accountDeleted === true,
  };
}
