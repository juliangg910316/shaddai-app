import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/appointment_model.dart';
import '../../../data/models/busy_slot_model.dart';
import '../../../data/models/calendar_settings_model.dart';
import '../../../data/models/closure_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/config_repository.dart';

import 'package:uuid/uuid.dart';

import '../../auth/providers/auth_provider.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../../services/providers/price_list_provider.dart';
import '../logic/bookable_catalog.dart';
import '../logic/booking_edit.dart';
import '../logic/booking_rules.dart';
import '../logic/booking_selection.dart'
    hide selectDay, selectSlot, selectItem, toggleAddon, requestItem;
import '../logic/booking_selection.dart'
    as pick
    show selectDay, selectSlot, selectItem, toggleAddon, requestItem;
import '../logic/booking_window.dart';
import '../logic/free_slots.dart';
import '../logic/salon_time.dart';

final bookingRepositoryProvider = Provider((ref) => BookingRepository());
final configRepositoryProvider = Provider((ref) => ConfigRepository());

final calendarSettingsProvider = StreamProvider<CalendarSettingsModel>((ref) {
  return ref.watch(configRepositoryProvider).getCalendarSettings();
});

/// El reloj de la app; los tests lo sustituyen (spec 005, RNF-1).
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Cada cuánto se actualiza "ahora" del salón.
const _salonTick = Duration(seconds: 30);

/// "Ahora" en hora de pared del salón, cada [_salonTick]: así se nota que una
/// hora pasa, que termina el turno activo o que llega la medianoche (RF-9,
/// RF-35).
final salonNowProvider = StreamProvider<DateTime>((ref) {
  final clock = ref.watch(clockProvider);
  final controller = StreamController<DateTime>();
  controller.add(toSalon(clock()));
  final timer = Timer.periodic(
    _salonTick,
    (_) => controller.add(toSalon(clock())),
  );
  ref.onDispose(() {
    timer.cancel();
    controller.close();
  });
  return controller.stream;
});

/// "Ahora" del salón, también antes de que llegue el primer valor de
/// [salonNowProvider].
DateTime _salonNow(Ref ref) =>
    ref.watch(salonNowProvider).value ?? toSalon(ref.read(clockProvider)());

/// Diferencia con UTC del dispositivo (RF-5).
final deviceUtcOffsetProvider = Provider<Duration>(
  (ref) => DateTime.now().timeZoneOffset,
);

/// Si la sesión es de la admin (spec 007, RF-1, RF-28).
final isAdminSessionProvider = Provider<bool>(
  (ref) => ref.watch(
    currentUserProvider.select((user) => user.value?.role == 'admin'),
  ),
);

/// Días de la ventana de reserva de la sesión: 365 para la admin, 60 para
/// la clienta (spec 007, RF-12).
final bookingWindowDaysProvider = Provider<int>(
  (ref) => ref.watch(isAdminSessionProvider)
      ? adminBookingWindowDays
      : bookingWindowDays,
);

/// Turnos ocupados de la ventana de reserva, en vivo (RF-6, D-2). Solo vuelve
/// a pedirlos cuando cambia el día del salón o el largo de la ventana (spec
/// 007, RF-12).
final busySlotsProvider = StreamProvider<List<BusySlot>>((ref) {
  final clock = ref.watch(clockProvider);
  // Antes del primer valor, el día del reloj: así no se vuelve a pedir la
  // ventana cuando llega.
  final today = ref.watch(
    salonNowProvider.select((now) => salonDay(now.value ?? toSalon(clock()))),
  );
  final window = bookingWindow(
    today,
    days: ref.watch(bookingWindowDaysProvider),
  );
  final end = window.last.add(const Duration(days: 1));
  return ref
      .watch(bookingRepositoryProvider)
      .watchBusySlots(fromSalon(window.first), fromSalon(end));
});

/// Los cierres de la agenda que terminan desde hoy a las 0:00 del salón, en
/// vivo (spec 008, RF-12, RF-15). Solo vuelve a pedirlos cuando cambia el
/// día del salón.
final closuresProvider = StreamProvider<List<ClosureModel>>((ref) {
  final clock = ref.watch(clockProvider);
  final today = ref.watch(
    salonNowProvider.select((now) => salonDay(now.value ?? toSalon(clock()))),
  );
  return ref.watch(configRepositoryProvider).watchClosures(fromSalon(today));
});

