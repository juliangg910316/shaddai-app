// Qué aviso genera un cambio en un turno y qué dice (spec 011, RF-1 a RF-5,
// RF-7 a RF-11, RNF-4; plan D-2, D-4, D-6). Lógica pura: ningún test toca
// Firebase.
import assert from 'node:assert/strict';
import { describe, test } from 'node:test';

import {
  noticeKind,
  noticeTag,
  noticeText,
  salonDay,
  uniqueTokens,
} from '../src/appointment_notice.ts';
import type { NoticeAppointment } from '../src/appointment_notice.ts';

/** Sábado 21 de noviembre de 2026, 10:00 a 11:00 en Curitiba (UTC−3). */
const base: NoticeAppointment = {
  clientId: 'ana',
  clientName: 'Ana Herrera',
  status: 'waiting_confirmation',
  start: new Date('2026-11-21T13:00:00Z'),
  end: new Date('2026-11-21T14:00:00Z'),
  bookedKey: '{"id":"mani"}',
  serviceName: 'Manicura',
  createdByAdmin: false,
  cancelledByClient: false,
  accountDeleted: false,
};

const appointment = (changes: Partial<NoticeAppointment> = {}) => ({
  ...base,
  ...changes,
});

const confirmed = appointment({ status: 'confirmed' });
const byAdmin = appointment({ status: 'confirmed', createdByAdmin: true });

describe('qué aviso genera cada cambio (RF-1 a RF-4, plan D-2)', () => {
  describe('al crearse', () => {
    test('la clienta reserva: turno nuevo (RF-1)', () => {
      assert.equal(noticeKind(null, appointment()), 'created');
    });

    test('la admin agenda para una clienta con cuenta: nada (RF-4)', () => {
      assert.equal(noticeKind(null, byAdmin), null);
    });

    test('la admin agenda para una persona sin cuenta: nada (RF-4)', () => {
      assert.equal(noticeKind(null, appointment({ ...byAdmin, clientId: null })), null);
    });

    test('un turno sin cuenta nunca avisa, aunque no lleve la marca', () => {
      assert.equal(noticeKind(null, appointment({ clientId: null })), null);
    });

    test('uno que nace confirmado o cancelado no es una reserva de la clienta', () => {
      assert.equal(noticeKind(null, confirmed), null);
      assert.equal(noticeKind(null, appointment({ status: 'cancelled' })), null);
    });
  });

  describe('la clienta edita su turno (RF-2)', () => {
    const later = {
      start: new Date('2026-11-21T15:00:00Z'),
      end: new Date('2026-11-21T16:00:00Z'),
    };

    test('otra hora: turno modificado', () => {
      assert.equal(noticeKind(confirmed, appointment(later)), 'edited');
    });

    test('otro servicio: turno modificado', () => {
      assert.equal(
        noticeKind(appointment(), appointment({ bookedKey: '{"id":"pedi"}' })),
        'edited',
      );
    });

    test('solo los adicionales (cambia lo reservado): turno modificado', () => {
      assert.equal(
        noticeKind(
          confirmed,
          appointment({ bookedKey: '{"id":"mani","addons":["deco"]}' }),
        ),
        'edited',
      );
    });

    test('solo otro fin: turno modificado', () => {
      assert.equal(
        noticeKind(appointment(), appointment({ end: later.end })),
        'edited',
      );
    });

    test('un turno que agendó la admin también avisa', () => {
      assert.equal(
        noticeKind(byAdmin, appointment({ ...later, createdByAdmin: true })),
        'edited',
      );
    });
  });

  describe('lo que hace la admin no avisa (RF-4)', () => {
    test('edita un turno: queda confirmado', () => {
      assert.equal(
        noticeKind(
          appointment(),
          appointment({
            status: 'confirmed',
            start: new Date('2026-11-22T13:00:00Z'),
            createdByAdmin: true,
          }),
        ),
        null,
      );
    });

    test('confirma', () => {
      assert.equal(noticeKind(appointment(), confirmed), null);
    });

    test('cancela (sin cancelledBy), también al bloquear', () => {
      assert.equal(
        noticeKind(confirmed, appointment({ status: 'cancelled' })),
        null,
      );
    });
  });

  describe('la clienta cancela (RF-3)', () => {
    const cancelledByClient = appointment({
      status: 'cancelled',
      cancelledByClient: true,
    });

    test('su turno activo: turno cancelado', () => {
      assert.equal(noticeKind(appointment(), cancelledByClient), 'cancelled');
      assert.equal(noticeKind(confirmed, cancelledByClient), 'cancelled');
    });

    test('uno que agendó la admin: turno cancelado', () => {
      assert.equal(
        noticeKind(byAdmin, { ...cancelledByClient, createdByAdmin: true }),
        'cancelled',
      );
    });

    test('al borrar su cuenta: turno cancelado', () => {
      assert.equal(
        noticeKind(appointment(), {
          ...cancelledByClient,
          accountDeleted: true,
        }),
        'cancelled',
      );
    });

    test('uno ya cancelado que se vuelve a escribir: nada', () => {
      assert.equal(noticeKind(cancelledByClient, cancelledByClient), null);
    });
  });

  describe('otros cambios no avisan', () => {
    test('el borrado de la cuenta marca un turno pasado', () => {
      const past = appointment({ status: 'confirmed' });
      assert.equal(
        noticeKind(past, { ...past, accountDeleted: true }),
        null,
      );
    });

    test('la clienta copia su WhatsApp nuevo (nada que compare cambia)', () => {
      assert.equal(noticeKind(appointment(), appointment()), null);
    });

    test('el turno se borra', () => {
      assert.equal(noticeKind(appointment(), null), null);
    });
  });
});

