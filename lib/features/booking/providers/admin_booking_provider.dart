import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../data/models/appointment_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/agenda_functions.dart';
import '../../admin/providers/admin_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../services/providers/price_list_provider.dart';
import '../logic/admin_booking.dart';
import '../logic/bookable_catalog.dart';
import '../logic/recipient.dart';
import '../logic/salon_time.dart';
import '../logic/whatsapp.dart';
import 'agenda_functions_provider.dart';
import 'booking_provider.dart';

/// Avisos de "Para quién" que la vista aún no ha mostrado.
enum RecipientNotice {
  /// La clienta elegida se bloqueó o dejó de existir y se quitó (RF-15).
  blocked,
}

/// Para quién, el texto de la búsqueda y los avisos pendientes (spec 007,
/// plan § 5, D-5). Una persona sin cuenta es su borrador ([GuestRecipient]).
class RecipientState {
  const RecipientState({
    this.recipient,
    this.query = '',
    this.notices = const [],
  });

  final Recipient? recipient;
  final String query;
  final List<RecipientNotice> notices;

  RecipientState copyWith({
    Recipient? Function()? recipient,
    String? query,
    List<RecipientNotice>? notices,
  }) => RecipientState(
    recipient: recipient == null ? this.recipient : recipient(),
    query: query ?? this.query,
    notices: notices ?? this.notices,
  );
}

/// Para quién es el turno que agenda la admin (RF-1 a RF-11). No se
/// destruye al dejar de escucharse: se conserva al cambiar de pestaña o de
/// página (RF-27). Quita a la clienta elegida si la bloquean (RF-15) y se
/// vacía al cambiar de cuenta.
class RecipientController extends Notifier<RecipientState> {
  @override
  RecipientState build() {
    ref.listen(adminUsersProvider, (_, users) => _reconcile(users));
    ref.listen(currentUserProvider.select((user) => user.value?.uid), (
      previous,
      next,
    ) {
      if (previous != next) state = const RecipientState();
    });
    return const RecipientState();
  }

  void _reconcile(AsyncValue<List<UserModel>> users) {
    final known = users.hasError ? null : users.value;
    final result = reconcileRecipient(state.recipient, known);
    if (!result.blocked) return;
    state = state.copyWith(
      recipient: () => result.recipient,
      notices: [...state.notices, RecipientNotice.blocked],
    );
  }

  void setQuery(String query) => state = state.copyWith(query: query);

  /// Elige a [user] y vacía la búsqueda (RF-3).
  void chooseAccount(UserModel user) => state = state.copyWith(
    recipient: () => AccountRecipient.of(user),
    query: '',
  );

  /// "Persona sin cuenta" (RF-5, RF-7).
  void startGuest() =>
      state = state.copyWith(recipient: () => GuestRecipient.empty);

  /// Cambia el borrador de la persona sin cuenta.
  void updateGuest({String? name, String? phone, bool? consent}) {
    final guest = state.recipient;
    if (guest is! GuestRecipient) return;
    state = state.copyWith(
      recipient: () =>
          guest.copyWith(name: name, phone: phone, consent: consent),
    );
  }

  /// Pone [recipient] y vacía la búsqueda: la persona del turno al abrir la
  /// edición de la admin, o la que tenía elegida al cerrarla (spec 008,
  /// RF-19, RF-33).
  void restore(Recipient? recipient) =>
      state = state.copyWith(recipient: () => recipient, query: '');

  /// Sin para quién y sin búsqueda.
  void clear() => state = RecipientState(notices: state.notices);

  /// Quita a la clienta elegida: se bloqueó al confirmar (RF-15).
  void dropBlocked() => state = state.copyWith(
    recipient: () => null,
    notices: [...state.notices, RecipientNotice.blocked],
  );

  /// La vista llama aquí tras mostrar los avisos.
  void consumeNotices() => state = state.copyWith(notices: const []);
}

final bookingRecipientProvider =
    NotifierProvider<RecipientController, RecipientState>(
      RecipientController.new,
    );

/// Las clientas que coinciden con la búsqueda (RF-3, RF-4). Con error si no
/// se pudieron cargar las fichas (RF-6).
final recipientSearchProvider = Provider<AsyncValue<List<UserModel>>>((ref) {
  final users = ref.watch(adminUsersProvider);
  final query = ref.watch(bookingRecipientProvider.select((s) => s.query));
  // Tras un error, Riverpod reintenta solo y el valor queda "cargando" con
  // el error dentro: el error manda (MEMORY).
  if (users.hasError) return AsyncError(users.error!, users.stackTrace!);
  return users.whenData((users) => searchClients(users, query));
});

