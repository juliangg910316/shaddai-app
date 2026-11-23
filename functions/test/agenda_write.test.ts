// Reservar en el servidor (spec 012, RF-1, RF-3, RF-4, RF-6, RF-8 a RF-12;
// plan § 4). Sin Firebase: un almacén en memoria con transacciones que se
// reintentan si el candado cambió.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, test } from 'node:test';

import { AgendaError, bookAppointment } from '../src/agenda_write.ts';
import type { BookRequest } from '../src/agenda_write.ts';
import { MemoryAgendaStore } from './memory_agenda_store.ts';
import type { MemoryAppointment } from './memory_agenda_store.ts';

/** Lunes 23/11/2026, 10:00 en el salón. */
const NOW = new Date('2026-11-23T13:00:00Z');
/** Martes 24/11, 10:00 en el salón. */
const TUESDAY_10 = new Date('2026-11-24T13:00:00Z');

const MANI = {
  kind: 'service',
  id: 'mani',
  name: { es: 'Manicura', pt: 'Manicure' },
  priceCents: 3000,
  priceFrom: false,
  durationMinutes: 60,
  addons: [] as unknown[],
};

const DECO = { id: 'deco', name: { es: 'Decoración', pt: 'Decoração' }, priceCents: 500 };

const PRICE_LIST = {
  categories: [
    {
      id: 'manos',
      name: { es: 'Manos', pt: 'Mãos' },
      items: [
        { ...MANI, kind: 'service', addons: undefined },
        { ...DECO, kind: 'addon' },
        { id: 'largo', kind: 'service', name: { es: 'Largo', pt: 'Longo' }, priceCents: 9000, durationMinutes: 600 },
      ],
    },
  ],
  combos: [],
};

function salon() {
  const store = new MemoryAgendaStore();
  store.priceList = PRICE_LIST;
  store.users.set('ana', {
    uid: 'ana',
    displayName: 'Ana',
    phoneNumber: '41999990000',
    photoUrl: 'https://foto/ana',
    role: 'cliente',
    isBlocked: false,
  });
  store.users.set('bea', {
    uid: 'bea',
    displayName: 'Bea',
    phoneNumber: '41888880000',
    photoUrl: null,
    role: 'cliente',
    isBlocked: false,
  });
  store.users.set('admin', {
    uid: 'admin',
    displayName: 'Beidis',
    phoneNumber: '41777770000',
    photoUrl: null,
    role: 'admin',
    isBlocked: false,
  });
  store.users.set('admin2', {
    uid: 'admin2',
    displayName: 'Otra',
    phoneNumber: null,
    photoUrl: null,
    role: 'admin',
    isBlocked: false,
  });
  return store;
}

const request = (overrides: Partial<BookRequest> = {}): BookRequest => ({
  id: 't1',
  start: TUESDAY_10,
  item: { kind: 'service', id: 'mani' },
  addonIds: [],
  booked: MANI,
  ...overrides,
});

/** Un turno que ya existe, confirmado, de [clientId]. */
function existing(
  id: string,
  start: string,
  end: string,
  fields: Partial<MemoryAppointment> = {},
): MemoryAppointment {
  return {
    id,
    clientId: null,
    clientName: 'Otra',
    clientPhone: '',
    clientPhotoUrl: null,
    startTime: new Date(start),
    endTime: new Date(end),
    status: 'confirmed',
    createdAt: NOW,
    createdByAdmin: false,
    booked: MANI,
    ...fields,
  };
}

async function rejection(promise: Promise<unknown>): Promise<string> {
  try {
    await promise;
  } catch (error) {
    assert.ok(error instanceof AgendaError, String(error));
    return error.reason;
  }
  assert.fail('Se esperaba un rechazo');
}

