// Las reglas de horas de la agenda en el servidor (spec 012, RF-1, RF-2,
// RF-4, RF-9, RF-10, RF-15; plan § 4, D-4).
//
// Es la traducción directa de las funciones puras de la app:
// `salon_time.dart`, `weekday_key.dart`, `booking_window.dart`,
// `free_slots.dart`, `booking_rules.dart` (`checkSlot`), `booking_edit.dart`
// (`isEditDaySelectable`, `editFreeSlots`) y `closures.dart`. Los casos de
// `test/fixtures/agenda_rules_cases.json` los pasan las dos: si una cambia,
// la otra tiene que cambiar igual (RNF-2).
//
// Sin Firebase. "Ahora" llega siempre como parámetro.
//
// Una "hora de pared" es un `Date` cuyos campos UTC son la hora de Curitiba,
// como en la app. Los instantes (lo que se guarda) se convierten con
// [toSalon] y [fromSalon].

/** Diferencia de Curitiba con UTC: −3 h, sin horario de verano. */
const SALON_OFFSET_MS = -3 * 3_600_000;

/** Paso de la rejilla de horas, en minutos (`slotStepMinutes`). */
export const SLOT_STEP_MINUTES = 30;

/** Días de la ventana de reserva de la clienta (`bookingWindowDays`). */
export const BOOKING_WINDOW_DAYS = 60;

/** Días de la ventana de la admin (`adminBookingWindowDays`). */
export const ADMIN_BOOKING_WINDOW_DAYS = 365;

/** Estados de un turno que ocupa su hora (`activeStatuses`). */
export const ACTIVE_STATUSES: ReadonlySet<string> = new Set([
  'waiting_confirmation',
  'confirmed',
]);

const MINUTE_MS = 60_000;

/** De [start] hasta antes de [end]. */
export interface Range {
  start: Date;
  end: Date;
}

/** Lo que importa de un turno para las horas: instantes y estado. */
export interface AgendaAppointment {
  id: string;
  start: Date;
  end: Date;
  status: string;
}

export interface DaySchedule {
  open: string;
  close: string;
  isClosed: boolean;
}

/** Lo que las reglas leen de `settings/calendar`. */
export interface CalendarSettings {
  /** Por día de la semana en inglés (`monday`…). Un día que falta, cerrado. */
  openingHours: Record<string, DaySchedule>;
  /** Fechas bloqueadas, `YYYY-MM-DD` (las antiguas, spec 008). */
  blockedDates: string[];
}

/**
 * El motivo por el que una hora no vale, o `ok`. La app solo distingue
 * `slot_taken` y `does_not_fit` ([coarseVerdict]); el resto es para el
 * registro y los tests del servidor.
 */
export type SlotReason =
  | 'ok'
  | 'slot_taken'
  | 'does_not_fit'
  | 'closed'
  | 'outside_hours'
  | 'outside_window'
  | 'past';

// Hora del salón ----------------------------------------------------------

/** La hora de pared del salón en [instant]. */
export const toSalon = (instant: Date): Date =>
  new Date(instant.getTime() + SALON_OFFSET_MS);

/** El instante de la hora de pared [wall]. */
export const fromSalon = (wall: Date): Date =>
  new Date(wall.getTime() - SALON_OFFSET_MS);

/** El día de la hora de pared [wall], a las 0:00. */
export const salonDay = (wall: Date): Date =>
  new Date(Date.UTC(wall.getUTCFullYear(), wall.getUTCMonth(), wall.getUTCDate()));

const addDays = (day: Date, days: number): Date =>
  new Date(Date.UTC(day.getUTCFullYear(), day.getUTCMonth(), day.getUTCDate() + days));

const addMinutes = (time: Date, minutes: number): Date =>
  new Date(time.getTime() + minutes * MINUTE_MS);

const minutesBetween = (from: Date, to: Date): number =>
  Math.floor((to.getTime() - from.getTime()) / MINUTE_MS);

const pad = (n: number, width = 2) => String(n).padStart(width, '0');

