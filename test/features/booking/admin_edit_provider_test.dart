import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/closure_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/admin/providers/admin_provider.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/admin_edit.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/free_slots.dart';
import 'package:shaddai/features/booking/logic/recipient.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/admin_booking_provider.dart';
import 'package:shaddai/features/booking/providers/admin_edit_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/services/logic/price_list_view_logic.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_config.dart';
import '../../helpers/fake_session.dart';

/// Abrir y cerrar la edición de la admin sin perder lo que tenía elegido
/// para agendar (spec 008, RF-19, RF-23 a RF-25, RF-33, RF-35; plan § 5, D-2).
///
/// "Ahora" es el martes 10/11/2026 a las 7:00 del salón (bookingTestNow); el
/// calendario por defecto abre de 9:00 a 18:00.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);
DateTime dayOf(int day) => DateTime.utc(2026, 11, day);

BilingualText text(String es) => BilingualText(es: es, pt: '$es (pt)');

/// s1: manicura de 45 minutos; s2: pedicura de 60.
PriceListModel priceList() => PriceListModel(
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
          durationMinutes: 45,
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
);

const s1 = BookableRef(BookedKind.service, 's1');
const s2 = BookableRef(BookedKind.service, 's2');

UserModel client(
  String uid,
  String name,
  String phone, {
  bool blocked = false,
}) => UserModel(
  uid: uid,
  email: '$uid@example.com',
  displayName: name,
  phoneNumber: phone,
  isBlocked: blocked,
);

final admin = UserModel(
  uid: 'admin1',
  email: 'beidis@example.com',
  displayName: 'Beidis Viera',
  phoneNumber: '+55 41 98000-0000',
  role: 'admin',
);
final ana = client('ana', 'Ana Souza', '+55 41 99111-0000');
final bea = client('bea', 'Beatriz', '+55 41 99222-0000');