describe('la clienta reserva (spec 005)', () => {
  test('a su nombre, esperando confirmación, con su ficha y su turno ocupado', async () => {
    const store = salon();
    const result = await bookAppointment(store, 'ana', request({ addonIds: ['deco'], booked: { ...MANI, addons: [DECO] } }), NOW);

    assert.deepEqual(result, { id: 't1' });
    assert.deepEqual(store.appointments.get('t1'), {
      id: 't1',
      clientId: 'ana',
      clientName: 'Ana',
      clientPhone: '41999990000',
      clientPhotoUrl: 'https://foto/ana',
      startTime: TUESDAY_10,
      endTime: new Date('2026-11-24T14:00:00Z'),
      status: 'waiting_confirmation',
      createdAt: NOW,
      createdByAdmin: false,
      booked: { ...MANI, addons: [DECO] },
    });
    assert.deepEqual(store.busySlots.get('t1'), {
      start: TUESDAY_10,
      end: new Date('2026-11-24T14:00:00Z'),
    });
    assert.deepEqual(store.lockUpdatedAt, NOW);
  });

  test('bloqueada → blocked', async () => {
    const store = salon();
    store.users.get('ana')!.isBlocked = true;
    assert.equal(await rejection(bookAppointment(store, 'ana', request(), NOW)), 'blocked');
    assert.equal(store.appointments.size, 0);
  });

  test('con un turno activo → already_active', async () => {
    const store = salon();
    store.appointments.set(
      'antes',
      existing('antes', '2026-11-26T13:00:00Z', '2026-11-26T14:00:00Z', {
        clientId: 'ana',
        status: 'waiting_confirmation',
      }),
    );
    assert.equal(await rejection(bookAppointment(store, 'ana', request(), NOW)), 'already_active');
  });

  test('un turno cancelado o terminado no le impide reservar', async () => {
    const store = salon();
    store.appointments.set(
      'cancelado',
      existing('cancelado', '2026-11-26T13:00:00Z', '2026-11-26T14:00:00Z', { clientId: 'ana', status: 'cancelled' }),
    );
    await bookAppointment(store, 'ana', request(), NOW);
    assert.equal(store.appointments.get('t1')?.status, 'waiting_confirmation');
  });

  test('si manda una persona → invalid', async () => {
    assert.equal(
      await rejection(bookAppointment(salon(), 'ana', request({ recipient: { clientId: 'bea' } }), NOW)),
      'invalid',
    );
  });
});