/// Los turnos que aún no terminaron, de cualquier persona, en vivo desde el
/// "ahora" en que se abre (RF-14). [activeAppointmentOfPerson] vuelve a
/// filtrar con "ahora", así que no hace falta volver a pedirlos.
final adminActiveAppointmentsProvider = StreamProvider<List<AppointmentModel>>((
  ref,
) {
  final now = ref.read(clockProvider)();
  return ref.watch(bookingRepositoryProvider).watchActiveAppointments(now);
});

/// El turno activo de la persona elegida, o `null` (RF-14). Con cuenta, se
/// busca por su cuenta y por el WhatsApp actual de su ficha; sin cuenta, por
/// su WhatsApp, en cuanto es válido.
final recipientActiveAppointmentProvider = Provider<AppointmentModel?>((ref) {
  final recipient = ref.watch(
    bookingRecipientProvider.select((s) => s.recipient),
  );
  if (recipient == null) return null;
  final String? uid;
  final String phone;
  switch (recipient) {
    case AccountRecipient(uid: final id, phone: final chosenPhone):
      uid = id;
      final user = ref
          .watch(adminUsersProvider)
          .value
          ?.where((u) => u.uid == id)
          .firstOrNull;
      phone = user?.phoneNumber ?? chosenPhone;
    case GuestRecipient(phone: final guestPhone):
      if (!isValidWhatsApp(guestPhone)) return null;
      uid = null;
      phone = guestPhone;
  }
  final active = ref.watch(adminActiveAppointmentsProvider).value;
  if (active == null) return null;
  // El turno que edita la admin no cuenta (spec 008, RF-25).
  final editingId = ref.watch(editTargetProvider.select((o) => o?.id));
  final now =
      ref.watch(salonNowProvider).value ?? toSalon(ref.read(clockProvider)());
  return activeAppointmentOfPerson(
    [
      for (final appointment in active)
        if (appointment.id != editingId) appointment,
    ],
    uid: uid,
    phone: phone,
    now: fromSalon(now),
  );
});

/// Resultado de "Agendar turno" de la admin (RF-14, RF-15, RF-18 a RF-20).
enum AdminBookingOutcome {
  ok,
  slotTaken,
  doesNotFit,
  personActive,
  recipientBlocked,

  /// Lo reservado ya no está en la lista de precios (spec 012, RF-12).
  itemUnavailable,

  /// Lo reservado cambió en la lista de precios (spec 012, RF-12).
  itemChanged,
  failed,
}

class AdminBookingResult {
  const AdminBookingResult(this.outcome, {this.active, this.name});

  final AdminBookingOutcome outcome;

  /// Con [AdminBookingOutcome.personActive], su turno activo.
  final AppointmentModel? active;

  /// Con [AdminBookingOutcome.ok], para quién se agendó.
  final String? name;
}

/// La persona de [recipient] como la recibe la función (spec 012): una
/// clienta por su cuenta (el servidor lee su ficha) o una persona sin
/// cuenta, sin espacios alrededor.
AgendaRecipient agendaRecipientOf(Recipient recipient) => switch (recipient) {
  AccountRecipient(:final uid) => AgendaAccountRecipient(uid),
  GuestRecipient(:final name, :final phone) => AgendaGuestRecipient(
    name: name.trim(),
    phone: phone.trim(),
  ),
};

/// Guarda el turno de la admin tras comprobarlo en el servidor (RF-18,
/// RF-19, plan § 5). Con `ok`, vacía la selección y para quién (RF-20).
class AdminBookingSubmitter {
  AdminBookingSubmitter(this._ref);

  final Ref _ref;

  static const _failed = AdminBookingResult(AdminBookingOutcome.failed);

