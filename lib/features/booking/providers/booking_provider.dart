import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/appointment_model.dart';
import '../../../data/models/busy_slot_model.dart';
import '../../../data/models/calendar_settings_model.dart';
import '../../../data/repositories/booking_repository.dart';
import '../../../data/repositories/config_repository.dart';

import 'package:uuid/uuid.dart';

import '../../auth/providers/auth_provider.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../../services/providers/price_list_provider.dart';
import '../logic/bookable_catalog.dart';
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

/// Turnos ocupados de la ventana de reserva, en vivo (RF-6, D-2). Solo vuelve
/// a pedirlos cuando cambia el día del salón.
final busySlotsProvider = StreamProvider<List<BusySlot>>((ref) {
  final clock = ref.watch(clockProvider);
  // Antes del primer valor, el día del reloj: así no se vuelve a pedir la
  // ventana cuando llega.
  final today = ref.watch(
    salonNowProvider.select((now) => salonDay(now.value ?? toSalon(clock()))),
  );
  final window = bookingWindow(today);
  final end = window.last.add(const Duration(days: 1));
  return ref
      .watch(bookingRepositoryProvider)
      .watchBusySlots(fromSalon(window.first), fromSalon(end));
});

/// [busySlotsProvider] en horas de pared del salón, para la lógica.
final busyRangesProvider = Provider<AsyncValue<List<BusyRange>>>((ref) {
  final slots = ref.watch(busySlotsProvider);
  // Tras un error, Riverpod reintenta solo y el valor queda "cargando" con
  // el error dentro; `whenData` lo perdería (RF-48).
  if (slots.hasError) return AsyncError(slots.error!, slots.stackTrace!);
  return slots.whenData(
    (slots) => [
      for (final slot in slots)
        (start: toSalon(slot.start), end: toSalon(slot.end)),
    ],
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
class BookingSelectionController extends Notifier<BookingSelectionState> {
  @override
  BookingSelectionState build() {
    void onChange(Object? _, Object? _) =>
        _apply(reconcile(selection, _context()));
    ref.listen(bookableCatalogProvider, onChange);
    ref.listen(calendarSettingsProvider, onChange);
    ref.listen(busyRangesProvider, onChange);
    ref.listen(salonNowProvider, onChange);
    return BookingSelectionState(
      reconcile(BookingSelection.empty, _context()).selection,
    );
  }

  BookingSelection get selection => state.selection;

  BookingContext _context() {
    final catalog = ref.read(bookableCatalogProvider);
    return BookingContext(
      catalog: catalog is PriceViewReady<BookableCatalog>
          ? catalog.value
          : null,
      settings: ref.read(calendarSettingsProvider).value,
      busy: ref.read(busyRangesProvider).value,
      nowSalon:
          ref.read(salonNowProvider).value ??
          toSalon(ref.read(clockProvider)()),
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
  void requestItem(BookableRef ref) {
    final context = _context();
    final requested = pick.requestItem(selection, context, ref);
    final reconciled = reconcile(requested.selection, context);
    _apply((
      selection: reconciled.selection,
      notices: [...requested.notices, ...reconciled.notices],
    ));
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

  /// La vista llama aquí tras mostrar los avisos.
  void consumeNotices() => state = BookingSelectionState(selection);
}

final bookingSelectionProvider =
    NotifierProvider<BookingSelectionController, BookingSelectionState>(
      BookingSelectionController.new,
    );

/// La hora libre elegida, con su cobertura, o `null` si no hay ninguna (o
/// aún no se sabe). Decide qué servicios caben (RF-12).
final selectedFreeSlotProvider = Provider<FreeSlot?>((ref) {
  final start = ref.watch(
    bookingSelectionProvider.select((state) => state.selection.start),
  );
  final settings = ref.watch(calendarSettingsProvider).value;
  final busy = ref.watch(busyRangesProvider).value;
  if (start == null || settings == null || busy == null) return null;
  final slots = freeSlots(
    day: salonDay(start),
    settings: settings,
    busy: busy,
    nowSalon: _salonNow(ref),
  );
  for (final slot in slots) {
    if (slot.start == start) return slot;
  }
  return null;
});

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
      final check = checkBeforeSave(
        start: start,
        durationMinutes: bookable.durationMinutes,
        settings: settings,
        busy: [
          for (final slot in data.busy)
            (start: toSalon(slot.start), end: toSalon(slot.end)),
        ],
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
