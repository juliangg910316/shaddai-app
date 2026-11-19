// Borrar la cuenta (spec 009, RF-34, RF-35, RF-39, RF-40, RF-42; plan D-8,
// D-10). La lógica se prueba con un almacén en memoria: ningún test toca
// Firebase.
import assert from 'node:assert/strict';
import { beforeEach, describe, test } from 'node:test';

import {
  AccountDeletionError,
  BATCH_LIMIT,
  deleteAccount,
} from '../src/delete_account.ts';
import type {
  AccountStore,
  StoredAppointment,
  StoredUser,
  Write,
} from '../src/delete_account.ts';

const now = new Date('2026-11-18T12:00:00Z');
const hours = (h: number) => new Date(now.getTime() + h * 3_600_000);

interface Appointment extends StoredAppointment {
  clientName: string;
  clientPhone: string;
  clientPhotoUrl: string | null;
  cancelledBy?: string;
  accountDeleted?: boolean;
}

/** Un almacén en memoria que aplica los lotes como Firestore. */
class MemoryStore implements AccountStore {
  users = new Map<string, StoredUser>();
  appointments = new Map<string, Appointment & { clientId: string }>();
  busySlots = new Set<string>();
  authUsers = new Set<string>();
  commits: Write[][] = [];
  /** Si está, el commit número [failOnCommit] (desde 0) falla sin escribir. */
  failOnCommit?: number;

  async getUser(uid: string) {
    return this.users.get(uid) ?? null;
  }

  async appointmentsOf(uid: string) {
    return [...this.appointments.values()]
      .filter((a) => a.clientId === uid)
      .map(({ id, status, endTime }) => ({ id, status, endTime }));
  }

  async commit(writes: Write[]) {
    if (this.failOnCommit === this.commits.length) {
      this.failOnCommit = undefined;
      throw new Error('unavailable');
    }
    this.commits.push(writes);
    for (const write of writes) {
      if (write.kind === 'deleteBusySlot') {
        this.busySlots.delete(write.id);
      } else {
        const current = this.appointments.get(write.id)!;
        this.appointments.set(write.id, { ...current, ...write.data });
      }
    }
  }

  async deleteUser(uid: string) {
    this.users.delete(uid);
  }

  async deleteAuthUser(uid: string) {
    this.authUsers.delete(uid);
  }
}

let store: MemoryStore;

function add(
  id: string,
  status: string,
  endTime: Date,
  clientId = 'ana',
): void {
  store.appointments.set(id, {
    id,
    clientId,
    status,
    endTime,
    clientName: 'Ana Herrera',
    clientPhone: '+55 41 99999-0000',
    clientPhotoUrl: 'https://foto/ana.png',
  });
  if (status !== 'cancelled') store.busySlots.add(id);
}

beforeEach(() => {
  store = new MemoryStore();
  store.users.set('ana', { role: 'cliente', isBlocked: false });
  store.authUsers.add('ana');
  store.users.set('bea', { role: 'cliente', isBlocked: false });
  store.authUsers.add('bea');
});

/** Lo que el almacén tiene ahora, para comparar dos ejecuciones. */
const snapshot = () => ({
  users: [...store.users.keys()].sort(),
  auth: [...store.authUsers].sort(),
  busy: [...store.busySlots].sort(),
  appointments: [...store.appointments.values()].sort((a, b) =>
    a.id.localeCompare(b.id),
  ),
});

describe('quién puede borrar (RF-40, RF-42)', () => {
  test('sin sesión: unauthenticated, sin tocar nada', async () => {
    add('t1', 'confirmed', hours(5));
    const before = snapshot();
    await assert.rejects(
      deleteAccount(store, undefined, now),
      (e: unknown) =>
        e instanceof AccountDeletionError && e.code === 'unauthenticated',
    );
    assert.deepEqual(snapshot(), before);
  });

  test('la admin: permission-denied, sin tocar nada', async () => {
    store.users.set('ana', { role: 'admin', isBlocked: false });
    add('t1', 'confirmed', hours(5));
    const before = snapshot();
    await assert.rejects(
      deleteAccount(store, 'ana', now),
      (e: unknown) =>
        e instanceof AccountDeletionError && e.code === 'permission-denied',
    );
    assert.deepEqual(snapshot(), before);
  });

  test('bloqueada: failed-precondition con motivo blocked, sin tocar nada', async () => {
    store.users.set('ana', { role: 'cliente', isBlocked: true });
    add('t1', 'confirmed', hours(5));
    const before = snapshot();
    await assert.rejects(
      deleteAccount(store, 'ana', now),
      (e: unknown) =>
        e instanceof AccountDeletionError &&
        e.code === 'failed-precondition' &&
        e.reason === 'blocked',
    );
    assert.deepEqual(snapshot(), before);
  });
});

