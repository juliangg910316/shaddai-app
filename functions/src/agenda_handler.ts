// El adaptador entre las funciones invocables y los casos de uso de la
// agenda (spec 012, RF-16, RF-17, RNF-4; plan § 2, § 6).
//
// - El uid sale de la sesión, nunca de los datos.
// - Los datos se validan con su forma exacta (sin campos de más): lo que no
//   la tiene es `invalid-argument`.
// - Un `AgendaError` llega a la app como su código y el motivo en
//   `details.reason` (y `ids` en `conflicts`), sin datos de otras personas.
// - Cualquier otro fallo queda en el registro y llega como `internal`, sin
//   detalles.
import { HttpsError } from 'firebase-functions/v2/https';

import type { Range } from './agenda_rules.ts';
import {
  AgendaError,
  bookAppointment,
  editAppointment,
  saveClosure,
} from './agenda_write.ts';
import type {
  AgendaStore,
  BookRequest,
  EditRequest,
  ExpectedAppointment,
  Recipient,
} from './agenda_write.ts';
import type { BookableRef } from './booked_catalog.ts';

/** Lo que importa de una llamada: la sesión y los datos. */
export interface AgendaCall {
  auth?: { uid: string };
  data?: unknown;
}

/** Dónde quedan los fallos inesperados. */
export interface AgendaLog {
  error(message: string, details: Record<string, unknown>): void;
}

/** Los datos no tienen la forma esperada. */
class InvalidData extends Error {}

type Data = Record<string, unknown>;

function record(value: unknown, keys: string[], optional: string[] = []): Data {
  if (typeof value !== 'object' || value === null || Array.isArray(value)) {
    throw new InvalidData();
  }
  const data = value as Data;
  for (const key of Object.keys(data)) {
    if (!keys.includes(key) && !optional.includes(key)) throw new InvalidData();
  }
  for (const key of keys) {
    if (!(key in data) || data[key] === undefined) throw new InvalidData();
  }
  return data;
}

function text(value: unknown): string {
  if (typeof value !== 'string') throw new InvalidData();
  return value;
}

function nullableText(value: unknown): string | null {
  return value === null ? null : text(value);
}

/** Un instante en ISO 8601. */
function instant(value: unknown): Date {
  const date = new Date(text(value));
  if (Number.isNaN(date.getTime())) throw new InvalidData();
  return date;
}

/** Un id de documento: texto no vacío, sin `/`, de hasta 128 caracteres. */
function docId(value: unknown): string {
  const id = text(value);
  if (id.length === 0 || id.length > 128 || id.includes('/')) throw new InvalidData();
  return id;
}

function item(value: unknown): BookableRef {
  const data = record(value, ['kind', 'id']);
  if (data.kind !== 'service' && data.kind !== 'combo') throw new InvalidData();
  return { kind: data.kind, id: text(data.id) };
}

function addonIds(value: unknown): string[] {
  if (!Array.isArray(value)) throw new InvalidData();
  return value.map(text);
}

/** La copia de lo reservado: un mapa; su contenido lo juzga la lista (RF-12). */
function booked(value: unknown): Data {
  return record(value, [], Object.keys((value ?? {}) as Data));
}

function recipient(value: unknown): Recipient | undefined {
  if (value === undefined) return undefined;
  if (typeof value === 'object' && value !== null && 'clientId' in value) {
    const data = record(value, ['clientId']);
    return { clientId: docId(data.clientId) };
  }
  const data = record(value, ['name', 'phone']);
  return { name: text(data.name), phone: text(data.phone) };
}

const SELECTION_KEYS = ['id', 'start', 'item', 'addonIds', 'booked'];

function bookRequest(value: unknown): BookRequest {
  const data = record(value, SELECTION_KEYS, ['recipient']);
  const request: BookRequest = {
    id: docId(data.id),
    start: instant(data.start),
    item: item(data.item),
    addonIds: addonIds(data.addonIds),
    booked: booked(data.booked),
  };
  const person = recipient(data.recipient);
  if (person !== undefined) request.recipient = person;
  return request;
}

function expected(value: unknown): ExpectedAppointment {
  const data = record(value, [
    'startTime',
    'endTime',
    'status',
    'booked',
    'clientId',
    'clientName',
    'clientPhone',
    'clientPhotoUrl',
    'createdByAdmin',
  ]);
  if (typeof data.createdByAdmin !== 'boolean') throw new InvalidData();
  return {
    startTime: instant(data.startTime),
    endTime: instant(data.endTime),
    status: text(data.status),
    booked: booked(data.booked),
    clientId: nullableText(data.clientId),
    clientName: text(data.clientName),
    clientPhone: text(data.clientPhone),
    clientPhotoUrl: nullableText(data.clientPhotoUrl),
    createdByAdmin: data.createdByAdmin,
  };
}

function editRequest(value: unknown): EditRequest {
  const { expected: sent, ...selection } = record(
    value,
    [...SELECTION_KEYS, 'expected'],
    ['recipient'],
  );
  return { ...bookRequest(selection), expected: expected(sent) };
}

function closureRequest(value: unknown): Range {
  const data = record(value, ['start', 'end']);
  return { start: instant(data.start), end: instant(data.end) };
}

/** Valida la sesión y los datos, llama al caso de uso y traduce los errores. */
async function handle<R, T>(
  name: string,
  call: AgendaCall,
  parse: (data: unknown) => R,
  run: (uid: string, request: R) => Promise<T>,
  log: AgendaLog,
): Promise<T> {
  const uid = call.auth?.uid;
  if (uid === undefined) throw new HttpsError('unauthenticated', 'unauthenticated');
  let request: R;
  try {
    request = parse(call.data);
  } catch (error) {
    if (error instanceof InvalidData) throw new HttpsError('invalid-argument', 'invalid');
    throw error;
  }
  try {
    return await run(uid, request);
  } catch (error) {
    if (error instanceof AgendaError) {
      throw new HttpsError(error.code, error.reason, { reason: error.reason, ...error.details });
    }
    log.error(`No se pudo ${name}`, { uid, error: String(error) });
    throw new HttpsError('internal', 'internal');
  }
}

/** `bookAppointment`: reserva para la clienta de la sesión o, la admin, para otra persona. */
export const handleBookAppointment = (
  call: AgendaCall,
  store: AgendaStore,
  now: Date,
  log: AgendaLog,
) =>
  handle('reservar el turno', call, bookRequest, (uid, request) =>
    bookAppointment(store, uid, request, now), log);

/** `editAppointment`: edita un turno activo. */
export const handleEditAppointment = (
  call: AgendaCall,
  store: AgendaStore,
  now: Date,
  log: AgendaLog,
) =>
  handle('editar el turno', call, editRequest, (uid, request) =>
    editAppointment(store, uid, request, now), log);

/** `saveClosure`: guarda un cierre de la admin. */
export const handleSaveClosure = (
  call: AgendaCall,
  store: AgendaStore,
  now: Date,
  log: AgendaLog,
) =>
  handle('guardar el cierre', call, closureRequest, (uid, range) =>
    saveClosure(store, uid, range, now), log);