/// [closures] en horas de pared del salón, para la lógica.
List<BusyRange> _closureRangesOf(List<ClosureModel> closures) => [
  for (final closure in closures)
    (start: toSalon(closure.start), end: toSalon(closure.end)),
];

/// [closuresProvider] en horas de pared del salón (spec 008, RF-12). Tras un
/// error, el error, aunque Riverpod esté reintentando (MEMORY).
final closureRangesProvider = Provider<AsyncValue<List<BusyRange>>>((ref) {
  final closures = ref.watch(closuresProvider);
  if (closures.hasError) {
    return AsyncError(closures.error!, closures.stackTrace!);
  }
  return closures.whenData(_closureRangesOf);
});

/// El turno en edición, o `null` si no se está editando (spec 006, RF-4,
/// RF-18). Va en su propio provider, separado de la selección, para no crear
/// un ciclo de dependencias (plan D-2).
class EditTargetController extends Notifier<EditOriginal?> {
  @override
  EditOriginal? build() => null;

  /// Abre la edición de [appointment].
  void start(AppointmentModel appointment) =>
      state = EditOriginal.of(appointment);

  /// Cierra la edición.
  void end() => state = null;
}

final editTargetProvider =
    NotifierProvider<EditTargetController, EditOriginal?>(
      EditTargetController.new,
    );

/// [slots] en horas de pared del salón, sin el turno ocupado [editingId].
List<BusyRange> _rangesOf(List<BusySlot> slots, String? editingId) => [
  for (final slot in slots)
    if (slot.id != editingId)
      (start: toSalon(slot.start), end: toSalon(slot.end)),
];

/// [busySlotsProvider] en horas de pared del salón, para la lógica, con los
/// cierres de la agenda, que ocupan su tiempo igual (spec 008, RF-12). Durante
/// la edición, sin el turno ocupado del propio turno (spec 006, RF-7). Si
/// falla cualquiera de los dos, el error (RF-48).
final busyRangesProvider = Provider<AsyncValue<List<BusyRange>>>((ref) {
  final slots = ref.watch(busySlotsProvider);
  final closures = ref.watch(closureRangesProvider);
  final editingId = ref.watch(editTargetProvider.select((o) => o?.id));
  // Tras un error, Riverpod reintenta solo y el valor queda "cargando" con
  // el error dentro; `whenData` lo perdería (RF-48).
  if (slots.hasError) return AsyncError(slots.error!, slots.stackTrace!);
  if (closures.hasError) {
    return AsyncError(closures.error!, closures.stackTrace!);
  }
  final closureRanges = closures.value;
  if (closureRanges == null) return const AsyncLoading();
  return slots.whenData(
    (slots) => [..._rangesOf(slots, editingId), ...closureRanges],
  );
});

/// Lo que se puede reservar de la lista de precios (RF-10, RF-11, RF-43,
/// RF-47).
final bookableCatalogProvider = Provider<PriceView<BookableCatalog>>(
  (ref) => switch (ref.watch(currentPriceListProvider)) {
    PriceListLoading() => const PriceViewLoading<BookableCatalog>(),
    PriceListUnavailable() => const PriceViewUnavailable<BookableCatalog>(),
    PriceListReady(:final list) => PriceViewReady(bookableCatalog(list)),
  },
);

/// Los turnos de la clienta con sesión, en vivo (RF-33). También los muestra
/// Perfil. Solo vuelve a pedirlos si cambia la cuenta, no con cada cambio de
/// la ficha.
final myAppointmentsProvider = StreamProvider<List<AppointmentModel>>((ref) {
  final uid = ref.watch(currentUserProvider.select((user) => user.value?.uid));
  if (uid == null) return Stream.value(const []);
  return ref.watch(bookingRepositoryProvider).getClientAppointments(uid);
});

AppointmentTimes _timesOf(AppointmentModel appointment) => (
  start: appointment.startTime,
  end: appointment.endTime,
  status: appointment.status,
);