/** La clave de [day] en `blockedDates`: `YYYY-MM-DD` (`blockedDateKey`). */
export const dayKey = (day: Date): string =>
  `${pad(day.getUTCFullYear(), 4)}-${pad(day.getUTCMonth() + 1)}-${pad(day.getUTCDate())}`;

const WEEKDAY_KEYS = [
  'sunday',
  'monday',
  'tuesday',
  'wednesday',
  'thursday',
  'friday',
  'saturday',
];

/** El día de la semana en inglés, la clave de `openingHours`. */
export const weekdayKey = (day: Date): string => WEEKDAY_KEYS[day.getUTCDay()];

// Calendario --------------------------------------------------------------

const DEFAULT_DAY: DaySchedule = { open: '09:00', close: '18:00', isClosed: false };

/** El horario por defecto (`CalendarSettingsModel.defaultSettings`). */
function defaultOpeningHours(): Record<string, DaySchedule> {
  const hours: Record<string, DaySchedule> = {};
  for (const key of WEEKDAY_KEYS) hours[key] = { ...DEFAULT_DAY };
  hours.sunday = { ...DEFAULT_DAY, isClosed: true };
  return hours;
}

const isRecord = (value: unknown): value is Record<string, unknown> =>
  typeof value === 'object' && value !== null && !Array.isArray(value);

/**
 * `settings/calendar` como lo lee la app (`CalendarSettingsModel.fromMap`):
 * sin `openingHours` (falta, vacío o no es un mapa), el horario por defecto;
 * un campo que falta en un día, su valor por defecto.
 */
export function readCalendarSettings(data: Record<string, unknown>): CalendarSettings {
  const raw = data.openingHours;
  let openingHours: Record<string, DaySchedule>;
  if (isRecord(raw) && Object.keys(raw).length > 0) {
    openingHours = {};
    for (const [key, value] of Object.entries(raw)) {
      const day = isRecord(value) ? value : {};
      openingHours[key] = {
        open: typeof day.open === 'string' ? day.open : DEFAULT_DAY.open,
        close: typeof day.close === 'string' ? day.close : DEFAULT_DAY.close,
        isClosed: typeof day.isClosed === 'boolean' ? day.isClosed : false,
      };
    }
  } else {
    openingHours = defaultOpeningHours();
  }
  const blocked = Array.isArray(data.blockedDates) ? data.blockedDates : [];
  return { openingHours, blockedDates: blocked.map((d) => String(d)) };
}

/** Minutos desde las 0:00 de una hora `HH:mm`, o `null` si no vale. */
function minutesOf(time: string): number | null {
  const match = /^(\d{1,2}):(\d{2})$/.exec(time.trim());
  if (match === null) return null;
  const hours = Number(match[1]);
  const minutes = Number(match[2]);
  if (hours > 23 || minutes > 59) return null;
  return hours * 60 + minutes;
}

/** Apertura y cierre de [day], o `null` si ese día no abre (`openingOf`). */
export function openingOf(
  day: Date,
  settings: CalendarSettings,
): { open: Date; close: Date } | null {
  const schedule = settings.openingHours[weekdayKey(day)];
  if (schedule === undefined || schedule.isClosed) return null;
  const open = minutesOf(schedule.open);
  const close = minutesOf(schedule.close);
  if (open === null || close === null || close <= open) return null;
  const d = salonDay(day);
  return { open: addMinutes(d, open), close: addMinutes(d, close) };
}

/** Las horas de inicio de [day], cada 30 min; `null` si no abre (`dayGrid`). */
export function dayGrid(day: Date, settings: CalendarSettings): Date[] | null {
  const opening = openingOf(day, settings);
  if (opening === null) return null;
  const grid: Date[] = [];
  for (
    let time = opening.open;
    time < opening.close;
    time = addMinutes(time, SLOT_STEP_MINUTES)
  ) {
    grid.push(time);
  }
  return grid;
}

