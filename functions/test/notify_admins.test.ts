// El envío de los avisos a la admin y la limpieza de los dispositivos (spec
// 011, RF-5, RF-12, RF-19, RF-21, RF-24; plan D-3, D-5). Con un almacén en
// memoria: ningún test toca Firebase.
import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import type { NoticeAppointment } from '../src/appointment_notice.ts';
import {
  notifyAdmins,
  notifyAdminsSafely,
  readNoticeAppointment,
} from '../src/notify_admins.ts';
import type {
  NoticeDevice,
  NoticeMessage,
  NoticeStore,
  SendResult,
} from '../src/notify_admins.ts';

/** Sábado 21 de noviembre de 2026, 10:00 en Curitiba. */
const reserved: NoticeAppointment = {
  clientId: 'ana',
  clientName: 'Ana Herrera',
  status: 'waiting_confirmation',
  start: new Date('2026-11-21T13:00:00Z'),
  end: new Date('2026-11-21T14:00:00Z'),
  bookedKey: '{"id":"mani"}',
  serviceName: 'Manicura',
  createdByAdmin: false,
  cancelledByClient: false,
  accountDeleted: false,
};

const input = (
  before: NoticeAppointment | null,
  after: NoticeAppointment | null,
) => ({ eventId: 'evento-1', appointmentId: 'turno-1', before, after });

/** Un almacén en memoria: devuelve un resultado por FID, en orden. */
class MemoryStore implements NoticeStore {
  devices: NoticeDevice[] = [];
  /** El código de error de cada FID; sin entrada, se entrega. */
  failures = new Map<string, string>();
  sent: { fids: string[]; message: NoticeMessage }[] = [];
  removed: NoticeDevice[] = [];
  /** Si está, `send` lanza este error. */
  sendError?: Error;

  async adminDevices() {
    return [...this.devices];
  }

  async send(fids: string[], message: NoticeMessage): Promise<SendResult[]> {
    if (this.sendError) throw this.sendError;
    this.sent.push({ fids, message });
    return fids.map((fid) => {
      const code = this.failures.get(fid);
      return code === undefined ? { ok: true } : { ok: false, code };
    });
  }

  async removeDevice(uid: string, fid: string) {
    this.removed.push({ uid, fid });
    this.devices = this.devices.filter(
      (d) => !(d.uid === uid && d.fid === fid),
    );
  }
}

describe('a quién y qué se envía', () => {
  test('sin aviso (lo hizo la admin), no lee ni envía nada (RF-4)', async () => {
    const store = new MemoryStore();
    store.devices = [{ uid: 'beidis', fid: 't1' }];
    const result = await notifyAdmins(
      store,
      input(reserved, { ...reserved, status: 'confirmed' }),
    );
    assert.deepEqual(result, { sent: 0, removed: 0 });
    assert.equal(store.sent.length, 0);
  });

  test('sin dispositivos, no envía ni falla (RF-24)', async () => {
    const store = new MemoryStore();
    const result = await notifyAdmins(store, input(null, reserved));
    assert.deepEqual(result, { sent: 0, removed: 0 });
    assert.equal(store.sent.length, 0);
  });

  test('a todos los dispositivos de todas las admins, cada FID una vez (RF-5, RF-19)', async () => {
    const store = new MemoryStore();
    store.devices = [
      { uid: 'beidis', fid: 'movil' },
      { uid: 'beidis', fid: 'tablet' },
      { uid: 'otra', fid: 'movil' },
      { uid: 'otra', fid: 'suyo' },
    ];
    const result = await notifyAdmins(store, input(null, reserved));
    assert.equal(store.sent.length, 1);
    assert.deepEqual(store.sent[0].fids, ['movil', 'tablet', 'suyo']);
    assert.deepEqual(result, { sent: 3, removed: 0 });
  });

  test('el mensaje: título, texto, kind, appointmentId, day y etiqueta (RF-12, plan D-4)', async () => {
    const store = new MemoryStore();
    store.devices = [{ uid: 'beidis', fid: 't1' }];
    await notifyAdmins(store, input(null, reserved));
    const { message } = store.sent[0];
    assert.equal(message.title, 'Turno nuevo');
    assert.match(message.body, /^Ana Herrera · sábado 21 de noviembre, 10:00/);
    assert.deepEqual(message.data, {
      kind: 'created',
      appointmentId: 'turno-1',
      day: '2026-11-21',
    });
    assert.match(message.tag, /^[0-9a-f]{32}$/);
  });

  test('la misma etiqueta si el mismo evento llega dos veces (RF-5)', async () => {
    const store = new MemoryStore();
    store.devices = [{ uid: 'beidis', fid: 't1' }];
    await notifyAdmins(store, input(null, reserved));
    await notifyAdmins(store, input(null, reserved));
    assert.equal(store.sent[0].message.tag, store.sent[1].message.tag);
  });

  test('el día es el del turno como quedó, también al cancelar', async () => {
    const store = new MemoryStore();
    store.devices = [{ uid: 'beidis', fid: 't1' }];
    await notifyAdmins(
      store,
      input(reserved, {
        ...reserved,
        status: 'cancelled',
        cancelledByClient: true,
      }),
    );
    assert.equal(store.sent[0].message.data.kind, 'cancelled');
    assert.equal(store.sent[0].message.data.day, '2026-11-21');
  });
});

