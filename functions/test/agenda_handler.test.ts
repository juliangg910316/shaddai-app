// El adaptador de las funciones invocables de la agenda (spec 012, RF-16,
// RF-17, RNF-4; plan § 2, § 6): el uid de la sesión, la forma de los datos
// y los errores como HttpsError. Sin Firebase: el almacén en memoria.
import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import { HttpsError } from 'firebase-functions/v2/https';

import {
  handleBookAppointment,
  handleEditAppointment,
  handleSaveClosure,
} from '../src/agenda_handler.ts';
import type { AgendaLog } from '../src/agenda_handler.ts';
import type { AgendaStore } from '../src/agenda_write.ts';
import { MemoryAgendaStore } from './memory_agenda_store.ts';

const NOW = new Date('2026-11-23T13:00:00Z');

const MANI = {
  kind: 'service',
  id: 'mani',
  name: { es: 'Manicura', pt: 'Manicure' },
  priceCents: 3000,
  priceFrom: false,
  durationMinutes: 60,
  addons: [],
};

class MemoryLog implements AgendaLog {
  errors: { message: string; details: Record<string, unknown> }[] = [];
  error(message: string, details: Record<string, unknown>) {
    this.errors.push({ message, details });
  }
}

function salon() {
  const store = new MemoryAgendaStore();
  store.priceList = {
    categories: [{ id: 'manos', name: { es: 'Manos', pt: 'Mãos' }, items: [{ ...MANI, addons: undefined }] }],
    combos: [],
  };
  for (const [uid, role, name, phone] of [
    ['ana', 'cliente', 'Ana', '41999990000'],
    ['bea', 'cliente', 'Bea Secreta', '41888880000'],
    ['admin', 'admin', 'Beidis', null],
  ] as const) {
    store.users.set(uid, { uid, displayName: name, phoneNumber: phone, photoUrl: null, role, isBlocked: false });
  }
  return store;
}

const bookData = (overrides: Record<string, unknown> = {}) => ({
  id: 't1',
  start: '2026-11-24T13:00:00.000Z',
  item: { kind: 'service', id: 'mani' },
  addonIds: [],
  booked: MANI,
  ...overrides,
});

async function httpsError(promise: Promise<unknown>): Promise<HttpsError> {
  try {
    await promise;
  } catch (error) {
    assert.ok(error instanceof HttpsError, String(error));
    return error;
  }
  assert.fail('Se esperaba un HttpsError');
}

describe('la sesión', () => {
  test('el uid sale de la sesión, no de los datos', async () => {
    const store = salon();
    const result = await handleBookAppointment(
      { auth: { uid: 'ana' }, data: bookData() },
      store,
      NOW,
      new MemoryLog(),
    );
    assert.deepEqual(result, { id: 't1' });
    assert.equal(store.appointments.get('t1')?.clientId, 'ana');
  });

  test('un uid en los datos es un campo de más', async () => {
    const error = await httpsError(
      handleBookAppointment({ auth: { uid: 'ana' }, data: bookData({ uid: 'bea' }) }, salon(), NOW, new MemoryLog()),
    );
    assert.equal(error.code, 'invalid-argument');
  });

  test('sin sesión → unauthenticated, en las tres', async () => {
    const log = new MemoryLog();
    for (const call of [
      handleBookAppointment({ data: bookData() }, salon(), NOW, log),
      handleEditAppointment({ data: {} }, salon(), NOW, log),
      handleSaveClosure({ data: {} }, salon(), NOW, log),
    ]) {
      assert.equal((await httpsError(call)).code, 'unauthenticated');
    }
  });
});

