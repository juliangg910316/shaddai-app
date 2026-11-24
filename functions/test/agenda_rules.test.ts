// Las piezas de las reglas de horas de la agenda (spec 012, RF-1, RF-2,
// RF-4, RF-9, RF-10; plan § 4). Los veredictos completos están en los casos
// compartidos (`agenda_rules_cases.test.ts`).
import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  bookingWindow,
  busyRanges,
  dayGrid,
  dayKey,
  fromSalon,
  overlaps,
  readCalendarSettings,
  salonDay,
  toSalon,
  weekdayKey,
} from '../src/agenda_rules.ts';

const wall = (iso: string) => new Date(`${iso}Z`);

describe('la hora del salón (Curitiba, UTC−3)', () => {
  test('toSalon y fromSalon son inversas', () => {
    const instant = new Date('2026-11-24T13:00:00Z');
    assert.deepEqual(toSalon(instant), wall('2026-11-24T10:00:00'));
    assert.deepEqual(fromSalon(toSalon(instant)), instant);
  });

  test('a las 0:30 UTC aún es el día anterior en el salón', () => {
    const day = salonDay(toSalon(new Date('2026-11-24T00:30:00Z')));
    assert.deepEqual(day, wall('2026-11-23T00:00:00'));
    assert.equal(dayKey(day), '2026-11-23');
  });

  test('weekdayKey en inglés, sin depender del idioma', () => {
    assert.equal(weekdayKey(wall('2026-11-23T10:00:00')), 'monday');
    assert.equal(weekdayKey(wall('2026-11-29T10:00:00')), 'sunday');
  });
});

describe('el calendario', () => {
  test('sin horario, el de siempre: lunes a sábado de 9:00 a 18:00', () => {
    const settings = readCalendarSettings({});
    assert.equal(settings.openingHours.monday.open, '09:00');
    assert.equal(settings.openingHours.sunday.isClosed, true);
    assert.deepEqual(settings.blockedDates, []);
  });

  test('un horario vacío o que no es un mapa también usa el de siempre', () => {
    assert.equal(readCalendarSettings({ openingHours: {} }).openingHours.monday.close, '18:00');
    assert.equal(readCalendarSettings({ openingHours: 'x' }).openingHours.monday.close, '18:00');
  });

  test('campos que faltan en un día: 9:00, 18:00 y abierto', () => {
    const settings = readCalendarSettings({ openingHours: { monday: {} } });
    assert.deepEqual(settings.openingHours.monday, {
      open: '09:00',
      close: '18:00',
      isClosed: false,
    });
    assert.equal(settings.openingHours.tuesday, undefined);
  });

  test('la rejilla: cada 30 minutos desde la apertura y antes del cierre', () => {
    const settings = readCalendarSettings({
      openingHours: { monday: { open: '9:00', close: '10:45' } },
    });
    assert.deepEqual(dayGrid(wall('2026-11-23T00:00:00'), settings), [
      wall('2026-11-23T09:00:00'),
      wall('2026-11-23T09:30:00'),
      wall('2026-11-23T10:00:00'),
      wall('2026-11-23T10:30:00'),
    ]);
  });

  test('sin rejilla si el día cierra o tiene una hora no válida', () => {
    const settings = readCalendarSettings({
      openingHours: {
        monday: { open: '18:00', close: '09:00' },
        tuesday: { open: '25:00', close: '26:00' },
      },
    });
    assert.equal(dayGrid(wall('2026-11-23T00:00:00'), settings), null);
    assert.equal(dayGrid(wall('2026-11-24T00:00:00'), settings), null);
    assert.equal(dayGrid(wall('2026-11-29T00:00:00'), settings), null);
  });
});

describe('la ventana de reserva', () => {
  test('desde hoy hasta 60 días después, los dos incluidos', () => {
    const window = bookingWindow(wall('2026-11-23T10:00:00'), 60);
    assert.deepEqual(window.first, wall('2026-11-23T00:00:00'));
    assert.deepEqual(window.last, wall('2027-01-22T00:00:00'));
  });
});

describe('solapes', () => {
  const a = { start: wall('2026-11-24T10:00:00'), end: wall('2026-11-24T11:00:00') };

  test('tocar el borde no cuenta', () => {
    assert.equal(
      overlaps(a, { start: wall('2026-11-24T11:00:00'), end: wall('2026-11-24T12:00:00') }),
      false,
    );
  });

  test('cruzarse, contener o estar dentro sí', () => {
    assert.equal(
      overlaps(a, { start: wall('2026-11-24T10:30:00'), end: wall('2026-11-24T11:30:00') }),
      true,
    );
    assert.equal(
      overlaps(a, { start: wall('2026-11-24T09:00:00'), end: wall('2026-11-24T12:00:00') }),
      true,
    );
  });

  test('busyRanges: solo los activos que no terminaron, sin el excluido', () => {
    const now = new Date('2026-11-24T13:30:00Z');
    const ranges = busyRanges(
      [
        { id: 'activo', start: new Date('2026-11-24T14:00:00Z'), end: new Date('2026-11-24T15:00:00Z'), status: 'confirmed' },
        { id: 'esperando', start: new Date('2026-11-24T15:00:00Z'), end: new Date('2026-11-24T16:00:00Z'), status: 'waiting_confirmation' },
        { id: 'cancelado', start: new Date('2026-11-24T16:00:00Z'), end: new Date('2026-11-24T17:00:00Z'), status: 'cancelled' },
        { id: 'terminado', start: new Date('2026-11-24T12:00:00Z'), end: new Date('2026-11-24T13:00:00Z'), status: 'confirmed' },
        { id: 'propio', start: new Date('2026-11-24T17:00:00Z'), end: new Date('2026-11-24T18:00:00Z'), status: 'confirmed' },
      ],
      now,
      'propio',
    );
    assert.deepEqual(ranges, [
      { start: wall('2026-11-24T11:00:00'), end: wall('2026-11-24T12:00:00') },
      { start: wall('2026-11-24T12:00:00'), end: wall('2026-11-24T13:00:00') },
    ]);
  });
});
