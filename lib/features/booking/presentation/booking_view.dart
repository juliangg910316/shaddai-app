import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/platform_provider.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../navigation/providers/tab_scroll_provider.dart';
import '../logic/bookable_catalog.dart';
import '../../services/providers/price_list_provider.dart';
import '../logic/booking_edit.dart';
import '../logic/booking_rules.dart';
import '../logic/recipient.dart';
import '../providers/admin_booking_provider.dart';
import '../providers/booking_edit_provider.dart';
import '../providers/booking_provider.dart';
import 'active_appointment_view.dart';
import 'booking_form.dart';
import 'booking_notices.dart';
import 'booking_sign_in_prompt.dart';
import 'edit_changes_dialog.dart';
import 'recipient_picker.dart';

class BookingView extends ConsumerStatefulWidget {
  const BookingView({super.key, this.request});

  /// El servicio o combo pedido en la dirección (`/booking?service=<id>`),
  /// que se elige al llegar (spec 005, RF-40 a RF-44).
  final BookableRef? request;

  @override
  ConsumerState<BookingView> createState() => _BookingViewState();
}

class _BookingViewState extends ConsumerState<BookingView> {
  bool _isBooking = false;

  @override
  void initState() {
    super.initState();
    _applyRequest();
  }

  @override
  void didUpdateWidget(BookingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.request != oldWidget.request) _applyRequest();
  }

  /// Elige lo pedido una vez, en el fotograma siguiente: no se cambia un
  /// provider mientras se construye la vista. Sin petición, se conserva lo
  /// elegido (RF-45).
  void _applyRequest() {
    final request = widget.request;
    if (request == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(bookingSelectionProvider.notifier).requestItem(request);
    });
  }

  /// En Web, la reserva creada se confirma en un diálogo que ofrece volver a
  /// la landing (spec 002, RF-22): un aviso que se va solo no es fiable con
  /// teclado ni con lector de pantalla.
  Future<void> _showBookedDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        final brand = dialogContext.brand;
        return AlertDialog(
          title: Text(l10n.bookingCreatedWebTitle),
          content: Text(l10n.bookingCreatedSuccess),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                MaterialLocalizations.of(dialogContext).closeButtonLabel,
                style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  spacing: 1.2,
                  color: brand.inkMuted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go('/');
              },
              child: Text(
                l10n.bookingBackToLanding,
                style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w600,
                  spacing: 1.2,
                  color: brand.onBrand,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  /// [slot] es la hora de pared del salón.
  /// Guarda el turno confirmado y avisa de cómo fue (RF-26 a RF-32,
  /// RF-36). Tras guardarlo, la vista pasa sola al turno activo, porque los
  /// turnos de la clienta llegan en vivo.
  Future<void> _submit() async {
    setState(() => _isBooking = true);
    final result = await ref.read(bookingSubmitProvider).confirm();
    if (!mounted) return;
    setState(() => _isBooking = false);
    switch (result) {
      case BookingSubmitResult.ok when ref.read(isWebProvider):
        await _showBookedDialog();
      case BookingSubmitResult.alreadyActive:
        // Reservado desde otro dispositivo: se vuelven a pedir sus turnos
        // para mostrar el que tiene, aunque aún no hayan llegado.
        ref.invalidate(myAppointmentsProvider);
        showBookingSubmitResult(context, result);
      default:
        showBookingSubmitResult(context, result);
    }
  }

  /// Guarda el turno que agenda la admin y avisa de cómo fue (spec 007,
  /// RF-14, RF-15, RF-18 a RF-20). Con `ok`, la selección y para quién ya
  /// quedaron vacíos: la vista sube al principio para agendar otro, también
  /// en Web, sin el diálogo de volver a la landing.
  Future<void> _submitAdmin() async {
    setState(() => _isBooking = true);
    final result = await ref.read(adminBookingSubmitProvider).confirm();
    if (!mounted) return;
    setState(() => _isBooking = false);
    switch (result.outcome) {
      case AdminBookingOutcome.ok:
        final name = result.name ?? '';
        showBookingMessage(context, (l10n) => l10n.bookingAdminCreated(name));
        final scroll = ref.read(tabScrollControllerProvider(MobileTab.booking));
        if (scroll.hasClients) scroll.jumpTo(0);
      case AdminBookingOutcome.slotTaken:
        showBookingSubmitResult(context, BookingSubmitResult.slotTaken);
      case AdminBookingOutcome.doesNotFit:
        showBookingSubmitResult(context, BookingSubmitResult.doesNotFit);
      case AdminBookingOutcome.failed:
        showBookingSubmitResult(context, BookingSubmitResult.failed);
      case AdminBookingOutcome.personActive:
        final active = result.active!;
        showBookingMessage(
          context,
          (l10n) => activeAppointmentMessage(l10n, active),
        );
      case AdminBookingOutcome.recipientBlocked:
        // Una clienta con cuenta ya se quitó y su aviso llega por los
        // avisos de "Para quién"; la persona sin cuenta se conserva para
        // cambiar el WhatsApp (RF-11, RF-15).
        if (ref.read(bookingRecipientProvider).recipient is GuestRecipient) {
          showBookingMessage(
            context,
            (l10n) => l10n.bookingGuestPhoneBlocked,
            isError: true,
          );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    // La clienta elegida se bloqueó y se quitó de "Para quién" (spec 007,
    // RF-15).
    ref.listen(bookingRecipientProvider.select((state) => state.notices), (
      _,
      notices,
    ) {
      if (notices.isEmpty) return;
      ref.read(bookingRecipientProvider.notifier).consumeNotices();
      for (final notice in notices) {
        switch (notice) {
          case RecipientNotice.blocked:
            showBookingMessage(
              context,
              (l10n) => l10n.bookingRecipientBlocked,
              isError: true,
            );
        }
      }
    });

    // Los avisos de lo elegido, en un SnackBar que también se anuncia
    // (RF-9, RF-13, RF-15 a RF-17; RNF-2).
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

    // Qué ve la clienta (spec 005, RF-33 a RF-39, RF-49). Sin sesión, el
    // aviso para iniciarla (spec 003, RF-16); en Web no se llega aquí sin
    // sesión: la redirección pide antes iniciarla.
    return switch (ref.watch(bookingScreenProvider)) {
      BookingScreenLoading() => const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      ),
      BookingScreenSignedOut() => const BookingSignInPrompt(),
      BookingScreenError() => const _StatePage(child: BookingLoadErrorNotice()),
      // La admin agenda para otra persona (spec 007, RF-1, RF-28).
      BookingScreenAdmin() => _buildForm(context, admin: true),
      BookingScreenActive(:final appointment, :final isBlocked) => _StatePage(
        child: ActiveAppointmentView(
          appointment: appointment,
          isBlocked: isBlocked,
        ),
      ),
      BookingScreenBlocked() => const _StatePage(child: BookingBlockedNotice()),
      BookingScreenBooking() => _buildForm(context),
      // La edición del turno activo (spec 006, RF-4).
      BookingScreenEditing() => _buildForm(context, editing: true),
    };
  }

  /// "Guardar cambios" con todo elegido: pide confirmar el antes y el
  /// después (spec 006, RF-11), guarda y avisa de cómo fue (RF-12 a RF-17).
  /// El antes y el después se toman antes de guardar, porque al guardar
  /// termina la edición; la vista pasa sola al turno, que llega en vivo.
  Future<void> _confirmEdit() async {
    if (await confirmEditChanges(context) != true || !mounted) return;
    final original = ref.read(editTargetProvider);
    final after = switch (ref.read(bookableCatalogProvider)) {
      PriceViewReady(:final value) => draftOfSelection(
        ref.read(bookingSelectionProvider).selection,
        value,
      ),
      _ => null,
    };

    setState(() => _isBooking = true);
    final result = await ref.read(bookingEditSaveProvider).save();
    if (!mounted) return;
    setState(() => _isBooking = false);
    if (result.outcome == EditSaveOutcome.ok &&
        original != null &&
        after != null) {
      await showEditSavedDialog(
        context,
        before: draftOfOriginal(original),
        after: after,
        changes: result.changes,
      );
    } else {
      showEditSaveResult(context, result.outcome);
    }
  }

  Widget _buildForm(
    BuildContext context, {
    bool editing = false,
    bool admin = false,
  }) {
    final brand = context.brand;

    return Scaffold(
      body: Stack(
        children: [
          BookingForm(
            editing: editing,
            admin: admin,
            onConfirmed: editing
                ? _confirmEdit
                : admin
                ? _submitAdmin
                : _submit,
          ),
          if (_isBooking)
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

/// Una página de la pestaña con un solo estado: un aviso o el turno activo,
/// con desplazamiento para el texto grande.
class _StatePage extends ConsumerWidget {
  const _StatePage({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          controller: ref.watch(tabScrollControllerProvider(MobileTab.booking)),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
          children: [child],
        ),
      ),
    );
  }
}
