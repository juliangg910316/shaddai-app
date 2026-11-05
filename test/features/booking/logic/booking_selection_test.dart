import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/data/models/booked_service_model.dart';
import 'package:shaddai/data/models/calendar_settings_model.dart';
import 'package:shaddai/data/models/price_list_model.dart';
import 'package:shaddai/features/booking/logic/bookable_catalog.dart';
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
}) => BookingContext(
  catalog: catalogKnown ? bookableCatalog(list ?? priceList()) : null,
  settings: scheduleKnown ? (calendar ?? settings()) : null,
  busy: scheduleKnown ? busy : null,
  nowSalon: nowSalon ?? now,
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
}
