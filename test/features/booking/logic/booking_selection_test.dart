import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
import 'package:shaddai/features/booking/logic/booking_edit.dart';
import 'package:shaddai/features/booking/logic/booking_selection.dart';
import 'package:shaddai/features/booking/logic/free_slots.dart';

// Horas de pared del salón. 2026-11-10 es martes.
DateTime at(int day, int hour, [int minute = 0]) =>
    DateTime.utc(2026, 11, day, hour, minute);
DateTime dayOf(int day) => DateTime.utc(2026, 11, day);

/// Martes a sábado de 8:00 a 12:00; domingo y lunes cerrados.
CalendarSettingsModel settings({List<String> blockedDates = const []}) {
  DaySchedule open() =>
      DaySchedule(open: '08:00', close: '12:00', isClosed: false);
  DaySchedule closed() =>
      DaySchedule(open: '08:00', close: '12:00', isClosed: true);
  return CalendarSettingsModel(
    openingHours: {
      'monday': closed(),
      'tuesday': open(),
      'wednesday': open(),
      'thursday': open(),
      'friday': open(),
      'saturday': open(),
      'sunday': closed(),
    },
    globalSlotDurationMinutes: 60,
    blockedDates: blockedDates,
  );
}

BilingualText text(String es) => BilingualText(es: es, pt: es);

PriceItemModel service(String id, int duration, {bool visible = true}) =>
    PriceItemModel(
      id: id,
      kind: PriceItemKind.service,
      name: text(id),
      priceCents: 3000,
      durationMinutes: duration,
      visible: visible,
    );

PriceItemModel addon(String id, {bool visible = true}) => PriceItemModel(
  id: id,
  kind: PriceItemKind.addon,
  name: text(id),
  priceCents: 1000,
  visible: visible,
);

/// s1 (45 min) con los adicionales a1 y a2; s2 (2 h); combo c1 (90 min).
PriceListModel priceList({
  bool s1Visible = true,
  bool a2Visible = true,
  int s1Duration = 45,
}) => PriceListModel(
  categories: [
    PriceCategoryModel(
      id: 'manos',
      name: text('Manos'),
      items: [
        service('s1', s1Duration, visible: s1Visible),
        addon('a1'),
        addon('a2', visible: a2Visible),
        service('s2', 120),
      ],
    ),
  ],
  combos: [
    ComboModel(
      id: 'c1',
      name: text('c1'),
      priceCents: 7000,
      durationMinutes: 90,
    ),
  ],
);

const s1 = BookableRef(BookedKind.service, 's1');
const s2 = BookableRef(BookedKind.service, 's2');
const c1 = BookableRef(BookedKind.combo, 'c1');

/// "Ahora": martes 10 a las 7:00, antes de abrir.
final now = at(10, 7);

BookingContext context({
  PriceListModel? list,
  bool catalogKnown = true,
  CalendarSettingsModel? calendar,
  List<BusyRange> busy = const [],
  bool scheduleKnown = true,
  DateTime? nowSalon,
  EditOriginal? original,
}) => BookingContext(
  catalog: catalogKnown ? bookableCatalog(list ?? priceList()) : null,
  settings: scheduleKnown ? (calendar ?? settings()) : null,
  busy: scheduleKnown ? busy : null,
  nowSalon: nowSalon ?? now,
  original: original,
);

BusyRange busy(DateTime start, DateTime end) => (start: start, end: end);

/// La hora libre de [start] en el contexto [ctx], o una inventada si no hay.
FreeSlot slotAt(BookingContext ctx, DateTime start) => ctx
    .freeSlotsOf(start)
    .firstWhere(
      (slot) => slot.start == start,
      orElse: () => FreeSlot(start: start, coverageMinutes: 0),
    );

