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
import '../providers/admin_booking_provider.dart';
import '../providers/booking_provider.dart';
import 'book_button.dart';

/// Pide confirmar los cambios de la edición (spec 006, RF-11): el turno de
/// antes y el de después, con lo que cambia marcado, y el aviso de que
/// volverá a esperar la confirmación. `true` si se confirma.
///
/// El antes y el después se calculan dentro del diálogo: si cambia el idioma
/// con el diálogo abierto, también cambian sus textos.
///
/// Con [admin], es la edición de la admin (spec 008, RF-27): empieza por
/// para quién, dice que el turno quedará confirmado y, con una clienta con
/// cuenta, avisa si ya no lo podrá cambiar por el margen.
Future<bool?> confirmEditChanges(BuildContext context, {bool admin = false}) =>
    showDialog<bool>(
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
                _CurrentChanges(admin: admin),
                const SizedBox(height: 16),
                Text(
                  admin
                      ? l10n.bookingAdminConfirmNote
                      : l10n.bookingEditConfirmPending,
                  style: AppText.sans(size: 14, color: brand.inkMuted),
                ),
                if (admin) const BookingMarginWarning(admin: true),
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

/// El antes (el turno en edición) y el después (lo elegido ahora). Con
/// [admin], también la persona.
class _CurrentChanges extends ConsumerWidget {
  const _CurrentChanges({required this.admin});

  final bool admin;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final original = ref.watch(editTargetProvider);
    final selection = ref.watch(bookingSelectionProvider).selection;
    final after = switch (ref.watch(bookableCatalogProvider)) {
      PriceViewReady(:final value) => draftOfSelection(selection, value),
      _ => null,
    };
    if (original == null || after == null) return const SizedBox.shrink();
    final recipient = admin
        ? ref.watch(bookingRecipientProvider).recipient
        : null;
    return EditChangesTable(
      before: draftOfOriginal(original),
      after: after,
      person: recipient == null
          ? null
          : (before: original.clientName, after: recipient.name.trim()),
    );
  }
}

/// La tabla de antes y después (RF-11): una fila por valor (fecha, inicio,
/// fin, servicio, adicionales, duración y total). En las que cambian, el
/// valor de antes, una flecha y el de después en negrita, y "cambia" para el
/// lector de pantalla; en las demás, un solo valor.
///
/// Con [person], la primera fila es para quién (spec 008, RF-27).
class EditChangesTable extends StatelessWidget {
  const EditChangesTable({
    super.key,
    required this.before,
    required this.after,
    this.person,
  });

  final BookingDraft before;
  final BookingDraft after;
  final ({String before, String after})? person;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final changed = changedFields(before, after);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (person case (:final before, :final after))
          _ChangeRow(
            label: l10n.bookingStepRecipient,
            before: before,
            after: after,
            changed: before != after,
          ),
        for (final field in EditField.values)
          _ChangeRow(
            label: editFieldLabel(l10n, field),
            before: editFieldValue(l10n, field, before),
            after: editFieldValue(l10n, field, after),
            changed: changed.contains(field),
          ),
      ],
    );
  }
}

/// El nombre de [field] en el idioma activo.
String editFieldLabel(AppLocalizations l10n, EditField field) =>
    switch (field) {
      EditField.date => l10n.bookingStepDate,
      EditField.start => l10n.bookingEditStart,
      EditField.end => l10n.bookingEditEnd,
      EditField.item => l10n.bookingStepService,
      EditField.addons => l10n.bookingStepAddons,
      EditField.duration => l10n.bookingDuration,
      EditField.total => l10n.bookingTotal,
    };

/// El valor de [field] en [draft], en el idioma activo.
String editFieldValue(
  AppLocalizations l10n,
  EditField field,
  BookingDraft draft,
) {
  final locale = l10n.localeName;
  String time(DateTime? t) => t == null ? '' : DateFormat.Hm(locale).format(t);
  final day = draft.day;
  return switch (field) {
    EditField.date =>
      day == null
          ? ''
          : capitalizeFirst(DateFormat.yMMMMEEEEd(locale).format(day)),
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

/// "Cambios guardados" (spec 006, RF-17; plan D-7): lo que cambió, con el
/// antes y el después, o que no cambió nada, y que el turno vuelve a esperar
/// la confirmación. Los textos se escriben dentro del diálogo, así que siguen
/// el cambio de idioma.
Future<void> showEditSavedDialog(
  BuildContext context, {
  required BookingDraft before,
  required BookingDraft after,
  required Set<EditField> changes,
}) => showDialog<void>(
  context: context,
  builder: (context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final body = AppText.sans(size: 15, color: brand.ink, height: 1.5);
    return AlertDialog(
      title: Text(l10n.bookingEditSavedTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (changes.isEmpty)
              Text(l10n.bookingEditNoChanges, style: body)
            else
              for (final field in EditField.values)
                if (changes.contains(field))
                  Text(
                    l10n.bookingEditChangeLine(
                      editFieldLabel(l10n, field),
                      editFieldValue(l10n, field, before),
                      editFieldValue(l10n, field, after),
                    ),
                    style: body,
                  ),
            const SizedBox(height: 16),
            Text(
              l10n.bookingEditSavedPending,
              style: AppText.sans(size: 14, color: brand.inkMuted),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        ElevatedButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            MaterialLocalizations.of(context).closeButtonLabel,
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
