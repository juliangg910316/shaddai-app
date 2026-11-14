import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/booking_edit.dart';
import 'package:shaddai/features/booking/logic/free_slots.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/providers/booking_edit_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/services/logic/price_list_view_logic.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';

import '../../helpers/fake_booking.dart';
import '../../helpers/fake_session.dart';

// Horas de pared del salón. "Ahora" es el martes 10/11/2026 a las 7:00
// (bookingTestNow); el calendario por defecto abre de 9:00 a 18:00.
DateTime at(int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, 10, hour, minute);

BilingualText text(String es) => BilingualText(es: es, pt: '$es (pt)');

/// s1 (45 min, R$ 30) con el adicional a1 (R$ 10).
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
        PriceItemModel(
          id: 'a1',
          kind: PriceItemKind.addon,
          name: text('Decoración'),
          priceCents: 1000,
        ),
      ],
    ),
  ],
);

const s1 = BookableRef(BookedKind.service, 's1');

/// Lo reservado en el turno original: s1 con a1, tal como está en la lista.
final booked = BookedServiceModel(
  kind: BookedKind.service,
  id: 's1',
  name: text('Manicura'),
  priceCents: 3000,
  durationMinutes: 45,
  addons: [
    BookedAddonModel(id: 'a1', name: text('Decoración'), priceCents: 1000),
  ],
);

/// El turno de la clienta: hoy de 9:00 a 9:45, confirmado.
AppointmentModel appointment({String status = 'confirmed', DateTime? start}) =>
    AppointmentModel(
      id: 't1',
      clientId: testClient.uid,
      clientName: testClient.displayName,
      clientPhone: testClient.phoneNumber!,
      startTime: fromSalon(start ?? at(9)),
      endTime: fromSalon(start ?? at(9)).add(const Duration(minutes: 45)),
      status: status,
      createdAt: bookingTestNow,
      booked: booked,
    );

BusySlot busy(String id, DateTime start, DateTime end) =>
    BusySlot(id: id, start: fromSalon(start), end: fromSalon(end));

/// El turno ocupado del propio turno.
final own = busy('t1', at(9), at(9, 45));

