// Lo reservado contra la lista de precios vigente (spec 012, RF-11 a RF-13;
// plan D-5). La copia la construye el servidor, igual que `snapshotOf` en la
// app, y se compara con la que mostraba la app. Sin Firebase.
import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  bookedKey,
  checkBooked,
  readBooked,
  readPriceList,
} from '../src/booked_catalog.ts';

/** Una lista de precios como `settings/priceList`. */
const list = () => ({
  schemaVersion: 1,
  categories: [
    {
      id: 'manos',
      name: { es: 'Manos', pt: 'Mãos' },
      visible: true,
      items: [
        {
          id: 'mani',
          kind: 'service',
          name: { es: 'Manicura', pt: 'Manicure' },
          priceCents: 3000,
          priceFrom: false,
          durationMinutes: 60,
          visible: true,
        },
        {
          id: 'gel',
          kind: 'service',
          name: { es: 'Gel', pt: 'Gel' },
          priceCents: 8000,
          priceFrom: true,
          durationMinutes: 120,
          visible: true,
        },
        {
          id: 'oculto',
          kind: 'service',
          name: { es: 'Oculto', pt: 'Oculto' },
          priceCents: 1000,
          durationMinutes: 30,
          visible: false,
        },
        {
          id: 'deco',
          kind: 'addon',
          name: { es: 'Decoración', pt: 'Decoração' },
          priceCents: 500,
          visible: true,
        },
        {
          id: 'brillo',
          kind: 'addon',
          name: { es: 'Brillo', pt: 'Brilho' },
          priceCents: 300,
          visible: true,
        },
        {
          id: 'retirado',
          kind: 'addon',
          name: { es: 'Retirado', pt: 'Retirado' },
          priceCents: 200,
          visible: false,
        },
      ],
    },
    {
      id: 'pies',
      name: { es: 'Pies', pt: 'Pés' },
      visible: true,
      items: [
        {
          id: 'pedi',
          kind: 'service',
          name: { es: 'Pedicura', pt: 'Pedicure' },
          priceCents: 3500,
          durationMinutes: 60,
        },
        {
          id: 'exfoliar',
          kind: 'addon',
          name: { es: 'Exfoliación', pt: 'Esfoliação' },
          priceCents: 700,
        },
      ],
    },
    {
      id: 'cerrada',
      name: { es: 'Cerrada', pt: 'Fechada' },
      visible: false,
      items: [
        {
          id: 'spa',
          kind: 'service',
          name: { es: 'Spa', pt: 'Spa' },
          priceCents: 9000,
          durationMinutes: 90,
        },
      ],
    },
  ],
  combos: [
    {
      id: 'combo1',
      name: { es: 'Manos y pies', pt: 'Mãos e pés' },
      priceCents: 6000,
      durationMinutes: 120,
      visible: true,
    },
    {
      id: 'combo-oculto',
      name: { es: 'Viejo', pt: 'Velho' },
      priceCents: 5000,
      durationMinutes: 90,
      visible: false,
    },
  ],
});

/** Lo que guarda la app para la manicura con decoración (`snapshotOf`). */
const mani = () => ({
  kind: 'service',
  id: 'mani',
  name: { es: 'Manicura', pt: 'Manicure' },
  priceCents: 3000,
  priceFrom: false,
  durationMinutes: 60,
  addons: [{ id: 'deco', name: { es: 'Decoración', pt: 'Decoração' }, priceCents: 500 }],
});

const prices = () => readPriceList(list());

describe('lo reservado que coincide con la lista (RF-12)', () => {
  test('un servicio con adicionales: la copia es la de la lista', () => {
    const result = checkBooked(prices(), { kind: 'service', id: 'mani' }, ['deco'], mani());
    assert.deepEqual(result, { ok: true, booked: mani() });
  });

  test('los adicionales van en el orden de la lista, sin repetir', () => {
    const sent = {
      ...mani(),
      addons: [
        { id: 'deco', name: { es: 'Decoración', pt: 'Decoração' }, priceCents: 500 },
        { id: 'brillo', name: { es: 'Brillo', pt: 'Brilho' }, priceCents: 300 },
      ],
    };
    const result = checkBooked(
      prices(),
      { kind: 'service', id: 'mani' },
      ['brillo', 'deco', 'deco'],
      sent,
    );
    assert.deepEqual(result, { ok: true, booked: sent });
  });

  test('un combo, sin adicionales y sin "desde"', () => {
    const combo = {
      kind: 'combo',
      id: 'combo1',
      name: { es: 'Manos y pies', pt: 'Mãos e pés' },
      priceCents: 6000,
      priceFrom: false,
      durationMinutes: 120,
      addons: [],
    };
    assert.deepEqual(
      checkBooked(prices(), { kind: 'combo', id: 'combo1' }, [], combo),
      { ok: true, booked: combo },
    );
  });

  test('un servicio "desde" lo copia', () => {
    const gel = {
      kind: 'service',
      id: 'gel',
      name: { es: 'Gel', pt: 'Gel' },
      priceCents: 8000,
      priceFrom: true,
      durationMinutes: 120,
      addons: [],
    };
    assert.deepEqual(checkBooked(prices(), { kind: 'service', id: 'gel' }, [], gel), {
      ok: true,
      booked: gel,
    });
  });
});

