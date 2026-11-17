import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../logic/booking_edit.dart';
import '../logic/booking_selection.dart';
import '../logic/salon_time.dart';
import '../providers/admin_booking_provider.dart';
import '../providers/booking_provider.dart';
import 'booking_summary.dart';

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
/// Con [admin], también falta para quién (spec 007, RF-17).
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
              const BookingSummary(showTitle: false),
              const SizedBox(height: 16),
              Text(
                l10n.bookingConfirmPending,
                style: AppText.sans(size: 14, color: brand.inkMuted),
              ),
              const _MarginWarning(),
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

/// Si el turno que se va a reservar ya empieza dentro del margen de edición,
/// avisa de que no se podrá cambiar (spec 006, RF-23). Con margen 0 nunca
/// sale: una hora libre siempre es futura.
class _MarginWarning extends ConsumerWidget {
  const _MarginWarning();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
        AppLocalizations.of(context)!
            .bookingEditMarginWarning(formatDuration(margin)),
        style: AppText.sans(
          size: 14,
          weight: FontWeight.w600,
          color: brand.inkStrong,
        ),
      ),
    );
  }
}