describe('la forma de los datos → invalid-argument', () => {
  const invalid: [string, unknown][] = [
    ['sin datos', undefined],
    ['sin start', (({ start: _, ...rest }) => rest)(bookData())],
    ['start que no es una fecha', bookData({ start: 'mañana' })],
    ['start que no es texto', bookData({ start: 1764000000000 })],
    ['id vacío', bookData({ id: '' })],
    ['id con barra', bookData({ id: 'a/b' })],
    ['otro tipo de servicio', bookData({ item: { kind: 'addon', id: 'mani' } })],
    ['adicionales que no son texto', bookData({ addonIds: [1] })],
    ['sin copia de lo reservado', bookData({ booked: 'mani' })],
    ['persona con campos de más', bookData({ recipient: { clientId: 'bea', name: 'Bea' } })],
    ['persona sin WhatsApp', bookData({ recipient: { name: 'Carla' } })],
    ['un campo de más', bookData({ status: 'confirmed' })],
  ];
  for (const [why, data] of invalid) {
    test(`reservar: ${why}`, async () => {
      const store = salon();
      const error = await httpsError(handleBookAppointment({ auth: { uid: 'ana' }, data }, store, NOW, new MemoryLog()));
      assert.equal(error.code, 'invalid-argument');
      assert.equal(store.appointments.size, 0);
    });
  }

  test('editar: sin lo esperado, o con lo esperado incompleto', async () => {
    const expected = {
      startTime: '2026-11-24T13:00:00.000Z',
      endTime: '2026-11-24T14:00:00.000Z',
      status: 'confirmed',
      booked: MANI,
      clientId: 'ana',
      clientName: 'Ana',
      clientPhone: '41999990000',
      clientPhotoUrl: null,
      createdByAdmin: false,
    };
    for (const data of [
      bookData(),
      bookData({ expected: { ...expected, startTime: undefined } }),
      bookData({ expected: { ...expected, createdByAdmin: 'no' } }),
      bookData({ expected: { ...expected, extra: 1 } }),
    ]) {
      const error = await httpsError(handleEditAppointment({ auth: { uid: 'ana' }, data }, salon(), NOW, new MemoryLog()));
      assert.equal(error.code, 'invalid-argument', JSON.stringify(data));
    }
  });

  test('cierre: sin fin, con fechas que no lo son o con campos de más', async () => {
    for (const data of [
      { start: '2026-11-24T17:00:00.000Z' },
      { start: '2026-11-24T17:00:00.000Z', end: 'luego' },
      { start: '2026-11-24T17:00:00.000Z', end: '2026-11-24T19:00:00.000Z', id: 'x' },
    ]) {
      const error = await httpsError(handleSaveClosure({ auth: { uid: 'admin' }, data }, salon(), NOW, new MemoryLog()));
      assert.equal(error.code, 'invalid-argument', JSON.stringify(data));
    }
  });
});

describe('los rechazos de la agenda', () => {
  test('failed-precondition con el motivo en details.reason', async () => {
    const store = salon();
    await handleBookAppointment({ auth: { uid: 'bea' }, data: bookData({ id: 'b1' }) }, store, NOW, new MemoryLog());
    const error = await httpsError(handleBookAppointment({ auth: { uid: 'ana' }, data: bookData() }, store, NOW, new MemoryLog()));
    assert.equal(error.code, 'failed-precondition');
    assert.deepEqual(error.details, { reason: 'slot_taken' });
  });

  test('sin ficha → permission-denied con su motivo', async () => {
    const error = await httpsError(
      handleBookAppointment({ auth: { uid: 'nadie' }, data: bookData() }, salon(), NOW, new MemoryLog()),
    );
    assert.equal(error.code, 'permission-denied');
    assert.deepEqual(error.details, { reason: 'no_profile' });
  });

  test('conflicts lleva los ids de los turnos', async () => {
    const store = salon();
    await handleBookAppointment({ auth: { uid: 'bea' }, data: bookData({ id: 'b1', start: '2026-11-24T17:00:00.000Z' }) }, store, NOW, new MemoryLog());
    const error = await httpsError(
      handleSaveClosure(
        { auth: { uid: 'admin' }, data: { start: '2026-11-24T17:00:00.000Z', end: '2026-11-24T19:00:00.000Z' } },
        store,
        NOW,
        new MemoryLog(),
      ),
    );
    assert.equal(error.code, 'failed-precondition');
    assert.deepEqual(error.details, { reason: 'conflicts', ids: ['b1'] });
  });

  test('los detalles no llevan datos de otra persona (RNF-4)', async () => {
    const store = salon();
    await handleBookAppointment({ auth: { uid: 'admin' }, data: bookData({ id: 'b1', start: '2026-11-25T13:00:00.000Z', recipient: { clientId: 'bea' } }) }, store, NOW, new MemoryLog());
    const error = await httpsError(
      handleBookAppointment({ auth: { uid: 'admin' }, data: bookData({ recipient: { clientId: 'bea' } }) }, store, NOW, new MemoryLog()),
    );
    assert.deepEqual(error.details, { reason: 'person_active' });
    const text = `${error.message} ${JSON.stringify(error.details)}`;
    for (const secret of ['Bea', '41888880000', 'Manicura', 'b1']) {
      assert.ok(!text.includes(secret), secret);
    }
  });

  test('reservar, editar y cerrar devuelven el id', async () => {
    const store = salon();
    const log = new MemoryLog();
    await handleBookAppointment({ auth: { uid: 'ana' }, data: bookData() }, store, NOW, log);
    const { id: _, ...saved } = store.appointments.get('t1')!;
    const expected = {
      ...saved,
      startTime: saved.startTime.toISOString(),
      endTime: saved.endTime.toISOString(),
      createdAt: undefined,
    };
    delete expected.createdAt;
    const edited = await handleEditAppointment(
      { auth: { uid: 'ana' }, data: bookData({ start: '2026-11-24T17:00:00.000Z', expected }) },
      store,
      NOW,
      log,
    );
    assert.deepEqual(edited, { id: 't1' });
    assert.deepEqual(store.appointments.get('t1')?.startTime, new Date('2026-11-24T17:00:00.000Z'));

    const closure = await handleSaveClosure(
      { auth: { uid: 'admin' }, data: { start: '2026-11-25T17:00:00.000Z', end: '2026-11-25T19:00:00.000Z' } },
      store,
      NOW,
      log,
    );
    assert.equal(typeof closure.id, 'string');
    assert.deepEqual(log.errors, []);
  });
});

