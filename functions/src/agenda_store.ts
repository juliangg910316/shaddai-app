// El almacén de la agenda sobre firebase-admin (spec 012, plan § 3, D-3).
//
// Cada caso de uso corre en una transacción del servidor que lee primero el
// candado `locks/agenda` y lo escribe al final: dos escrituras a la vez
// chocan en él, y Firestore repite la segunda, que entonces lee lo que
// guardó la primera (RF-3, RF-5, RF-8). Las consultas filtran un solo
// campo (`endTime >= now`, `end >= now`): no hacen falta índices nuevos.
import { Timestamp } from 'firebase-admin/firestore';
import type { DocumentData, Firestore, Transaction } from 'firebase-admin/firestore';

import { sameWhatsApp } from './agenda_rules.ts';
import type { Range } from './agenda_rules.ts';
import type {
  AgendaStore,
  AgendaTransaction,
  AppointmentRecord,
  AppointmentUpdate,
  AppointmentWrite,
  StoredAppointment,
  UserProfile,
} from './agenda_write.ts';

const textOr = (value: unknown, fallback: string) =>
  typeof value === 'string' ? value : fallback;

const textOrNull = (value: unknown) => (typeof value === 'string' ? value : null);

/** Un Timestamp como Date; sin fecha válida, el 1/1/1970 (cuenta como pasado). */
const dateOf = (value: unknown) =>
  value instanceof Timestamp ? value.toDate() : new Date(0);

/** Una ficha como la lee la app (`UserModel.fromMap`). */
function profileOf(uid: string, data: DocumentData): UserProfile {
  return {
    uid,
    displayName: textOr(data.displayName, ''),
    phoneNumber: textOrNull(data.phoneNumber),
    photoUrl: textOrNull(data.photoUrl),
    role: textOr(data.role, 'cliente'),
    isBlocked: data.isBlocked === true,
  };
}

/** Un turno como lo lee la app (`AppointmentModel.fromMap`). */
function recordOf(id: string, data: DocumentData): AppointmentRecord {
  return {
    id,
    clientId: textOrNull(data.clientId),
    clientName: textOr(data.clientName, ''),
    clientPhone: textOr(data.clientPhone, ''),
    clientPhotoUrl: textOrNull(data.clientPhotoUrl),
    startTime: dateOf(data.startTime),
    endTime: dateOf(data.endTime),
    status: textOr(data.status, ''),
    createdByAdmin: data.createdByAdmin === true,
    booked: data.booked,
  };
}

class FirestoreAgendaTransaction implements AgendaTransaction {
  private readonly db: Firestore;
  private readonly tx: Transaction;

  constructor(db: Firestore, tx: Transaction) {
    this.db = db;
    this.tx = tx;
  }

  private get lock() {
    return this.db.collection('locks').doc('agenda');
  }

  async readLock() {
    await this.tx.get(this.lock);
  }

  async user(uid: string) {
    const doc = await this.tx.get(this.db.collection('users').doc(uid));
    const data = doc.data();
    return data === undefined ? null : profileOf(uid, data);
  }

  async clientsWithPhone(phone: string) {
    // El WhatsApp se guarda como lo escribió cada una: se compara
    // normalizado. Fuera de la transacción, para no bloquear las fichas.
    const query = await this.db.collection('users').where('role', '==', 'cliente').get();
    return query.docs
      .map((doc) => profileOf(doc.id, doc.data()))
      .filter((user) => sameWhatsApp(user.phoneNumber ?? '', phone));
  }

  async calendar() {
    const doc = await this.tx.get(this.db.collection('settings').doc('calendar'));
    return doc.data() ?? null;
  }

  async priceList() {
    const doc = await this.tx.get(this.db.collection('settings').doc('priceList'));
    return doc.data() ?? null;
  }

  async appointmentsEndingFrom(now: Date): Promise<StoredAppointment[]> {
    const query = await this.tx.get(
      this.db.collection('appointments').where('endTime', '>=', Timestamp.fromDate(now)),
    );
    return query.docs.map((doc) => {
      const a = recordOf(doc.id, doc.data());
      return {
        id: a.id,
        clientId: a.clientId,
        clientPhone: a.clientPhone,
        start: a.startTime,
        end: a.endTime,
        status: a.status,
      };
    });
  }

  async closuresEndingFrom(now: Date): Promise<Range[]> {
    const query = await this.tx.get(
      this.db.collection('closures').where('end', '>=', Timestamp.fromDate(now)),
    );
    return query.docs.map((doc) => ({
      start: dateOf(doc.get('start')),
      end: dateOf(doc.get('end')),
    }));
  }

  async appointment(id: string) {
    const doc = await this.tx.get(this.db.collection('appointments').doc(id));
    const data = doc.data();
    return data === undefined ? null : recordOf(id, data);
  }

  async appointmentExists(id: string) {
    return (await this.tx.get(this.db.collection('appointments').doc(id))).exists;
  }

  createAppointment(id: string, data: AppointmentWrite) {
    this.tx.create(this.db.collection('appointments').doc(id), { ...data });
    this.tx.set(this.db.collection('busySlots').doc(id), {
      start: data.startTime,
      end: data.endTime,
    });
  }

  updateAppointment(id: string, fields: AppointmentUpdate) {
    this.tx.update(this.db.collection('appointments').doc(id), { ...fields });
    this.tx.set(this.db.collection('busySlots').doc(id), {
      start: fields.startTime,
      end: fields.endTime,
    });
  }

  createClosure(range: Range) {
    const ref = this.db.collection('closures').doc();
    this.tx.set(ref, { start: range.start, end: range.end });
    return ref.id;
  }

  touchLock(now: Date) {
    this.tx.set(this.lock, { updatedAt: now });
  }
}

export function agendaStore(db: Firestore): AgendaStore {
  return {
    runTransaction: (fn) =>
      db.runTransaction((tx) => fn(new FirestoreAgendaTransaction(db, tx))),
  };
}
