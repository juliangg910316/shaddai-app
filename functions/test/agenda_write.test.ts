// Reservar, editar y cerrar en el servidor (spec 012, RF-1 a RF-15; plan
// § 4). Sin Firebase: un almacén en memoria con transacciones que se
// reintentan si el candado cambió.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, test } from 'node:test';

import { coarseVerdict } from '../src/agenda_rules.ts';
import {
  AgendaError,
  bookAppointment,
  editAppointment,
  saveClosure,
} from '../src/agenda_write.ts';
import type { BookRequest, EditRequest } from '../src/agenda_write.ts';
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
        { id: 'gel', kind: 'service', name: { es: 'Gel', pt: 'Gel' }, priceCents: 8000, durationMinutes: 120 },
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

// Editar -------------------------------------------------------------------

const GEL = {
  kind: 'service',
  id: 'gel',
  name: { es: 'Gel', pt: 'Gel' },
  priceCents: 8000,
  priceFrom: false,
  durationMinutes: 120,
  addons: [] as unknown[],
};

/** El turno de Ana: martes de 10:00 a 11:00 en el salón, esperando. */
function withAnaAppointment(fields: Partial<MemoryAppointment> = {}) {
  const store = salon();
  store.appointments.set(
    'ana1',
    existing('ana1', '2026-11-24T13:00:00Z', '2026-11-24T14:00:00Z', {
      clientId: 'ana',
      clientName: 'Ana',
      clientPhone: '41999990000',
      clientPhotoUrl: 'https://foto/ana',
      status: 'waiting_confirmation',
      ...fields,
    }),
  );
  store.busySlots.set('ana1', {
    start: new Date('2026-11-24T13:00:00Z'),
    end: new Date('2026-11-24T14:00:00Z'),
  });
  return store;
}

/** Lo que tenía el turno al abrir la edición. */
function expectedOf(store: MemoryAgendaStore, id = 'ana1') {
  const { id: _, ...current } = store.appointments.get(id)!;
  return current;
}

const edit = (store: MemoryAgendaStore, overrides: Partial<EditRequest> = {}): EditRequest => ({
  id: 'ana1',
  start: new Date('2026-11-24T17:00:00Z'), // 14:00 en el salón
  item: { kind: 'service', id: 'mani' },
  addonIds: [],
  booked: MANI,
  expected: expectedOf(store),
  ...overrides,
});

