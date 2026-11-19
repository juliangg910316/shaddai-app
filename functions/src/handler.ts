// El adaptador entre la llamada y la lógica del borrado (spec 009, RF-37,
// RF-42; plan D-8).
import { HttpsError } from 'firebase-functions/v2/https';
import { logger } from 'firebase-functions';

import { AccountDeletionError, deleteAccount } from './delete_account.ts';
import type { AccountStore } from './delete_account.ts';

/** Lo que importa de una llamada: la sesión. Los datos se ignoran. */
export interface DeleteAccountRequest {
  auth?: { uid: string };
  data?: unknown;
}

/**
 * Borra la cuenta del uid de la sesión, nunca de uno que venga en los datos
 * (RF-42), y traduce los errores de la lógica a `HttpsError`: la app recibe
 * el código y, si está bloqueada, el motivo `blocked` en `details` (RF-40).
 * Cualquier otro fallo llega como `internal`, sin detalles técnicos.
 */
export async function handleDeleteAccount(
  request: DeleteAccountRequest,
  store: AccountStore,
  now: Date,
): Promise<{ ok: true }> {
  try {
    return await deleteAccount(store, request.auth?.uid, now);
  } catch (error) {
    if (error instanceof AccountDeletionError) {
      throw new HttpsError(
        error.code,
        error.reason ?? error.code,
        error.reason === undefined ? undefined : { reason: error.reason },
      );
    }
    logger.error('No se pudo borrar la cuenta', {
      uid: request.auth?.uid,
      error: String(error),
    });
    throw new HttpsError('internal', 'internal');
  }
}