/// Qué muestra la pantalla de reserva (RF-33 a RF-39, RF-49).
final bookingScreenProvider = Provider<BookingScreen<AppointmentModel>>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  final mineAsync = ref.watch(myAppointmentsProvider);
  final editingId = ref.watch(editTargetProvider.select((o) => o?.id));
  final user = userAsync.value;
  return bookingScreen(
    // Tras un error, Riverpod reintenta solo y el valor queda "cargando" con
    // el error dentro: se muestra el error, con "Reintentar" (RF-49).
    userLoading: userAsync.isLoading && user == null && !userAsync.hasError,
    userError: userAsync.hasError,
    user: user == null
        ? null
        : (isAdmin: user.role == 'admin', isBlocked: user.isBlocked),
    mine: mineAsync.value,
    mineError: mineAsync.hasError,
    times: _timesOf,
    now: fromSalon(_salonNow(ref)),
    isEditing: (appointment) => appointment.id == editingId,
  );
});

/// Lo elegido en la reserva y los avisos que aún no se han mostrado.
class BookingSelectionState {
  const BookingSelectionState(this.selection, [this.notices = const []]);

  final BookingSelection selection;
  final List<BookingNotice> notices;
}

/// Lo elegido en la reserva (RF-1, RF-8 a RF-21, RF-40, RF-45). Cada acción
/// aplica la lógica de `booking_selection.dart` y guarda sus avisos; cuando
/// cambian el catálogo, el calendario, los turnos ocupados o "ahora", aplica
/// [reconcile].
///
/// También es la selección de la edición (spec 006, plan D-1): al empezar,
/// carga lo del turno; al terminar, vuelve a la selección vacía. Termina la
/// edición si la bloquean o si el turno deja de ser el activo.
class BookingSelectionController extends Notifier<BookingSelectionState> {
  /// Servicio pedido desde su detalle durante la edición que aún no se pudo
  /// decidir (spec 006, RF-27): se vuelve a intentar al llegar los datos.
  BookableRef? _pendingEditRequest;

  @override
  BookingSelectionState build() {
    void onChange(Object? _, Object? _) {
      _apply(reconcile(selection, _context()));
      _retryEditRequest();
    }

    ref.listen(bookableCatalogProvider, onChange);
    ref.listen(calendarSettingsProvider, onChange);
    ref.listen(busyRangesProvider, onChange);
    ref.listen(closureRangesProvider, onChange);
    ref.listen(bookingWindowDaysProvider, onChange);
    ref.listen(salonNowProvider, (_, _) {
      onChange(null, null);
      _checkEdit();
    });
    ref.listen<EditOriginal?>(editTargetProvider, _onEditTarget);
    ref.listen(currentUserProvider, (_, _) => _checkEdit());
    ref.listen(myAppointmentsProvider, (_, _) => _checkEdit());
    return BookingSelectionState(
      reconcile(BookingSelection.empty, _context()).selection,
    );
  }

  void _onEditTarget(EditOriginal? previous, EditOriginal? next) {
    _pendingEditRequest = null;
    final context = _context();
    if (next != null) {
      final update = selectionOf(next, context);
      state = BookingSelectionState(update.selection, [
        ...state.notices,
        ...update.notices,
      ]);
    } else if (previous != null) {
      _set(reconcile(BookingSelection.empty, context).selection);
    }
  }

  /// Termina la edición si la bloquean (sin aviso: se ve el de bloqueo) o si
  /// el turno ya no es el activo (avisa, casos límite de la spec 006).
  void _checkEdit() {
    final original = ref.read(editTargetProvider);
    if (original == null) return;
    final user = ref.read(currentUserProvider).value;
    final mine = ref.read(myAppointmentsProvider);
    final target = ref.read(editTargetProvider.notifier);
    if (user != null && user.isBlocked) {
      target.end();
      return;
    }
    final appointments = mine.value;
    if (mine.hasError || appointments == null) return;
    final active = activeAppointment(
      appointments,
      times: _timesOf,
      now: fromSalon(_context().nowSalon),
    );
    if (active?.id != original.id) {
      target.end();
      state = BookingSelectionState(selection, [
        ...state.notices,
        const BookingNotice(BookingNoticeKind.editNotActive),
      ]);
    }
  }

  BookingSelection get selection => state.selection;