describe('la clienta edita su turno (spec 006)', () => {
  test('cambia horas, servicio y estado, y su turno ocupado; nada más', async () => {
    const store = withAnaAppointment({ status: 'confirmed', createdAt: new Date('2026-11-01T12:00:00Z') });
    const before = expectedOf(store);
    const result = await editAppointment(store, 'ana', edit(store, { item: { kind: 'service', id: 'gel' }, booked: GEL }), NOW);

    assert.deepEqual(result, { id: 'ana1' });
    assert.deepEqual(store.appointments.get('ana1'), {
      ...before,
      id: 'ana1',
      startTime: new Date('2026-11-24T17:00:00Z'),
      endTime: new Date('2026-11-24T19:00:00Z'),
      status: 'waiting_confirmation',
      booked: GEL,
      createdAt: new Date('2026-11-01T12:00:00Z'),
      clientName: 'Ana',
    });
    assert.deepEqual(store.busySlots.get('ana1'), {
      start: new Date('2026-11-24T17:00:00Z'),
      end: new Date('2026-11-24T19:00:00Z'),
    });
    assert.deepEqual(store.lockUpdatedAt, NOW);
  });

  test('de otra persona, bloqueada o dentro del margen → not_editable', async () => {
    const other = withAnaAppointment();
    assert.equal(await rejection(editAppointment(other, 'bea', edit(other), NOW)), 'not_editable');

    const blocked = withAnaAppointment();
    blocked.users.get('ana')!.isBlocked = true;
    assert.equal(await rejection(editAppointment(blocked, 'ana', edit(blocked), NOW)), 'not_editable');

    // Margen de 24 h: el turno empieza justo dentro de 24 h.
    const margin = withAnaAppointment();
    margin.calendar = { editMarginMinutes: 1440 };
    assert.equal(await rejection(editAppointment(margin, 'ana', edit(margin), NOW)), 'not_editable');
    margin.calendar = { editMarginMinutes: 1439 };
    await editAppointment(margin, 'ana', edit(margin), NOW);
  });

  test('cancelado, terminado o que no existe → not_active', async () => {
    const cancelled = withAnaAppointment({ status: 'cancelled' });
    assert.equal(await rejection(editAppointment(cancelled, 'ana', edit(cancelled), NOW)), 'not_active');

    const ended = withAnaAppointment();
    assert.equal(
      await rejection(editAppointment(ended, 'ana', edit(ended), new Date('2026-11-24T14:00:00Z'))),
      'not_active',
    );

    const missing = withAnaAppointment();
    assert.equal(await rejection(editAppointment(missing, 'ana', edit(missing, { id: 'nada' }), NOW)), 'not_active');
  });

  test('distinto de lo que tenía al abrir la edición → changed', async () => {
    const store = withAnaAppointment();
    const expected = { ...expectedOf(store), startTime: new Date('2026-11-24T12:00:00Z') };
    assert.equal(await rejection(editAppointment(store, 'ana', edit(store, { expected }), NOW)), 'changed');
    const otherBooked = { ...expectedOf(store), booked: GEL };
    assert.equal(await rejection(editAppointment(store, 'ana', edit(store, { expected: otherBooked }), NOW)), 'changed');
  });

  test('si manda una persona → invalid', async () => {
    const store = withAnaAppointment();
    assert.equal(
      await rejection(editAppointment(store, 'ana', edit(store, { recipient: { clientId: 'bea' } }), NOW)),
      'invalid',
    );
  });
});

describe('la admin edita un turno (spec 008)', () => {
  test('queda confirmado; sin cambiar la persona, la marca y la persona no se escriben', async () => {
    const store = withAnaAppointment();
    await editAppointment(store, 'admin', edit(store), NOW);
    const saved = store.appointments.get('ana1')!;
    assert.equal(saved.status, 'confirmed');
    assert.equal(saved.createdByAdmin, false);
    assert.equal(saved.clientId, 'ana');

    const marked = withAnaAppointment({ createdByAdmin: true });
    await editAppointment(marked, 'admin', edit(marked, { recipient: { clientId: 'ana' } }), NOW);
    assert.equal(marked.appointments.get('ana1')!.createdByAdmin, true);
  });

  test('cambiar la persona escribe la nueva y pone la marca', async () => {
    const store = withAnaAppointment();
    await editAppointment(store, 'admin', edit(store, { recipient: { clientId: 'bea' } }), NOW);
    const saved = store.appointments.get('ana1')!;
    assert.equal(saved.clientId, 'bea');
    assert.equal(saved.clientName, 'Bea');
    assert.equal(saved.clientPhone, '41888880000');
    assert.equal(saved.clientPhotoUrl, null);
    assert.equal(saved.createdByAdmin, true);

    const guest = withAnaAppointment();
    await editAppointment(guest, 'admin', edit(guest, { recipient: { name: 'Carla', phone: '41966660000' } }), NOW);
    assert.equal(guest.appointments.get('ana1')!.clientId, null);
    assert.equal(guest.appointments.get('ana1')!.clientName, 'Carla');
  });

  test('a una persona con otro turno activo → person_active; bloqueada → recipient_blocked (RF-7)', async () => {
    const store = withAnaAppointment();
    store.appointments.set('bea1', existing('bea1', '2026-11-26T13:00:00Z', '2026-11-26T14:00:00Z', { clientId: 'bea' }));
    assert.equal(
      await rejection(editAppointment(store, 'admin', edit(store, { recipient: { clientId: 'bea' } }), NOW)),
      'person_active',
    );

    const blocked = withAnaAppointment();
    blocked.users.get('bea')!.isBlocked = true;
    assert.equal(
      await rejection(editAppointment(blocked, 'admin', edit(blocked, { recipient: { clientId: 'bea' } }), NOW)),
      'recipient_blocked',
    );
  });

  test('el turno que se edita no cuenta como otro turno activo de la persona', async () => {
    const store = withAnaAppointment();
    await editAppointment(store, 'admin', edit(store, { recipient: { clientId: 'ana' } }), NOW);
  });

  test('la admin edita un turno en curso sin moverlo', async () => {
    const during = new Date('2026-11-24T13:30:00Z');
    const store = withAnaAppointment();
    await editAppointment(
      store,
      'admin',
      edit(store, { start: new Date('2026-11-24T13:00:00Z'), item: { kind: 'service', id: 'gel' }, booked: GEL }),
      during,
    );
    assert.deepEqual(store.appointments.get('ana1')!.endTime, new Date('2026-11-24T15:00:00Z'));
  });
});

