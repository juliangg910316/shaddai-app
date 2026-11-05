import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../logic/booking_selection.dart';
import '../providers/booking_provider.dart';
import 'booking_summary.dart';

/// El texto de lo que falta para agendar (RF-24).
String missingMessage(AppLocalizations l10n, Set<BookingPart> missing) =>
    missing.length > 1
    ? l10n.bookingMissingBoth
    : missing.contains(BookingPart.slot)
    ? l10n.bookingMissingSlot
    : l10n.bookingMissingService;

/// "Agendar turno", siempre activo (spec 005, RF-23). Si falta algo, lo dice
/// y llama a [onMissing] para que se marque cada parte (RF-24). Con todo
/// elegido, pide confirmación con el resumen (RF-25) y, si se confirma,
/// llama a [onConfirmed].
class BookButton extends ConsumerWidget {
  const BookButton({
    super.key,
    required this.onMissing,
    required this.onConfirmed,
  });

  final VoidCallback onMissing;
  final VoidCallback onConfirmed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return GoldPillButton(
      label: l10n.bookingAction.toUpperCase(),
      onPressed: () async {
        final missing = missingParts(
          ref.read(bookingSelectionProvider).selection,
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
        if (await _confirm(context) == true) onConfirmed();
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
