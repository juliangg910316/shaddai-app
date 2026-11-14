/// Lo elegido en la reserva y cómo se mantiene coherente cuando cambian los
/// datos, sin Flutter ni Firebase (spec 005, plan § 4.5). Todos los días y
/// horas son horas de pared del salón (`salon_time.dart`).
///
/// Cada acción devuelve la selección nueva y los avisos que hay que mostrar.
/// Los avisos son datos ([BookingNotice]): la vista los traduce al pintarlos
/// (plan, D-7).
library;

import '../../../data/models/calendar_settings_model.dart';
import '../../../data/models/price_list_model.dart';
import 'bookable_catalog.dart';
import 'booking_edit.dart';
import 'booking_window.dart';
import 'free_slots.dart';
import 'salon_time.dart';

/// Día, hora de inicio, servicio o combo, y adicionales marcados.
class BookingSelection {
  const BookingSelection({
    this.day,
    this.start,
    this.item,
    this.addonIds = const {},
  });

  static const empty = BookingSelection();

  /// Día del salón, a las 0:00.
  final DateTime? day;
  final DateTime? start;
  final BookableRef? item;
  final Set<String> addonIds;

  @override
  bool operator ==(Object other) =>
      other is BookingSelection &&
      other.day == day &&
      other.start == start &&
      other.item == item &&
      other.addonIds.length == addonIds.length &&
      other.addonIds.containsAll(addonIds);

  @override
  int get hashCode =>
      Object.hash(day, start, item, Object.hashAllUnordered(addonIds));

  @override
  String toString() =>
      'BookingSelection(day: $day, start: $start, item: $item, '
      'addons: $addonIds)';
}

/// Qué aviso hay que mostrar.
enum BookingNoticeKind {
  /// Se tocó un servicio que no cabe en la hora elegida (RF-13). Con
  /// [BookingNotice.minutes], su duración.
  needsLongerSlot,

  /// Se tocó una hora en la que no cabe el servicio elegido (RF-15). Con
  /// [BookingNotice.minutes], la duración del servicio.
  slotTooShortFor,

  /// La hora elegida dejó de ser libre (RF-9).
  slotGone,

  /// El servicio elegido ya no cabe en la hora elegida (RF-16, D-10).
  slotNoLongerFits,

  /// El servicio elegido ya no está disponible (RF-17, RF-44).
  itemUnavailable,

  /// La fecha elegida ya no se puede elegir y se pasó a otra (casos límite).
  dateMoved,

  /// En la edición, se cambió el servicio desde su detalle (spec 006,
  /// RF-28). Con [BookingNotice.before] y [BookingNotice.after].
  editItemChanged,

  /// En la edición, el servicio pedido desde su detalle no cabe en la hora
  /// elegida (spec 006, RF-29). Con [BookingNotice.name],
  /// [BookingNotice.minutes] (su duración) y [BookingNotice.freeMinutes].
  editItemDoesNotFit,

  /// Al abrir la edición, algún adicional del turno ya no está disponible y
  /// se quitó (spec 006, RF-6).
  editAddonsUnavailable,
}

/// Un aviso para la clienta.
class BookingNotice {
  const BookingNotice(
    this.kind, {
    this.minutes,
    this.name,
    this.freeMinutes,
    this.before,
    this.after,
  });

  final BookingNoticeKind kind;

  /// Duración que cita el aviso, si la cita.
  final int? minutes;

  /// Servicio que cita el aviso, en los dos idiomas.
  final BilingualText? name;

  /// Minutos libres que cita el aviso.
  final int? freeMinutes;

  /// Lo elegido antes y después de un cambio.
  final BookingDraft? before;
  final BookingDraft? after;

  @override
  bool operator ==(Object other) =>
      other is BookingNotice &&
      other.kind == kind &&
      other.minutes == minutes &&
      other.name?.es == name?.es &&
      other.name?.pt == name?.pt &&
      other.freeMinutes == freeMinutes &&
      other.before == before &&
      other.after == after;

  @override
  int get hashCode => Object.hash(
    kind,
    minutes,
    name?.es,
    name?.pt,
    freeMinutes,
    before,
    after,
  );