describe('turnos de antes de la spec 005', () => {
  test('editar uno sin copia de lo reservado: expected.booked puede ser null', async () => {
    const store = salon();
    store.appointments.set('viejo', {
      id: 'viejo',
      clientId: 'ana',
      clientName: 'Ana',
      clientPhone: '41999990000',
      clientPhotoUrl: null,
      startTime: new Date('2026-11-24T13:00:00Z'),
      endTime: new Date('2026-11-24T14:00:00Z'),
      status: 'confirmed',
      createdAt: NOW,
      createdByAdmin: false,
      booked: undefined,
    });
    const result = await handleEditAppointment(
      {
        auth: { uid: 'ana' },
        data: bookData({
          id: 'viejo',
          start: '2026-11-24T17:00:00.000Z',
          expected: {
            startTime: '2026-11-24T13:00:00.000Z',
            endTime: '2026-11-24T14:00:00.000Z',
            status: 'confirmed',
            booked: null,
            clientId: 'ana',
            clientName: 'Ana',
            clientPhone: '41999990000',
            clientPhotoUrl: null,
            createdByAdmin: false,
          },
        }),
      },
      store,
      NOW,
      new MemoryLog(),
    );
    assert.deepEqual(result, { id: 'viejo' });
    assert.deepEqual(store.appointments.get('viejo')?.booked, MANI);
  });
});

describe('cualquier otro fallo', () => {
  test('internal, sin detalles, y queda en el registro', async () => {
    const broken: AgendaStore = {
      runTransaction: async () => {
        throw new Error('Firestore no responde');
      },
    };
    const log = new MemoryLog();
    const error = await httpsError(handleBookAppointment({ auth: { uid: 'ana' }, data: bookData() }, broken, NOW, log));
    assert.equal(error.code, 'internal');
    assert.equal(error.details, undefined);
    assert.ok(!error.message.includes('Firestore'));
    assert.equal(log.errors.length, 1);
    assert.match(String(log.errors[0].details.error), /Firestore no responde/);
    assert.equal(log.errors[0].details.uid, 'ana');
  });
});

describe('index.ts', () => {
  test('exporta las tres funciones en southamerica-east1', async () => {
    const { readFileSync } = await import('node:fs');
    const source = readFileSync(new URL('../src/index.ts', import.meta.url), 'utf8');
    for (const name of ['bookAppointment', 'editAppointment', 'saveClosure']) {
      assert.match(
        source,
        new RegExp(`export const ${name} = onCall\\(\\{ region: 'southamerica-east1' \\}`),
        name,
      );
    }
  });
});