describe('lo que ya no se puede reservar: item_unavailable (RF-12)', () => {
  const unavailable = { ok: false, reason: 'item_unavailable' };

  test('un servicio que no existe, oculto o de una categoría oculta', () => {
    for (const id of ['nada', 'oculto', 'spa']) {
      assert.deepEqual(checkBooked(prices(), { kind: 'service', id }, [], mani()), unavailable, id);
    }
  });

  test('un adicional suelto no se reserva como servicio', () => {
    assert.deepEqual(checkBooked(prices(), { kind: 'service', id: 'deco' }, [], mani()), unavailable);
  });

  test('un combo oculto o que no existe', () => {
    for (const id of ['combo-oculto', 'nada']) {
      assert.deepEqual(checkBooked(prices(), { kind: 'combo', id }, [], mani()), unavailable, id);
    }
  });

  test('un adicional oculto, de otra categoría o que no existe', () => {
    for (const addon of ['retirado', 'exfoliar', 'nada']) {
      assert.deepEqual(
        checkBooked(prices(), { kind: 'service', id: 'mani' }, [addon], mani()),
        unavailable,
        addon,
      );
    }
  });

  test('un combo con adicionales', () => {
    assert.deepEqual(
      checkBooked(prices(), { kind: 'combo', id: 'combo1' }, ['deco'], mani()),
      unavailable,
    );
  });
});

describe('lo que cambió en la lista: item_changed (RF-12)', () => {
  const changed = { ok: false, reason: 'item_changed' };
  const check = (sent: unknown) =>
    checkBooked(prices(), { kind: 'service', id: 'mani' }, ['deco'], sent);

  test('otro precio, nombre, "desde" o duración', () => {
    assert.deepEqual(check({ ...mani(), priceCents: 2500 }), changed);
    assert.deepEqual(check({ ...mani(), name: { es: 'Manicure', pt: 'Manicure' } }), changed);
    assert.deepEqual(check({ ...mani(), priceFrom: true }), changed);
    assert.deepEqual(check({ ...mani(), durationMinutes: 30 }), changed);
  });

  test('un adicional con otro precio, o los adicionales de otra selección', () => {
    const addon = mani().addons[0];
    assert.deepEqual(check({ ...mani(), addons: [{ ...addon, priceCents: 1 }] }), changed);
    assert.deepEqual(check({ ...mani(), addons: [] }), changed);
  });

  test('sin copia o con otra forma', () => {
    assert.deepEqual(check(undefined), changed);
    assert.deepEqual(check('mani'), changed);
    assert.deepEqual(check({ ...mani(), id: 'gel' }), changed);
  });
});

describe('la lista y la copia como las lee la app', () => {
  test('las líneas sin id, sin nombre o sin precio válido se omiten', () => {
    const parsed = readPriceList({
      categories: [
        {
          id: 'c',
          name: { es: 'C', pt: '' },
          items: [
            { id: '', name: { es: 'X', pt: 'X' }, priceCents: 1 },
            { id: 'a', name: { es: '', pt: '' }, priceCents: 1 },
            { id: 'b', name: { es: 'B', pt: 'B' }, priceCents: -1 },
            { id: 'c', name: { es: 'C', pt: 'C' }, priceCents: 1.5 },
            { id: 'ok', name: { es: 'Ok', pt: '' }, priceCents: 100 },
          ],
        },
        { id: '', name: { es: 'Sin id', pt: '' } },
        'no es un mapa',
      ],
      combos: [{ id: 'k', name: { es: 'K', pt: 'K' } }],
    });
    assert.deepEqual(
      parsed.categories.map((c) => [c.id, c.items.map((i) => i.id)]),
      [['c', ['ok']]],
    );
    assert.deepEqual(parsed.combos, []);
  });

  test('sin duración válida, 60 minutos; "visible" falta = visible; kind desconocido = servicio', () => {
    const item = readPriceList({
      categories: [
        {
          id: 'c',
          name: { es: 'C', pt: 'C' },
          items: [{ id: 's', kind: 'otro', name: { es: 'S', pt: 'S' }, priceCents: 100, durationMinutes: 0 }],
        },
      ],
    }).categories[0].items[0];
    assert.equal(item.durationMinutes, 60);
    assert.equal(item.visible, true);
    assert.equal(item.kind, 'service');
  });

  test('readBooked: como BookedServiceModel.fromMap', () => {
    assert.equal(readBooked(undefined), null);
    assert.equal(readBooked({ name: { es: '', pt: '' } }), null);
    assert.deepEqual(readBooked({ name: { es: 'X', pt: '' }, addons: [{ name: { es: '', pt: '' }, priceCents: 1 }, 'x'] }), {
      kind: 'service',
      id: '',
      name: { es: 'X', pt: '' },
      priceCents: 0,
      priceFrom: false,
      durationMinutes: 60,
      addons: [],
    });
  });
});

describe('bookedKey (RF-13)', () => {
  test('el mismo aunque cambie el orden de las claves', () => {
    const a = mani();
    const b = {
      addons: a.addons.map((x) => ({ priceCents: x.priceCents, name: { pt: x.name.pt, es: x.name.es }, id: x.id })),
      durationMinutes: 60,
      priceFrom: false,
      priceCents: 3000,
      name: { pt: 'Manicure', es: 'Manicura' },
      id: 'mani',
      kind: 'service',
    };
    assert.equal(bookedKey(a), bookedKey(b));
    assert.notEqual(bookedKey(a), bookedKey({ ...a, priceCents: 1 }));
  });
});
