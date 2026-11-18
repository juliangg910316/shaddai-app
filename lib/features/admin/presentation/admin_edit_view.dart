import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_colors.dart';
import '../../../data/models/appointment_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/logic/admin_edit.dart';
import '../../booking/logic/booking_rules.dart';
import '../../booking/logic/recipient.dart';
import '../../booking/logic/salon_time.dart';
import '../../booking/presentation/booking_form.dart';
import '../../booking/presentation/booking_notices.dart';
import '../../booking/presentation/edit_changes_dialog.dart';
import '../../booking/presentation/recipient_picker.dart';
import '../../booking/providers/admin_booking_provider.dart';
import '../../booking/providers/admin_edit_provider.dart';
import '../../booking/providers/booking_provider.dart';
import '../../services/presentation/price_list_notices.dart';
import '../../services/providers/price_list_provider.dart';
import '../providers/admin_provider.dart';
import 'admin_navigation.dart';

/// La edición de un turno por la admin (spec 008, RF-19 a RF-35): el
/// formulario de reserva con la persona, el día, la hora y lo reservado del
/// turno, "Guardar cambios" y "Cancelar".
///
/// Al abrirse empieza la edición en cuanto llega el turno; si no existe o ya
/// no está activo, lo dice y ofrece volver a la agenda. Al salir por
/// cualquier camino (guardar, "Cancelar", atrás), la edición termina y vuelve
/// lo que la admin tenía elegido para agendar (RF-33, RF-35).
class AdminAppointmentEditView extends ConsumerStatefulWidget {
  const AdminAppointmentEditView({super.key, required this.appointmentId});

  final String appointmentId;

  @override
  ConsumerState<AdminAppointmentEditView> createState() =>
      _AdminAppointmentEditViewState();
}