describe('los turnos existentes (RF-13, RF-15)', () => {
  test('sin cambiar lo reservado, se conserva la copia aunque la lista cambie', async () => {
    const store = withAnaAppointment();
    store.priceList = {
      ...PRICE_LIST,
      categories: [{ ...PRICE_LIST.categories[0], items: PRICE_LIST.categories[0].items.map((i) => (i.id === 'mani' ? { ...i, priceCents: 3500, durationMinutes: 90 } : i)) }],
    };
    await editAppointment(store, 'ana', edit(store), NOW);
    const saved = store.appointments.get('ana1')!;
    assert.deepEqual(saved.booked, MANI);
    assert.deepEqual(saved.endTime, new Date('2026-11-24T18:00:00Z'));
  });

  test('un servicio retirado de la lista también se conserva si no se cambia', async () => {
    const store = withAnaAppointment();
    store.priceList = { categories: [], combos: [] };
    await editAppointment(store, 'ana', edit(store), NOW);
    assert.deepEqual(store.appointments.get('ana1')!.booked, MANI);
  });

  test('cambiar lo reservado exige la lista vigente', async () => {
    const store = withAnaAppointment();
    assert.equal(
      await rejection(editAppointment(store, 'ana', edit(store, { item: { kind: 'service', id: 'gel' }, booked: { ...GEL, priceCents: 1 } }), NOW)),
      'item_changed',
    );
    assert.equal(
      await rejection(editAppointment(store, 'ana', edit(store, { addonIds: ['deco'], booked: { ...MANI, addons: [{ ...DECO, priceCents: 1 }] } }), NOW)),
      'item_changed',
    );
  });

  test('la misma hora fuera del horario nuevo → ok', async () => {
    const store = withAnaAppointment();
    store.calendar = { openingHours: { tuesday: { open: '11:00', close: '18:00' } } };
    await editAppointment(store, 'ana', edit(store, { start: new Date('2026-11-24T13:00:00Z') }), NOW);
  });

  test('la misma hora bajo un cierre nuevo → slot_taken', async () => {
    const store = withAnaAppointment();
    store.closures = [{ start: new Date('2026-11-24T12:00:00Z'), end: new Date('2026-11-24T15:00:00Z') }];
    const reason = await rejection(editAppointment(store, 'ana', edit(store, { start: new Date('2026-11-24T13:00:00Z') }), NOW));
    assert.equal(coarseVerdict(reason), 'slot_taken');
  });

  test('ampliar el fin sobre otro turno → does_not_fit', async () => {
    const store = withAnaAppointment();
    store.appointments.set('otro', existing('otro', '2026-11-24T14:00:00Z', '2026-11-24T15:00:00Z'));
    assert.equal(
      await rejection(
        editAppointment(store, 'ana', edit(store, { start: new Date('2026-11-24T13:00:00Z'), item: { kind: 'service', id: 'gel' }, booked: GEL }), NOW),
      ),
      'does_not_fit',
    );
  });

  test('otra hora ocupada → slot_taken', async () => {
    const store = withAnaAppointment();
    store.appointments.set('otro', existing('otro', '2026-11-24T17:00:00Z', '2026-11-24T18:00:00Z'));
    assert.equal(await rejection(editAppointment(store, 'ana', edit(store), NOW)), 'slot_taken');
  });
});

// Cierres ----------------------------------------------------------------

