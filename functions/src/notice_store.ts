// El almacén de los avisos sobre firebase-admin (spec 011, RF-6, RF-19,
// RF-21, RF-22; plan D-1, D-4, D-5).
import type { Firestore } from 'firebase-admin/firestore';
import type { Message, Messaging } from 'firebase-admin/messaging';

import type { NoticeDevice, NoticeStore } from './notify_admins.ts';

export function noticeStore(db: Firestore, messaging: Messaging): NoticeStore {
  return {
    // Solo las fichas que hoy son admin: una exadmin deja de recibir avisos
    // aunque le queden dispositivos (RF-22).
    async adminDevices() {
      const admins = await db
        .collection('users')
        .where('role', '==', 'admin')
        .get();
      const devices: NoticeDevice[] = [];
      for (const admin of admins.docs) {
        const own = await admin.ref.collection('pushDevices').get();
        for (const device of own.docs) {
          const token = device.data().token;
          devices.push({
            uid: admin.id,
            token: typeof token === 'string' && token !== '' ? token : device.id,
          });
        }
      }
      return devices;
    },

    async send(tokens, message) {
      const messages: Message[] = tokens.map((token) => ({
        token,
        notification: { title: message.title, body: message.body },
        data: { ...message.data },
        // Que llegue enseguida aunque el teléfono esté en reposo (RF-6), y
        // que un evento repetido sustituya al anterior (plan D-4).
        android: { priority: 'high', notification: { tag: message.tag } },
        apns: {
          headers: { 'apns-collapse-id': message.tag },
          payload: { aps: { sound: 'default' } },
        },
      }));
      const response = await messaging.sendEach(messages);
      return response.responses.map((result) =>
        result.success
          ? { ok: true as const }
          : { ok: false as const, code: result.error?.code ?? 'unknown' },
      );
    },

    async removeDevice(uid, token) {
      await db
        .collection('users')
        .doc(uid)
        .collection('pushDevices')
        .doc(token)
        .delete();
    },
  };
}