  BookingContext _context() {
    final catalog = ref.read(bookableCatalogProvider);
    final original = ref.read(editTargetProvider);
    // Los turnos ocupados se leen aquí sin el turno en edición, y no de
    // busyRangesProvider: al empezar la edición, este controlador se entera
    // antes de que ese provider se recalcule.
    final busySlots = ref.read(busySlotsProvider);
    final slots = busySlots.hasError ? null : busySlots.value;
    final closures = ref.read(closureRangesProvider);
    return BookingContext(
      catalog: catalog is PriceViewReady<BookableCatalog>
          ? catalog.value
          : null,
      settings: ref.read(calendarSettingsProvider).value,
      busy: slots == null ? null : _rangesOf(slots, original?.id),
      closures: closures.hasError ? null : closures.value,
      nowSalon:
          ref.read(salonNowProvider).value ??
          toSalon(ref.read(clockProvider)()),
      original: original,
      windowDays: ref.read(bookingWindowDaysProvider),
    );
  }

  void _apply(BookingUpdate update) => state = BookingSelectionState(
    update.selection,
    [...state.notices, ...update.notices],
  );

  void _set(BookingSelection selection) =>
      state = BookingSelectionState(selection, state.notices);

  void selectDay(DateTime day) => _set(pick.selectDay(selection, day));

  void selectSlot(FreeSlot slot) =>
      _apply(pick.selectSlot(selection, _context(), slot));

  void selectItem(BookableRef ref) =>
      _apply(pick.selectItem(selection, _context(), ref));

  void toggleAddon(String id) =>
      _set(pick.toggleAddon(selection, _context(), id));

  /// El servicio pedido desde su detalle (RF-40 a RF-44). Con la lista ya
  /// cargada, un servicio que no existe se quita y se avisa enseguida.
  ///
  /// Durante la edición, lo cambia solo si cabe (spec 006, RF-27 a RF-30).
  /// Si aún no se puede decidir, lo intenta otra vez al llegar los datos.
  void requestItem(BookableRef ref) {
    if (this.ref.read(editTargetProvider) != null) {
      _pendingEditRequest = ref;
      _retryEditRequest();
      return;
    }
    final context = _context();
    final requested = pick.requestItem(selection, context, ref);
    final reconciled = reconcile(requested.selection, context);
    _apply((
      selection: reconciled.selection,
      notices: [...requested.notices, ...reconciled.notices],
    ));
  }

  void _retryEditRequest() {
    final request = _pendingEditRequest;
    if (request == null) return;
    final update = requestItemInEdit(selection, _context(), request);
    if (update == null) return;
    _pendingEditRequest = null;
    _apply(update);
  }

  /// Quita la hora y conserva lo demás (RF-29, RF-30).
  void dropSlot() => _set(
    BookingSelection(
      day: selection.day,
      item: selection.item,
      addonIds: selection.addonIds,
    ),
  );

  /// Tras guardar: conserva solo el día.
  void clear() => _set(BookingSelection(day: selection.day));

  /// Tras agendar la admin: vacía todo, también el día, y vuelve a elegir el
  /// primero con horas libres, como al abrir (spec 007, RF-20, D-8).
  void reset() => _set(reconcile(BookingSelection.empty, _context()).selection);

  /// La vista llama aquí tras mostrar los avisos.
  void consumeNotices() => state = BookingSelectionState(selection);
}

final bookingSelectionProvider =
    NotifierProvider<BookingSelectionController, BookingSelectionState>(
      BookingSelectionController.new,
    );

/// Las horas libres de [day], o `null` si el calendario o los turnos
/// ocupados aún no se conocen. En la edición, sin el propio turno y con su
/// hora original (spec 006, RF-5, RF-7, RF-8). Lo usan la vista y la lógica,
/// para que calculen lo mismo.
final freeSlotsOfDayProvider = Provider.family<List<FreeSlot>?, DateTime>((
  ref,
  day,
) {
  final settings = ref.watch(calendarSettingsProvider).value;
  final busy = ref.watch(busyRangesProvider).value;
  if (settings == null || busy == null) return null;
  final original = ref.watch(editTargetProvider);
  final now = _salonNow(ref);
  return original == null
      ? freeSlots(day: day, settings: settings, busy: busy, nowSalon: now)
      : editFreeSlots(
          day: day,
          settings: settings,
          busy: busy,
          nowSalon: now,
          original: original,
        );
});

