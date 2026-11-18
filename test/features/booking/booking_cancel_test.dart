import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/cancel_appointment.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_cancel_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/services/logic/price_list_view_logic.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';

// Horas de pared del salón del martes 10/11/2026. "Ahora" por defecto es
// bookingTestNow (7:00 del salón).
DateTime at(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, 10, hour, minute);

BilingualText text(String es) => BilingualText(es: es, pt: '$es (pt)');

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
          durationMinutes: 60,
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
  durationMinutes: 60,
);

/// El turno de la clienta: hoy de [start] (10:00) a una hora después.
AppointmentModel appointment({
  DateTime? start,
  String status = 'waiting_confirmation',
}) {
  final from = fromSalon(start ?? at(10));
  return AppointmentModel(
    id: 't1',
    clientId: testClient.uid,
    clientName: testClient.displayName,
    clientPhone: testClient.phoneNumber!,
    startTime: from,
    endTime: from.add(const Duration(hours: 1)),
    status: status,
    createdAt: bookingTestNow,
    booked: booked,
  );
}

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeBookingRepository bookings;
  late ProviderContainer c;

  /// Prepara los providers con margen [margin] y "ahora" [nowSalon] (hora de
  /// pared; por defecto, bookingTestNow) o los valores de [nowStream].
  Future<void> start({
    int margin = 60,
    DateTime? nowSalon,
    Stream<DateTime> Function()? nowStream,
  }) async {
    final defaults = CalendarSettingsModel.defaultSettings();
    c = ProviderContainer(
      overrides: [
        ...bookingDataOverrides(
          bookings: bookings,
          now: nowSalon == null ? null : fromSalon(nowSalon),
          nowStream: nowStream,
          settings: CalendarSettingsModel(
            openingHours: defaults.openingHours,
            globalSlotDurationMinutes: defaults.globalSlotDurationMinutes,
            blockedDates: defaults.blockedDates,
            editMarginMinutes: margin,
          ),
        ),
        currentPriceListProvider.overrideWith(
          (ref) => PriceListReady(priceList),
        ),
      ],
    );
    addTearDown(c.dispose);
    c.listen(bookingSelectionProvider, (_, _) {});
    c.listen(calendarSettingsProvider, (_, _) {});
    c.listen(myAppointmentsProvider, (_, _) {});
    await settle();
  }

  Future<CancelOutcome> cancel([AppointmentModel? shown]) =>
      c.read(appointmentCancelProvider).cancel(shown ?? appointment());

  setUp(() {
    bookings = FakeBookingRepository(
      mine: [appointment()],
      busy: [
        BusySlot(id: 't1', start: fromSalon(at(10)), end: fromSalon(at(11))),
      ],
    );
  });

  group('cancelAvailabilityProvider (RF-3, RF-4, RF-7)', () {
    test(
      'pasa de cancelable a cerrado al llegar el margen, sin recargar',
      () async {
        final now = StreamController<DateTime>.broadcast();
        addTearDown(now.close);
        await start(nowStream: () => now.stream);
        final start10 = appointment().startTime;
        final values = <CancelAvailability>[];
        c.listen(
          cancelAvailabilityProvider(start10),
          (_, next) => values.add(next),
          fireImmediately: true,
        );

        now.add(at(8, 59));
        await settle();
        expect(values.last, CancelAvailability.cancellable);

        now.add(at(9));
        await settle();
        expect(values.last, CancelAvailability.closed);
      },
    );

    test('mientras el calendario carga, loading; si falla, error', () async {
      final settings = StreamController<CalendarSettingsModel>.broadcast();
      addTearDown(settings.close);
      c = ProviderContainer(
        overrides: bookingDataOverrides(
          bookings: bookings,
          settingsStream: () => settings.stream,
        ),
      );
      addTearDown(c.dispose);
      final key = cancelAvailabilityProvider(appointment().startTime);
      c.listen(key, (_, _) {});
      await settle();
      expect(c.read(key), CancelAvailability.loading);

      settings.addError(Exception('sin red'));
      await settle();
      expect(c.read(key), CancelAvailability.error);
    });
  });

  group('AppointmentCanceller.cancel (RF-11 a RF-15, RF-17)', () {
    test('ok: lo cancela por la clienta y deja de ser su turno activo '
        '(RF-11, RF-12, RF-13)', () async {
      await start();

      expect(await cancel(), CancelOutcome.ok);
      await settle();

      expect(bookings.cancelled, ['t1']);
      final mine = c.read(myAppointmentsProvider).value!;
      expect(mine.single.status, 'cancelled');
      expect(mine.single.cancelledByClient, isTrue);
      expect(bookings.busy, isEmpty);
    });

    test('si la admin solo lo confirmó, se cancela igual (D-3)', () async {
      bookings.mine = [appointment(status: 'confirmed')];
      await start();
      expect(await cancel(), CancelOutcome.ok);
    });

    test('ya cancelado: notActive, sin cambios (RF-14)', () async {
      bookings.mine = [appointment(status: 'cancelled')];
      await start();
      expect(await cancel(), CancelOutcome.notActive);
      expect(bookings.cancelled, isEmpty);
    });

    test('ya no existe: notActive (RF-14)', () async {
      bookings.mine = [];
      await start();
      expect(await cancel(), CancelOutcome.notActive);
      expect(bookings.cancelled, isEmpty);
    });

    test('la admin lo movió: changed, sin cambios (RF-14)', () async {
      bookings.mine = [appointment(start: at(11))];
      await start();
      expect(await cancel(), CancelOutcome.changed);
      expect(bookings.cancelled, isEmpty);
      expect(bookings.busy, hasLength(1));
    });

    test('dentro del margen: notCancellable, sin cambios (RF-14)', () async {
      await start(nowSalon: at(9, 30));
      expect(await cancel(), CancelOutcome.notCancellable);
      expect(bookings.cancelled, isEmpty);
    });

    test('error al guardar: failed, sin cambios (RF-15)', () async {
      await start();
      bookings.cancelError = Exception('sin red');
      expect(await cancel(), CancelOutcome.failed);
      expect(bookings.mine.single.status, 'waiting_confirmation');
      expect(bookings.busy, hasLength(1));
    });

    test('tiempo agotado: failed (RF-15)', () async {
      await start();
      bookings.cancelError = TimeoutException('lento');
      expect(await cancel(), CancelOutcome.failed);
    });

    test('con la edición de ese turno abierta, la cierra sin el aviso de '
        '"ya no está activo" (RF-17)', () async {
      await start();
      c.read(editTargetProvider.notifier).start(appointment());
      await settle();
      expect(c.read(editTargetProvider)?.id, 't1');

      expect(await cancel(), CancelOutcome.ok);
      await settle();

      expect(c.read(editTargetProvider), isNull);
      final notices = c.read(bookingSelectionProvider).notices;
      expect(
        notices.where((n) => n.kind == BookingNoticeKind.editNotActive),
        isEmpty,
      );
      expect(c.read(bookingSelectionProvider).selection.item, isNull);
    });

    test(
      'sin el calendario cargado: failed, sin llamar al repositorio',
      () async {
        final settings = StreamController<CalendarSettingsModel>.broadcast();
        addTearDown(settings.close);
        c = ProviderContainer(
          overrides: bookingDataOverrides(
            bookings: bookings,
            settingsStream: () => settings.stream,
          ),
        );
        addTearDown(c.dispose);
        c.listen(calendarSettingsProvider, (_, _) {});
        await settle();
        expect(await cancel(), CancelOutcome.failed);
        expect(bookings.cancelled, isEmpty);
      },
    );
  });
}
