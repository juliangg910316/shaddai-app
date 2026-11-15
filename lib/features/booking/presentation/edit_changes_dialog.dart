import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/capitalize.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../../services/providers/price_list_provider.dart';
import '../logic/booking_edit.dart';
import '../providers/booking_provider.dart';

/// Pide confirmar los cambios de la edición (spec 006, RF-11): el turno de
/// antes y el de después, con lo que cambia marcado, y el aviso de que
/// volverá a esperar la confirmación. `true` si se confirma.
///
/// El antes y el después se calculan dentro del diálogo: si cambia el idioma
/// con el diálogo abierto, también cambian sus textos.
Future<bool?> confirmEditChanges(BuildContext context) => showDialog<bool>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    return AlertDialog(
      title: Text(l10n.bookingEditConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            const _CurrentChanges(),
            const SizedBox(height: 16),
            Text(
              l10n.bookingEditConfirmPending,
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

/// El antes (el turno en edición) y el después (lo elegido ahora).
class _CurrentChanges extends ConsumerWidget {
  const _CurrentChanges();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final original = ref.watch(editTargetProvider);
    final selection = ref.watch(bookingSelectionProvider).selection;
    final after = switch (ref.watch(bookableCatalogProvider)) {
      PriceViewReady(:final value) => draftOfSelection(selection, value),
      _ => null,
    };
    if (original == null || after == null) return const SizedBox.shrink();
    return EditChangesTable(before: draftOfOriginal(original), after: after);
  }
}

/// La tabla de antes y después (RF-11): una fila por valor (fecha, inicio,
/// fin, servicio, adicionales, duración y total). En las que cambian, el
/// valor de antes, una flecha y el de después en negrita, y "cambia" para el
/// lector de pantalla; en las demás, un solo valor.
class EditChangesTable extends StatelessWidget {
  const EditChangesTable({
    super.key,
    required this.before,
    required this.after,
  });

  final BookingDraft before;
  final BookingDraft after;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final locale = l10n.localeName;
    final changed = changedFields(before, after);
    final hm = DateFormat.Hm(locale);

    String label(EditField field) => switch (field) {
      EditField.date => l10n.bookingStepDate,
      EditField.start => l10n.bookingEditStart,
      EditField.end => l10n.bookingEditEnd,
      EditField.item => l10n.bookingStepService,
      EditField.addons => l10n.bookingStepAddons,
      EditField.duration => l10n.bookingDuration,
      EditField.total => l10n.bookingTotal,
    };

    String value(EditField field, BookingDraft draft) {
      String time(DateTime? t) => t == null ? '' : hm.format(t);
      return switch (field) {
        EditField.date =>
          draft.day == null
              ? ''
              : capitalizeFirst(
                  DateFormat.yMMMMEEEEd(locale).format(draft.day!),
                ),
        EditField.start => time(draft.start),
        EditField.end => time(draft.end),
        EditField.item => draft.name.of(locale),
        EditField.addons =>
          draft.addons.isEmpty
              ? l10n.bookingEditNoAddons
              : draft.addons.map((addon) => addon.of(locale)).join(', '),
        EditField.duration => formatDuration(draft.durationMinutes),
        EditField.total => formatPrice(
          draft.totalCents,
          from: draft.totalFrom ? l10n.priceFrom : null,
        ),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final field in EditField.values)
          _ChangeRow(
            label: label(field),
            before: value(field, before),
            after: value(field, after),
            changed: changed.contains(field),
          ),
      ],
    );
  }
}

class _ChangeRow extends StatelessWidget {
  const _ChangeRow({
    required this.label,
    required this.before,
    required this.after,
    required this.changed,
  });

  final String label;
  final String before;
  final String after;
  final bool changed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final body = AppText.sans(size: 15, color: brand.ink, height: 1.4);
    final strong = AppText.sans(
      size: 15,
      weight: FontWeight.w600,
      color: brand.inkStrong,
      height: 1.4,
    );

    return Semantics(
      container: true,
      label: changed
          ? '$label, ${l10n.bookingEditChangedLabel}. '
                '${l10n.bookingEditBefore}: $before. '
                '${l10n.bookingEditAfter}: $after.'
          : '$label: $after',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(label, style: AppText.sans(size: 13, color: brand.inkMuted)),
            if (changed)
              Text.rich(
                TextSpan(
                  style: body,
                  children: [
                    TextSpan(text: before),
                    const TextSpan(text: ' → '),
                    TextSpan(text: after, style: strong),
                  ],
                ),
              )
            else
              Text(after, style: body),
          ],
        ),
      ),
    );
  }
}
