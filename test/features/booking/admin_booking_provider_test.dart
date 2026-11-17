import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/auth/providers/auth_provider.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/free_slots.dart';
import 'package:shaddai/features/booking/logic/recipient.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/admin_booking_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/services/logic/price_list_view_logic.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';

/// Providers de la reserva de la admin (spec 007, RF-6, RF-12, RF-14,
/// RF-15, RF-18 a RF-20, RF-27; plan § 5).
///
/// "Ahora" es el martes 10/11/2026 a las 7:00 del salón (bookingTestNow); el
/// calendario por defecto abre de 9:00 a 18:00.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);
DateTime dayOf(int day) => DateTime.utc(2026, 11, day);

BilingualText text(String es) => BilingualText(es: es, pt: '$es (pt)');

/// s1: manicura de 45 minutos, R$ 30.
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
      ],
    ),
  ],
  combos: const [],
);

const s1 = BookableRef(BookedKind.service, 's1');

UserModel client(
  String uid,
  String name, {
  String phone = '41 99999-0000',
  bool blocked = false,
  String? photoUrl,
}) => UserModel(
  uid: uid,
  email: '$uid@example.com',
  displayName: name,
  phoneNumber: phone,
  isBlocked: blocked,
  photoUrl: photoUrl,
);

/// La admin de prueba, con su propia cuenta.
final admin = UserModel(
  uid: 'admin1',
  email: 'beidis@example.com',
  displayName: 'Beidis Viera',
  phoneNumber: '+55 41 98000-0000',
  role: 'admin',
);

final ana = client(
  'ana',
  'Ana Souza',
  phone: '+55 41 99111-0000',
  photoUrl: 'https://example.com/ana.png',
);
final bea = client('bea', 'Beatriz', phone: '41 99222-0000');
final carla = client('carla', 'Carla Bloqueada', blocked: true);

const rosa = GuestRecipient(
  name: '  Rosa Lima  ',
  phone: ' (41) 99333-0000 ',
  consent: true,
);