void main() {
  final tuesday = dayOf(10);

  group('selectDay (RF-8)', () {
    test('quita la hora y conserva lo reservado', () {
      final selection = BookingSelection(
        day: tuesday,
        start: at(10, 9),
        item: s1,
        addonIds: const {'a1'},
      );
      final next = selectDay(selection, dayOf(11));
      expect(next.day, dayOf(11));
      expect(next.start, isNull);
      expect(next.item, s1);
      expect(next.addonIds, {'a1'});
    });

    test('guarda solo el día, sin la hora', () {
      expect(selectDay(BookingSelection.empty, at(11, 15)).day, dayOf(11));
    });
  });

  group('selectSlot (RF-15)', () {
    test('sin servicio elegido, elige la hora', () {
      final ctx = context();
      final result = selectSlot(
        BookingSelection(day: tuesday),
        ctx,
        slotAt(ctx, at(10, 11)),
      );
      expect(result.selection.start, at(10, 11));
      expect(result.notices, isEmpty);
    });

    test('con un servicio que cabe, la elige', () {
      final ctx = context();
      final result = selectSlot(
        BookingSelection(day: tuesday, item: s1),
        ctx,
        slotAt(ctx, at(10, 11)), // 60 min hasta el cierre
      );
      expect(result.selection.start, at(10, 11));
      expect(result.notices, isEmpty);
    });

    test('tocar la hora elegida la quita y conserva el día, el servicio y '
        'los adicionales (RF-59)', () {
      final ctx = context();
      final result = selectSlot(
        BookingSelection(
          day: tuesday,
          start: at(10, 11),
          item: s1,
          addonIds: const {'a1'},
        ),
        ctx,
        slotAt(ctx, at(10, 11)),
      );
      expect(
        result.selection,
        BookingSelection(day: tuesday, item: s1, addonIds: const {'a1'}),
      );
      expect(result.notices, isEmpty);
    });

    test('con un servicio que no cabe, la rechaza y avisa', () {
      final ctx = context();
      final selection = BookingSelection(day: tuesday, item: s2);
      final result = selectSlot(selection, ctx, slotAt(ctx, at(10, 11)));
      expect(result.selection, selection);
      expect(result.notices, [
        const BookingNotice(BookingNoticeKind.slotTooShortFor, minutes: 120),
      ]);
    });
  });

  group('selectItem (RF-13, RF-20)', () {
    test('sin hora elegida, elige cualquier servicio (RF-14)', () {
      final result = selectItem(BookingSelection(day: tuesday), context(), s2);
      expect(result.selection.item, s2);
      expect(result.notices, isEmpty);
    });

    test('rechaza un servicio que no cabe en la hora, con su duración', () {
      final selection = BookingSelection(
        day: tuesday,
        start: at(10, 11),
        item: s1,
        addonIds: const {'a1'},
      );
      final result = selectItem(selection, context(), s2);
      expect(result.selection, selection);
      expect(result.notices, [
        const BookingNotice(BookingNoticeKind.needsLongerSlot, minutes: 120),
      ]);
    });

    test('al cambiar de servicio desmarca los adicionales', () {
      final result = selectItem(
        BookingSelection(day: tuesday, item: s1, addonIds: const {'a1'}),
        context(),
        c1,
      );
      expect(result.selection.item, c1);
      expect(result.selection.addonIds, isEmpty);
    });

    test('tocar el servicio elegido lo quita con sus adicionales y conserva '
        'el día y la hora (RF-59)', () {
      final result = selectItem(
        BookingSelection(
          day: tuesday,
          start: at(10, 11),
          item: s1,
          addonIds: const {'a1'},
        ),
        context(),
        s1,
      );
      expect(
        result.selection,
        BookingSelection(day: tuesday, start: at(10, 11)),
      );
      expect(result.notices, isEmpty);
    });
  });

  group('toggleAddon (RF-18)', () {
    test('marca y desmarca un adicional de la categoría', () {
      final ctx = context();
      final selection = BookingSelection(day: tuesday, item: s1);
      final marked = toggleAddon(selection, ctx, 'a1');
      expect(marked.addonIds, {'a1'});
      expect(toggleAddon(marked, ctx, 'a1').addonIds, isEmpty);
    });

    test('no marca un adicional que no está disponible', () {
      final ctx = context(list: priceList(a2Visible: false));
      expect(
        toggleAddon(BookingSelection(item: s1), ctx, 'a2').addonIds,
        isEmpty,
      );
      expect(
        toggleAddon(BookingSelection(item: c1), ctx, 'a1').addonIds,
        isEmpty,
      );
    });
  });

  group('requestItem (RF-40)', () {
    test('sustituye el servicio, desmarca los adicionales y conserva la '
        'fecha y la hora si cabe', () {
      final result = requestItem(
        BookingSelection(
          day: tuesday,
          start: at(10, 9),
          item: s1,
          addonIds: const {'a1'},
        ),
        context(),
        c1,
      );
      expect(result.selection.day, tuesday);
      expect(result.selection.start, at(10, 9));
      expect(result.selection.item, c1);
      expect(result.selection.addonIds, isEmpty);
      expect(result.notices, isEmpty);
    });

    test('quita la hora si el servicio no cabe, y avisa (D-10)', () {
      final result = requestItem(
        BookingSelection(day: tuesday, start: at(10, 11)),
        context(),
        s2,
      );
      expect(result.selection.item, s2);
      expect(result.selection.start, isNull);
      expect(result.notices, [
        const BookingNotice(BookingNoticeKind.slotNoLongerFits),
      ]);
    });

    test('con la lista de precios cargando, guarda la petición sin más', () {
      final result = requestItem(
        BookingSelection(day: tuesday, start: at(10, 11)),
        context(catalogKnown: false),
        s2,
      );
      expect(result.selection.item, s2);
      expect(result.selection.start, at(10, 11));
      expect(result.notices, isEmpty);
    });
  });

  group('reconcile', () {
    final cases =
        <
          String,
          ({
            BookingSelection selection,
            BookingContext ctx,
            BookingSelection expected,
            List<BookingNotice> notices,
          })
        >{
          'sin cambios, nada que avisar': (
            selection: BookingSelection(
              day: tuesday,
              start: at(10, 9),
              item: s1,
              addonIds: const {'a1'},
            ),
            ctx: context(),
            expected: BookingSelection(
              day: tuesday,
              start: at(10, 9),
              item: s1,
              addonIds: const {'a1'},
            ),
            notices: const [],
          ),
          'sin día, elige el de RF-1 sin avisar': (
            selection: BookingSelection.empty,
            ctx: context(),
            expected: BookingSelection(day: tuesday),
            notices: const [],
          ),
          'sin día y hoy sin horas libres: mañana (RF-1)': (
            selection: BookingSelection.empty,
            ctx: context(nowSalon: at(10, 11, 30)),
            expected: BookingSelection(day: dayOf(11)),
            notices: const [],
          ),
          'una hora que pasó se quita (RF-9)': (
            selection: BookingSelection(day: tuesday, start: at(10, 9)),
            ctx: context(nowSalon: at(10, 9)),
            expected: BookingSelection(day: tuesday),
            notices: const [BookingNotice(BookingNoticeKind.slotGone)],
          ),
          'una hora que otro turno ocupa se quita (RF-9)': (
            selection: BookingSelection(day: tuesday, start: at(10, 9)),
            ctx: context(busy: [busy(at(10, 8, 30), at(10, 9, 30))]),
            expected: BookingSelection(day: tuesday),
            notices: const [BookingNotice(BookingNoticeKind.slotGone)],
          ),
          'una hora en la que el servicio ya no cabe se quita (RF-16)': (
            selection: BookingSelection(
              day: tuesday,
              start: at(10, 9),
              item: s1,
            ),
            ctx: context(busy: [busy(at(10, 9, 30), at(10, 10))]),
            expected: BookingSelection(day: tuesday, item: s1),
            notices: const [BookingNotice(BookingNoticeKind.slotNoLongerFits)],
          ),
          'el servicio pasa a durar más y ya no cabe (RF-16)': (
            selection: BookingSelection(
              day: tuesday,
              start: at(10, 11),
              item: s1,
            ),
            ctx: context(list: priceList(s1Duration: 90)),
            expected: BookingSelection(day: tuesday, item: s1),
            notices: const [BookingNotice(BookingNoticeKind.slotNoLongerFits)],
          ),
          'un servicio que se oculta se quita con sus adicionales (RF-17)': (
            selection: BookingSelection(
              day: tuesday,
              start: at(10, 9),
              item: s1,
              addonIds: const {'a1'},
            ),
            ctx: context(list: priceList(s1Visible: false)),
            expected: BookingSelection(day: tuesday, start: at(10, 9)),
            notices: const [BookingNotice(BookingNoticeKind.itemUnavailable)],
          ),
          'un adicional que se oculta se desmarca sin avisar (RF-21)': (
            selection: BookingSelection(
              day: tuesday,
              item: s1,
              addonIds: const {'a1', 'a2'},
            ),
            ctx: context(list: priceList(a2Visible: false)),
            expected: BookingSelection(
              day: tuesday,
              item: s1,
              addonIds: const {'a1'},
            ),
            notices: const [],
          ),
          'la fecha elegida se bloquea: pasa a la de RF-1 y avisa': (
            selection: BookingSelection(
              day: dayOf(12),
              start: at(12, 9),
              item: s1,
            ),
            ctx: context(calendar: settings(blockedDates: ['2026-11-12'])),
            expected: BookingSelection(day: tuesday, item: s1),
            notices: const [BookingNotice(BookingNoticeKind.dateMoved)],
          ),
          'a medianoche, ayer queda fuera de la ventana': (
            selection: BookingSelection(day: dayOf(10), item: s1),
            ctx: context(nowSalon: at(11, 0, 1)),
            expected: BookingSelection(day: dayOf(11), item: s1),
            notices: const [BookingNotice(BookingNoticeKind.dateMoved)],
          ),
          'con la lista de precios cargando, no toca lo reservado': (
            selection: BookingSelection(
              day: tuesday,
              start: at(10, 11),
              item: s2,
              addonIds: const {'x'},
            ),
            ctx: context(catalogKnown: false),
            expected: BookingSelection(
              day: tuesday,
              start: at(10, 11),
              item: s2,
              addonIds: const {'x'},
            ),
            notices: const [],
          ),
          'con el calendario cargando, no toca la fecha ni la hora': (
            selection: BookingSelection(
              day: dayOf(12),
              start: at(12, 9),
              item: s1,
            ),
            ctx: context(scheduleKnown: false),
            expected: BookingSelection(
              day: dayOf(12),
              start: at(12, 9),
              item: s1,
            ),
            notices: const [],
          ),
          'ningún día se puede elegir: sin día ni hora (RF-2)': (
            selection: BookingSelection(day: tuesday, start: at(10, 9)),
            ctx: context(
              calendar: CalendarSettingsModel(
                openingHours: const {},
                globalSlotDurationMinutes: 60,
                blockedDates: const [],
              ),
            ),
            expected: BookingSelection.empty,
            notices: const [BookingNotice(BookingNoticeKind.dateMoved)],
          ),
        };

    cases.forEach((name, c) {
      test(name, () {
        final result = reconcile(c.selection, c.ctx);
        expect(result.selection, c.expected);
        expect(result.notices, c.notices);
      });
    });
  });

  group('missingParts (RF-24)', () {
    test('sin nada elegido faltan la hora y el servicio', () {
      expect(missingParts(BookingSelection(day: tuesday)), {
        BookingPart.slot,
        BookingPart.item,
      });
    });

    test('solo con la hora falta el servicio', () {
      expect(missingParts(BookingSelection(day: tuesday, start: at(10, 9))), {
        BookingPart.item,
      });
    });

    test('con todo elegido no falta nada', () {
      expect(
        missingParts(
          BookingSelection(day: tuesday, start: at(10, 9), item: s1),
        ),
        isEmpty,
      );
    });
  });

  test('BookingSelection se compara por valor', () {
    expect(
      BookingSelection(day: tuesday, item: s1, addonIds: const {'a1'}),
      BookingSelection(day: tuesday, item: s1, addonIds: const {'a1'}),
    );
    expect(
      BookingSelection(day: tuesday),
      isNot(BookingSelection(day: dayOf(11))),
    );
  });

  group('edición (spec 006)', () {
    BookedAddonModel bookedAddon(String id) =>
        BookedAddonModel(id: id, name: text(id), priceCents: 1000);

    /// El turno original: s1 (45 min) de 9:00 a 9:45 del día [day], con los
    /// adicionales [addons].
    EditOriginal original({
      int day = 10,
      int hour = 9,
      int minute = 0,
      List<String> addons = const ['a1'],
    }) => EditOriginal(
      id: 't1',
      start: at(day, hour, minute),
      end: at(day, hour, minute).add(const Duration(minutes: 45)),
      status: 'confirmed',
      booked: BookedServiceModel(
        kind: BookedKind.service,
        id: 's1',
        name: text('s1'),
        priceCents: 3000,
        durationMinutes: 45,
        addons: [for (final id in addons) bookedAddon(id)],
      ),
    );

    group('selectionOf (RF-4 a RF-6)', () {
      test('con el catálogo listo: el día, la hora, el servicio y los '
          'adicionales del turno', () {
        final o = original();
        final update = selectionOf(o, context(original: o));
        expect(
          update.selection,
          BookingSelection(
            day: tuesday,
            start: at(10, 9),
            item: s1,
            addonIds: const {'a1'},
          ),
        );
        expect(update.notices, isEmpty);
      });

      test('servicio no disponible: sin servicio ni adicionales, y avisa', () {
        final o = original();
        final update = selectionOf(
          o,
          context(list: priceList(s1Visible: false), original: o),
        );
        expect(update.selection.item, isNull);
        expect(update.selection.addonIds, isEmpty);
        expect(update.selection.start, at(10, 9));
        expect(update.notices, [
          const BookingNotice(BookingNoticeKind.itemUnavailable),
        ]);
      });

      test('adicional no disponible: sin él, y avisa', () {
        final o = original(addons: ['a1', 'a2']);
        final update = selectionOf(
          o,
          context(list: priceList(a2Visible: false), original: o),
        );
        expect(update.selection.addonIds, {'a1'});
        expect(update.notices, [
          const BookingNotice(BookingNoticeKind.editAddonsUnavailable),
        ]);
      });

      test('con el catálogo cargando lo deja todo; reconcile comprueba al '
          'llegar', () {
        final o = original(addons: ['a1', 'a2']);
        final loading = selectionOf(
          o,
          context(catalogKnown: false, original: o),
        );
        expect(loading.selection.addonIds, {'a1', 'a2'});
        expect(loading.notices, isEmpty);

        final arrived = reconcile(
          loading.selection,
          context(list: priceList(a2Visible: false), original: o),
        );
        expect(arrived.selection.addonIds, {'a1'});
        expect(arrived.notices, [
          const BookingNotice(BookingNoticeKind.editAddonsUnavailable),
        ]);
      });

      test('el día original cerrado (lunes) y su hora se conservan (RF-5)', () {
        final o = original(day: 16);
        final update = selectionOf(o, context(original: o));
        expect(update.selection.day, dayOf(16));
        expect(update.selection.start, at(16, 9));
        expect(update.notices, isEmpty);
      });
    });

    group('reconcile con el turno original (RF-7 a RF-9)', () {
      test('no salta del día original cerrado', () {
        final o = original(day: 16);
        final selection = BookingSelection(
          day: dayOf(16),
          start: at(16, 9),
          item: s1,
        );
        final update = reconcile(selection, context(original: o));
        expect(update.selection, selection);
        expect(update.notices, isEmpty);
      });

      test('mantiene su hora fuera de la rejilla', () {
        final o = original(minute: 15);
        final selection = BookingSelection(
          day: tuesday,
          start: at(10, 9, 15),
          item: s1,
        );
        expect(reconcile(selection, context(original: o)).selection, selection);
      });

      test('su hora no sale ocupada sin el propio turno, y las demás horas '
          'respetan a las demás', () {
        final o = original();
        final ctx = context(original: o, busy: [busy(at(10, 11), at(10, 12))]);
        final starts = ctx.freeSlotsOf(tuesday).map((s) => s.start);
        expect(starts, contains(at(10, 9)));
        expect(starts, isNot(contains(at(10, 11))));
      });

      test('otro día cerrado: se aplican las reglas de la 005', () {
        final o = original();
        final update = reconcile(
          BookingSelection(day: dayOf(15), item: s1),
          context(original: o),
        );
        expect(update.selection.day, isNot(dayOf(15)));
        expect(update.notices, [
          const BookingNotice(BookingNoticeKind.dateMoved),
        ]);
      });

      test('un adicional añadido en la edición que deja de estar disponible '
          'se quita sin avisar, como en la 005', () {
        final o = original(addons: const []);
        final update = reconcile(
          BookingSelection(
            day: tuesday,
            start: at(10, 9),
            item: s1,
            addonIds: const {'a2'},
          ),
          context(list: priceList(a2Visible: false), original: o),
        );
        expect(update.selection.addonIds, isEmpty);
        expect(update.notices, isEmpty);
      });
    });

    group('requestItemInEdit (RF-27 a RF-30)', () {
      // s1 (45 min) con a1; short (30 min); same (45 min); long (90 min).
      final list = PriceListModel(
        categories: [
          PriceCategoryModel(
            id: 'manos',
            name: text('Manos'),
            items: [
              service('s1', 45),
              addon('a1'),
              service('short', 30),
              service('same', 45),
              service('long', 90),
            ],
          ),
        ],
      );
      const short = BookableRef(BookedKind.service, 'short');
      const same = BookableRef(BookedKind.service, 'same');
      const long = BookableRef(BookedKind.service, 'long');
      final o = original();
      final editing = BookingSelection(
        day: tuesday,
        start: at(10, 9),
        item: s1,
        addonIds: const {'a1'},
      );

      BookingUpdate? request(
        BookableRef ref, {
        BookingSelection? from,
        List<BusyRange> others = const [],
        bool catalogKnown = true,
        bool scheduleKnown = true,
      }) => requestItemInEdit(
        from ?? editing,
        context(
          list: list,
          catalogKnown: catalogKnown,
          scheduleKnown: scheduleKnown,
          busy: others,
          original: o,
        ),
        ref,
      );

      test('más corto: lo cambia, desmarca los adicionales y avisa con el '
          'antes y el después', () {
        final update = request(short)!;
        expect(
          update.selection,
          BookingSelection(day: tuesday, start: at(10, 9), item: short),
        );
        final notice = update.notices.single;
        expect(notice.kind, BookingNoticeKind.editItemChanged);
        expect(notice.before!.name.es, 's1');
        expect(notice.before!.end, at(10, 9, 45));
        expect(notice.before!.totalCents, 4000);
        expect(notice.after!.name.es, 'short');
        expect(notice.after!.end, at(10, 9, 30));
        expect(notice.after!.durationMinutes, 30);
        expect(notice.after!.totalCents, 3000);
      });

      test('igual de largo: lo cambia', () {
        expect(request(same)!.selection.item, same);
      });

      test('más largo con el tiempo de después libre: lo cambia', () {
        expect(request(long)!.selection.item, long);
      });

      test('más largo con el tiempo de después ocupado: no lo cambia y '
          'avisa con N y M', () {
        final update = request(long, others: [busy(at(10, 10), at(10, 11))])!;
        expect(update.selection, editing);
        final notice = update.notices.single;
        expect(notice.kind, BookingNoticeKind.editItemDoesNotFit);
        expect(notice.name!.es, 'long');
        expect(notice.minutes, 90);
        expect(notice.freeMinutes, 60);
      });

      test('más largo que pasa del cierre: no lo cambia', () {
        final at11 = BookingSelection(
          day: tuesday,
          start: at(10, 11),
          item: s1,
        );
        final update = request(long, from: at11)!;
        expect(update.selection, at11);
        expect(update.notices.single.freeMinutes, 60);
      });

      test('sin hora: lo cambia, y el aviso no tiene fin', () {
        final noStart = BookingSelection(day: tuesday, item: s1);
        final update = request(long, from: noStart)!;
        expect(update.selection.item, long);
        expect(update.notices.single.after!.end, isNull);
      });

      test('el mismo servicio: sin cambios ni aviso, con sus adicionales', () {
        final update = request(s1)!;
        expect(update.selection, editing);
        expect(update.notices, isEmpty);
      });

      test('no disponible: sin cambios, y avisa', () {
        final update = request(const BookableRef(BookedKind.service, 'x'))!;
        expect(update.selection, editing);
        expect(update.notices, [
          const BookingNotice(BookingNoticeKind.itemUnavailable),
        ]);
      });

      test('con el catálogo cargando, o sin los turnos ocupados si hay hora, '
          'aún no decide (null)', () {
        expect(request(short, catalogKnown: false), isNull);
        expect(request(short, scheduleKnown: false), isNull);
        expect(
          request(
            short,
            from: BookingSelection(day: tuesday, item: s1),
            scheduleKnown: false,
          ),
          isNotNull,
        );
      });
    });
  });
}