describe('los dispositivos que ya no valen (RF-21, plan D-5)', () => {
  test('los no registrados o inválidos se borran de cada dueña', async () => {
    const store = new MemoryStore();
    store.devices = [
      { uid: 'beidis', fid: 'viejo' },
      { uid: 'otra', fid: 'viejo' },
      { uid: 'beidis', fid: 'roto' },
      { uid: 'beidis', fid: 'bueno' },
    ];
    store.failures.set('viejo', 'messaging/registration-token-not-registered');
    store.failures.set('roto', 'messaging/invalid-registration-token');
    const result = await notifyAdmins(store, input(null, reserved));
    assert.deepEqual(store.removed, [
      { uid: 'beidis', fid: 'viejo' },
      { uid: 'otra', fid: 'viejo' },
      { uid: 'beidis', fid: 'roto' },
    ]);
    assert.deepEqual(result, { sent: 1, removed: 3 });
    assert.deepEqual(store.devices, [{ uid: 'beidis', fid: 'bueno' }]);
  });

  test('otros errores (por ejemplo, de la red) no borran nada', async () => {
    const store = new MemoryStore();
    store.devices = [{ uid: 'beidis', fid: 't1' }];
    store.failures.set('t1', 'messaging/internal-error');
    const result = await notifyAdmins(store, input(null, reserved));
    assert.deepEqual(store.removed, []);
    assert.deepEqual(result, { sent: 0, removed: 0 });
  });
});

describe('si algo falla, no se propaga (RF-24, plan D-3)', () => {
  test('notifyAdmins lanza el error del envío', async () => {
    const store = new MemoryStore();
    store.devices = [{ uid: 'beidis', fid: 't1' }];
    store.sendError = new Error('sin red');
    await assert.rejects(notifyAdmins(store, input(null, reserved)), /sin red/);
  });

  test('el adaptador lo registra y no relanza', async () => {
    const store = new MemoryStore();
    store.devices = [{ uid: 'beidis', fid: 't1' }];
    store.sendError = new Error('sin red');
    const logged: unknown[][] = [];
    const result = await notifyAdminsSafely(
      store,
      input(null, reserved),
      (...args) => logged.push(args),
    );
    assert.equal(result, null);
    assert.equal(logged.length, 1);
    assert.match(String(logged[0][1] && JSON.stringify(logged[0][1])), /turno-1/);
    assert.match(JSON.stringify(logged[0][1]), /sin red/);
  });

  test('si va bien, devuelve el resultado y no registra errores', async () => {
    const store = new MemoryStore();
    store.devices = [{ uid: 'beidis', fid: 't1' }];
    const logged: unknown[][] = [];
    const result = await notifyAdminsSafely(
      store,
      input(null, reserved),
      (...args) => logged.push(args),
    );
    assert.deepEqual(result, { sent: 1, removed: 0 });
    assert.equal(logged.length, 0);
  });
});