  Future<AdminBookingResult> confirm() async {
    final selection = _ref.read(bookingSelectionProvider).selection;
    final recipient = _ref.read(bookingRecipientProvider).recipient;
    final start = selection.start;
    final item = selection.item;
    final settings = _ref.read(calendarSettingsProvider).value;
    final catalog = switch (_ref.read(bookableCatalogProvider)) {
      PriceViewReady(:final value) => value,
      _ => null,
    };
    final bookable = start == null || item == null || catalog == null
        ? null
        : findBookable(catalog, item);
    if (start == null ||
        bookable == null ||
        settings == null ||
        recipient == null ||
        (recipient is GuestRecipient && guestErrors(recipient).isNotEmpty)) {
      return _failed;
    }

    final repository = _ref.read(bookingRepositoryProvider);
    final selector = _ref.read(bookingSelectionProvider.notifier);
    final recipients = _ref.read(bookingRecipientProvider.notifier);
    final now = _ref.read(clockProvider)();
    final day = salonDay(start);
    final String name;
    try {
      final data = await repository.fetchAdminBookingCheck(
        from: fromSalon(day),
        to: fromSalon(day.add(const Duration(days: 1))),
        now: now,
      );
      final closures = await fetchClosureRanges(_ref, day);
      final recipientUser = switch (recipient) {
        AccountRecipient(:final uid) =>
          await _ref.read(userRepositoryProvider).fetchUser(uid),
        GuestRecipient() => null,
      };
      final check = checkAdminBeforeSave(
        start: start,
        durationMinutes: bookable.durationMinutes,
        settings: settings,
        busy: [
          for (final slot in data.busy)
            (start: toSalon(slot.start), end: toSalon(slot.end)),
        ],
        closures: closures,
        active: data.active,
        recipient: recipient,
        recipientUser: recipientUser,
        users: _ref.read(adminUsersProvider).value ?? const [],
        nowSalon: toSalon(now),
      );
      switch (check) {
        case AdminCheckRecipientBlocked():
          // Una clienta bloqueada se quita; la persona sin cuenta se
          // conserva para cambiar su WhatsApp (RF-11, RF-15).
          if (recipient is AccountRecipient) recipients.dropBlocked();
          return const AdminBookingResult(AdminBookingOutcome.recipientBlocked);
        case AdminCheckPersonActive(:final appointment):
          return AdminBookingResult(
            AdminBookingOutcome.personActive,
            active: appointment,
          );
        case AdminCheckSlotTaken():
          selector.dropSlot();
          return const AdminBookingResult(AdminBookingOutcome.slotTaken);
        case AdminCheckDoesNotFit():
          selector.dropSlot();
          return const AdminBookingResult(AdminBookingOutcome.doesNotFit);
        case AdminCheckOk():
          break;
      }

      final addons = [
        for (final addon in availableAddons(catalog!, item!))
          if (selection.addonIds.contains(addon.id)) addon,
      ];
      // Guarda el servidor, que vuelve a comprobarlo todo (spec 012, D-1).
      final agenda = _ref.read(agendaFunctionsProvider);
      final saved = await agenda
          .book(
            id: const Uuid().v4(),
            start: fromSalon(start),
            booked: snapshotOf(bookable, addons),
            recipient: agendaRecipientOf(recipient),
          )
          .timeout(agenda.timeout);
      switch (saved.rejection) {
        case null:
          break;
        case AgendaRejection.personActive:
          // El texto de siempre necesita su turno: se vuelve a leer.
          final active = activeAppointmentOfPerson(
            await repository.fetchActiveAppointments(now),
            uid: recipient is AccountRecipient ? recipient.uid : null,
            phone: recipientUser?.phoneNumber ?? recipient.phone,
            now: now,
          );
          return active == null
              ? _failed
              : AdminBookingResult(
                  AdminBookingOutcome.personActive,
                  active: active,
                );
        case AgendaRejection.recipientBlocked:
          if (recipient is AccountRecipient) recipients.dropBlocked();
          return const AdminBookingResult(AdminBookingOutcome.recipientBlocked);
        case final rejection:
          final outcome = switch (bookingResultOf(rejection)) {
            BookingSubmitResult.slotTaken => AdminBookingOutcome.slotTaken,
            BookingSubmitResult.doesNotFit => AdminBookingOutcome.doesNotFit,
            BookingSubmitResult.itemUnavailable =>
              AdminBookingOutcome.itemUnavailable,
            BookingSubmitResult.itemChanged => AdminBookingOutcome.itemChanged,
            _ => AdminBookingOutcome.failed,
          };
          if (outcome == AdminBookingOutcome.slotTaken ||
              outcome == AdminBookingOutcome.doesNotFit) {
            selector.dropSlot();
          }
          return AdminBookingResult(outcome);
      }
      name = switch (recipient) {
        AccountRecipient() => recipientUser!.displayName,
        GuestRecipient(name: final guestName) => guestName.trim(),
      };
    } catch (error) {
      debugPrint('No se pudo agendar el turno de la admin: $error');
      return _failed;
    }
    selector.reset();
    recipients.clear();
    return AdminBookingResult(AdminBookingOutcome.ok, name: name);
  }
}

final adminBookingSubmitProvider = Provider(AdminBookingSubmitter.new);