class _AdminAppointmentEditViewState
    extends ConsumerState<AdminAppointmentEditView> {
  // Creados en `initState`: `dispose` los usa (MEMORY).
  late final AdminEditController _editor;
  final _scroll = ScrollController();
  bool _started = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _editor = ref.read(adminEditProvider.notifier);
  }

  @override
  void dispose() {
    _scroll.dispose();
    // Fuera del desmontaje del árbol, donde no se puede cambiar un provider.
    final editor = _editor;
    scheduleMicrotask(editor.end);
    super.dispose();
  }

  bool _isActive(AppointmentModel appointment) {
    final now =
        ref.read(salonNowProvider).value ?? toSalon(ref.read(clockProvider)());
    return activeStatuses.contains(appointment.status) &&
        toSalon(appointment.endTime).isAfter(now);
  }

  /// Empieza la edición una sola vez, en el fotograma siguiente: no se cambia
  /// un provider mientras se construye la vista.
  void _start(AppointmentModel appointment) {
    _started = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _editor.start(appointment);
    });
  }

  void _leave() => closeAdminEdit(context, ref);

  /// "Guardar cambios" con todo elegido (RF-26 a RF-31).
  Future<void> _confirm() async {
    final original = ref.read(editTargetProvider);
    final recipient = ref.read(bookingRecipientProvider).recipient;
    final catalog = switch (ref.read(bookableCatalogProvider)) {
      PriceViewReady(:final value) => value,
      _ => null,
    };
    if (original != null &&
        recipient != null &&
        catalog != null &&
        adminEditChanges(
          original,
          recipient,
          ref.read(bookingSelectionProvider).selection,
          catalog,
        ).isEmpty) {
      showBookingMessage(context, (l10n) => l10n.adminEditNoChanges);
      return;
    }
    if (await confirmEditChanges(context, admin: true) != true || !mounted) {
      return;
    }

    setState(() => _saving = true);
    final result = await _editor.save();
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result.outcome) {
      case AdminEditOutcome.ok:
        // La agenda se abre en el día del turno (RF-28).
        final day = result.day!;
        ref.read(adminSelectedDateProvider.notifier).state = DateTime(
          day.year,
          day.month,
          day.day,
        );
        final name = result.name ?? '';
        showBookingMessage(context, (l10n) => l10n.adminEditSaved(name));
        _leave();
      case AdminEditOutcome.noChanges:
        showBookingMessage(context, (l10n) => l10n.adminEditNoChanges);
      case AdminEditOutcome.incomplete:
        // "Guardar cambios" ya marca lo que falta antes de llegar aquí.
        break;
      case AdminEditOutcome.slotTaken:
        showBookingSubmitResult(context, BookingSubmitResult.slotTaken);
      case AdminEditOutcome.doesNotFit:
        showBookingSubmitResult(context, BookingSubmitResult.doesNotFit);
      case AdminEditOutcome.failed:
        showBookingSubmitResult(context, BookingSubmitResult.failed);
      case AdminEditOutcome.personActive:
        final active = result.active!;
        showBookingMessage(
          context,
          (l10n) => activeAppointmentMessage(l10n, active),
        );
      case AdminEditOutcome.recipientBlocked:
        // La clienta con cuenta ya se quitó y su aviso llega por los avisos
        // de "Para quién"; la persona sin cuenta se conserva (spec 007).
        if (ref.read(bookingRecipientProvider).recipient is GuestRecipient) {
          showBookingMessage(
            context,
            (l10n) => l10n.bookingGuestPhoneBlocked,
            isError: true,
          );
        }
      case AdminEditOutcome.notActive:
        _alert(AdminEditAlert.notActive);
      case AdminEditOutcome.changed:
        _alert(AdminEditAlert.changed);
    }
  }

  /// El turno ya no está activo o alguien lo cambió: lo dice y vuelve a la
  /// agenda sin guardar (RF-30).
  void _alert(AdminEditAlert alert) {
    showBookingMessage(
      context,
      (l10n) => switch (alert) {
        AdminEditAlert.notActive => l10n.adminEditNotActive,
        AdminEditAlert.changed => l10n.adminEditChanged,
      },
      isError: true,
    );
    _leave();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final id = widget.appointmentId;

    // La vigilancia: si el turno cambia mientras se edita (RF-30).
    ref.listen(adminEditAlertProvider, (_, alert) {
      if (alert != null) _alert(alert);
    });
    // Los avisos de lo elegido y de "Para quién", como en la reserva.
    ref.listen(bookingSelectionProvider.select((state) => state.notices), (
      _,
      notices,
    ) {
      if (notices.isEmpty) return;
      ref.read(bookingSelectionProvider.notifier).consumeNotices();
      for (final notice in notices) {
        showBookingNotice(context, notice);
      }
    });
    ref.listen(bookingRecipientProvider.select((state) => state.notices), (
      _,
      notices,
    ) {
      if (notices.isEmpty) return;
      ref.read(bookingRecipientProvider.notifier).consumeNotices();
      if (notices.contains(RecipientNotice.blocked)) {
        showBookingMessage(
          context,
          (l10n) => l10n.bookingRecipientBlocked,
          isError: true,
        );
      }
    });

    final appointment = ref.watch(adminEditAppointmentProvider(id));
    final editing = ref.watch(adminEditProvider) == id;
    final Widget body;
    if (editing) {
      body = BookingForm(
        editing: true,
        admin: true,
        showTitle: false,
        scrollController: _scroll,
        onConfirmed: _confirm,
        onCancel: _leave,
      );
    } else if (appointment.hasError) {
      body = const _Message(child: BookingLoadErrorNotice());
    } else if (!appointment.hasValue || _started) {
      body = const Center(child: CircularProgressIndicator(strokeWidth: 2));
    } else if (appointment.value case final value? when _isActive(value)) {
      _start(value);
      body = const Center(child: CircularProgressIndicator(strokeWidth: 2));
    } else {
      body = _Message(
        child: AppNotice(
          message: l10n.adminEditNotFound,
          actions: [
            AppNoticeButton(
              label: l10n.adminEditBackToAgenda,
              onPressed: _leave,
            ),
          ],
        ),
      );
    }

    return Scaffold(
      backgroundColor: brand.background,
      appBar: AppBar(title: Text(l10n.bookingEditTitle)),
      body: Stack(
        children: [
          body,
          if (_saving)
            Container(
              color: brand.brand.withValues(alpha: 0.45),
              child: Center(
                child: CircularProgressIndicator(
                  color: brand.onBrand,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
    children: [child],
  );
}