describe('leer el turno del documento (lectura tolerante)', () => {
  /** Como un `Timestamp` de Firestore: solo importa `toDate`. */
  const ts = (iso: string) => ({ toDate: () => new Date(iso) });

  const doc = {
    clientId: 'ana',
    clientName: 'Ana Herrera',
    clientPhone: '+5541999998888',
    clientPhotoUrl: 'https://example.com/ana.jpg',
    status: 'waiting_confirmation',
    startTime: ts('2026-11-21T13:00:00Z'),
    endTime: ts('2026-11-21T14:00:00Z'),
    createdByAdmin: false,
    booked: {
      kind: 'service',
      id: 'mani',
      name: { es: 'Manicura', pt: 'Manicure' },
      addons: [{ id: 'deco', name: { es: 'Deco', pt: 'Deco' }, priceCents: 500 }],
    },
  };

  test('sin documento, null', () => {
    assert.equal(readNoticeAppointment(undefined), null);
  });

  test('un turno completo', () => {
    const appointment = readNoticeAppointment(doc)!;
    assert.equal(appointment.clientId, 'ana');
    assert.equal(appointment.clientName, 'Ana Herrera');
    assert.equal(appointment.status, 'waiting_confirmation');
    assert.equal(appointment.start.toISOString(), '2026-11-21T13:00:00.000Z');
    assert.equal(appointment.end.toISOString(), '2026-11-21T14:00:00.000Z');
    assert.equal(appointment.serviceName, 'Manicura');
    assert.equal(appointment.createdByAdmin, false);
    assert.equal(appointment.cancelledByClient, false);
    assert.equal(appointment.accountDeleted, false);
  });

  test('no copia el WhatsApp ni la foto (RNF-4)', () => {
    const text = JSON.stringify(readNoticeAppointment(doc));
    assert.doesNotMatch(text, /999998888|example\.com/);
  });

  test('las marcas de la 007 y la 009', () => {
    const appointment = readNoticeAppointment({
      ...doc,
      createdByAdmin: true,
      cancelledBy: 'client',
      accountDeleted: true,
    })!;
    assert.equal(appointment.createdByAdmin, true);
    assert.equal(appointment.cancelledByClient, true);
    assert.equal(appointment.accountDeleted, true);
  });

  test('lo reservado se compara igual aunque cambie el orden de las claves', () => {
    const reordered = readNoticeAppointment({
      ...doc,
      booked: {
        addons: doc.booked.addons,
        name: { pt: 'Manicure', es: 'Manicura' },
        id: 'mani',
        kind: 'service',
      },
    })!;
    assert.equal(reordered.bookedKey, readNoticeAppointment(doc)!.bookedKey);
  });

  test('otro adicional cambia lo reservado', () => {
    const other = readNoticeAppointment({
      ...doc,
      booked: { ...doc.booked, addons: [] },
    })!;
    assert.notEqual(other.bookedKey, readNoticeAppointment(doc)!.bookedKey);
  });

  test('sin nombre en español, el portugués; sin ninguno o sin booked, null (RF-11)', () => {
    assert.equal(
      readNoticeAppointment({ ...doc, booked: { name: { pt: 'Manicure' } } })!
        .serviceName,
      'Manicure',
    );
    assert.equal(
      readNoticeAppointment({ ...doc, booked: { name: {} } })!.serviceName,
      null,
    );
    const { booked: _, ...withoutBooked } = doc;
    assert.equal(readNoticeAppointment(withoutBooked)!.serviceName, null);
  });

  test('campos que faltan o con otro tipo: valores por defecto', () => {
    const appointment = readNoticeAppointment({})!;
    assert.equal(appointment.clientId, null);
    assert.equal(appointment.clientName, '');
    assert.equal(appointment.status, '');
    assert.equal(appointment.start.getTime(), 0);
    assert.equal(appointment.end.getTime(), 0);
    assert.equal(appointment.serviceName, null);
    assert.equal(appointment.bookedKey, 'null');
    assert.equal(appointment.createdByAdmin, false);
    assert.equal(readNoticeAppointment({ clientId: '' })!.clientId, null);
  });
});
