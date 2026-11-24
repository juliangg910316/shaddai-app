import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/appointment_model.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/busy_slot_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/data/repositories/agenda_functions.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/booking_edit.dart';
import 'package:shaddai/features/booking/logic/salon_time.dart';
import 'package:shaddai/features/booking/presentation/active_appointment_view.dart';
import 'package:shaddai/features/booking/presentation/booking_form.dart';
import 'package:shaddai/features/booking/presentation/booking_view.dart';
import 'package:shaddai/features/booking/providers/agenda_functions_provider.dart';
import 'package:shaddai/features/booking/providers/booking_edit_provider.dart';
import 'package:shaddai/features/booking/providers/booking_provider.dart';
import 'package:shaddai/features/services/logic/price_list_view_logic.dart';
import 'package:shaddai/features/services/providers/price_list_provider.dart';

import '../../helpers/fake_agenda.dart';
import '../../helpers/fake_booking.dart';
import '../../helpers/fake_price_list.dart';
import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

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
        agendaFunctionsProvider.overrideWith(FakeAgendaFunctions.linked),
      ],
    );
    addTearDown(c.dispose);
    c.listen(bookingSelectionProvider, (_, _) {});
    c.listen(calendarSettingsProvider, (_, _) {});
    await settle();
    c.read(editTargetProvider.notifier).start(target ?? appointment());
  }

  /// Elige [hour] (hoy). El servicio (s1) y el adicional (a1) ya vienen del
  /// turno al abrir la edición.
  void choose(DateTime hour) {
    final selector = c.read(bookingSelectionProvider.notifier);
    expect(selector.selection.item, s1);
    expect(selector.selection.addonIds, {'a1'});
    if (selector.selection.start == hour) return;
    selector.selectSlot(
      c
          .read(freeSlotsOfDayProvider(DateTime.utc(2026, 11, 10)))!
          .firstWhere((s) => s.start == hour),
    );
  }

  Future<EditSaveResult> save() => c.read(bookingEditSaveProvider).save();
  FakeAgendaFunctions agenda() =>
      c.read(agendaFunctionsProvider) as FakeAgendaFunctions;

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

    test('tras la comprobación, guarda llamando a la función con lo que tenía '
        'el turno (spec 012)', () async {
      await start();
      bookings.editCheckData = (appointment: appointment(), busy: [own]);
      choose(at(10));
      await save();
      final call = agenda().edits.single;
      expect(call.id, 't1');
      expect(call.start, fromSalon(at(10)));
      expect(call.booked, booked);
      expect(call.expected!.startTime, appointment().startTime);
      expect(call.expected!.booked, booked);
      expect(call.recipient, isNull);
    });

    // Lo que responde el servidor (spec 012, plan § 6): si quita la hora y
    // si termina la edición.
    const rejections = <AgendaRejection, (EditSaveOutcome, bool, bool)>{
      AgendaRejection.slotTaken: (EditSaveOutcome.slotTaken, true, false),
      AgendaRejection.closed: (EditSaveOutcome.slotTaken, true, false),
      AgendaRejection.outsideHours: (EditSaveOutcome.slotTaken, true, false),
      AgendaRejection.outsideWindow: (EditSaveOutcome.slotTaken, true, false),
      AgendaRejection.past: (EditSaveOutcome.slotTaken, true, false),
      AgendaRejection.doesNotFit: (EditSaveOutcome.doesNotFit, true, false),
      AgendaRejection.itemUnavailable: (
        EditSaveOutcome.itemUnavailable,
        false,
        false,
      ),
      AgendaRejection.itemChanged: (EditSaveOutcome.itemChanged, false, false),
      AgendaRejection.notActive: (EditSaveOutcome.notActive, false, true),
      AgendaRejection.changed: (EditSaveOutcome.changed, false, true),
      AgendaRejection.notEditable: (EditSaveOutcome.notEditable, false, true),
      AgendaRejection.blocked: (EditSaveOutcome.failed, false, false),
      AgendaRejection.invalid: (EditSaveOutcome.failed, false, false),
      AgendaRejection.failed: (EditSaveOutcome.failed, false, false),
    };
    rejections.forEach((rejection, expected) {
      final (outcome, dropsSlot, ends) = expected;
      test(
        'el servidor responde ${rejection.name} → ${outcome.name}',
        () async {
          await start();
          bookings.editCheckData = (appointment: appointment(), busy: [own]);
          choose(at(10));
          agenda().rejection = rejection;

          final result = await save();

          expect(result.outcome, outcome);
          expect(bookings.edited, isEmpty);
          final selector = c.read(bookingSelectionProvider.notifier);
          if (ends) {
            expect(c.read(editTargetProvider), isNull);
          } else {
            expect(c.read(editTargetProvider)?.id, 't1');
            expect(selector.selection.start, dropsSlot ? isNull : at(10));
            expect(selector.selection.item, s1);
          }
        },
      );
    });

    test('sin turno en edición → failed', () async {
      await start();
      c.read(editTargetProvider.notifier).end();
      expect((await save()).outcome, EditSaveOutcome.failed);
      expect(bookings.editCheckRequests, isEmpty);
    });
  });

  group('Guardar desde la vista (RF-12 a RF-17, RF-26)', () {
    Finder inDialog(Finder finder) =>
        find.descendant(of: find.byType(AlertDialog), matching: finder);
    Finder inSnackBar(String message) => find.descendant(
      of: find.byType(SnackBar),
      matching: find.text(message),
    );

    Future<void> pumpFrames(WidgetTester tester) async {
      for (var i = 0; i < 5; i++) {
        await tester.pump();
      }
    }

    /// Un diálogo tarda en abrirse o cerrarse.
    Future<void> animate(WidgetTester tester) async {
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await pumpFrames(tester);
    }

    Future<void> tap(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.tap(finder);
      await pumpFrames(tester);
    }

    /// Abre la edición del turno de las 9:00 (confirmado), elige [hour] y
    /// confirma los cambios. [beforeSave] prepara el servidor.
    Future<void> editAndSave(
      WidgetTester tester, {
      String? hour = '10:00',
      String language = 'es',
      Stream<CalendarSettingsModel> Function()? settingsStream,
      void Function()? beforeSave,
    }) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(800, 2400);
      addTearDown(tester.view.reset);
      bookings = FakeBookingRepository(mine: [appointment()], busy: [own]);
      await pumpApp(
        tester,
        stored: {'language': language},
        home: const BookingView(),
        priceListRepository: FakePriceListRepository(stored: priceList),
        overrides: [
          ...bookingDataOverrides(
            bookings: bookings,
            settingsStream: settingsStream,
          ),
        ],
      );
      await pumpFrames(tester);
      final pt = language == 'pt';
      await tap(tester, find.text(pt ? 'EDITAR HORÁRIO' : 'EDITAR TURNO'));
      if (hour != null) await tap(tester, find.text(hour));
      beforeSave?.call();
      await tap(
        tester,
        find.text(pt ? 'SALVAR ALTERAÇÕES' : 'GUARDAR CAMBIOS'),
      );
      await animate(tester);
      await tester.tap(inDialog(find.byType(ElevatedButton)));
      await animate(tester);
    }

    testWidgets('guarda y abre "Cambios guardados" con lo que cambió; al '
        'cerrarlo, el turno espera confirmación (RF-13, RF-17, RF-26)', (
      tester,
    ) async {
      await editAndSave(tester);

      expect(bookings.edited.single.start, fromSalon(at(10)));
      // Las demás ven la hora nueva ocupada y la antigua libre (RF-26).
      expect(bookings.busy.single.start, fromSalon(at(10)));
      expect(bookings.busy.single.end, fromSalon(at(10, 45)));

      expect(inDialog(find.text('Cambios guardados')), findsOneWidget);
      expect(inDialog(find.text('Inicio: 9:00 → 10:00')), findsOneWidget);
      expect(inDialog(find.text('Fin: 9:45 → 10:45')), findsOneWidget);
      expect(inDialog(find.textContaining('Servicio')), findsNothing);
      expect(
        inDialog(
          find.text('Tu turno vuelve a esperar la confirmación de Beidis.'),
        ),
        findsOneWidget,
      );

      await tester.tap(inDialog(find.byType(ElevatedButton)));
      await animate(tester);
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(ActiveAppointmentView), findsOneWidget);
      expect(find.text('EN REVISIÓN'), findsOneWidget);
      expect(find.text('10:00 – 10:45'), findsOneWidget);
    });

    testWidgets('sin cambios: "No cambiaste nada…"', (tester) async {
      await editAndSave(tester, hour: null);

      expect(bookings.edited, hasLength(1));
      expect(inDialog(find.text('Cambios guardados')), findsOneWidget);
      expect(
        inDialog(find.text('No cambiaste nada: el turno sigue igual.')),
        findsOneWidget,
      );
      expect(inDialog(find.textContaining('→')), findsNothing);
    });

    for (final (rejection, language, message) in [
      (
        AgendaRejection.itemChanged,
        'es',
        'El servicio cambió de nombre, precio o duración. Revisa el resumen '
            'y vuelve a confirmar.',
      ),
      (
        AgendaRejection.itemChanged,
        'pt',
        'O serviço mudou de nome, preço ou duração. Revise o resumo e '
            'confirme novamente.',
      ),
      (
        AgendaRejection.itemUnavailable,
        'es',
        'El servicio elegido ya no está disponible.',
      ),
      (
        AgendaRejection.itemUnavailable,
        'pt',
        'O serviço escolhido não está mais disponível.',
      ),
    ]) {
      testWidgets('el servidor responde ${rejection.name} ($language): avisa '
          'y la edición sigue con lo elegido (spec 012)', (tester) async {
        await editAndSave(
          tester,
          language: language,
          beforeSave: () => (appContainer(tester).read(
            agendaFunctionsProvider,
          ) as FakeAgendaFunctions).rejection = rejection,
        );

        expect(bookings.edited, isEmpty);
        expect(inSnackBar(message), findsOneWidget);
        final container = appContainer(tester);
        expect(container.read(editTargetProvider)?.id, 't1');
        expect(
          container.read(bookingSelectionProvider).selection.start,
          at(10),
        );
      });
    }

    testWidgets('en portugués', (tester) async {
      await editAndSave(tester, language: 'pt');

      expect(inDialog(find.text('Alterações salvas')), findsOneWidget);
      expect(inDialog(find.text('Início: 09:00 → 10:00')), findsOneWidget);
      expect(
        inDialog(
          find.text('Seu horário volta a aguardar a confirmação de Beidis.'),
        ),
        findsOneWidget,
      );
    });

    for (final (label, others, message) in [
      (
        'la hora ya está ocupada',
        [busy('x', at(10), at(11))],
        'Esa hora acaba de ocuparse. Elige otra.',
      ),
      (
        'el servicio ya no cabe',
        [busy('x', at(10, 30), at(11))],
        'La hora elegida ya no tiene tiempo suficiente para el servicio. '
            'Elige otra.',
      ),
    ]) {
      testWidgets('$label: el aviso de la 005 y la edición sigue sin la hora '
          '(RF-14)', (tester) async {
        await editAndSave(
          tester,
          beforeSave: () => bookings.editCheckData = (
            appointment: appointment(),
            busy: [own, ...others],
          ),
        );

        expect(inSnackBar(message), findsOneWidget);
        expect(find.byType(BookingForm), findsOneWidget);
        expect(
          appContainer(tester).read(bookingSelectionProvider).selection.start,
          isNull,
        );
        expect(bookings.edited, isEmpty);
      });
    }

    for (final (label, current, message) in [
      (
        'ya no está activo',
        null,
        'Tu turno ya no está activo: se canceló o terminó.',
      ),
      (
        'alguien lo cambió',
        appointment(status: 'waiting_confirmation'),
        'Tu turno cambió mientras lo editabas. Revisa cómo está ahora.',
      ),
    ]) {
      testWidgets('$label: su texto y vuelve al turno (RF-15)', (tester) async {
        await editAndSave(
          tester,
          beforeSave: () =>
              bookings.editCheckData = (appointment: current, busy: [own]),
        );

        expect(inSnackBar(message), findsOneWidget);
        expect(find.byType(ActiveAppointmentView), findsOneWidget);
        expect(bookings.edited, isEmpty);
      });
    }

    testWidgets('ya no es editable: su texto y vuelve al turno (RF-15)', (
      tester,
    ) async {
      final calendar = StreamController<CalendarSettingsModel>.broadcast();
      addTearDown(calendar.close);
      final defaults = CalendarSettingsModel.defaultSettings();
      await editAndSave(
        tester,
        settingsStream: () async* {
          yield defaults;
          yield* calendar.stream;
        },
        // La admin pone un margen de 3 h mientras edita.
        beforeSave: () => calendar.add(
          CalendarSettingsModel(
            openingHours: defaults.openingHours,
            globalSlotDurationMinutes: defaults.globalSlotDurationMinutes,
            blockedDates: defaults.blockedDates,
            editMarginMinutes: 180,
          ),
        ),
      );

      expect(
        inSnackBar(
          'Ya no se puede cambiar el turno: falta poco para que empiece.',
        ),
        findsOneWidget,
      );
      expect(find.byType(ActiveAppointmentView), findsOneWidget);
      expect(bookings.edited, isEmpty);
    });

    testWidgets('error: aviso sin detalles y la edición sigue igual (RF-16)', (
      tester,
    ) async {
      await editAndSave(
        tester,
        beforeSave: () => bookings.updateError = Exception('permission-denied'),
      );

      expect(
        inSnackBar('No pudimos guardar los cambios. Inténtalo de nuevo.'),
        findsOneWidget,
      );
      expect(find.textContaining('permission-denied'), findsNothing);
      expect(find.byType(BookingForm), findsOneWidget);
      expect(
        appContainer(tester).read(bookingSelectionProvider).selection.start,
        at(10),
      );
      expect(appContainer(tester).read(editTargetProvider), isNotNull);
    });
  });
}
