// Un `AgendaStore` en memoria para los tests (spec 012, plan § 3). Imita
// las transacciones de Firestore: cada una lee con su propia vista, guarda
// sus escrituras aparte y, al terminar, las aplica solo si el candado no
// cambió desde que lo leyó; si cambió, vuelve a empezar (D-3).
import type {
  AgendaStore,
  AgendaTransaction,
  AppointmentRecord,
  AppointmentUpdate,
  AppointmentWrite,
  StoredAppointment,
  UserProfile,
} from '../src/agenda_write.ts';
import type { Range } from '../src/agenda_rules.ts';
import { sameWhatsApp } from '../src/agenda_rules.ts';

/** Lo que hay guardado de un turno: lo escrito, con su id. */
export type MemoryAppointment = Omit<AppointmentWrite, 'booked'> & {
  id: string;
  booked: unknown;
};

export class MemoryAgendaStore implements AgendaStore {
  users = new Map<string, UserProfile>();
  calendar: Record<string, unknown> | null = null;
  priceList: unknown = null;
  appointments = new Map<string, MemoryAppointment>();
  busySlots = new Map<string, Range>();
  closures: Range[] = [];
  lockVersion = 0;
  lockUpdatedAt: Date | null = null;
  /** Cuántas veces se volvió a empezar una transacción. */
  retries = 0;

  async runTransaction<T>(fn: (tx: AgendaTransaction) => Promise<T>): Promise<T> {
    for (;;) {
      const tx = new MemoryTransaction(this);
      const result = await fn(tx);
      // Deja que las otras transacciones lean antes de aplicar esta.
      await new Promise((resolve) => setImmediate(resolve));
      if (tx.lockRead !== this.lockVersion) {
        this.retries++;
        continue;
      }
      tx.apply();
      return result;
    }
  }
}

class MemoryTransaction implements AgendaTransaction {
  lockRead: number | null = null;
  private readonly writes: (() => void)[] = [];
  private readonly store: MemoryAgendaStore;

  constructor(store: MemoryAgendaStore) {
    this.store = store;
  }

  private async tick() {
    await new Promise((resolve) => setImmediate(resolve));
  }

  async readLock() {
    await this.tick();
    this.lockRead = this.store.lockVersion;
  }

  async user(uid: string) {
    await this.tick();
    return this.store.users.get(uid) ?? null;
  }

  async clientsWithPhone(phone: string) {
    await this.tick();
    return [...this.store.users.values()].filter(
      (u) => u.role === 'cliente' && sameWhatsApp(u.phoneNumber ?? '', phone),
    );
  }

  async calendar() {
    await this.tick();
    return this.store.calendar;
  }

  async priceList() {
    await this.tick();
    return this.store.priceList;
  }

  async appointmentsEndingFrom(now: Date): Promise<StoredAppointment[]> {
    await this.tick();
    return [...this.store.appointments.values()]
      .filter((a) => a.endTime >= now)
      .map((a) => ({
        id: a.id,
        clientId: a.clientId,
        clientPhone: a.clientPhone,
        start: a.startTime,
        end: a.endTime,
        status: a.status,
      }));
  }

  async closuresEndingFrom(now: Date) {
    await this.tick();
    return this.store.closures.filter((c) => c.end >= now);
  }

  async appointment(id: string): Promise<AppointmentRecord | null> {
    await this.tick();
    const found = this.store.appointments.get(id);
    return found === undefined ? null : { ...found };
  }

  async appointmentExists(id: string) {
    await this.tick();
    return this.store.appointments.has(id);
  }

  createAppointment(id: string, data: AppointmentWrite) {
    this.writes.push(() => {
      this.store.appointments.set(id, { id, ...data });
      this.store.busySlots.set(id, { start: data.startTime, end: data.endTime });
    });
  }

  updateAppointment(id: string, fields: AppointmentUpdate) {
    this.writes.push(() => {
      const current = this.store.appointments.get(id)!;
      const updated = { ...current, ...fields };
      this.store.appointments.set(id, updated);
      this.store.busySlots.set(id, { start: updated.startTime, end: updated.endTime });
    });
  }

  createClosure(range: Range): string {
    const id = `cierre-${this.store.closures.length + 1}`;
    this.writes.push(() => {
      this.store.closures.push({ start: range.start, end: range.end });
    });
    return id;
  }

  touchLock(now: Date) {
    this.writes.push(() => {
      this.store.lockVersion++;
      this.store.lockUpdatedAt = now;
    });
  }

  apply() {
    if (this.lockRead === null) throw new Error('La transacción no leyó el candado');
    for (const write of this.writes) write();
  }
}
