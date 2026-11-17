import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/appointment_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../logic/booking_edit.dart';
import '../logic/booking_selection.dart';
import '../logic/recipient.dart';
import '../logic/salon_time.dart';
import '../providers/admin_booking_provider.dart';
import '../providers/booking_provider.dart';
import 'booking_summary.dart';
import 'recipient_picker.dart';

/// El texto de lo que falta para agendar (RF-24). Con para quién (spec 007,
/// RF-17), uno propio o, si falta algo más, el que pide revisar lo marcado.
String missingMessage(AppLocalizations l10n, Set<BookingPart> missing) =>
    missing.contains(BookingPart.recipient)
    ? (missing.length > 1
          ? l10n.bookingMissingSeveral
          : l10n.bookingMissingRecipient)
    : missing.length > 1
    ? l10n.bookingMissingBoth
    : missing.contains(BookingPart.slot)
    ? l10n.bookingMissingSlot
    : l10n.bookingMissingService;

/// "Agendar turno", siempre activo (spec 005, RF-23). Si falta algo, lo dice
/// y llama a [onMissing] para que se marque cada parte (RF-24). Con todo
/// elegido, pide confirmación con el resumen (RF-25) y, si se confirma,
/// llama a [onConfirmed].
///
/// Con [editing], es "Guardar cambios" de la edición (spec 006, RF-10): avisa
/// igual de lo que falta y, con todo elegido, llama a [onConfirmed], que se
/// encarga de confirmar los cambios.
///
/// Con [admin], también falta para quién (spec 007, RF-17); si la persona
/// ya tiene un turno activo, lo dice en lugar de confirmar (RF-14); y la
/// confirmación empieza por para quién y dice que quedará confirmado
/// (RF-16, RF-29).
class BookButton extends ConsumerWidget {
  const BookButton({
    super.key,
    required this.onMissing,
    required this.onConfirmed,
    this.editing = false,
    this.admin = false,
  });

  final VoidCallback onMissing;
  final VoidCallback onConfirmed;
  final bool editing;
  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return GoldPillButton(
      label: (editing ? l10n.bookingSaveChangesAction : l10n.bookingAction)
          .toUpperCase(),
      onPressed: () async {
        final missing = missingParts(
          ref.read(bookingSelectionProvider).selection,
          admin: admin,
          recipient: admin
              ? ref.read(bookingRecipientProvider).recipient
              : null,
        );
        if (missing.isNotEmpty) {
          onMissing();
          final message = missingMessage(l10n, missing);
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: _MissingText(missing)));
          SemanticsService.sendAnnouncement(
            View.of(context),
            message,
            Directionality.of(context),
          );
          return;
        }
        final active = admin
            ? ref.read(recipientActiveAppointmentProvider)
            : null;
        if (active != null) {
          onMissing();
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: _ActiveText(active)));
          SemanticsService.sendAnnouncement(
            View.of(context),
            activeAppointmentMessage(l10n, active),
            Directionality.of(context),
          );
          return;
        }
        if (editing) {
          onConfirmed();
        } else if (await _confirm(context) == true) {
          onConfirmed();
        }
      },
    );
  }

  Future<bool?> _confirm(BuildContext context) => showDialog<bool>(
    context: context,
    builder: (context) {
      // Textos dentro del builder: si cambia el idioma con el diálogo
      // abierto, el diálogo también cambia (RF-50).
      final l10n = AppLocalizations.of(context)!;
      final brand = context.brand;
      return AlertDialog(
        title: Text(l10n.bookingConfirmTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              BookingSummary(showTitle: false, admin: admin),
              const SizedBox(height: 16),
              Text(
                admin
                    ? l10n.bookingAdminConfirmNote
                    : l10n.bookingConfirmPending,
                style: AppText.sans(size: 14, color: brand.inkMuted),
              ),
              _MarginWarning(admin: admin),
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              l10n.cancelAction,
              style: AppText.sans(
                size: 12,
                weight: FontWeight.w500,
                spacing: 1.2,
                color: brand.inkMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              l10n.confirmAction,
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

/// Lo que falta, traducido en su `build` (RF-50).
class _MissingText extends StatelessWidget {
  const _MissingText(this.missing);

  final Set<BookingPart> missing;

  @override
  Widget build(BuildContext context) =>
      Text(missingMessage(AppLocalizations.of(context)!, missing));
}

/// El aviso del turno activo de la persona, traducido en su `build`.
class _ActiveText extends StatelessWidget {
  const _ActiveText(this.active);

  final AppointmentModel active;

  @override
  Widget build(BuildContext context) =>
      Text(activeAppointmentMessage(AppLocalizations.of(context)!, active));
}

/// Si el turno que se va a reservar ya empieza dentro del margen de edición,
/// avisa de que no se podrá cambiar (spec 006, RF-23). Con margen 0 nunca
/// sale: una hora libre siempre es futura.
///
/// Con [admin], el aviso nombra a la clienta, y no sale para una persona sin
/// cuenta, que no edita (spec 007, RF-29).
class _MarginWarning extends ConsumerWidget {
  const _MarginWarning({required this.admin});

  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recipient = admin
        ? ref.watch(bookingRecipientProvider.select((s) => s.recipient))
        : null;
    if (admin && recipient is! AccountRecipient) {
      return const SizedBox.shrink();
    }
    final start = ref.watch(bookingSelectionProvider).selection.start;
    final margin =
        ref.watch(calendarSettingsProvider).value?.editMarginMinutes ?? 0;
    if (start == null || margin <= 0) return const SizedBox.shrink();
    final now =
        ref.watch(salonNowProvider).value ?? toSalon(ref.read(clockProvider)());
    if (!startsWithinEditMargin(
      start: fromSalon(start),
      now: fromSalon(now),
      marginMinutes: margin,
    )) {
      return const SizedBox.shrink();
    }
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Text(
        recipient == null
            ? AppLocalizations.of(context)!
                  .bookingEditMarginWarning(formatDuration(margin))
            : AppLocalizations.of(context)!.bookingAdminMarginWarning(
                recipient.name,
                formatDuration(margin),
              ),
        style: AppText.sans(
          size: 14,
          weight: FontWeight.w600,
          color: brand.inkStrong,
        ),
      ),
    );
  }
}
