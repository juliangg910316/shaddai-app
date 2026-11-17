import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/user_model.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/free_slots.dart';
import 'package:shaddai/features/booking/logic/recipient.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/booking_form.dart';
import 'package:shaddai/features/booking/presentation/recipient_picker.dart';
import 'package:shaddai/features/booking/providers/admin_booking_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/navigation/providers/tab_scroll_provider.dart';
import 'package:shaddai/features/services/presentation/price_detail_view.dart';

import '../../helpers/fake_auth.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';
import '../../helpers/pump_web_app.dart';

/// La admin agenda y lo que pasa después (spec 007, RF-15, RF-18 a RF-20,
/// RF-27), con la app real en Android/iOS y en Web. "Ahora" es el martes
/// 10/11/2026 a las 7:00 del salón; "Spa de manos" (spa) dura 45 min.
const spa = BookableRef(BookedKind.service, 'spa');

DateTime at(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, 11, hour, minute);

final ana = UserModel(
  uid: 'ana',
  email: 'ana@example.com',
  displayName: 'Ana Souza',
  phoneNumber: '+55 41 99111-0000',
  role: 'cliente',
);

Finder inSnackBar(String message) =>
    find.descendant(of: find.byType(SnackBar), matching: find.text(message));

Future<void> _tap(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await settleWeb(tester);
  await tester.tap(finder);
  await settleWeb(tester);
}

RecipientState _recipient(WidgetTester tester) =>
    appContainer(tester).read(bookingRecipientProvider);

/// Elige para Ana el miércoles 11 a las 10:00 y "Spa de manos".
Future<void> _chooseAll(WidgetTester tester, {Recipient? recipient}) async {
  final container = appContainer(tester);
  if (recipient == null) {
    container.read(bookingRecipientProvider.notifier).chooseAccount(ana);
  } else {
    container.read(bookingRecipientProvider.notifier).startGuest();
    final guest = recipient as GuestRecipient;
    container
        .read(bookingRecipientProvider.notifier)
        .updateGuest(
          name: guest.name,
          phone: guest.phone,
          consent: guest.consent,
        );
  }
  final selection = container.read(bookingSelectionProvider.notifier);
  selection.selectDay(DateTime.utc(2026, 11, 11));
  selection.selectSlot(FreeSlot(start: at(10), coverageMinutes: 8 * 60));
  selection.selectItem(spa);
  await settleWeb(tester);
}

/// "Agendar turno" y "Confirmar".
Future<void> _book(WidgetTester tester) async {
  // "Agendar turno" va al final de la lista: se baja hasta él.
  final scroll = appContainer(tester)
      .read(tabScrollControllerProvider(MobileTab.booking));
  final button = find.text('AGENDAR TURNO');
  for (var i = 0; i < 10 && button.evaluate().isEmpty; i++) {
    scroll.jumpTo(scroll.position.maxScrollExtent);
    await tester.pump();
  }
  await _tap(tester, button);
  expect(find.text('Confirmar turno'), findsOneWidget);
  await tester.tap(find.text('CONFIRMAR'));
  await settleWeb(tester);
}

