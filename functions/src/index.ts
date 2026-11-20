// Cloud Functions de Studio Shaddai.
import { initializeApp } from 'firebase-admin/app';
import { getAuth } from 'firebase-admin/auth';
import { getFirestore } from 'firebase-admin/firestore';
import { getMessaging } from 'firebase-admin/messaging';
import { logger } from 'firebase-functions';
import { onDocumentWritten } from 'firebase-functions/v2/firestore';
import { onCall } from 'firebase-functions/v2/https';

import { adminStore } from './admin_store.ts';
import { handleDeleteAccount } from './handler.ts';
import { noticeStore } from './notice_store.ts';
import {
  notifyAdminsSafely,
  readNoticeAppointment,
} from './notify_admins.ts';

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

/**
 * La región de la base de datos de Firestore: el disparador tiene que estar
 * en ella (spec 011, plan D-3). Comprobar en la consola antes de desplegar
 * (Firestore → Base de datos → ubicación); si es la multirregión `nam5`,
 * cambiar a `us-central1`.
 */
const FIRESTORE_REGION = 'southamerica-east1';

/**
 * Avisa a la admin cuando una clienta reserva, edita o cancela un turno
 * (spec 011, RF-1 a RF-6, RF-24). Sin reintentos, para no duplicar avisos:
 * si falla, queda en el registro y el turno sigue guardado.
 */
export const notifyAdminsOnAppointmentWrite = onDocumentWritten(
  { document: 'appointments/{id}', region: FIRESTORE_REGION, retry: false },
  async (event) => {
    await notifyAdminsSafely(
      noticeStore(getFirestore(), getMessaging()),
      {
        eventId: event.id,
        appointmentId: event.params.id,
        before: readNoticeAppointment(event.data?.before.data()),
        after: readNoticeAppointment(event.data?.after.data()),
      },
      (message, details) => logger.error(message, details),
    );
  },
);