describe('la admin reserva para otra persona (spec 007)', () => {
  test('para una clienta: confirmado, marcado y con la ficha de la clienta', async () => {
    const store = salon();
    await bookAppointment(store, 'admin', request({ recipient: { clientId: 'bea' } }), NOW);
    const saved = store.appointments.get('t1')!;
    assert.equal(saved.clientId, 'bea');
    assert.equal(saved.clientName, 'Bea');
    assert.equal(saved.clientPhone, '41888880000');
    assert.equal(saved.clientPhotoUrl, null);
    assert.equal(saved.status, 'confirmed');
    assert.equal(saved.createdByAdmin, true);
  });

  test('para una persona sin cuenta: sin clientId, con su nombre y WhatsApp', async () => {
    const store = salon();
    await bookAppointment(
      store,
      'admin',
      request({ recipient: { name: '  Carla ', phone: ' 41 96666-0000 ' } }),
      NOW,
    );
    const saved = store.appointments.get('t1')!;
    assert.equal(saved.clientId, null);
    assert.equal(saved.clientName, 'Carla');
    assert.equal(saved.clientPhone, '41 96666-0000');
    assert.equal(saved.clientPhotoUrl, null);
    assert.equal(saved.status, 'confirmed');
    assert.equal(saved.createdByAdmin, true);
  });

  test('hasta 365 días; la clienta, solo 60', async () => {
    const day89 = new Date('2027-02-20T13:00:00Z'); // sábado
    await bookAppointment(salon(), 'admin', request({ start: day89, recipient: { clientId: 'bea' } }), NOW);
    assert.equal(await rejection(bookAppointment(salon(), 'ana', request({ start: day89 }), NOW)), 'outside_window');
  });

  test('persona con un turno activo, por su cuenta o por su WhatsApp → person_active', async () => {
    const byAccount = salon();
    byAccount.appointments.set(
      'antes',
      existing('antes', '2026-11-26T13:00:00Z', '2026-11-26T14:00:00Z', { clientId: 'bea' }),
    );
    assert.equal(
      await rejection(bookAppointment(byAccount, 'admin', request({ recipient: { clientId: 'bea' } }), NOW)),
      'person_active',
    );

    const byPhone = salon();
    byPhone.appointments.set(
      'antes',
      existing('antes', '2026-11-26T13:00:00Z', '2026-11-26T14:00:00Z', { clientPhone: '+55 41 96666-0000' }),
    );
    assert.equal(
      await rejection(
        bookAppointment(byPhone, 'admin', request({ recipient: { name: 'Carla', phone: '41966660000' } }), NOW),
      ),
      'person_active',
    );

    const accountByPhone = salon();
    accountByPhone.appointments.set(
      'antes',
      existing('antes', '2026-11-26T13:00:00Z', '2026-11-26T14:00:00Z', { clientPhone: '5541888880000' }),
    );
    assert.equal(
      await rejection(bookAppointment(accountByPhone, 'admin', request({ recipient: { clientId: 'bea' } }), NOW)),
      'person_active',
    );
  });

  test('destinataria bloqueada, con cuenta o por el WhatsApp de su cuenta → recipient_blocked', async () => {
    const store = salon();
    store.users.get('bea')!.isBlocked = true;
    assert.equal(
      await rejection(bookAppointment(store, 'admin', request({ recipient: { clientId: 'bea' } }), NOW)),
      'recipient_blocked',
    );
    assert.equal(
      await rejection(
        bookAppointment(store, 'admin', request({ recipient: { name: 'Bea', phone: '+55 41 88888-0000' } }), NOW),
      ),
      'recipient_blocked',
    );
  });

  test('para sí misma, para otra admin, para nadie o con datos no válidos → invalid', async () => {
    for (const recipient of [
      { clientId: 'admin' },
      { clientId: 'admin2' },
      { clientId: 'nadie' },
      { name: ' ', phone: '41966660000' },
      { name: 'Carla', phone: '1234' },
      undefined,
    ]) {
      assert.equal(
        await rejection(bookAppointment(salon(), 'admin', request({ recipient }), NOW)),
        'invalid',
        JSON.stringify(recipient),
      );
    }
  });
});

describe('las horas y lo reservado', () => {
  test('hora ocupada → slot_taken; cancelado no ocupa', async () => {
    const store = salon();
    store.appointments.set('otro', existing('otro', '2026-11-24T13:00:00Z', '2026-11-24T14:00:00Z'));
    assert.equal(await rejection(bookAppointment(store, 'ana', request(), NOW)), 'slot_taken');

    const free = salon();
    free.appointments.set('otro', existing('otro', '2026-11-24T13:00:00Z', '2026-11-24T14:00:00Z', { status: 'cancelled' }));
    await bookAppointment(free, 'ana', request(), NOW);
  });

  test('bajo un cierre o en una fecha bloqueada → closed', async () => {
    const store = salon();
    store.closures = [{ start: new Date('2026-11-24T12:00:00Z'), end: new Date('2026-11-24T15:00:00Z') }];
    assert.equal(await rejection(bookAppointment(store, 'ana', request(), NOW)), 'closed');

    const blocked = salon();
    blocked.calendar = { blockedDates: ['2026-11-24'] };
    assert.equal(await rejection(bookAppointment(blocked, 'ana', request(), NOW)), 'closed');
  });

  test('fuera de la rejilla → outside_hours; ya pasada → past', async () => {
    assert.equal(
      await rejection(bookAppointment(salon(), 'ana', request({ start: new Date('2026-11-24T13:15:00Z') }), NOW)),
      'outside_hours',
    );
    assert.equal(
      await rejection(bookAppointment(salon(), 'ana', request({ start: new Date('2026-11-23T12:00:00Z') }), NOW)),
      'past',
    );
  });

  test('el servicio no cabe hasta el cierre → does_not_fit', async () => {
    const largo = { ...MANI, id: 'largo', name: { es: 'Largo', pt: 'Longo' }, priceCents: 9000, durationMinutes: 600 };
    assert.equal(
      await rejection(bookAppointment(salon(), 'ana', request({ item: { kind: 'service', id: 'largo' }, booked: largo }), NOW)),
      'does_not_fit',
    );
  });

  test('el fin lo calcula el servidor con la duración de la lista (RF-11)', async () => {
    const store = salon();
    await bookAppointment(store, 'ana', request(), NOW);
    assert.deepEqual(store.appointments.get('t1')?.endTime, new Date('2026-11-24T14:00:00Z'));
  });

  test('lo que ya no se ofrece → item_unavailable; lo que cambió → item_changed', async () => {
    assert.equal(
      await rejection(bookAppointment(salon(), 'ana', request({ item: { kind: 'service', id: 'nada' } }), NOW)),
      'item_unavailable',
    );
    assert.equal(
      await rejection(bookAppointment(salon(), 'ana', request({ booked: { ...MANI, priceCents: 1 } }), NOW)),
      'item_changed',
    );
  });
});

