import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/active_appointment_view.dart';
import 'package:shaddai/features/booking/presentation/booking_form.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/booking_edit_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/profile/presentation/profile_view.dart';
import 'package:shaddai/features/services/logic/price_list_view_logic.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

/// La clienta ve el turno que le agendó la admin (spec 007, RF-21) y lo
/// edita como cualquier otro (spec 006; caso límite de la 007). "Ahora" es
/// el martes 10/11/2026 a las 7:00 del salón.
DateTime at(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, 10, hour, minute);

BilingualText text(String es) => BilingualText(es: es, pt: '$es (pt)');

/// s1 (45 min, R$ 30).
final priceList = PriceListModel(
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
);

final booked = BookedServiceModel(
  kind: BookedKind.service,
  id: 's1',
  name: text('Manicura'),
  priceCents: 3000,
  durationMinutes: 45,
);

/// El turno que la admin le agendó: hoy de 9:00 a 9:45, confirmado.
final adminBooked = AppointmentModel(
  id: 'de-la-admin',
  clientId: testClient.uid,
  clientName: testClient.displayName,
  clientPhone: testClient.phoneNumber!,
  startTime: fromSalon(at(9)),
  endTime: fromSalon(at(9, 45)),
  status: 'confirmed',
  createdAt: bookingTestNow,
  createdByAdmin: true,
  booked: booked,
);

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 5; i++) {
    await tester.pump();
  }
}

void main() {
  late FakeBookingRepository bookings;

  setUp(() => bookings = FakeBookingRepository());

  testWidgets('con la reserva abierta, el turno llega y pasa a verse como su '
      'turno activo, sin recargar (RF-21)', (tester) async {
    await pumpApp(
      tester,
      stored: const {'language': 'es'},
      home: const BookingView(),
      overrides: bookingDataOverrides(bookings: bookings, user: testClient),
    );
    await settle(tester);
    expect(find.byType(BookingForm), findsOneWidget);

    bookings.emitMine([adminBooked]);
    await settle(tester);

    expect(find.byType(BookingForm), findsNothing);
    expect(find.byType(ActiveAppointmentView), findsOneWidget);
    expect(find.text('CONFIRMADA'), findsOneWidget);
    expect(find.text('EDITAR TURNO'), findsOneWidget);
  });

  testWidgets('también aparece en su perfil, sin recargar (RF-21)', (
    tester,
  ) async {
    await pumpApp(
      tester,
      stored: const {'language': 'es'},
      home: const ProfileView(),
      overrides: bookingDataOverrides(bookings: bookings, user: testClient),
    );
    await settle(tester);
    expect(find.text('CONFIRMADA'), findsNothing);

    bookings.emitMine([adminBooked]);
    await settle(tester);
    expect(find.text('CONFIRMADA'), findsOneWidget);
  });

  test('lo edita: vuelve a esperar confirmación y sigue marcado como creado '
      'por la admin (spec 006, RF-13; RF-30)', () async {
    bookings = FakeBookingRepository(
      mine: [adminBooked],
      busy: [
        BusySlot(
          id: adminBooked.id,
          start: adminBooked.startTime,
          end: adminBooked.endTime,
        ),
      ],
    );
    final c = ProviderContainer(
      overrides: [
        ...bookingDataOverrides(bookings: bookings, user: testClient),
        currentPriceListProvider.overrideWith(
          (ref) => PriceListReady(priceList),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(bookingSelectionProvider, (_, _) {});
    c.listen(calendarSettingsProvider, (_, _) {});
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    c.read(editTargetProvider.notifier).start(adminBooked);
    bookings.editCheckData = (
      appointment: adminBooked,
      busy: [
        BusySlot(
          id: adminBooked.id,
          start: adminBooked.startTime,
          end: adminBooked.endTime,
        ),
      ],
    );
    final selector = c.read(bookingSelectionProvider.notifier);
    selector.selectSlot(
      c
          .read(freeSlotsOfDayProvider(DateTime.utc(2026, 11, 10)))!
          .firstWhere((s) => s.start == at(10)),
    );

    final result = await c.read(bookingEditSaveProvider).save();

    expect(result.outcome, EditSaveOutcome.ok);
    final edited = bookings.mine.single;
    expect(edited.startTime, fromSalon(at(10)));
    expect(edited.status, 'waiting_confirmation');
    expect(edited.createdByAdmin, isTrue);
  });

  test('la hora de un turno sin cuenta no sale libre para la clienta '
      '(RF-24)', () async {
    // Su turno ocupado no lleva de quién es: igual que cualquier otro.
    bookings = FakeBookingRepository(
      busy: [
        BusySlot(
          id: 'sin-cuenta',
          start: fromSalon(at(10)),
          end: fromSalon(at(10, 45)),
        ),
      ],
    );
    final c = ProviderContainer(
      overrides: bookingDataOverrides(bookings: bookings, user: testClient),
    );
    addTearDown(c.dispose);
    c.listen(busySlotsProvider, (_, _) {});
    c.listen(closuresProvider, (_, _) {});
    c.listen(calendarSettingsProvider, (_, _) {});
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }

    final starts = [
      for (final slot in c.read(
        freeSlotsOfDayProvider(DateTime.utc(2026, 11, 10)),
      )!)
        slot.start,
    ];
    expect(starts, isNot(contains(at(10))));
    expect(starts, contains(at(11)));
  });
}
