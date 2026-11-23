// Los casos compartidos de las reglas de horas (spec 012, RNF-2, plan D-4),
// pasados por las reglas del servidor. La app pasa los mismos en
// `test/features/booking/agenda_rules_cases_test.dart`: si los dos dan lo
// mismo, el servidor nunca rechaza una hora que la app ofrece.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { describe, test } from 'node:test';

import {
  checkSlotRules,
  coarseVerdict,
  editTimesRules,
  readCalendarSettings,
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

const { cases } = JSON.parse(
  readFileSync(
    new URL('../../test/fixtures/agenda_rules_cases.json', import.meta.url),
    'utf8',
  ),
) as { cases: Case[] };

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