/** Desde hoy hasta [days] días después, en días del salón (`bookingWindow`). */
export function bookingWindow(nowSalon: Date, days: number): { first: Date; last: Date } {
  const first = salonDay(nowSalon);
  return { first, last: addDays(first, days) };
}

const inWindow = (window: { first: Date; last: Date }, day: Date) => {
  const d = salonDay(day);
  return d >= window.first && d <= window.last;
};

/** Si [a] y [b] se cruzan; tocar el borde no cuenta (`overlaps`). */
export const overlaps = (a: Range, b: Range): boolean =>
  a.start < b.end && b.start < a.end;

/** Si [time] cae dentro de [range]: desde su inicio hasta antes de su fin. */
const covers = (range: Range, time: Date) => range.start <= time && time < range.end;

/** Si los cierres cubren todo el horario de [day] (`isClosedAllDay`). */
export function isClosedAllDay(
  day: Date,
  settings: CalendarSettings,
  closures: Range[],
): boolean {
  const opening = openingOf(day, settings);
  if (opening === null) return false;
  let covered = opening.open;
  while (covered < opening.close) {
    let next: Date | null = null;
    for (const closure of closures) {
      if (closure.start <= covered && closure.end > covered) {
        if (next === null || closure.end > next) next = closure.end;
      }
    }
    if (next === null) return false;
    covered = next;
  }
  return true;
}

/** Si [day] se puede elegir: en la ventana, sin bloquear, abierto y no cerrado entero. */
function isSelectableDay(
  day: Date,
  settings: CalendarSettings,
  window: { first: Date; last: Date },
  closures: Range[],
): boolean {
  return (
    inWindow(window, day) &&
    !settings.blockedDates.includes(dayKey(day)) &&
    openingOf(day, settings) !== null &&
    !isClosedAllDay(day, settings, closures)
  );
}

// Horas libres ------------------------------------------------------------

/** Una hora libre y los minutos hasta el siguiente turno o el cierre. */
export interface FreeSlot {
  start: Date;
  coverageMinutes: number;
}

/**
 * Los rangos (hora de pared) de los turnos de [appointments] que ocupan su
 * hora en [now]: esperando confirmación o confirmados, sin terminar, y sin
 * [excludeId] (el turno que se edita).
 */
export function busyRanges(
  appointments: AgendaAppointment[],
  now: Date,
  excludeId?: string,
): Range[] {
  return appointments
    .filter(
      (a) => a.id !== excludeId && ACTIVE_STATUSES.has(a.status) && a.end > now,
    )
    .map((a) => ({ start: toSalon(a.start), end: toSalon(a.end) }));
}

/** Las horas libres de [day] con su cobertura (`freeSlots`). */
export function freeSlots(
  day: Date,
  settings: CalendarSettings,
  busy: Range[],
  nowSalon: Date,
): FreeSlot[] {
  const opening = openingOf(day, settings);
  const grid = dayGrid(day, settings);
  if (opening === null || grid === null) return [];
  const starts = busy.map((r) => r.start).sort((a, b) => a.getTime() - b.getTime());
  const slots: FreeSlot[] = [];
  for (const time of grid) {
    if (time <= nowSalon) continue;
    if (busy.some((range) => covers(range, time))) continue;
    let limit = opening.close;
    for (const start of starts) {
      if (start > time) {
        if (start < limit) limit = start;
        break;
      }
    }
    slots.push({ start: time, coverageMinutes: minutesBetween(time, limit) });
  }
  return slots;
}

/**
 * Las horas libres de [day] al editar (`editFreeSlots`): las de siempre y,
 * en el día original, también la hora original si no ha empezado (la admin:
 * si no ha terminado) y no la cubre otro turno ni un cierre. Su cobertura
 * llega hasta el siguiente turno o cierre, sin pasar del cierre del día o
 * del fin original, lo que sea más tarde.
 */