  @override
  String toString() => 'BookingNotice(${kind.name}, $minutes)';
}

/// La selección nueva y los avisos que provoca.
typedef BookingUpdate = ({
  BookingSelection selection,
  List<BookingNotice> notices,
});

/// Lo que se sabe al decidir: el catálogo, el calendario, los turnos
/// ocupados y "ahora". Un dato que aún no ha llegado es `null`, y lo que
/// depende de él no se toca.
class BookingContext {
  const BookingContext({
    this.catalog,
    this.settings,
    this.busy,
    required this.nowSalon,
    this.original,
  });

  final BookableCatalog? catalog;
  final CalendarSettingsModel? settings;

  /// Sin el propio turno durante la edición (spec 006, RF-7).
  final List<BusyRange>? busy;
  final DateTime nowSalon;

  /// El turno en edición, o `null` en una reserva nueva (spec 006). Con él,
  /// su día y su hora valen aunque ya no cumplan las reglas (RF-5, RF-8).
  final EditOriginal? original;

  bool get _scheduleKnown => settings != null && busy != null;

  /// Las horas libres del día de [day], o ninguna si el calendario o los
  /// turnos ocupados aún no han llegado. En la edición, con su hora original
  /// (`editFreeSlots`).
  List<FreeSlot> freeSlotsOf(DateTime day) {
    final settings = this.settings;
    final busy = this.busy;
    if (settings == null || busy == null) return const [];
    final original = this.original;
    if (original != null) {
      return editFreeSlots(
        day: salonDay(day),
        settings: settings,
        busy: busy,
        nowSalon: nowSalon,
        original: original,
      );
    }
    return freeSlots(
      day: salonDay(day),
      settings: settings,
      busy: busy,
      nowSalon: nowSalon,
    );
  }

  /// Si [day] se puede elegir: con las reglas de la reserva o, en la
  /// edición, también el día original (RF-5, RF-9).
  bool isDaySelectable(DateTime day, CalendarSettingsModel settings) {
    final window = bookingWindow(nowSalon);
    final original = this.original;
    return original == null
        ? isSelectableDay(day, settings, window)
        : isEditDaySelectable(day, settings, window, original);
  }

  /// La duración de [ref], o `null` si no se conoce o no está disponible.
  int? durationOf(BookableRef? ref) {
    final catalog = this.catalog;
    if (ref == null || catalog == null) return null;
    return findBookable(catalog, ref)?.durationMinutes;
  }

  /// La hora libre de [start], o `null` si ya no lo es.
  FreeSlot? slotAt(DateTime start) {
    for (final slot in freeSlotsOf(start)) {
      if (slot.start == start) return slot;
    }
    return null;
  }
}

BookingUpdate _unchanged(BookingSelection selection, [BookingNotice? notice]) =>
    (selection: selection, notices: [?notice]);

/// Cambia de fecha: quita la hora y conserva lo reservado (RF-8).
BookingSelection selectDay(BookingSelection selection, DateTime day) =>
    BookingSelection(
      day: salonDay(day),
      item: selection.item,
      addonIds: selection.addonIds,
    );

/// Elige la hora [slot], salvo que el servicio elegido no quepa en ella
/// (RF-15). Si ya era la elegida, la quita (RF-59).
BookingUpdate selectSlot(
  BookingSelection selection,
  BookingContext context,
  FreeSlot slot,
) {
  if (slot.start == selection.start) {
    return _unchanged(
      BookingSelection(
        day: selection.day,
        item: selection.item,
        addonIds: selection.addonIds,
      ),
    );
  }
  final duration = context.durationOf(selection.item);
  if (duration != null && !fits(duration, slot)) {
    return _unchanged(
      selection,
      BookingNotice(BookingNoticeKind.slotTooShortFor, minutes: duration),
    );
  }
  return _unchanged(
    BookingSelection(
      day: selection.day,
      start: slot.start,
      item: selection.item,
      addonIds: selection.addonIds,
    ),
  );
}