void main() {
  late FakeBookingRepository bookings;
  late FakeUserRepository users;

  setUp(() {
    bookings = FakeBookingRepository();
    users = FakeUserRepository(users: [ana, testAdmin]);
  });

  Future<FakeWebSession> open(
    WidgetTester tester, {
    required bool isWeb,
    String location = '/booking',
  }) => (isWeb ? pumpWebApp : pumpMobileApp)(
    tester,
    location: location,
    user: testAdmin,
    userRepository: users,
    priceListRepository: FakePriceListRepository(stored: testPriceList()),
    overrides: bookingScheduleOverrides(bookings: bookings),
  );

  for (final isWeb in [false, true]) {
    final platform = isWeb ? 'Web' : 'Android/iOS';

    testWidgets('$platform: tras agendar, lo confirma y deja la vista vacía '
        '(RF-19, RF-20)', (tester) async {
      await open(tester, isWeb: isWeb);
      expect(find.byType(RecipientPicker), findsOneWidget);
      await _chooseAll(tester);
      await _book(tester);

      final saved = bookings.created.single;
      expect(saved.clientId, 'ana');
      expect(saved.status, 'confirmed');
      expect(saved.createdByAdmin, isTrue);

      expect(inSnackBar('Turno agendado para Ana Souza.'), findsOneWidget);
      // Sin el diálogo de la clienta en Web.
      expect(find.text('Reserva creada'), findsNothing);
      expect(find.text('VOLVER AL INICIO'), findsNothing);

      final selection = appContainer(tester)
          .read(bookingSelectionProvider)
          .selection;
      expect(selection.start, isNull);
      expect(selection.item, isNull);
      expect(_recipient(tester).recipient, isNull);
      expect(find.byType(BookingForm), findsOneWidget);
      expect(find.text('Para quién'), findsOneWidget);
    });

    testWidgets('$platform: "Para quién" y lo elegido se conservan al ir a '
        'otra pestaña o página y volver (RF-27)', (tester) async {
      await open(tester, isWeb: isWeb);
      await _chooseAll(tester);
      webRouter(tester).go(isWeb ? '/profile' : '/home');
      await settleWeb(tester);
      expect(find.byType(RecipientPicker), findsNothing);

      webRouter(tester).go('/booking');
      await settleWeb(tester);
      expect(_recipient(tester).recipient, AccountRecipient.of(ana));
      expect(find.text('Ana Souza'), findsWidgets);
      final selection = appContainer(tester)
          .read(bookingSelectionProvider)
          .selection;
      expect(selection.start, at(10));
      expect(selection.item, spa);
    });
  }

  testWidgets('con una persona sin cuenta, la guarda sin cuenta y la nombra '
      '(RF-19, RF-20)', (tester) async {
    await open(tester, isWeb: false);
    await _chooseAll(
      tester,
      recipient: const GuestRecipient(
        name: '  Rosa  ',
        phone: '41 99333-0000',
        consent: true,
      ),
    );
    await _book(tester);

    final saved = bookings.created.single;
    expect(saved.clientId, isNull);
    expect(saved.clientName, 'Rosa');
    expect(inSnackBar('Turno agendado para Rosa.'), findsOneWidget);
    expect(_recipient(tester).recipient, isNull);
  });

  group('si no se guarda, lo dice y conserva lo elegido (RF-18)', () {
    testWidgets('la hora se ocupó', (tester) async {
      await open(tester, isWeb: false);
      bookings.adminCheckData = (
        busy: [
          BusySlot(id: 'x', start: fromSalon(at(10)), end: fromSalon(at(11))),
        ],
        active: [],
      );
      await _chooseAll(tester);
      await _book(tester);

      expect(bookings.created, isEmpty);
      expect(
        inSnackBar('Esa hora acaba de ocuparse. Elige otra.'),
        findsOneWidget,
      );
      expect(_recipient(tester).recipient, AccountRecipient.of(ana));
      expect(
        appContainer(tester).read(bookingSelectionProvider).selection.item,
        spa,
      );
    });

    testWidgets('el servicio ya no cabe', (tester) async {
      await open(tester, isWeb: false);
      bookings.adminCheckData = (
        busy: [
          BusySlot(
            id: 'x',
            start: fromSalon(at(10, 30)),
            end: fromSalon(at(11)),
          ),
        ],
        active: [],
      );
      await _chooseAll(tester);
      await _book(tester);

      expect(bookings.created, isEmpty);
      expect(
        inSnackBar(
          'La hora elegida ya no tiene tiempo suficiente para el servicio. '
          'Elige otra.',
        ),
        findsOneWidget,
      );
      expect(_recipient(tester).recipient, AccountRecipient.of(ana));
    });

    testWidgets('error al guardar', (tester) async {
      await open(tester, isWeb: false);
      bookings.saveError = Exception('permission-denied');
      await _chooseAll(tester);
      await _book(tester);

      expect(
        inSnackBar('No pudimos crear la reserva. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining('permission-denied'), findsNothing);
      expect(_recipient(tester).recipient, AccountRecipient.of(ana));
      final selection = appContainer(tester)
          .read(bookingSelectionProvider)
          .selection;
      expect(selection.start, at(10));
      expect(selection.item, spa);
    });

    testWidgets('la persona ya tenía un turno activo (RF-14)', (tester) async {
      await open(tester, isWeb: false);
      // Lo pidió desde otro dispositivo justo antes: la lista en vivo aún
      // no lo tiene, pero el servidor sí.
      bookings.adminCheckData = (busy: [], active: [_anaActive]);
      await _chooseAll(tester);
      await _book(tester);

      expect(bookings.created, isEmpty);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.textContaining('Ya tiene un turno el'),
        ),
        findsOneWidget,
      );
      expect(_recipient(tester).recipient, AccountRecipient.of(ana));
    });

    testWidgets('la clienta se bloqueó: la quita y avisa (RF-15)', (
      tester,
    ) async {
      await open(tester, isWeb: false);
      users.serverUsers = [ana.copyWith(isBlocked: true), testAdmin];
      await _chooseAll(tester);
      await _book(tester);

      expect(bookings.created, isEmpty);
      expect(
        inSnackBar('Esa clienta está bloqueada: ya no se le puede agendar.'),
        findsOneWidget,
      );
      expect(_recipient(tester).recipient, isNull);
    });

    testWidgets('si la bloquean con la reserva abierta, la quita y avisa '
        '(RF-15)', (tester) async {
      await open(tester, isWeb: false);
      await _chooseAll(tester);
      users.emitUsers([ana.copyWith(isBlocked: true), testAdmin]);
      await settleWeb(tester);

      expect(_recipient(tester).recipient, isNull);
      expect(
        inSnackBar('Esa clienta está bloqueada: ya no se le puede agendar.'),
        findsOneWidget,
      );
    });

    testWidgets('una persona sin cuenta con el WhatsApp de una bloqueada: '
        'la conserva y avisa (RF-11)', (tester) async {
      await open(tester, isWeb: false);
      users.serverUsers = [ana, testAdmin];
      await _chooseAll(
        tester,
        recipient: const GuestRecipient(
          name: 'Rosa',
          phone: '41 99333-0000',
          consent: true,
        ),
      );
      users.emitUsers([
        ana,
        testAdmin,
        UserModel(
          uid: 'b',
          email: 'b@example.com',
          displayName: 'Bloqueada',
          phoneNumber: '41 99333-0000',
          role: 'cliente',
          isBlocked: true,
        ),
      ]);
      await settleWeb(tester);
      await _book(tester);

      expect(bookings.created, isEmpty);
      expect(
        inSnackBar(
          'Este WhatsApp es de una clienta bloqueada: no se le puede agendar.',
        ),
        findsOneWidget,
      );
      expect(_recipient(tester).recipient, isA<GuestRecipient>());
    });
  });

  testWidgets('desde el detalle, "Reservar cita" abre la reserva de la admin '
      'con el servicio y sin para quién', (tester) async {
    await open(tester, isWeb: true, location: '/services/service/spa');
    await _tap(
      tester,
      find.descendant(
        of: find.byType(PriceDetailView),
        matching: find.text('RESERVAR CITA'),
      ),
    );

    expect(find.byType(RecipientPicker), findsOneWidget);
    expect(
      appContainer(tester).read(bookingSelectionProvider).selection.item,
      spa,
    );
    expect(_recipient(tester).recipient, isNull);
  });
}

/// Turno activo de Ana, del jueves 12 de 9:00 a 9:45.
final _anaActive = AppointmentModel(
  id: 'de-ana',
  clientId: 'ana',
  clientName: 'Ana Souza',
  clientPhone: '+55 41 99111-0000',
  startTime: fromSalon(DateTime.utc(2026, 11, 12, 9)),
  endTime: fromSalon(DateTime.utc(2026, 11, 12, 9, 45)),
  status: 'waiting_confirmation',
  createdAt: DateTime.utc(2026, 11, 10),
);