function editFreeSlots(
  day: Date,
  settings: CalendarSettings,
  busy: Range[],
  nowSalon: Date,
  original: Range,
  allowStarted: boolean,
): FreeSlot[] {
  const slots = freeSlots(day, settings, busy, nowSalon);
  const start = original.start;
  if (salonDay(day).getTime() !== salonDay(start).getTime()) return slots;
  const started = start <= nowSalon;
  if (started && !(allowStarted && original.end > nowSalon)) return slots;
  if (busy.some((range) => covers(range, start))) return slots;
  if (slots.some((slot) => slot.start.getTime() === start.getTime())) return slots;

  const close = openingOf(day, settings)?.close;
  let limit = close !== undefined && close > original.end ? close : original.end;
  for (const range of busy) {
    if (range.start > start && range.start < limit) limit = range.start;
  }
  const own = { start, coverageMinutes: minutesBetween(start, limit) };
  return [...slots, own].sort((a, b) => a.start.getTime() - b.start.getTime());
}

// Veredictos --------------------------------------------------------------

/** Lo que se comprueba de un turno: sus horas y lo que las rodea. */
export interface SlotInput {
  settings: CalendarSettings;
  /** Los turnos que no terminaron (instantes); se filtran aquí. */
  appointments: AgendaAppointment[];
  /** Los cierres (instantes). Las fechas bloqueadas van en [settings]. */
  closures: Range[];
  /** El inicio pedido (instante). */
  start: Date;
  durationMinutes: number;
  now: Date;
  /** La admin: ventana de 365 días y, al editar, el turno en curso vale. */
  admin: boolean;
}

/** Por qué [start] no es una hora libre de [day]. */
function whyNotFree(
  start: Date,
  day: Date,
  settings: CalendarSettings,
  busy: Range[],
  closures: Range[],
  nowSalon: Date,
): SlotReason {
  if (start <= nowSalon) return 'past';
  const grid = dayGrid(day, settings);
  if (grid === null) return 'closed';
  if (!grid.some((time) => time.getTime() === start.getTime())) return 'outside_hours';
  if (closures.some((range) => covers(range, start))) return 'closed';
  return 'slot_taken';
}

function verdictOf(
  slots: FreeSlot[],
  start: Date,
  durationMinutes: number,
  why: () => SlotReason,
): SlotReason {
  const slot = slots.find((s) => s.start.getTime() === start.getTime());
  if (slot === undefined) return why();
  return durationMinutes <= slot.coverageMinutes ? 'ok' : 'does_not_fit';
}

/**
 * Si un turno nuevo puede empezar en [input.start] y durar
 * [input.durationMinutes] (RF-1, RF-4, RF-9, RF-10): el día se puede elegir
 * y la hora está libre, con el servicio cabiendo (`isSelectableDay` +
 * `checkSlot`).
 */
export function checkSlotRules(input: SlotInput): SlotReason {
  const nowSalon = toSalon(input.now);
  const start = toSalon(input.start);
  const day = salonDay(start);
  const window = bookingWindow(
    nowSalon,
    input.admin ? ADMIN_BOOKING_WINDOW_DAYS : BOOKING_WINDOW_DAYS,
  );
  const busy = busyRanges(input.appointments, input.now);
  const closures = input.closures.map((c) => ({ start: toSalon(c.start), end: toSalon(c.end) }));

  if (!inWindow(window, day)) return 'outside_window';
  if (!isSelectableDay(day, input.settings, window, closures)) return 'closed';
  const slots = freeSlots(day, input.settings, [...busy, ...closures], nowSalon);
  return verdictOf(slots, start, input.durationMinutes, () =>
    whyNotFree(start, day, input.settings, busy, closures, nowSalon),
  );
}

/**
 * Si la edición de [input.original] puede quedar en [input.start] con
 * [input.durationMinutes] (RF-2, RF-15): el día se puede elegir o es el
 * original, y la hora está entre las libres de la edición, sin contar el
 * propio turno (`isEditDaySelectable` + `editFreeSlots`).
 */