/// Elige el servicio o combo [ref], salvo que no quepa en la hora elegida
/// (RF-13), y desmarca los adicionales (RF-20). Si ya era el elegido, lo
/// quita con sus adicionales (RF-59).
BookingUpdate selectItem(
  BookingSelection selection,
  BookingContext context,
  BookableRef ref,
) {
  if (ref == selection.item) {
    return _unchanged(
      BookingSelection(day: selection.day, start: selection.start),
    );
  }
  final duration = context.durationOf(ref);
  final start = selection.start;
  if (duration != null && start != null) {
    final slot = context.slotAt(start);
    if (slot != null && !fits(duration, slot)) {
      return _unchanged(
        selection,
        BookingNotice(BookingNoticeKind.needsLongerSlot, minutes: duration),
      );
    }
  }
  return _unchanged(
    BookingSelection(
      day: selection.day,
      start: selection.start,
      item: ref,
      addonIds: const {},
    ),
  );
}

/// Marca o desmarca el adicional [addonId], si es de los disponibles para el
/// servicio elegido (RF-18).
BookingSelection toggleAddon(
  BookingSelection selection,
  BookingContext context,
  String addonId,
) {
  final item = selection.item;
  final catalog = context.catalog;
  if (item == null || catalog == null) return selection;
  final available = availableAddons(catalog, item).any((a) => a.id == addonId);
  if (!available) return selection;

  final addons = {...selection.addonIds};
  if (!addons.remove(addonId)) addons.add(addonId);
  return BookingSelection(
    day: selection.day,
    start: selection.start,
    item: item,
    addonIds: addons,
  );
}

/// Elige [ref] al llegar desde el detalle de un servicio (RF-40): sustituye
/// el servicio, desmarca los adicionales y conserva la fecha. La hora se
/// conserva solo si el servicio cabe; si no, se quita y se avisa (D-10).
///
/// Si el servicio aún no se conoce (la lista de precios está cargando), se
/// guarda tal cual: [reconcile] lo quita y avisa si al llegar la lista no
/// está disponible (RF-43, RF-44).
BookingUpdate requestItem(
  BookingSelection selection,
  BookingContext context,
  BookableRef ref,
) {
  var start = selection.start;
  BookingNotice? notice;
  final duration = context.durationOf(ref);
  if (start != null && duration != null) {
    final slot = context.slotAt(start);
    if (slot != null && !fits(duration, slot)) {
      start = null;
      notice = const BookingNotice(BookingNoticeKind.slotNoLongerFits);
    }
  }
  return _unchanged(
    BookingSelection(day: selection.day, start: start, item: ref),
    notice,
  );
}

/// Mantiene [selection] coherente con [context] cuando cambian los datos:
/// - sin fecha, o con una que ya no se puede elegir, pasa a la de RF-1; en
///   la edición, el día original sigue valiendo (spec 006, RF-5);
/// - quita el servicio que ya no está disponible, con sus adicionales
///   (RF-17), y desmarca los adicionales que ya no lo están (RF-21); en la
///   edición, avisa si alguno era del turno original (spec 006, RF-6);
/// - quita la hora que dejó de ser libre (RF-9) o en la que el servicio ya
///   no cabe (RF-16).
BookingUpdate reconcile(BookingSelection selection, BookingContext context) {
  final notices = <BookingNotice>[];
  var day = selection.day;
  var start = selection.start;
  var item = selection.item;
  var addonIds = selection.addonIds;

  final settings = context.settings;
  if (settings != null && context._scheduleKnown) {
    if (day == null || !context.isDaySelectable(day, settings)) {
      final next = initialDay(
        nowSalon: context.nowSalon,
        settings: settings,
        hasFreeSlot: (d) => context.freeSlotsOf(d).isNotEmpty,
      );
      if (day != null && next != day) {
        notices.add(const BookingNotice(BookingNoticeKind.dateMoved));
      }
      day = next;
      start = null;
    }
  }

  final catalog = context.catalog;
  if (catalog != null && item != null) {
    if (findBookable(catalog, item) == null) {
      item = null;
      addonIds = const {};
      notices.add(const BookingNotice(BookingNoticeKind.itemUnavailable));
    } else {
      final available = {for (final a in availableAddons(catalog, item)) a.id};
      if (!available.containsAll(addonIds)) {
        final removed = addonIds.where((id) => !available.contains(id));
        final originalIds = {
          for (final addon in context.original?.booked?.addons ?? const [])
            addon.id,
        };
        if (removed.any(originalIds.contains)) {
          notices.add(
            const BookingNotice(BookingNoticeKind.editAddonsUnavailable),
          );
        }
        addonIds = addonIds.where(available.contains).toSet();
      }
    }
  }

  if (start != null && context._scheduleKnown) {
    final slot = context.slotAt(start);
    final duration = context.durationOf(item);
    if (slot == null) {
      start = null;
      notices.add(const BookingNotice(BookingNoticeKind.slotGone));
    } else if (duration != null && !fits(duration, slot)) {
      start = null;
      notices.add(const BookingNotice(BookingNoticeKind.slotNoLongerFits));
    }
  }

  return (
    selection: BookingSelection(
      day: day,
      start: start,
      item: item,
      addonIds: addonIds,
    ),
    notices: notices,
  );
}

