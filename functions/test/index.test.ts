// El adaptador de la función invocable (spec 009, RF-37, RF-42; plan D-8):
// usa el uid de la sesión, nunca el de los datos, y traduce los errores de
// la lógica a HttpsError. Sin Firebase: el almacén es un doble.
import assert from 'node:assert/strict';
import { test } from 'node:test';

import { HttpsError } from 'firebase-functions/v2/https';

import { handleDeleteAccount } from '../src/handler.ts';
import type { AccountStore, StoredUser, Write } from '../src/delete_account.ts';

const now = new Date('2026-11-18T12:00:00Z');

/** Un almacén que registra a quién se borra. */
function recordingStore(user: StoredUser | null = {
  role: 'cliente',
  isBlocked: false,
}) {
  const deleted: string[] = [];
  const store: AccountStore = {
    getUser: async () => user,
    appointmentsOf: async () => [],
    commit: async (_: Write[]) => {},
    deleteUser: async (uid) => {
      deleted.push(`ficha:${uid}`);
    },
    deleteAuthUser: async (uid) => {
      deleted.push(`auth:${uid}`);
    },
  };
  return { store, deleted };
}

test('borra la cuenta de la sesión, no la que venga en los datos (RF-42)', async () => {
  const { store, deleted } = recordingStore();
  const result = await handleDeleteAccount(
    { auth: { uid: 'ana' }, data: { uid: 'bea' } },
    store,
    now,
  );
  assert.deepEqual(result, { ok: true });
  assert.deepEqual(deleted, ['ficha:ana', 'auth:ana']);
});

const rejectsWith =
  (code: string, reason?: string) => (error: unknown) =>
    error instanceof HttpsError &&
    error.code === code &&
    (reason === undefined ||
      (error.details as { reason?: string } | undefined)?.reason === reason);

test('sin sesión: unauthenticated, aunque los datos traigan un uid', async () => {
  const { store, deleted } = recordingStore();
  await assert.rejects(
    handleDeleteAccount({ data: { uid: 'ana' } }, store, now),
    rejectsWith('unauthenticated'),
  );
  assert.deepEqual(deleted, []);
});

test('la admin: permission-denied', async () => {
  const { store } = recordingStore({ role: 'admin', isBlocked: false });
  await assert.rejects(
    handleDeleteAccount({ auth: { uid: 'admin' } }, store, now),
    rejectsWith('permission-denied'),
  );
});

test('bloqueada: failed-precondition con el motivo blocked en los detalles (RF-40)', async () => {
  const { store } = recordingStore({ role: 'cliente', isBlocked: true });
  await assert.rejects(
    handleDeleteAccount({ auth: { uid: 'ana' } }, store, now),
    rejectsWith('failed-precondition', 'blocked'),
  );
});

test('cualquier otro fallo: internal, sin detalles técnicos', async () => {
  const { store } = recordingStore();
  store.deleteUser = async () => {
    throw new Error('DEADLINE_EXCEEDED: secreto interno');
  };
  await assert.rejects(
    handleDeleteAccount({ auth: { uid: 'ana' } }, store, now),
    (error: unknown) =>
      error instanceof HttpsError &&
      error.code === 'internal' &&
      !error.message.includes('secreto'),
  );
});