describe('quién llama y el id', () => {
  test('sin ficha → permission-denied', async () => {
    const error = await bookAppointment(salon(), 'nadie', request(), NOW).catch((e: unknown) => e);
    assert.ok(error instanceof AgendaError);
    assert.equal(error.code, 'permission-denied');
  });

  test('un id ya usado → invalid, sin tocar el turno', async () => {
    const store = salon();
    store.appointments.set('t1', existing('t1', '2026-12-01T13:00:00Z', '2026-12-01T14:00:00Z', { status: 'cancelled' }));
    assert.equal(await rejection(bookAppointment(store, 'ana', request(), NOW)), 'invalid');
    assert.equal(store.appointments.get('t1')?.status, 'cancelled');
  });
});

describe('dos reservas a la vez (RF-3, RF-8)', () => {
  test('de la misma hora: se guarda una y la otra recibe slot_taken', async () => {
    const store = salon();
    const results = await Promise.allSettled([
      bookAppointment(store, 'ana', request({ id: 'a' }), NOW),
      bookAppointment(store, 'bea', request({ id: 'b' }), NOW),
    ]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    const failed = results.find((r) => r.status === 'rejected') as PromiseRejectedResult;
    assert.equal((failed.reason as AgendaError).reason, 'slot_taken');
    assert.equal(store.appointments.size, 1);
    assert.ok(store.retries >= 1);
  });

  test('de la misma clienta en días distintos: se guarda una y la otra recibe already_active', async () => {
    const store = salon();
    const results = await Promise.allSettled([
      bookAppointment(store, 'ana', request({ id: 'a' }), NOW),
      bookAppointment(store, 'ana', request({ id: 'b', start: new Date('2026-11-25T13:00:00Z') }), NOW),
    ]);
    assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
    const failed = results.find((r) => r.status === 'rejected') as PromiseRejectedResult;
    assert.equal((failed.reason as AgendaError).reason, 'already_active');
    assert.equal(store.appointments.size, 1);
  });
});

describe('la forma de lo escrito', () => {
  test('los mismos campos que AppointmentModel.toMap (casos compartidos)', async () => {
    const { appointmentFields } = JSON.parse(
      readFileSync(new URL('../../test/fixtures/agenda_rules_cases.json', import.meta.url), 'utf8'),
    ) as { appointmentFields: string[] };
    for (const [caller, recipient] of [
      ['ana', undefined],
      ['admin', { clientId: 'bea' }],
      ['admin', { name: 'Carla', phone: '41966660000' }],
    ] as const) {
      const store = salon();
      await bookAppointment(store, caller, request({ recipient }), NOW);
      const { id: _, ...written } = store.appointments.get('t1')!;
      assert.deepEqual(Object.keys(written).sort(), appointmentFields);
    }
  });
});