/// Lo que falta para poder agendar (RF-24).
enum BookingPart { slot, item }

Set<BookingPart> missingParts(BookingSelection selection) => {
  if (selection.start == null) BookingPart.slot,
  if (selection.item == null) BookingPart.item,
};

/// La selección al abrir la edición de [original] (spec 006, RF-4 a RF-6):
/// su día, su hora, su servicio y sus adicionales. Lo que ya no está
/// disponible se quita y se avisa; si el catálogo aún carga, lo hace
/// [reconcile] cuando llega.
BookingUpdate selectionOf(EditOriginal original, BookingContext context) {
  final booked = original.booked;
  return reconcile(
    BookingSelection(
      day: salonDay(original.start),
      start: original.start,
      item: booked == null ? null : BookableRef(booked.kind, booked.id),
      addonIds: {for (final addon in booked?.addons ?? const []) addon.id},
    ),
    context,
  );
}

/// "Reservar cita" en el detalle de [ref] con la edición abierta (spec 006,
/// RF-27 a RF-30):
/// - el mismo servicio: sin cambios, con sus adicionales;
/// - no disponible: sin cambios, y avisa (RF-30);
/// - no cabe en la hora elegida (sin contar el propio turno): sin cambios, y
///   avisa con su duración y los minutos libres (RF-29);
/// - si cabe, o no hay hora: lo elige, desmarca los adicionales y avisa con
///   el antes y el después (RF-28).
///
/// `null` si aún no se puede decidir: el catálogo carga o, con hora, aún no
/// se conocen el calendario y los turnos ocupados. Quien la llama la vuelve
/// a pedir cuando lleguen.
BookingUpdate? requestItemInEdit(
  BookingSelection selection,
  BookingContext context,
  BookableRef ref,
) {
  if (ref == selection.item) return _unchanged(selection);
  final catalog = context.catalog;
  if (catalog == null) return null;
  final bookable = findBookable(catalog, ref);
  if (bookable == null) {
    return _unchanged(
      selection,
      const BookingNotice(BookingNoticeKind.itemUnavailable),
    );
  }
  final start = selection.start;
  if (start != null) {
    if (!context._scheduleKnown) return null;
    final slot = context.slotAt(start);
    if (slot == null || !fits(bookable.durationMinutes, slot)) {
      return _unchanged(
        selection,
        BookingNotice(
          BookingNoticeKind.editItemDoesNotFit,
          name: bookable.name,
          minutes: bookable.durationMinutes,
          freeMinutes: slot?.coverageMinutes ?? 0,
        ),
      );
    }
  }
  final next = BookingSelection(day: selection.day, start: start, item: ref);
  return _unchanged(
    next,
    BookingNotice(
      BookingNoticeKind.editItemChanged,
      before: draftOfSelection(selection, catalog),
      after: draftOfSelection(next, catalog),
    ),
  );
}
