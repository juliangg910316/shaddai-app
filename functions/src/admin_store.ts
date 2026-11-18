// El almacén del borrado sobre firebase-admin (spec 009, plan D-10).
import type { Auth } from 'firebase-admin/auth';
import { Timestamp } from 'firebase-admin/firestore';
import type { Firestore } from 'firebase-admin/firestore';

import type { AccountStore, StoredAppointment } from './delete_account.ts';

export function adminStore(db: Firestore, auth: Auth): AccountStore {
  return {
    async getUser(uid) {
      const data = (await db.collection('users').doc(uid).get()).data();
      if (data === undefined) return null;
      return {
        role: typeof data.role === 'string' ? data.role : 'cliente',
        isBlocked: data.isBlocked === true,
      };
    },

    async appointmentsOf(uid) {
      const query = await db
        .collection('appointments')
        .where('clientId', '==', uid)
        .get();
      return query.docs.map((doc): StoredAppointment => {
        const data = doc.data();
        const end = data.endTime;
        return {
          id: doc.id,
          status: typeof data.status === 'string' ? data.status : '',
          // Sin hora de fin válida, cuenta como pasado: no se cancela.
          endTime: end instanceof Timestamp ? end.toDate() : new Date(0),
        };
      });
    },

    async commit(writes) {
      const batch = db.batch();
      for (const write of writes) {
        if (write.kind === 'deleteBusySlot') {
          batch.delete(db.collection('busySlots').doc(write.id));
        } else {
          batch.update(
            db.collection('appointments').doc(write.id),
            { ...write.data },
          );
        }
      }
      await batch.commit();
    },

    async deleteUser(uid) {
      await db.collection('users').doc(uid).delete();
    },

    async deleteAuthUser(uid) {
      try {
        await auth.deleteUser(uid);
      } catch (error) {
        // Si ya no existe (un intento anterior llegó hasta aquí), no es error.
        if ((error as { code?: string }).code === 'auth/user-not-found') return;
        throw error;
      }
    },
  };
}
