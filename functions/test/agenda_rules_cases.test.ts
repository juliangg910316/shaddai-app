// Los casos compartidos de las reglas de horas (spec 012, RNF-2, plan D-4),
// pasados por las reglas del servidor. La app pasa los mismos en
// `test/features/booking/agenda_rules_cases_test.dart`: si los dos dan lo
// mismo, el servidor nunca rechaza una hora que la app ofrece.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, test } from 'node:test';

import {
  activeAppointmentOfPerson,
  checkSlotRules,
  coarseVerdict,
  editTimesRules,
  normalizeWhatsApp,
  readCalendarSettings,
  sameWhatsApp,
} from '../src/agenda_rules.ts';
import type { AgendaAppointment, Range } from '../src/agenda_rules.ts';

interface RawRange {
  start: string;
  end: string;
  status?: string;
}

interface Case {
  name: string;
  now: string;
  mode?: 'client' | 'admin';
  settings?: Record<string, unknown>;
  busy?: RawRange[];
  closures?: RawRange[];
  original?: RawRange;
  start: string;
  durationMinutes: number;
  verdict: string;
  reason: string;
}

interface PersonCase {
  name: string;
  now: string;
  uid: string | null;
  phone: string;
  excludeId?: string;
  appointments: (RawRange & { id: string; clientId: string | null; clientPhone: string })[];
  expected: string | null;
}

const { cases, whatsapp, persons } = JSON.parse(
  readFileSync(
    new URL('../../test/fixtures/agenda_rules_cases.json', import.meta.url),
    'utf8',
  ),
) as {
  cases: Case[];
  whatsapp: { normalize: [string, string, string][]; same: [string, string, boolean, string][] };
  persons: PersonCase[];
};

const range = (raw: RawRange): Range => ({
  start: new Date(raw.start),
  end: new Date(raw.end),
});

const appointments = (c: Case): AgendaAppointment[] =>
  (c.busy ?? []).map((raw, i) => ({
    id: `otro-${i}`,
    ...range(raw),
    status: raw.status ?? 'confirmed',
  }));

function reasonOf(c: Case): string {
  const input = {
    settings: readCalendarSettings(c.settings ?? {}),
    appointments: appointments(c),
    closures: (c.closures ?? []).map(range),
    start: new Date(c.start),
    durationMinutes: c.durationMinutes,
    now: new Date(c.now),
    admin: c.mode === 'admin',
  };
  return c.original === undefined
    ? checkSlotRules(input)
    : editTimesRules({
        ...input,
        original: { id: 'original', ...range(c.original) },
      });
}

describe('los casos compartidos con la app (RNF-2)', () => {
  for (const c of cases) {
    test(`${c.name}: ${c.reason}`, () => {
      const reason = reasonOf(c);
      assert.equal(reason, c.reason);
      assert.equal(coarseVerdict(reason), c.verdict);
    });
  }
});

describe('WhatsApp normalizado, como la app (spec 007)', () => {
  for (const [input, expected, why] of whatsapp.normalize) {
    test(`${why}: "${input}" → "${expected}"`, () => {
      assert.equal(normalizeWhatsApp(input), expected);
    });
  }
  for (const [a, b, expected, why] of whatsapp.same) {
    test(`${why}: "${a}" y "${b}" → ${expected}`, () => {
      assert.equal(sameWhatsApp(a, b), expected);
      assert.equal(sameWhatsApp(b, a), expected);
    });
  }
});

describe('el turno activo de una persona (RF-6, RF-7)', () => {
  for (const c of persons) {
    test(`${c.name}: ${c.expected}`, () => {
      const active = activeAppointmentOfPerson(
        c.appointments.map((a) => ({
          id: a.id,
          clientId: a.clientId,
          clientPhone: a.clientPhone,
          start: new Date(a.start),
          end: new Date(a.end),
          status: a.status ?? 'confirmed',
        })),
        { uid: c.uid, phone: c.phone },
        new Date(c.now),
        c.excludeId,
      );
      assert.equal(active?.id ?? null, c.expected);
    });
  }
});
