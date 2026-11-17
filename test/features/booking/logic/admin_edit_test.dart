import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/booking/logic/admin_edit.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/booking_edit.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/free_slots.dart';
import 'package:shaddai/features/booking/logic/recipient.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';

/// La edición de la admin, sin Flutter ni Firebase (spec 008, RF-20 a
/// RF-26, RF-29 a RF-31, RNF-1; plan § 4.3 y § 4.4).
///
/// Horas de pared del salón. 2026-11-10 es martes; abre de 8:00 a 12:00, con
/// turnos de 60 minutos.
DateTime at(int hour, [int minute = 0, int day = 10]) =>
    DateTime.utc(2026, 11, day, hour, minute);

final settings = CalendarSettingsModel(
  openingHours: {
    'tuesday': DaySchedule(open: '08:00', close: '12:00', isClosed: false),
    'thursday': DaySchedule(open: '08:00', close: '12:00', isClosed: false),
  },
  globalSlotDurationMinutes: 60,
  blockedDates: const [],
);

BilingualText text(String es) => BilingualText(es: es, pt: '$es (pt)');

const s1 = BookableRef(BookedKind.service, 's1');

const booked = BookedServiceModel(
  kind: BookedKind.service,
  id: 's1',
  name: BilingualText(es: 'Manicura', pt: 'Manicura (pt)'),
  priceCents: 3000,
  durationMinutes: 60,
);

/// s1: manicura de 60 minutos; s2: pedicura de 60 minutos.
final catalog = bookableCatalog(
  PriceListModel(
    categories: [
      PriceCategoryModel(
        id: 'manos',
        name: text('Manos'),
        items: [
          PriceItemModel(
            id: 's1',
            kind: PriceItemKind.service,
            name: text('Manicura'),
            priceCents: 3000,
            durationMinutes: 60,
          ),
          PriceItemModel(
            id: 's2',
            kind: PriceItemKind.service,
            name: text('Pedicura'),
            priceCents: 4000,
            durationMinutes: 60,
          ),
        ],
      ),
    ],
    combos: const [],
  ),
);

/// Un turno de las 9:00 a las 10:00 del martes 10.
AppointmentModel appt({
  String id = 't1',
  String? clientId = 'ana',
  String name = 'Ana Souza',
  String phone = '+55 41 99111-0000',
  String? photo,
  String status = 'confirmed',
  bool createdByAdmin = false,
  DateTime? start,
  DateTime? end,
}) => AppointmentModel(
  id: id,
  clientId: clientId,
  clientName: name,
  clientPhone: phone,
  clientPhotoUrl: photo,
  startTime: fromSalon(start ?? at(9)),
  endTime: fromSalon(end ?? at(10)),
  status: status,
  createdAt: fromSalon(at(7)),
  createdByAdmin: createdByAdmin,
  booked: booked,
);

UserModel user(
  String uid, {
  String phone = '+55 41 99111-0000',
  bool blocked = false,
  String role = 'cliente',
}) => UserModel(
  uid: uid,
  email: '$uid@example.com',
  displayName: uid,
  phoneNumber: phone,
  isBlocked: blocked,
  role: role,
);