/// La hora libre elegida, con su cobertura, o `null` si no hay ninguna (o
/// aún no se sabe). Decide qué servicios caben (RF-12).
final selectedFreeSlotProvider = Provider<FreeSlot?>((ref) {
  final start = ref.watch(
    bookingSelectionProvider.select((state) => state.selection.start),
  );
  if (start == null) return null;
  for (final slot
      in ref.watch(freeSlotsOfDayProvider(salonDay(start))) ?? const []) {
    if (slot.start == start) return slot;
  }
  return null;
});

/// Lee **del servidor** los cierres que terminan desde el día [day] (hora
/// de pared) en adelante, en horas de pared, para comprobar un turno antes
/// de guardarlo (spec 008, RF-12). Si falla, lanza el error.
Future<List<BusyRange>> fetchClosureRanges(Ref ref, DateTime day) async =>
    _closureRangesOf(
      await ref.read(configRepositoryProvider).fetchClosures(fromSalon(day)),
    );

/// Resultado de "Agendar turno" (RF-26 a RF-31, RF-36).
enum BookingSubmitResult { ok, slotTaken, doesNotFit, alreadyActive, failed }

/// Guarda el turno elegido tras comprobarlo en el servidor (plan D-4).
class BookingSubmitter {
  BookingSubmitter(this._ref);

  final Ref _ref;

  Future<BookingSubmitResult> confirm() async {
    final selection = _ref.read(bookingSelectionProvider).selection;
    final start = selection.start;
    final item = selection.item;
    final settings = _ref.read(calendarSettingsProvider).value;
    final catalog = _ref.read(bookableCatalogProvider);
    final bookable = start == null || item == null
        ? null
        : switch (catalog) {
            PriceViewReady(:final value) => findBookable(value, item),
            _ => null,
          };
    final user = _ref.read(currentUserProvider).value;
    if (start == null || bookable == null || user == null || settings == null) {
      return BookingSubmitResult.failed;
    }

    final repository = _ref.read(bookingRepositoryProvider);
    final selector = _ref.read(bookingSelectionProvider.notifier);
    final day = salonDay(start);
    try {
      final data = await repository.fetchBookingCheck(
        clientId: user.uid,
        from: fromSalon(day),
        to: fromSalon(day.add(const Duration(days: 1))),
      );
      final closures = await fetchClosureRanges(_ref, day);
      final check = checkBeforeSave(
        start: start,
        durationMinutes: bookable.durationMinutes,
        settings: settings,
        busy: [
          for (final slot in data.busy)
            (start: toSalon(slot.start), end: toSalon(slot.end)),
        ],
        closures: closures,
        mine: data.mine,
        times: _timesOf,
        nowSalon: toSalon(_ref.read(clockProvider)()),
      );
      switch (check) {
        case BookingCheck.alreadyActive:
          return BookingSubmitResult.alreadyActive;
        case BookingCheck.slotTaken:
          selector.dropSlot();
          return BookingSubmitResult.slotTaken;
        case BookingCheck.doesNotFit:
          selector.dropSlot();
          return BookingSubmitResult.doesNotFit;
        case BookingCheck.ok:
          break;
      }

      final addons = [
        for (final addon in availableAddons(
          (catalog as PriceViewReady<BookableCatalog>).value,
          item!,
        ))
          if (selection.addonIds.contains(addon.id)) addon,
      ];
      final startTime = fromSalon(start);
      await repository
          .createAppointment(
            AppointmentModel(
              id: const Uuid().v4(),
              clientId: user.uid,
              clientName: user.displayName,
              clientPhone: user.phoneNumber ?? '',
              clientPhotoUrl: user.photoUrl,
              startTime: startTime,
              endTime: startTime.add(
                Duration(minutes: bookable.durationMinutes),
              ),
              status: 'waiting_confirmation',
              createdAt: _ref.read(clockProvider)(),
              booked: snapshotOf(bookable, addons),
            ),
          )
          .timeout(repository.saveTimeout);
    } catch (error) {
      debugPrint('No se pudo agendar el turno: $error');
      return BookingSubmitResult.failed;
    }
    selector.clear();
    return BookingSubmitResult.ok;
  }
}

final bookingSubmitProvider = Provider(BookingSubmitter.new);