describe('los turnos (RF-34, RF-35)', () => {
  test('cancela solo el activo, por la clienta, y borra su turno ocupado; '
    + 'también si empieza enseguida (sin margen)', async () => {
    add('activo', 'waiting_confirmation', hours(0.5));
    add('pasado', 'confirmed', hours(-24));
    add('cancelado', 'cancelled', hours(48));
    add('de-bea', 'confirmed', hours(10), 'bea');

    assert.deepEqual(await deleteAccount(store, 'ana', now), { ok: true });

    const active = store.appointments.get('activo')!;
    assert.equal(active.status, 'cancelled');
    assert.equal(active.cancelledBy, 'client');
    assert.equal(store.appointments.get('pasado')!.status, 'confirmed');
    assert.equal(store.appointments.get('pasado')!.cancelledBy, undefined);
    assert.equal(store.appointments.get('cancelado')!.cancelledBy, undefined);
    assert.deepEqual([...store.busySlots].sort(), ['de-bea', 'pasado']);
    // Lo de otra clienta, intacto.
    const bea = store.appointments.get('de-bea')!;
    assert.equal(bea.status, 'confirmed');
    assert.equal(bea.accountDeleted, undefined);
    assert.equal(bea.clientPhotoUrl, 'https://foto/ana.png');
  });

  test('un turno confirmado que ya terminó no se cancela', async () => {
    add('terminado', 'confirmed', now);
    await deleteAccount(store, 'ana', now);
    assert.equal(store.appointments.get('terminado')!.status, 'confirmed');
  });

  test('todos sus turnos quedan marcados y sin foto, con nombre y WhatsApp '
    + 'intactos', async () => {
    add('activo', 'confirmed', hours(3));
    add('pasado', 'confirmed', hours(-24));
    add('cancelado', 'cancelled', hours(-48));

    await deleteAccount(store, 'ana', now);

    for (const id of ['activo', 'pasado', 'cancelado']) {
      const a = store.appointments.get(id)!;
      assert.equal(a.accountDeleted, true, id);
      assert.equal(a.clientPhotoUrl, null, id);
      assert.equal(a.clientName, 'Ana Herrera', id);
      assert.equal(a.clientPhone, '+55 41 99999-0000', id);
      assert.equal(a.clientId, 'ana', id);
    }
  });
});

describe('la cuenta (RF-36)', () => {
  test('borra su ficha y su cuenta de Auth, y no las de otras', async () => {
    await deleteAccount(store, 'ana', now);
    assert.deepEqual([...store.users.keys()], ['bea']);
    assert.deepEqual([...store.authUsers], ['bea']);
  });

  test('sin turnos, también', async () => {
    assert.deepEqual(await deleteAccount(store, 'ana', now), { ok: true });
    assert.equal(store.users.has('ana'), false);
    assert.deepEqual(store.commits, []);
  });

  test('borra la ficha después de los turnos y Auth al final', async () => {
    add('activo', 'confirmed', hours(3));
    const order: string[] = [];
    const commit = store.commit.bind(store);
    store.commit = async (w) => {
      order.push('commit');
      await commit(w);
    };
    const deleteUser = store.deleteUser.bind(store);
    store.deleteUser = async (uid) => {
      order.push('ficha');
      await deleteUser(uid);
    };
    const deleteAuthUser = store.deleteAuthUser.bind(store);
    store.deleteAuthUser = async (uid) => {
      order.push('auth');
      await deleteAuthUser(uid);
    };
    await deleteAccount(store, 'ana', now);
    assert.deepEqual(order, ['commit', 'ficha', 'auth']);
  });
});

describe('repetirlo deja el mismo resultado (RF-39)', () => {
  test('un fallo a mitad y el reintento', async () => {
    for (let i = 0; i < BATCH_LIMIT; i++) {
      add(`p${String(i).padStart(4, '0')}`, 'confirmed', hours(-24 - i));
    }
    add('activo', 'confirmed', hours(3));

    // Ejecución sin fallos, como referencia.
    const reference = new MemoryStore();
    const base = store;
    store = reference;
    store.users = new Map(base.users);
    store.authUsers = new Set(base.authUsers);
    store.appointments = new Map(base.appointments);
    store.busySlots = new Set(base.busySlots);
    await deleteAccount(store, 'ana', now);
    const expected = snapshot();

    store = base;
    store.failOnCommit = 1;
    await assert.rejects(deleteAccount(store, 'ana', now));
    // El primer lote se escribió; la ficha sigue ahí para reintentar.
    assert.equal(store.users.has('ana'), true);

    await deleteAccount(store, 'ana', now);
    assert.deepEqual(snapshot(), expected);
  });

  test('si la ficha ya no existe (un intento anterior llegó más lejos), '
    + 'sigue y termina', async () => {
    add('pasado', 'confirmed', hours(-24));
    store.users.delete('ana');
    assert.deepEqual(await deleteAccount(store, 'ana', now), { ok: true });
    assert.equal(store.appointments.get('pasado')!.accountDeleted, true);
    assert.equal(store.authUsers.has('ana'), false);
  });

  test('si ya no queda nada, termina igual', async () => {
    await deleteAccount(store, 'ana', now);
    assert.deepEqual(await deleteAccount(store, 'ana', now), { ok: true });
  });
});

test('más de 400 turnos: varios lotes de 400 escrituras como mucho, con el '
  + 'turno activo y su turno ocupado en el mismo lote', async () => {
  for (let i = 0; i < 899; i++) {
    add(`p${String(i).padStart(4, '0')}`, 'confirmed', hours(-24 - i));
  }
  add('zz-activo', 'confirmed', hours(3));

  await deleteAccount(store, 'ana', now);

  assert.equal(BATCH_LIMIT, 400);
  assert.equal(store.commits.length, 3);
  for (const batch of store.commits) {
    assert.ok(batch.length <= BATCH_LIMIT, `${batch.length}`);
  }
  assert.equal(
    store.commits.reduce((n, b) => n + b.length, 0),
    899 + 2,
  );
  const withActive = store.commits.find((b) =>
    b.some((w) => w.id === 'zz-activo'),
  )!;
  assert.equal(withActive.filter((w) => w.id === 'zz-activo').length, 2);
  assert.equal(
    [...store.appointments.values()].every((a) => a.accountDeleted),
    true,
  );
});
