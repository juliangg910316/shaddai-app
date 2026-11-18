// Cloud Functions de Studio Shaddai.
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { onCall } from 'firebase-functions/v2/https';

import { adminStore } from './admin_store.ts';
import { handleDeleteAccount } from './handler.ts';

initializeApp();

/**
 * Borra la cuenta de la clienta con la sesión iniciada (spec 009, RF-34 a
 * RF-42; plan D-8). En São Paulo, cerca del salón. Usa el SDK de
 * administración, así que no pide una sesión reciente (RF-37).
 */
export const deleteAccount = onCall({ region: 'southamerica-east1' }, (request) =>
  handleDeleteAccount(
    request,
    adminStore(getFirestore(), getAuth()),
    new Date(),
  ),
);