/// El turno de Ana del viernes 20, de 10:00 a 10:45, con s1.
AppointmentModel anaAppointment({String? clientId = 'ana'}) => AppointmentModel(
  id: 't1',
  clientId: clientId,
  clientName: clientId == null ? 'Rosa Lima' : 'Ana Souza',
  clientPhone: clientId == null ? '41 99333-0000' : '+55 41 99111-0000',
  startTime: fromSalon(at(20, 10)),
  endTime: fromSalon(at(20, 10, 45)),
  status: 'confirmed',
  createdAt: DateTime.utc(2026, 11, 1),
  booked: BookedServiceModel(
    kind: BookedKind.service,
    id: 's1',
    name: text('Manicura'),
    priceCents: 3000,
    durationMinutes: 45,
  ),
);

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeBookingRepository bookings;
  late FakeUserRepository users;
  late StreamController<UserModel?> session;
  late ProviderContainer c;

  Future<void> start() async {
    session = StreamController<UserModel?>.broadcast();
    c = ProviderContainer(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookings),
        configRepositoryProvider.overrideWithValue(FakeConfigRepository()),
        userRepositoryProvider.overrideWithValue(users),
        currentUserProvider.overrideWith((ref) => session.stream),
        calendarSettingsProvider.overrideWith(
          (ref) => Stream.value(CalendarSettingsModel.defaultSettings()),
        ),
        clockProvider.overrideWithValue(() => bookingTestNow),
        salonNowProvider.overrideWith(
          (ref) => Stream.value(toSalon(bookingTestNow)),
        ),
        currentPriceListProvider.overrideWithValue(PriceListReady(priceList())),
      ],
    );
    c.listen(currentUserProvider, (_, _) {});
    c.listen(bookingSelectionProvider, (_, _) {});
    c.listen(bookingRecipientProvider, (_, _) {});
    c.listen(adminUsersProvider, (_, _) {});
    c.listen(myAppointmentsProvider, (_, _) {});
    session.add(admin);
    await settle();
  }

  setUp(() {
    bookings = FakeBookingRepository(
      active: [anaAppointment()],
      busy: [
        BusySlot(
          id: 't1',
          start: fromSalon(at(20, 10)),
          end: fromSalon(at(20, 10, 45)),
        ),
      ],
    );
    users = FakeUserRepository(users: [ana, bea, admin]);
  });

  tearDown(() async {
    c.dispose();
    await session.close();
  });

  BookingSelectionController selector() =>
      c.read(bookingSelectionProvider.notifier);
  BookingSelection selection() => c.read(bookingSelectionProvider).selection;
  RecipientState recipientState() => c.read(bookingRecipientProvider);
  AdminEditController editor() => c.read(adminEditProvider.notifier);

  FreeSlot slot(DateTime start) => c
      .read(freeSlotsOfDayProvider(salonDay(start)))!
      .firstWhere((s) => s.start == start);

  /// Lo que la admin tenía a medias para agendar: Bea, el jueves 12 a las
  /// 9:00, con s2.
  Future<void> halfBooked() async {
    c.read(bookingRecipientProvider.notifier).chooseAccount(bea);
    selector().selectDay(dayOf(12));
    selector().selectSlot(slot(at(12, 9)));
    selector().selectItem(s2);
    await settle();
  }

  group('start (RF-19, RF-24, RF-33)', () {
    test(
      'carga la persona, el día, la hora y lo reservado del turno',
      () async {
        await start();
        await halfBooked();

        editor().start(anaAppointment());
        await settle();

        expect(c.read(adminEditProvider), 't1');
        expect(c.read(editTargetProvider)?.id, 't1');
        expect(
          selection(),
          BookingSelection(day: dayOf(20), start: at(20, 10), item: s1),
        );
        expect(
          recipientState().recipient,
          const AccountRecipient(
            uid: 'ana',
            name: 'Ana Souza',
            phone: '+55 41 99111-0000',
          ),
        );
      },
    );

    test(
      'una persona sin cuenta llega con la casilla marcada (RF-24)',
      () async {
        bookings.active = [anaAppointment(clientId: null)];
        await start();
        editor().start(anaAppointment(clientId: null));
        await settle();
        expect(
          recipientState().recipient,
          const GuestRecipient(
            name: 'Rosa Lima',
            phone: '41 99333-0000',
            consent: true,
          ),
        );
      },
    );

    test(
      'su propia hora sale libre: su turno ocupado no cuenta (RF-21)',
      () async {
        await start();
        editor().start(anaAppointment());
        await settle();
        expect(
          c.read(freeSlotsOfDayProvider(dayOf(20)))!.map((s) => s.start),
          contains(at(20, 10)),
        );
      },
    );
  });

  group('end (RF-33, RF-35)', () {
    test('devuelve lo que tenía a medias para agendar', () async {
      await start();
      await halfBooked();
      editor().start(anaAppointment());
      await settle();

      editor().end();
      await settle();

      expect(c.read(adminEditProvider), isNull);
      expect(c.read(editTargetProvider), isNull);
      expect(
        selection(),
        BookingSelection(day: dayOf(12), start: at(12, 9), item: s2),
      );
      expect(recipientState().recipient, AccountRecipient.of(bea));
    });

    test('y lo ajusta a los datos de ahora: una hora que se ocupó mientras '
        'editaba se quita con su aviso', () async {
      await start();
      await halfBooked();
      editor().start(anaAppointment());
      await settle();
      bookings.emitBusy([
        ...bookings.busy,
        BusySlot(
          id: 'otro',
          start: fromSalon(at(12, 9)),
          end: fromSalon(at(12, 10)),
        ),
      ]);
      await settle();

      editor().end();
      await settle();

      expect(selection().day, dayOf(12));
      expect(selection().start, isNull);
      expect(selection().item, s2);
      expect(
        c.read(bookingSelectionProvider).notices.map((n) => n.kind),
        contains(BookingNoticeKind.slotGone),
      );
    });

    test('sin nada a medias, vuelve a la selección vacía', () async {
      await start();
      editor().start(anaAppointment());
      await settle();
      editor().end();
      await settle();
      expect(selection().start, isNull);
      expect(selection().item, isNull);
      expect(recipientState().recipient, isNull);
    });

    test('sin edición abierta, no hace nada', () async {
      await start();
      await halfBooked();
      editor().end();
      await settle();
      expect(selection().start, at(12, 9));
      expect(recipientState().recipient, AccountRecipient.of(bea));
    });
  });

  test('el turno en edición no cuenta como turno activo de su persona '
      '(RF-25)', () async {
    await start();
    c.listen(adminActiveAppointmentsProvider, (_, _) {});
    c.listen(recipientActiveAppointmentProvider, (_, _) {});
    c.read(bookingRecipientProvider.notifier).chooseAccount(ana);
    await settle();
    expect(c.read(recipientActiveAppointmentProvider)?.id, 't1');

    editor().start(anaAppointment());
    await settle();
    expect(c.read(recipientActiveAppointmentProvider), isNull);
  });

  test('la comprobación de la edición de la clienta no cierra la de la '
      'admin', () async {
    await start();
    editor().start(anaAppointment());
    await settle();

    // Llegan los turnos propios de la admin, sin ese turno: para la
    // clienta, la edición ya no sería de su turno activo y se cerraría.
    bookings.emitMine([
      AppointmentModel(
        id: 'propio',
        clientId: 'admin1',
        clientName: 'Beidis Viera',
        clientPhone: '+55 41 98000-0000',
        startTime: fromSalon(at(3, 10)),
        endTime: fromSalon(at(3, 11)),
        status: 'cancelled',
        createdAt: DateTime.utc(2026, 11, 1),
      ),
    ]);
    await settle();

    expect(c.read(editTargetProvider)?.id, 't1');
    expect(c.read(adminEditProvider), 't1');
  });

  test('si bloquean a la clienta del turno mientras se edita, se quita con '
      'su aviso (spec 007, RF-15)', () async {
    await start();
    editor().start(anaAppointment());
    await settle();

    users.emitUsers([
      client('ana', 'Ana Souza', '+55 41 99111-0000', blocked: true),
      bea,
      admin,
    ]);
    await settle();

    expect(recipientState().recipient, isNull);
    expect(recipientState().notices, contains(RecipientNotice.blocked));
  });

  group('save (RF-26, RF-28 a RF-31, RF-34)', () {
    Future<AdminEditResult> save() => editor().save();

    /// Abre la edición del turno [appointment] (por defecto, el de Ana).
    Future<void> edit([AppointmentModel? appointment]) async {
      final target = appointment ?? anaAppointment();
      bookings.emitAppointment(target.id, target);
      bookings.active = [target];
      await start();
      c.listen(adminEditAlertProvider, (_, _) {});
      editor().start(target);
      await settle();
    }

    test('sin cambios: no lee ni guarda (RF-26)', () async {
      await edit();
      final result = await save();
      expect(result.outcome, AdminEditOutcome.noChanges);
      expect(bookings.adminEditCheckRequests, isEmpty);
      expect(bookings.adminEdits, isEmpty);
    });

    test('sin hora: no lee ni guarda (RF-34)', () async {
      await edit();
      selector().dropSlot();
      final result = await save();
      expect(result.outcome, AdminEditOutcome.incomplete);
      expect(bookings.adminEditCheckRequests, isEmpty);
    });

    test('sin para quién: no guarda (RF-34)', () async {
      await edit();
      selector().selectSlot(slot(at(20, 11)));
      c.read(bookingRecipientProvider.notifier).clear();
      expect((await save()).outcome, AdminEditOutcome.incomplete);
      expect(bookings.adminEdits, isEmpty);
    });

    test('ok con otra hora: guarda confirmado, sin la persona, y devuelve el '
        'día y el nombre; la edición se cierra (RF-28)', () async {
      await edit();
      selector().selectSlot(slot(at(20, 11)));

      final result = await save();

      expect(result.outcome, AdminEditOutcome.ok);
      expect(result.day, dayOf(20));
      expect(result.name, 'Ana Souza');
      final saved = bookings.adminEdits.single;
      expect(saved.id, 't1');
      expect(saved.start, fromSalon(at(20, 11)));
      expect(saved.end, fromSalon(at(20, 11, 45)));
      expect(saved.booked.id, 's1');
      expect(saved.person, isNull);
      final now = bookings.active.single;
      expect(now.status, 'confirmed');
      expect(now.createdByAdmin, isFalse);
      expect(c.read(adminEditProvider), isNull);
      expect(c.read(adminEditAlertProvider), isNull);
      // Su nuevo turno ocupado no hace avisar de que la hora editada se
      // perdió.
      await settle();
      expect(c.read(bookingSelectionProvider).notices, isEmpty);
      // Lee del servidor el día nuevo, desde "ahora".
      final request = bookings.adminEditCheckRequests.single;
      expect(request.appointmentId, 't1');
      expect(request.from, fromSalon(dayOf(20)));
      expect(request.now, bookingTestNow);
    });

    test('un turno esperando confirmación queda confirmado', () async {
      await edit(
        AppointmentModel(
          id: 't1',
          clientId: 'ana',
          clientName: 'Ana Souza',
          clientPhone: '+55 41 99111-0000',
          startTime: fromSalon(at(20, 10)),
          endTime: fromSalon(at(20, 10, 45)),
          status: 'waiting_confirmation',
          createdAt: DateTime.utc(2026, 11, 1),
          booked: anaAppointment().booked,
        ),
      );
      selector().selectSlot(slot(at(20, 11)));
      expect((await save()).outcome, AdminEditOutcome.ok);
      expect(bookings.active.single.status, 'confirmed');
    });

    test('con otra persona: la escribe, con los datos de su ficha del '
        'servidor, y lo marca como de la admin (RF-31)', () async {
      await edit();
      c
          .read(bookingRecipientProvider.notifier)
          .restore(AccountRecipient.of(bea));

      final result = await save();

      expect(result.outcome, AdminEditOutcome.ok);
      expect(result.name, 'Beatriz');
      expect(bookings.adminEdits.single.person, (
        clientId: 'bea',
        clientName: 'Beatriz',
        clientPhone: '+55 41 99222-0000',
        clientPhotoUrl: null,
      ));
      expect(bookings.active.single.createdByAdmin, isTrue);
      expect(users.fetchRequests, ['bea']);
    });

    test('a una persona sin cuenta: sin cuenta y con sus datos sin espacios '
        'alrededor', () async {
      await edit();
      c
          .read(bookingRecipientProvider.notifier)
          .restore(
            const GuestRecipient(
              name: '  Rosa Lima ',
              phone: ' 41 99333-0000 ',
              consent: true,
            ),
          );
      expect((await save()).outcome, AdminEditOutcome.ok);
      expect(bookings.adminEdits.single.person, (
        clientId: null,
        clientName: 'Rosa Lima',
        clientPhone: '41 99333-0000',
        clientPhotoUrl: null,
      ));
    });

    test('la marca de un turno de la admin sigue (RF-31)', () async {
      await edit(
        AppointmentModel(
          id: 't1',
          clientId: 'ana',
          clientName: 'Ana Souza',
          clientPhone: '+55 41 99111-0000',
          startTime: fromSalon(at(20, 10)),
          endTime: fromSalon(at(20, 10, 45)),
          status: 'confirmed',
          createdAt: DateTime.utc(2026, 11, 1),
          createdByAdmin: true,
          booked: anaAppointment().booked,
        ),
      );
      selector().selectSlot(slot(at(20, 11)));
      await save();
      expect(bookings.adminEdits.single.person, isNull);
      expect(bookings.active.single.createdByAdmin, isTrue);
    });

    test(
      'hora ocupada: slotTaken, no guarda y quita la hora (RF-29)',
      () async {
        await edit();
        selector().selectSlot(slot(at(20, 11)));
        bookings.adminEditCheckData = (
          appointment: anaAppointment(),
          busy: [
            BusySlot(
              id: 'otro',
              start: fromSalon(at(20, 11)),
              end: fromSalon(at(20, 12)),
            ),
          ],
          active: [anaAppointment()],
        );

        expect((await save()).outcome, AdminEditOutcome.slotTaken);
        expect(bookings.adminEdits, isEmpty);
        expect(selection().start, isNull);
        expect(selection().item, s1);
        expect(c.read(adminEditProvider), 't1');
      },
    );

    test('hora dentro de un cierre leído del servidor: slotTaken', () async {
      await edit();
      selector().selectSlot(slot(at(20, 11)));
      final config = c.read(configRepositoryProvider) as FakeConfigRepository;
      config.closures = [
        ClosureModel(
          id: 'c1',
          start: fromSalon(at(20, 11)),
          end: fromSalon(at(20, 12)),
        ),
      ];
      expect((await save()).outcome, AdminEditOutcome.slotTaken);
      expect(config.closureFetches, [fromSalon(dayOf(20))]);
    });

    test('su propio turno ocupado no cuenta', () async {
      await edit();
      selector().selectItem(s2);
      // s2 dura 60 minutos: de 10:00 a 11:00 pisa su propio turno ocupado.
      expect((await save()).outcome, AdminEditOutcome.ok);
    });

    test('no cabe: doesNotFit y quita la hora (RF-29)', () async {
      await edit();
      selector().selectSlot(slot(at(20, 11)));
      bookings.adminEditCheckData = (
        appointment: anaAppointment(),
        busy: [
          BusySlot(
            id: 'otro',
            start: fromSalon(at(20, 11, 30)),
            end: fromSalon(at(20, 12)),
          ),
        ],
        active: [anaAppointment()],
      );
      expect((await save()).outcome, AdminEditOutcome.doesNotFit);
      expect(selection().start, isNull);
    });

    test('clienta bloqueada: recipientBlocked y la quita (RF-29)', () async {
      users.serverUsers = [
        client('ana', 'Ana Souza', '+55 41 99111-0000', blocked: true),
      ];
      await edit();
      selector().selectSlot(slot(at(20, 11)));
      expect((await save()).outcome, AdminEditOutcome.recipientBlocked);
      expect(recipientState().recipient, isNull);
      expect(bookings.adminEdits, isEmpty);
    });

    test('la nueva persona tiene otro turno activo: personActive con ese '
        'turno (RF-25)', () async {
      final beaActive = AppointmentModel(
        id: 'b1',
        clientId: 'bea',
        clientName: 'Beatriz',
        clientPhone: '+55 41 99222-0000',
        startTime: fromSalon(at(25, 9)),
        endTime: fromSalon(at(25, 10)),
        status: 'confirmed',
        createdAt: DateTime.utc(2026, 11, 1),
      );
      await edit();
      bookings.active = [anaAppointment(), beaActive];
      c
          .read(bookingRecipientProvider.notifier)
          .restore(AccountRecipient.of(bea));

      final result = await save();
      expect(result.outcome, AdminEditOutcome.personActive);
      expect(result.active?.id, 'b1');
      expect(bookings.adminEdits, isEmpty);
    });

    test('el turno se canceló: notActive (RF-30)', () async {
      await edit();
      selector().selectSlot(slot(at(20, 11)));
      bookings.emitAppointment(
        't1',
        AppointmentModel(
          id: 't1',
          clientId: 'ana',
          clientName: 'Ana Souza',
          clientPhone: '+55 41 99111-0000',
          startTime: fromSalon(at(20, 10)),
          endTime: fromSalon(at(20, 10, 45)),
          status: 'cancelled',
          createdAt: DateTime.utc(2026, 11, 1),
          booked: anaAppointment().booked,
        ),
      );
      expect((await save()).outcome, AdminEditOutcome.notActive);
      expect(bookings.adminEdits, isEmpty);
    });

    test('alguien lo cambió: changed (RF-30)', () async {
      await edit();
      selector().selectSlot(slot(at(20, 11)));
      bookings.emitAppointment(
        't1',
        AppointmentModel(
          id: 't1',
          clientId: 'ana',
          clientName: 'Ana Souza',
          clientPhone: '+55 41 99111-0000',
          startTime: fromSalon(at(20, 14)),
          endTime: fromSalon(at(20, 14, 45)),
          status: 'waiting_confirmation',
          createdAt: DateTime.utc(2026, 11, 1),
          booked: anaAppointment().booked,
        ),
      );
      expect((await save()).outcome, AdminEditOutcome.changed);
    });

    test('si cambia entre la lectura y la transacción: changed', () async {
      await edit();
      selector().selectSlot(slot(at(20, 11)));
      // El servidor dice que está igual; la transacción lo ve cancelado.
      bookings.adminEditCheckData = (
        appointment: anaAppointment(),
        busy: const [],
        active: [anaAppointment()],
      );
      bookings.emitAppointment('t1', null);
      expect((await save()).outcome, AdminEditOutcome.changed);
      expect(bookings.adminEdits, isEmpty);
    });

    test('sin conexión: failed, no guarda y conserva lo elegido', () async {
      await edit();
      selector().selectSlot(slot(at(20, 11)));
      bookings.adminEditCheckError = Exception('sin red');
      expect((await save()).outcome, AdminEditOutcome.failed);
      expect(selection().start, at(20, 11));
      expect(c.read(adminEditProvider), 't1');
    });

    test('si falla al guardar: failed', () async {
      await edit();
      selector().selectSlot(slot(at(20, 11)));
      bookings.updateError = Exception('sin red');
      expect((await save()).outcome, AdminEditOutcome.failed);
    });
  });

  group('adminEditAlertProvider: la vigilancia (RF-30)', () {
    Future<void> edit() async {
      bookings.emitAppointment('t1', anaAppointment());
      await start();
      c.listen(adminEditAlertProvider, (_, _) {});
      editor().start(anaAppointment());
      await settle();
    }

    test('sin edición o con el turno igual, nada', () async {
      await edit();
      expect(c.read(adminEditAlertProvider), isNull);
      editor().end();
      await settle();
      expect(c.read(adminEditAlertProvider), isNull);
    });

    test('si se cancela o se borra, notActive', () async {
      await edit();
      bookings.emitAppointment('t1', null);
      await settle();
      expect(c.read(adminEditAlertProvider), AdminEditAlert.notActive);
    });

    test('el propio guardado no la hace saltar', () async {
      await edit();
      final alerts = <AdminEditAlert?>[];
      c.listen(adminEditAlertProvider, (_, next) => alerts.add(next));
      selector().selectSlot(slot(at(20, 11)));
      bookings.adminEditLatency = const Duration(milliseconds: 1);

      expect((await editor().save()).outcome, AdminEditOutcome.ok);
      await settle();
      expect(alerts.whereType<AdminEditAlert>(), isEmpty);
    });

    test('si alguien lo cambia, changed', () async {
      await edit();
      bookings.emitAppointment(
        't1',
        AppointmentModel(
          id: 't1',
          clientId: 'ana',
          clientName: 'Ana Souza',
          clientPhone: '+55 41 97777-0000',
          startTime: fromSalon(at(20, 10)),
          endTime: fromSalon(at(20, 10, 45)),
          status: 'confirmed',
          createdAt: DateTime.utc(2026, 11, 1),
          booked: anaAppointment().booked,
        ),
      );
      await settle();
      expect(c.read(adminEditAlertProvider), AdminEditAlert.changed);
    });
  });
}