/** Martes 24/11 de 14:00 a 16:00 en el salón. */
const AFTERNOON = { start: new Date('2026-11-24T17:00:00Z'), end: new Date('2026-11-24T19:00:00Z') };

describe('la admin guarda un cierre (spec 008, RF-5)', () => {
  test('lo guarda con su inicio y su fin', async () => {
    const store = salon();
    const result = await saveClosure(store, 'admin', AFTERNOON, NOW);
    assert.equal(typeof result.id, 'string');
    assert.deepEqual(store.closures, [AFTERNOON]);
    assert.deepEqual(store.lockUpdatedAt, NOW);
  });

  test('días enteros: de las 0:00 del primero a las 0:00 del siguiente al último', async () => {
    const store = salon();
    const days = { start: new Date('2026-11-24T03:00:00Z'), end: new Date('2026-11-26T03:00:00Z') };
    await saveClosure(store, 'admin', days, NOW);
    assert.deepEqual(store.closures, [days]);
  });

  test('solo la admin', async () => {
    const error = await saveClosure(salon(), 'ana', AFTERNOON, NOW).catch((e: unknown) => e);
    assert.ok(error instanceof AgendaError);
    assert.equal(error.code, 'permission-denied');
  });

  test('fin antes del inicio, ya pasado, demasiado lejos o de varios días sin ser días enteros → invalid', async () => {
    for (const range of [
      { start: AFTERNOON.end, end: AFTERNOON.start },
      { start: AFTERNOON.start, end: AFTERNOON.start },
      { start: new Date('2026-11-23T11:00:00Z'), end: new Date('2026-11-23T13:00:00Z') },
      { start: new Date('2027-11-25T13:00:00Z'), end: new Date('2027-11-25T14:00:00Z') },
      { start: new Date('2026-11-24T17:00:00Z'), end: new Date('2026-11-25T17:00:00Z') },
    ]) {
      assert.equal(await rejection(saveClosure(salon(), 'admin', range, NOW)), 'invalid', JSON.stringify(range));
    }
  });

  test('un cierre que ya empezó vale; uno a 365 días también', async () => {
    await saveClosure(salon(), 'admin', { start: new Date('2026-11-23T12:00:00Z'), end: new Date('2026-11-23T15:00:00Z') }, NOW);
    await saveClosure(salon(), 'admin', { start: new Date('2027-11-23T13:00:00Z'), end: new Date('2027-11-23T14:00:00Z') }, NOW);
  });

  test('con turnos activos encima → conflicts con sus ids, por orden de inicio', async () => {
    const store = salon();
    store.appointments.set('tarde', existing('tarde', '2026-11-24T18:00:00Z', '2026-11-24T19:00:00Z'));
    store.appointments.set('antes', existing('antes', '2026-11-24T16:30:00Z', '2026-11-24T17:30:00Z', { status: 'waiting_confirmation' }));
    store.appointments.set('cancelado', existing('cancelado', '2026-11-24T17:00:00Z', '2026-11-24T18:00:00Z', { status: 'cancelled' }));
    store.appointments.set('borde', existing('borde', '2026-11-24T19:00:00Z', '2026-11-24T20:00:00Z'));
    const error = await saveClosure(store, 'admin', AFTERNOON, NOW).catch((e: unknown) => e);
    assert.ok(error instanceof AgendaError);
    assert.equal(error.reason, 'conflicts');
    assert.deepEqual(error.details, { ids: ['antes', 'tarde'] });
    assert.deepEqual(store.closures, []);
  });

  test('un cierre y una reserva a la vez en la misma hora: se guarda solo uno (RF-5)', async () => {
    for (let i = 0; i < 2; i++) {
      const store = salon();
      const book = bookAppointment(store, 'ana', request({ start: AFTERNOON.start }), NOW);
      const close = saveClosure(store, 'admin', AFTERNOON, NOW);
      const results = await Promise.allSettled(i === 0 ? [book, close] : [close, book]);
      assert.equal(results.filter((r) => r.status === 'fulfilled').length, 1);
      assert.equal(store.appointments.size + store.closures.length, 1);
    }
  });
});