/// Un turno con horas de pared del salón.
AppointmentModel appt(
  String id, {
  String? clientId,
  String phone = '41 90000-0000',
  required DateTime start,
  required DateTime end,
}) => AppointmentModel(
  id: id,
  clientId: clientId,
  clientName: id,
  clientPhone: phone,
  startTime: fromSalon(start),
  endTime: fromSalon(end),
  status: 'confirmed',
  createdAt: DateTime.utc(2026, 11, 1),
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

  Future<void> start({UserModel? user}) async {
    session = StreamController<UserModel?>.broadcast();
    c = ProviderContainer(
      overrides: [
        bookingRepositoryProvider.overrideWithValue(bookings),
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
    session.add(user ?? admin);
    await settle();
  }

  setUp(() {
    bookings = FakeBookingRepository();
    users = FakeUserRepository(users: [ana, bea, carla, admin]);
  });

  tearDown(() async {
    c.dispose();
    await session.close();
  });

  BookingSelectionController selector() =>
      c.read(bookingSelectionProvider.notifier);
  BookingSelection selection() => c.read(bookingSelectionProvider).selection;
  RecipientController recipients() => c.read(bookingRecipientProvider.notifier);
  RecipientState recipientState() => c.read(bookingRecipientProvider);

  FreeSlot slot(DateTime start) => c
      .read(freeSlotsOfDayProvider(salonDay(start)))!
      .firstWhere((s) => s.start == start);

  void chooseSlotAndService() {
    selector().selectSlot(slot(at(10, 9)));
    selector().selectItem(s1);
  }

  group('ventana (RF-12)', () {
    test('la admin tiene 365 días y la clienta, 60', () async {
      await start();
      expect(c.read(isAdminSessionProvider), isTrue);
      expect(c.read(bookingWindowDaysProvider), 365);

      session.add(testClient);
      await settle();
      expect(c.read(isAdminSessionProvider), isFalse);
      expect(c.read(bookingWindowDaysProvider), 60);
    });

    test('con la admin, los turnos ocupados se piden para 365 días', () async {
      await start();
      c.listen(busySlotsProvider, (_, _) {});
      await settle();
      expect(
        bookings.busyWindows.last.to.isAtSameMomentAs(
          fromSalon(DateTime.utc(2027, 11, 11)),
        ),
        isTrue,
      );
    });

    test('con la admin, un día a 200 días se conserva', () async {
      await start();
      // 2027-05-28 es viernes, a 199 días.
      final far = DateTime.utc(2027, 5, 28);
      selector().selectDay(far);
      // Llegan otra vez los turnos ocupados: se reconcilia.
      bookings.emitBusy(const []);
      await settle();
      expect(selection().day, far);
    });
  });

  group('bookingRecipientProvider (RF-3 a RF-6, RF-15, RF-27)', () {
    test('empieza sin nada elegido', () async {
      await start();
      expect(recipientState().recipient, isNull);
      expect(recipientState().query, '');
    });

    test('busca entre las fichas que puede agendar', () async {
      await start();
      c.listen(recipientSearchProvider, (_, _) {});
      recipients().setQuery('a');
      await settle();
      expect(c.read(recipientSearchProvider).value, isEmpty);

      recipients().setQuery('ana');
      await settle();
      expect(c.read(recipientSearchProvider).value, [ana]);

      // Ni bloqueadas ni admins.
      recipients().setQuery('bloq');
      await settle();
      expect(c.read(recipientSearchProvider).value, isEmpty);
      recipients().setQuery('beidis');
      await settle();
      expect(c.read(recipientSearchProvider).value, isEmpty);
    });

    test(
      'si no se pueden cargar las fichas, la búsqueda da error (RF-6)',
      () async {
        await start();
        c.listen(recipientSearchProvider, (_, _) {});
        recipients().setQuery('ana');
        await settle();
        users.failUsers(Exception('sin conexión'));
        await settle();
        expect(c.read(recipientSearchProvider).hasError, isTrue);
      },
    );

    test(
      'elegir una clienta, la persona sin cuenta y volver a buscar',
      () async {
        await start();
        recipients().setQuery('ana');
        recipients().chooseAccount(ana);
        expect(recipientState().recipient, AccountRecipient.of(ana));
        expect(recipientState().query, '');

        recipients().startGuest();
        expect(recipientState().recipient, GuestRecipient.empty);
        recipients().updateGuest(name: 'Rosa');
        recipients().updateGuest(phone: '41 99333-0000');
        recipients().updateGuest(consent: true);
        expect(
          recipientState().recipient,
          const GuestRecipient(
            name: 'Rosa',
            phone: '41 99333-0000',
            consent: true,
          ),
        );

        recipients().clear();
        expect(recipientState().recipient, isNull);
      },
    );

    test('se conserva aunque nadie lo escuche (RF-27)', () async {
      await start();
      final sub = c.listen(bookingRecipientProvider, (_, _) {});
      recipients().chooseAccount(ana);
      sub.close();
      await settle();
      expect(recipientState().recipient, AccountRecipient.of(ana));
    });

    test('si la bloquean, se quita y avisa (RF-15)', () async {
      await start();
      c.listen(bookingRecipientProvider, (_, _) {});
      recipients().chooseAccount(ana);
      await settle();
      users.emitUsers([ana.copyWith(isBlocked: true), bea]);
      await settle();
      expect(recipientState().recipient, isNull);
      expect(recipientState().notices, [RecipientNotice.blocked]);

      recipients().consumeNotices();
      expect(recipientState().notices, isEmpty);
    });

    test('la persona sin cuenta no se quita al cambiar las fichas', () async {
      await start();
      c.listen(bookingRecipientProvider, (_, _) {});
      recipients().startGuest();
      users.emitUsers([carla]);
      await settle();
      expect(recipientState().recipient, GuestRecipient.empty);
    });

    test('se vacía al cambiar de cuenta', () async {
      await start();
      c.listen(bookingRecipientProvider, (_, _) {});
      recipients().chooseAccount(ana);
      recipients().setQuery('be');
      session.add(admin.copyWith(uid: 'admin2'));
      await settle();
      expect(recipientState().recipient, isNull);
      expect(recipientState().query, '');
    });
  });

  group('recipientActiveAppointmentProvider (RF-14)', () {
    test('el turno activo de la clienta elegida, por su cuenta', () async {
      bookings.active = [
        appt('de-ana', clientId: 'ana', start: at(12, 10), end: at(12, 11)),
      ];
      await start();
      c.listen(recipientActiveAppointmentProvider, (_, _) {});
      expect(c.read(recipientActiveAppointmentProvider), isNull);
      recipients().chooseAccount(ana);
      await settle();
      expect(c.read(recipientActiveAppointmentProvider)?.id, 'de-ana');
    });

    test('por WhatsApp, también para una persona sin cuenta', () async {
      await start();
      c.listen(recipientActiveAppointmentProvider, (_, _) {});
      recipients().startGuest();
      recipients().updateGuest(phone: '41 99111-0000');
      bookings.emitActive([
        appt(
          'sin-cuenta',
          phone: '(41) 99111-0000',
          start: at(12, 10),
          end: at(12, 11),
        ),
      ]);
      await settle();
      expect(c.read(recipientActiveAppointmentProvider)?.id, 'sin-cuenta');

      // La clienta con ese WhatsApp también lo tiene como activo.
      recipients().chooseAccount(ana);
      await settle();
      expect(c.read(recipientActiveAppointmentProvider)?.id, 'sin-cuenta');
    });

    test('pide los turnos que terminan desde "ahora"', () async {
      await start();
      c.listen(recipientActiveAppointmentProvider, (_, _) {});
      recipients().chooseAccount(ana);
      await settle();
      expect(
        bookings.activeRequests.single.isAtSameMomentAs(bookingTestNow),
        isTrue,
      );
    });
  });

  group('adminBookingSubmitProvider (RF-15, RF-18 a RF-20)', () {
    Future<AdminBookingResult> confirm() =>
        c.read(adminBookingSubmitProvider).confirm();

    test(
      'guarda el turno confirmado de una clienta con cuenta (RF-19)',
      () async {
        await start();
        c.listen(bookingRecipientProvider, (_, _) {});
        recipients().chooseAccount(ana);
        chooseSlotAndService();

        final result = await confirm();

        expect(result.outcome, AdminBookingOutcome.ok);
        expect(result.name, 'Ana Souza');
        final saved = bookings.created.single;
        expect(saved.clientId, 'ana');
        expect(saved.clientName, 'Ana Souza');
        expect(saved.clientPhone, '+55 41 99111-0000');
        expect(saved.clientPhotoUrl, 'https://example.com/ana.png');
        expect(saved.status, 'confirmed');
        expect(saved.createdByAdmin, isTrue);
        expect(saved.startTime.isAtSameMomentAs(fromSalon(at(10, 9))), isTrue);
        expect(
          saved.endTime.isAtSameMomentAs(fromSalon(at(10, 9, 45))),
          isTrue,
        );
        expect(saved.booked!.id, 's1');
        expect(saved.id, hasLength(36));
        expect(users.fetchRequests, ['ana']);
      },
    );

    test('con los datos actuales de su ficha, leídos del servidor', () async {
      users.serverUsers = [ana.copyWith(phoneNumber: '41 97777-0000')];
      await start();
      recipients().chooseAccount(ana);
      chooseSlotAndService();
      await confirm();
      expect(bookings.created.single.clientPhone, '41 97777-0000');
    });

    test('guarda una persona sin cuenta, sin cuenta ni foto (RF-19)', () async {
      await start();
      recipients().startGuest();
      recipients().updateGuest(
        name: rosa.name,
        phone: rosa.phone,
        consent: true,
      );
      chooseSlotAndService();

      final result = await confirm();

      expect(result.outcome, AdminBookingOutcome.ok);
      expect(result.name, 'Rosa Lima');
      final saved = bookings.created.single;
      expect(saved.clientId, isNull);
      expect(saved.clientName, 'Rosa Lima');
      expect(saved.clientPhone, '(41) 99333-0000');
      expect(saved.clientPhotoUrl, isNull);
      expect(saved.status, 'confirmed');
      expect(saved.createdByAdmin, isTrue);
      expect(users.fetchRequests, isEmpty);
    });

    test(
      'comprueba en el servidor el día elegido, desde "ahora" (RF-18)',
      () async {
        await start();
        recipients().chooseAccount(ana);
        chooseSlotAndService();
        await confirm();
        final request = bookings.adminCheckRequests.single;
        expect(request.from.isAtSameMomentAs(fromSalon(dayOf(10))), isTrue);
        expect(request.to.isAtSameMomentAs(fromSalon(dayOf(11))), isTrue);
        expect(request.now.isAtSameMomentAs(bookingTestNow), isTrue);
      },
    );

    test('tras guardar, vacía todo, también el día y para quién (RF-20, '
        'D-8)', () async {
      await start();
      recipients().chooseAccount(ana);
      selector().selectDay(dayOf(12));
      selector().selectSlot(slot(at(12, 10)));
      selector().selectItem(s1);

      await confirm();

      // Vuelve al primer día con horas libres, como al abrir.
      expect(selection(), BookingSelection(day: dayOf(10)));
      expect(recipientState().recipient, isNull);
      expect(recipientState().query, '');
    });

    test('si la persona ya tiene un turno activo, no guarda (RF-14)', () async {
      final existing = appt(
        'de-ana',
        clientId: 'ana',
        start: at(20, 10),
        end: at(20, 11),
      );
      bookings.active = [existing];
      await start();
      recipients().chooseAccount(ana);
      chooseSlotAndService();

      final result = await confirm();

      expect(result.outcome, AdminBookingOutcome.personActive);
      expect(result.active?.id, 'de-ana');
      expect(bookings.created, isEmpty);
      expect(selection().start, at(10, 9));
      expect(recipientState().recipient, AccountRecipient.of(ana));
    });

    test('si la bloquearon, no guarda y la quita (RF-15)', () async {
      users.serverUsers = [ana.copyWith(isBlocked: true)];
      await start();
      recipients().chooseAccount(ana);
      chooseSlotAndService();

      final result = await confirm();

      expect(result.outcome, AdminBookingOutcome.recipientBlocked);
      expect(bookings.created, isEmpty);
      expect(recipientState().recipient, isNull);
      expect(selection().start, at(10, 9));
    });

    test('una persona sin cuenta con el WhatsApp de una bloqueada no se '
        'agenda y se conserva (RF-11)', () async {
      await start();
      c.listen(bookingRecipientProvider, (_, _) {});
      await settle();
      recipients().startGuest();
      recipients().updateGuest(
        name: 'Carla',
        phone: carla.phoneNumber,
        consent: true,
      );
      chooseSlotAndService();

      final result = await confirm();

      expect(result.outcome, AdminBookingOutcome.recipientBlocked);
      expect(bookings.created, isEmpty);
      expect(recipientState().recipient, isA<GuestRecipient>());
    });

    test('la hora ya no está libre o no cabe: quita la hora (RF-18)', () async {
      await start();
      recipients().chooseAccount(ana);
      chooseSlotAndService();
      bookings.adminCheckData = (
        busy: [
          BusySlot(
            id: 'x',
            start: fromSalon(at(10, 9)),
            end: fromSalon(at(10, 10)),
          ),
        ],
        active: const [],
      );
      expect((await confirm()).outcome, AdminBookingOutcome.slotTaken);
      expect(selection().start, isNull);
      expect(selection().item, s1);

      selector().selectSlot(slot(at(10, 9)));
      bookings.adminCheckData = (
        busy: [
          BusySlot(
            id: 'y',
            start: fromSalon(at(10, 9, 30)),
            end: fromSalon(at(10, 10)),
          ),
        ],
        active: const [],
      );
      expect((await confirm()).outcome, AdminBookingOutcome.doesNotFit);
      expect(selection().start, isNull);
      expect(bookings.created, isEmpty);
    });

    test('sin conexión o con un error, no guarda y conserva todo', () async {
      await start();
      recipients().chooseAccount(ana);
      chooseSlotAndService();

      bookings.adminCheckError = Exception('sin conexión');
      expect((await confirm()).outcome, AdminBookingOutcome.failed);

      bookings.adminCheckError = null;
      users.fetchError = Exception('sin conexión');
      expect((await confirm()).outcome, AdminBookingOutcome.failed);

      users.fetchError = null;
      bookings.saveError = Exception('permission-denied');
      expect((await confirm()).outcome, AdminBookingOutcome.failed);

      expect(bookings.created, isEmpty);
      expect(selection().start, at(10, 9));
      expect(recipientState().recipient, AccountRecipient.of(ana));
    });

    test(
      'sin para quién, sin hora o sin servicio: failed sin pedir nada',
      () async {
        await start();
        chooseSlotAndService();
        expect((await confirm()).outcome, AdminBookingOutcome.failed);

        recipients().startGuest();
        expect((await confirm()).outcome, AdminBookingOutcome.failed);
        expect(bookings.adminCheckRequests, isEmpty);
      },
    );
  });
}