describe('el día del salón (RF-12, plan D-6)', () => {
  test('la fecha de Curitiba, en YYYY-MM-DD', () => {
    assert.equal(salonDay(base.start), '2026-11-21');
  });

  test('a las 22:30 de Curitiba ya es otro día en UTC, pero no en el salón', () => {
    assert.equal(salonDay(new Date('2026-12-31T01:30:00Z')), '2026-12-30');
  });

  test('con ceros a la izquierda', () => {
    assert.equal(salonDay(new Date('2027-01-05T12:00:00Z')), '2027-01-05');
  });
});

describe('qué dice el aviso (RF-7 a RF-11, RNF-4, plan D-6)', () => {
  test('turno nuevo: nombre, día, hora del salón y servicio (RF-8)', () => {
    assert.deepEqual(noticeText('created', appointment()), {
      title: 'Turno nuevo',
      body: 'Ana Herrera · sábado 21 de noviembre, 10:00 · Manicura. Espera tu confirmación.',
    });
  });

  test('turno modificado: cómo quedó, y que espera confirmación (RF-9)', () => {
    assert.deepEqual(noticeText('edited', appointment()), {
      title: 'Turno modificado',
      body: 'Ana Herrera lo cambió a sábado 21 de noviembre, 10:00 · Manicura. Espera tu confirmación.',
    });
  });

  test('turno cancelado: la hora queda libre (RF-10)', () => {
    assert.deepEqual(noticeText('cancelled', appointment()), {
      title: 'Turno cancelado',
      body: 'Ana Herrera canceló su turno del sábado 21 de noviembre, 10:00. La hora queda libre.',
    });
  });

  test('cancelado al borrar la cuenta: lo dice (RF-10)', () => {
    assert.deepEqual(
      noticeText('cancelled', appointment({ accountDeleted: true })),
      {
        title: 'Turno cancelado',
        body: 'Ana Herrera eliminó su cuenta y se canceló su turno del sábado 21 de noviembre, 10:00. La hora queda libre.',
      },
    );
  });

  test('sin servicio guardado, sin servicio (RF-11)', () => {
    const old = appointment({ serviceName: null });
    assert.equal(
      noticeText('created', old).body,
      'Ana Herrera · sábado 21 de noviembre, 10:00. Espera tu confirmación.',
    );
    assert.equal(
      noticeText('edited', old).body,
      'Ana Herrera lo cambió a sábado 21 de noviembre, 10:00. Espera tu confirmación.',
    );
  });

  test('sin nombre: "Una clienta"', () => {
    assert.equal(
      noticeText('cancelled', appointment({ clientName: '  ' })).body,
      'Una clienta canceló su turno del sábado 21 de noviembre, 10:00. La hora queda libre.',
    );
  });

  test('la hora y el día del salón, aunque en UTC ya sea otro día', () => {
    const late = appointment({ start: new Date('2026-12-31T01:30:00Z') });
    assert.equal(
      noticeText('created', late).body,
      'Ana Herrera · miércoles 30 de diciembre, 22:30 · Manicura. Espera tu confirmación.',
    );
  });

  test('las horas de una cifra, sin cero delante, como en la app', () => {
    const early = appointment({ start: new Date('2026-11-22T12:05:00Z') });
    assert.match(noticeText('created', early).body, /domingo 22 de noviembre, 9:05/);
  });

  test('todos los días y meses en español (RF-7)', () => {
    const days = [];
    for (let d = 0; d < 7; d++) {
      const start = new Date(Date.UTC(2026, 10, 22 + d, 13));
      days.push(noticeText('cancelled', appointment({ start })).body.split(' ')[6]);
    }
    assert.deepEqual(days, [
      'domingo',
      'lunes',
      'martes',
      'miércoles',
      'jueves',
      'viernes',
      'sábado',
    ]);

    const months = [];
    for (let m = 0; m < 12; m++) {
      const start = new Date(Date.UTC(2027, m, 10, 13));
      months.push(/ de (\S+),/.exec(noticeText('created', appointment({ start })).body)![1]);
    }
    assert.deepEqual(months, [
      'enero',
      'febrero',
      'marzo',
      'abril',
      'mayo',
      'junio',
      'julio',
      'agosto',
      'septiembre',
      'octubre',
      'noviembre',
      'diciembre',
    ]);
  });

  test('nunca el WhatsApp ni la foto, aunque el turno los tenga (RNF-4)', () => {
    const withData = {
      ...appointment(),
      clientPhone: '+5541999998888',
      clientPhotoUrl: 'https://example.com/ana.jpg',
    } as NoticeAppointment;
    for (const kind of ['created', 'edited', 'cancelled'] as const) {
      const { title, body } = noticeText(kind, withData);
      assert.doesNotMatch(title + body, /999998888|example\.com/);
    }
  });
});

describe('un aviso por dispositivo (RF-5, plan D-4)', () => {
  test('quita los tokens repetidos y conserva el orden', () => {
    assert.deepEqual(
      uniqueTokens([
        { uid: 'beidis', token: 'b' },
        { uid: 'beidis', token: 'a' },
        { uid: 'otra', token: 'b' },
        { uid: 'otra', token: 'c' },
      ]),
      ['b', 'a', 'c'],
    );
  });

  test('sin dispositivos, ninguno', () => {
    assert.deepEqual(uniqueTokens([]), []);
  });

  test('la etiqueta: 32 caracteres, la misma para el mismo evento', () => {
    const tag = noticeTag('evento-1');
    assert.match(tag, /^[0-9a-f]{32}$/);
    assert.equal(noticeTag('evento-1'), tag);
    assert.notEqual(noticeTag('evento-2'), tag);
  });
});