export function editTimesRules(
  input: SlotInput & { original: Range & { id: string } },
): SlotReason {
  const nowSalon = toSalon(input.now);
  const start = toSalon(input.start);
  const day = salonDay(start);
  const window = bookingWindow(
    nowSalon,
    input.admin ? ADMIN_BOOKING_WINDOW_DAYS : BOOKING_WINDOW_DAYS,
  );
  const busy = busyRanges(input.appointments, input.now, input.original.id);
  const closures = input.closures.map((c) => ({ start: toSalon(c.start), end: toSalon(c.end) }));
  const original = { start: toSalon(input.original.start), end: toSalon(input.original.end) };

  const originalDay = salonDay(original.start).getTime() === day.getTime();
  if (!originalDay && !isSelectableDay(day, input.settings, window, closures)) {
    return inWindow(window, day) ? 'closed' : 'outside_window';
  }
  const slots = editFreeSlots(
    day,
    input.settings,
    [...busy, ...closures],
    nowSalon,
    original,
    input.admin,
  );
  return verdictOf(slots, start, input.durationMinutes, () =>
    whyNotFree(start, day, input.settings, busy, closures, nowSalon),
  );
}

/** El veredicto como lo da la app: `ok`, `does_not_fit` o `slot_taken`. */
export function coarseVerdict(reason: SlotReason | string): 'ok' | 'does_not_fit' | 'slot_taken' {
  if (reason === 'ok' || reason === 'does_not_fit') return reason;
  return 'slot_taken';
}

// La persona de un turno (spec 007; spec 012, RF-6, RF-7) ----------------

/** Código de Brasil. */
const BRAZIL = '55';

/**
 * Dígitos mínimos de un número con el código de Brasil delante: 55 + DDD
 * (2) + fijo de 8. Con menos, un `55` inicial es el DDD de Rio Grande do Sul.
 */
const MIN_DIGITS_WITH_COUNTRY = 12;

const digitsOf = (raw: string) => raw.replace(/\D/g, '');

const hasBrazilPrefix = (raw: string, digits: string) =>
  digits.startsWith(BRAZIL) &&
  (raw.trim().startsWith('+') || digits.length >= MIN_DIGITS_WITH_COUNTRY);

/** Solo los dígitos de [raw], sin el código de Brasil (`normalizeWhatsApp`). */
export function normalizeWhatsApp(raw: string): string {
  const digits = digitsOf(raw);
  return hasBrazilPrefix(raw, digits) ? digits.slice(BRAZIL.length) : digits;
}

/** Si [a] y [b] son el mismo WhatsApp, no vacío (`sameWhatsApp`). */
export function sameWhatsApp(a: string, b: string): boolean {
  const normalized = normalizeWhatsApp(a);
  return normalized.length > 0 && normalized === normalizeWhatsApp(b);
}

/** Un turno con su persona: su cuenta (`null` sin cuenta) y su WhatsApp. */
export interface PersonAppointment extends AgendaAppointment {
  clientId: string | null;
  clientPhone: string;
}

/** Una persona: su cuenta, si tiene, y su WhatsApp. */
export interface Person {
  uid: string | null;
  phone: string;
}

/**
 * El turno activo de [person] en [now] (`activeAppointmentOfPerson` y
 * `activeAppointment`): entre los de su cuenta y los que llevan su WhatsApp,
 * esperando confirmación o confirmados y que terminan después de [now], el
 * que empieza antes. Sin [excludeId] (el turno que se edita). `null` si no
 * hay ninguno.
 */
export function activeAppointmentOfPerson<T extends PersonAppointment>(
  appointments: T[],
  person: Person,
  now: Date,
  excludeId?: string,
): T | null {
  let active: T | null = null;
  for (const a of appointments) {
    if (a.id === excludeId) continue;
    const mine =
      (person.uid !== null && a.clientId === person.uid) ||
      sameWhatsApp(a.clientPhone, person.phone);
    if (!mine || !ACTIVE_STATUSES.has(a.status) || !(a.end > now)) continue;
    if (active === null || a.start < active.start) active = a;
  }
  return active;
}