Future<void> settle() async {
  for (var i = 0; i < 5; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  late FakeBookingRepository bookings;
  late ProviderContainer c;

  /// Abre la edición de [target] (por defecto, el turno de las 9:00).
  Future<void> start({int margin = 0, AppointmentModel? target}) async {
    final defaults = CalendarSettingsModel.defaultSettings();
    c = ProviderContainer(
      overrides: [
        ...bookingDataOverrides(
          bookings: bookings,
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
    await settle();
    c.read(editTargetProvider.notifier).start(target ?? appointment());
  }

  /// Elige [hour] (hoy), s1 y a1, como si la clienta editara.
  void choose(DateTime hour) {
    final selector = c.read(bookingSelectionProvider.notifier);
    // El día ya es hoy (RF-1 de la 005).
    expect(selector.selection.day, DateTime.utc(2026, 11, 10));
    selector.selectSlot(
      freeSlots(
        day: DateTime.utc(2026, 11, 10),
        settings: CalendarSettingsModel.defaultSettings(),
        busy: const [],
        nowSalon: toSalon(bookingTestNow),
      ).firstWhere((s) => s.start == hour),
    );
    selector.selectItem(s1);
    selector.toggleAddon('a1');
  }

  Future<EditSaveResult> save() => c.read(bookingEditSaveProvider).save();

  setUp(() {
    bookings = FakeBookingRepository(mine: [appointment()]);
  });

  test('editTargetProvider: start guarda el turno y end lo quita', () async {
    await start();
    final target = c.read(editTargetProvider)!;
    expect(target.id, 't1');
    expect(target.start, at(9));
    c.read(editTargetProvider.notifier).end();
    expect(c.read(editTargetProvider), isNull);
  });

  group('BookingEditor.save (RF-12 a RF-16, RF-26)', () {
    test('ok: guarda el mismo turno con las horas nuevas y la copia nueva, '
        'devuelve lo que cambió y termina la edición', () async {
      await start();
      bookings.editCheckData = (appointment: appointment(), busy: [own]);
      choose(at(10));

      final result = await save();

      expect(result.outcome, EditSaveOutcome.ok);
      expect(result.changes, {EditField.start, EditField.end});
      final edit = bookings.edited.single;
      expect(edit.id, 't1');
      expect(edit.start, fromSalon(at(10)));
      expect(edit.end, fromSalon(at(10, 45)));
      expect(edit.booked, booked);
      // Como Firestore: el turno vuelve a esperar confirmación y su turno
      // ocupado tiene las horas nuevas (RF-13, RF-26).
      expect(bookings.mine.single.status, 'waiting_confirmation');
      expect(bookings.mine.single.startTime, fromSalon(at(10)));
      expect(c.read(editTargetProvider), isNull);
      expect(bookings.editCheckRequests.single.appointmentId, 't1');
      expect(bookings.editCheckRequests.single.from, fromSalon(at(0)));
    });

    test('ok sin cambios: guarda igual y no devuelve cambios', () async {
      // El turno es el de las 10:00, y se elige lo mismo que tiene. Su
      // propio turno ocupado no cuenta.
      bookings.mine = [appointment(start: at(10))];
      await start(target: appointment(start: at(10)));
      bookings.editCheckData = (
        appointment: appointment(start: at(10)),
        busy: [busy('t1', at(10), at(10, 45))],
      );
      choose(at(10));

      final result = await save();

      expect(result.outcome, EditSaveOutcome.ok);
      expect(result.changes, isEmpty);
      expect(bookings.edited, hasLength(1));
    });

    for (final (label, others, outcome) in [
      (
        'la hora nueva está ocupada',
        [busy('x', at(10), at(11))],
        EditSaveOutcome.slotTaken,
      ),
      (
        'el servicio ya no cabe',
        [busy('x', at(10, 30), at(11))],
        EditSaveOutcome.doesNotFit,
      ),
    ]) {
      test('$label → ${outcome.name}: no guarda, quita la hora y conserva '
          'lo demás', () async {
        await start();
        bookings.editCheckData = (
          appointment: appointment(),
          busy: [own, ...others],
        );
        choose(at(10));

        final result = await save();

        expect(result.outcome, outcome);
        expect(bookings.edited, isEmpty);
        final selection = c.read(bookingSelectionProvider).selection;
        expect(selection.start, isNull);
        expect(selection.item, s1);
        expect(selection.addonIds, {'a1'});
        expect(c.read(editTargetProvider), isNotNull);
      });
    }

    for (final (label, current, margin, outcome) in [
      ('el turno ya no existe', null, 0, EditSaveOutcome.notActive),
      (
        'el turno se canceló',
        appointment(status: 'cancelled'),
        0,
        EditSaveOutcome.notActive,
      ),
      (
        'alguien cambió el turno',
        appointment(status: 'waiting_confirmation'),
        0,
        EditSaveOutcome.changed,
      ),
      (
        'ya está dentro del margen',
        appointment(),
        180,
        EditSaveOutcome.notEditable,
      ),
    ]) {
      test(
        '$label → ${outcome.name}: no guarda y termina la edición',
        () async {
          await start(margin: margin);
          bookings.editCheckData = (appointment: current, busy: [own]);
          choose(at(10));

          final result = await save();

          expect(result.outcome, outcome);
          expect(bookings.edited, isEmpty);
          expect(c.read(editTargetProvider), isNull);
        },
      );
    }

    test('el turno cambia entre la comprobación y el guardado: la '
        'transacción no guarda → changed', () async {
      await start();
      bookings.editCheckData = (appointment: appointment(), busy: [own]);
      bookings.mine = [appointment(status: 'waiting_confirmation')];
      choose(at(10));

      final result = await save();

      expect(result.outcome, EditSaveOutcome.changed);
      expect(bookings.edited, isEmpty);
      expect(c.read(editTargetProvider), isNull);
    });

    for (final (label, prepare) in [
      (
        'la comprobación falla',
        (FakeBookingRepository b) => b.editCheckError = Exception('offline'),
      ),
      (
        'el guardado falla',
        (FakeBookingRepository b) => b.updateError = Exception('denied'),
      ),
      (
        'el guardado tarda demasiado',
        (FakeBookingRepository b) => b.updateError = TimeoutException('lento'),
      ),
    ]) {
      test('$label → failed: la edición sigue igual', () async {
        await start();
        bookings.editCheckData = (appointment: appointment(), busy: [own]);
        prepare(bookings);
        choose(at(10));
        final before = c.read(bookingSelectionProvider).selection;

        final result = await save();

        expect(result.outcome, EditSaveOutcome.failed);
        expect(bookings.edited, isEmpty);
        expect(c.read(bookingSelectionProvider).selection, before);
        expect(c.read(editTargetProvider), isNotNull);
      });
    }

    test('sin turno en edición → failed', () async {
      await start();
      c.read(editTargetProvider.notifier).end();
      choose(at(10));
      expect((await save()).outcome, EditSaveOutcome.failed);
      expect(bookings.editCheckRequests, isEmpty);
    });
  });
}