void main() {
  group('EditOriginal.of copia la persona y la marca (plan § 4.3)', () {
    test('con cuenta', () {
      final o = EditOriginal.of(
        appt(photo: 'https://example.com/a.png', createdByAdmin: true),
      );
      expect(o.clientId, 'ana');
      expect(o.clientName, 'Ana Souza');
      expect(o.clientPhone, '+55 41 99111-0000');
      expect(o.clientPhotoUrl, 'https://example.com/a.png');
      expect(o.createdByAdmin, isTrue);
    });

    test('sin cuenta', () {
      final o = EditOriginal.of(appt(clientId: null, name: 'Rosa'));
      expect(o.clientId, isNull);
      expect(o.clientName, 'Rosa');
      expect(o.createdByAdmin, isFalse);
    });
  });

  group('recipientOf (RF-19, RF-24)', () {
    test('con cuenta: la clienta del turno', () {
      expect(
        recipientOf(EditOriginal.of(appt(photo: 'p.png'))),
        const AccountRecipient(
          uid: 'ana',
          name: 'Ana Souza',
          phone: '+55 41 99111-0000',
          photoUrl: 'p.png',
        ),
      );
    });

    test('sin cuenta: su nombre y su WhatsApp, con la casilla marcada', () {
      expect(
        recipientOf(
          EditOriginal.of(appt(clientId: null, name: 'Rosa', phone: '41 9')),
        ),
        const GuestRecipient(name: 'Rosa', phone: '41 9', consent: true),
      );
    });
  });

  group('personChanged (RF-23, RF-24, RF-31)', () {
    final account = EditOriginal.of(appt());
    final guest = EditOriginal.of(
      appt(clientId: null, name: 'Rosa Lima', phone: '+55 41 99333-0000'),
    );

    for (final (label, original, recipient, expected) in [
      ('la misma clienta', account, recipientOf(account), false),
      (
        'la misma clienta con otros datos en su ficha',
        account,
        const AccountRecipient(uid: 'ana', name: 'Ana S.', phone: '1'),
        false,
      ),
      (
        'otra clienta',
        account,
        const AccountRecipient(uid: 'bea', name: 'Bea', phone: '2'),
        true,
      ),
      (
        'de cuenta a sin cuenta, aunque con su nombre y WhatsApp',
        account,
        const GuestRecipient(
          name: 'Ana Souza',
          phone: '+55 41 99111-0000',
          consent: true,
        ),
        true,
      ),
      (
        'de sin cuenta a cuenta',
        guest,
        const AccountRecipient(uid: 'ana', name: 'Ana', phone: '1'),
        true,
      ),
      ('la misma persona sin cuenta', guest, recipientOf(guest), false),
      (
        'su nombre con espacios alrededor',
        guest,
        const GuestRecipient(
          name: '  Rosa Lima ',
          phone: '+55 41 99333-0000',
          consent: true,
        ),
        false,
      ),
      (
        'su WhatsApp con otro formato',
        guest,
        const GuestRecipient(
          name: 'Rosa Lima',
          phone: '(41) 99333-0000',
          consent: true,
        ),
        false,
      ),
      (
        'otro nombre',
        guest,
        const GuestRecipient(
          name: 'Rosa Maria',
          phone: '+55 41 99333-0000',
          consent: true,
        ),
        true,
      ),
      (
        'otro WhatsApp',
        guest,
        const GuestRecipient(
          name: 'Rosa Lima',
          phone: '+55 41 99444-0000',
          consent: true,
        ),
        true,
      ),
    ]) {
      test('$label → $expected', () {
        expect(personChanged(original, recipient), expected);
      });
    }
  });

  group('adminEditChanges (RF-26, RF-27)', () {
    final original = EditOriginal.of(appt());
    final same = BookingSelection(day: at(0), start: at(9), item: s1);

    test('sin cambios: vacío', () {
      final changes = adminEditChanges(
        original,
        recipientOf(original),
        same,
        catalog,
      );
      expect(changes.isEmpty, isTrue);
      expect(changes.fields, isEmpty);
      expect(changes.person, isFalse);
    });

    test('solo la persona', () {
      final changes = adminEditChanges(
        original,
        const AccountRecipient(uid: 'bea', name: 'Bea', phone: '2'),
        same,
        catalog,
      );
      expect(changes.isEmpty, isFalse);
      expect(changes.person, isTrue);
      expect(changes.fields, isEmpty);
    });

    test('la hora', () {
      final changes = adminEditChanges(
        original,
        recipientOf(original),
        BookingSelection(day: at(0), start: at(10), item: s1),
        catalog,
      );
      expect(changes.fields, {EditField.start, EditField.end});
      expect(changes.person, isFalse);
    });

    test('el servicio', () {
      final changes = adminEditChanges(
        original,
        recipientOf(original),
        BookingSelection(
          day: at(0),
          start: at(9),
          item: const BookableRef(BookedKind.service, 's2'),
        ),
        catalog,
      );
      expect(changes.fields, containsAll([EditField.item, EditField.total]));
    });
  });

  group('markAfterEdit (RF-31)', () {
    final mine = EditOriginal.of(appt());
    final byAdmin = EditOriginal.of(appt(createdByAdmin: true));
    const bea = AccountRecipient(uid: 'bea', name: 'Bea', phone: '2');

    for (final (label, original, recipient, expected) in [
      ('de la clienta, misma persona', mine, recipientOf(mine), false),
      ('de la clienta, otra persona', mine, bea, true),
      ('de la admin, misma persona', byAdmin, recipientOf(byAdmin), true),
      ('de la admin, otra persona', byAdmin, bea, true),
    ]) {
      test('$label → $expected', () {
        expect(markAfterEdit(original, recipient), expected);
      });
    }
  });

  group('editFreeSlots(allowStarted) (RF-21)', () {
    final o = EditOriginal.of(appt());

    List<DateTime> starts({required bool allowStarted, DateTime? now}) => [
      for (final slot in editFreeSlots(
        day: at(0),
        settings: settings,
        busy: const [],
        nowSalon: now ?? at(9, 30),
        original: o,
        allowStarted: allowStarted,
      ))
        slot.start,
    ];

    /// Las horas de siempre, sin la original, con "ahora" [now].
    List<DateTime> grid(DateTime now) => [
      for (final slot in freeSlots(
        day: at(0),
        settings: settings,
        busy: const [],
        nowSalon: now,
      ))
        slot.start,
    ];

    test('con un turno en curso, su hora vale para la admin', () {
      expect(grid(at(9, 30)), isNot(contains(at(9))));
      expect(starts(allowStarted: true), [at(9), ...grid(at(9, 30))]);
    });

    test('su cobertura llega hasta el cierre', () {
      final own = editFreeSlots(
        day: at(0),
        settings: settings,
        busy: [(start: at(11), end: at(12))],
        nowSalon: at(9, 30),
        original: o,
        allowStarted: true,
      ).first;
      expect(own.start, at(9));
      expect(own.coverageMinutes, 120);
    });

    test('para la clienta (false), igual que antes: ya no vale', () {
      expect(starts(allowStarted: false), grid(at(9, 30)));
    });

    test('un turno ya terminado no vale ni para la admin', () {
      expect(starts(allowStarted: true, now: at(10, 30)), grid(at(10, 30)));
    });
  });

  group('checkAdminEditBeforeSave (RF-20 a RF-22, RF-25, RF-28 a RF-30)', () {
    final original = EditOriginal.of(appt());
    final ana = user('ana');

    AdminEditCheck check({
      AppointmentModel? current,
      bool missing = false,
      Recipient? recipient,
      UserModel? recipientUser,
      bool noUser = false,
      List<UserModel> users = const [],
      DateTime? start,
      int duration = 60,
      List<BusyRange> busy = const [],
      List<BusyRange> closures = const [],
      List<AppointmentModel> active = const [],
      DateTime? now,
    }) => checkAdminEditBeforeSave(
      original: original,
      current: missing ? null : current ?? appt(),
      recipient: recipient ?? recipientOf(original),
      recipientUser: noUser ? null : recipientUser ?? ana,
      users: users,
      start: start ?? at(10),
      durationMinutes: duration,
      settings: settings,
      busy: busy,
      closures: closures,
      active: active,
      nowSalon: now ?? at(7),
    );

    test('todo bien → ok', () {
      expect(check(), isA<AdminEditOk>());
    });

    test('sin margen de edición: un turno que empieza enseguida → ok '
        '(RF-22)', () {
      expect(check(now: at(8, 59), start: at(9)), isA<AdminEditOk>());
    });

    test('en curso, mantener su hora → ok (RF-21)', () {
      expect(check(now: at(9, 30), start: at(9)), isA<AdminEditOk>());
    });

    for (final (label, current, missing) in [
      ('ya no existe', null, true),
      ('cancelado', appt(status: 'cancelled'), false),
    ]) {
      test('$label → notActive (RF-30)', () {
        expect(
          check(current: current, missing: missing),
          isA<AdminEditNotActive>(),
        );
      });
    }

    test('ya terminado → notActive (RF-30)', () {
      expect(check(now: at(10, 30), start: at(11)), isA<AdminEditNotActive>());
    });

    for (final (label, current) in [
      ('otra hora', appt(start: at(10), end: at(11))),
      ('otro estado', appt(status: 'waiting_confirmation')),
      ('otra persona', appt(clientId: 'bea', name: 'Bea')),
      ('otro WhatsApp', appt(phone: '+55 41 90000-0000')),
      ('la marca', appt(createdByAdmin: true)),
    ]) {
      test('alguien cambió $label → changed (RF-30)', () {
        expect(check(current: current), isA<AdminEditChanged>());
      });
    }

    test('lo que no está activo se dice antes que lo que cambió', () {
      expect(
        check(
          current: appt(status: 'cancelled', start: at(10), end: at(11)),
        ),
        isA<AdminEditNotActive>(),
      );
    });

    for (final (label, recipientUser, noUser) in [
      ('bloqueada', user('ana', blocked: true), false),
      ('ya no existe', null, true),
      ('ya no es clienta', user('ana', role: 'admin'), false),
    ]) {
      test('la clienta $label → recipientBlocked (RF-29)', () {
        expect(
          check(recipientUser: recipientUser, noUser: noUser),
          isA<AdminEditRecipientBlocked>(),
        );
      });
    }

    test('sin cuenta con el WhatsApp de una bloqueada → recipientBlocked', () {
      expect(
        check(
          recipient: const GuestRecipient(
            name: 'Rosa',
            phone: '41 99333-0000',
            consent: true,
          ),
          users: [user('carla', phone: '+55 41 99333-0000', blocked: true)],
        ),
        isA<AdminEditRecipientBlocked>(),
      );
    });

    test('la nueva persona tiene otro turno activo → personActive con ese '
        'turno (RF-25)', () {
      final other = appt(
        id: 'otro',
        clientId: 'bea',
        start: at(11),
        end: at(12),
      );
      final result = check(
        recipient: const AccountRecipient(uid: 'bea', name: 'Bea', phone: '2'),
        recipientUser: user('bea', phone: '+55 41 92222-0000'),
        active: [other],
      );
      expect(result, isA<AdminEditPersonActive>());
      expect((result as AdminEditPersonActive).appointment.id, 'otro');
    });

    test('el turno que se edita no cuenta como activo de la persona '
        '(RF-25)', () {
      expect(check(active: [appt()]), isA<AdminEditOk>());
    });

    test('la persona bloqueada se dice antes que su turno activo', () {
      expect(
        check(
          recipientUser: user('ana', blocked: true),
          active: [appt(id: 'otro', start: at(11), end: at(12))],
        ),
        isA<AdminEditRecipientBlocked>(),
      );
    });

    test('hora ocupada → slotTaken (RF-29)', () {
      expect(
        check(busy: [(start: at(10), end: at(11))]),
        isA<AdminEditSlotTaken>(),
      );
    });

    test('hora dentro de un cierre → slotTaken (RF-20)', () {
      expect(
        check(closures: [(start: at(10), end: at(12))]),
        isA<AdminEditSlotTaken>(),
      );
    });

    test('no cabe → doesNotFit (RF-29)', () {
      expect(check(start: at(11), duration: 120), isA<AdminEditDoesNotFit>());
    });

    test('su persona activa se dice antes que la hora ocupada', () {
      final other = appt(
        id: 'otro',
        clientId: 'bea',
        start: at(11),
        end: at(12),
      );
      expect(
        check(
          recipient: const AccountRecipient(
            uid: 'bea',
            name: 'Bea',
            phone: '2',
          ),
          recipientUser: user('bea', phone: '+55 41 92222-0000'),
          active: [other],
          busy: [(start: at(10), end: at(11))],
        ),
        isA<AdminEditPersonActive>(),
      );
    });
  });
}
