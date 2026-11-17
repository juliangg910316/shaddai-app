import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../../services/presentation/price_list_notices.dart';
import '../logic/booking_edit.dart';
import '../logic/booking_selection.dart';
import '../providers/booking_edit_provider.dart';
import '../providers/booking_provider.dart';
import 'edit_changes_dialog.dart';

/// No se pudo cargar la ficha o los turnos: "Reintentar" los vuelve a pedir
/// (spec 005, RF-49). Con [schedule], lo que no se pudo cargar es el
/// calendario o los turnos ocupados: "Reintentar" los vuelve a pedir, y
/// también ofrece WhatsApp (RF-48). Nunca muestra el error técnico.
class BookingLoadErrorNotice extends ConsumerWidget {
  const BookingLoadErrorNotice({super.key, this.schedule = false});

  final bool schedule;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return AppNotice(
      message: l10n.bookingLoadError,
      actions: [
        AppNoticeButton(
          label: l10n.bookingRetry,
          onPressed: () {
            if (schedule) {
              ref.invalidate(calendarSettingsProvider);
              ref.invalidate(busySlotsProvider);
            } else {
              ref.invalidate(currentUserProvider);
              ref.invalidate(myAppointmentsProvider);
            }
          },
        ),
        if (schedule) const WhatsappNoticeButton(),
      ],
    );
  }
}

/// La cuenta está bloqueada: no puede reservar, y puede escribir por
/// WhatsApp (RF-37, RF-38).
class BookingBlockedNotice extends StatelessWidget {
  const BookingBlockedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return AppNotice(
      message: AppLocalizations.of(context)!.bookingBlocked,
      actions: const [WhatsappNoticeButton()],
    );
  }
}

/// El texto de [notice] en el idioma activo (plan, D-7).
String bookingNoticeMessage(AppLocalizations l10n, BookingNotice notice) {
  final duration = formatDuration(notice.minutes ?? 0);
  return switch (notice.kind) {
    BookingNoticeKind.needsLongerSlot => l10n.bookingServiceNeedsLongerSlot(
      duration,
    ),
    BookingNoticeKind.slotTooShortFor => l10n.bookingSlotTooShortFor(duration),
    BookingNoticeKind.slotGone => l10n.bookingSlotGone,
    BookingNoticeKind.slotNoLongerFits => l10n.bookingSlotNoLongerFits,
    BookingNoticeKind.itemUnavailable => l10n.bookingItemUnavailable,
    BookingNoticeKind.dateMoved => l10n.bookingDateMoved,
    BookingNoticeKind.editItemChanged => _itemChangedMessage(l10n, notice),
    BookingNoticeKind.editItemDoesNotFit => l10n.bookingEditItemDoesNotFit(
      notice.name?.of(l10n.localeName) ?? '',
      duration,
      formatDuration(notice.freeMinutes ?? 0),
    ),
    BookingNoticeKind.editAddonsUnavailable =>
      l10n.bookingEditAddonsUnavailable,
    BookingNoticeKind.editNotActive => l10n.bookingEditNotActive,
  };
}

/// "Cambiaste el servicio:" y, debajo, lo que cambia con el antes y el
/// después: servicio, adicionales, fin, duración y total (spec 006, RF-28).
String _itemChangedMessage(AppLocalizations l10n, BookingNotice notice) {
  final before = notice.before;
  final after = notice.after;
  if (before == null || after == null) return l10n.bookingEditItemChanged;
  final changes = changedFields(before, after);
  final lines = [
    for (final field in EditField.values)
      if (changes.contains(field))
        l10n.bookingEditChangeLine(
          editFieldLabel(l10n, field),
          editFieldValue(l10n, field, before),
          editFieldValue(l10n, field, after),
        ),
  ];
  if (lines.isEmpty) return l10n.bookingEditItemChanged;
  return '${l10n.bookingEditItemChanged}\n${lines.join(' · ')}';
}

/// Un aviso de la selección, traducido en su `build`: si cambia el idioma
/// con el aviso abierto, también cambia (RF-50).
class BookingNoticeText extends StatelessWidget {
  const BookingNoticeText(this.notice, {super.key});

  final BookingNotice notice;

  @override
  Widget build(BuildContext context) =>
      Text(bookingNoticeMessage(AppLocalizations.of(context)!, notice));
}

/// Muestra [notice] en un `SnackBar` y lo anuncia al lector de pantalla
/// (RNF-2).
void showBookingNotice(BuildContext context, BookingNotice notice) {
  ScaffoldMessenger.of(context)
      .showSnackBar(SnackBar(content: BookingNoticeText(notice)));
  SemanticsService.sendAnnouncement(
    View.of(context),
    bookingNoticeMessage(AppLocalizations.of(context)!, notice),
    Directionality.of(context),
  );
}

/// Un `SnackBar` con [content]. Un error va sobre el color de peligro, con
/// el texto en el color de fondo: es el mismo par que el texto de peligro
/// sobre el fondo, así que cumple AA en los dos temas (RNF-2). El dorado de
/// los avisos normales no se lee sobre el peligro.
SnackBar _resultSnackBar(
  BuildContext context,
  Widget content, {
  required bool isError,
}) {
  if (!isError) return SnackBar(content: content);
  final brand = context.brand;
  return SnackBar(
    backgroundColor: brand.danger,
    content: DefaultTextStyle.merge(
      style: TextStyle(color: brand.background),
      child: content,
    ),
  );
}

/// Muestra en un `SnackBar` el texto que da [message], traducido en su
/// `build` para que cambie con el idioma, y lo anuncia al lector de
/// pantalla. Con [isError], sobre el color de peligro.
void showBookingMessage(
  BuildContext context,
  String Function(AppLocalizations l10n) message, {
  bool isError = false,
}) {
  ScaffoldMessenger.of(context).showSnackBar(
    _resultSnackBar(context, _MessageText(message), isError: isError),
  );
  SemanticsService.sendAnnouncement(
    View.of(context),
    message(AppLocalizations.of(context)!),
    Directionality.of(context),
  );
}

class _MessageText extends StatelessWidget {
  const _MessageText(this.message);

  final String Function(AppLocalizations l10n) message;

  @override
  Widget build(BuildContext context) =>
      Text(message(AppLocalizations.of(context)!));
}

/// El aviso de "Agendar turno" según [result] (RF-29 a RF-32, RF-36).
String bookingSubmitMessage(
  AppLocalizations l10n,
  BookingSubmitResult result,
) => switch (result) {
  BookingSubmitResult.ok => l10n.bookingCreatedSuccess,
  BookingSubmitResult.slotTaken => l10n.bookingSlotTaken,
  BookingSubmitResult.doesNotFit => l10n.bookingSlotNoLongerFits,
  BookingSubmitResult.alreadyActive => l10n.bookingAlreadyActive,
  BookingSubmitResult.failed => l10n.bookingCreateError,
};

/// Muestra el resultado de "Agendar turno" en un `SnackBar`, que traduce en
/// su `build` (RF-50), y lo anuncia al lector de pantalla (RNF-2). Un error
/// va sobre el color de peligro, sin detalles técnicos (RF-31).
void showBookingSubmitResult(BuildContext context, BookingSubmitResult result) {
  ScaffoldMessenger.of(context).showSnackBar(
    _resultSnackBar(
      context,
      _SubmitText(result),
      isError: result == BookingSubmitResult.failed,
    ),
  );
  SemanticsService.sendAnnouncement(
    View.of(context),
    bookingSubmitMessage(AppLocalizations.of(context)!, result),
    Directionality.of(context),
  );
}

class _SubmitText extends StatelessWidget {
  const _SubmitText(this.result);

  final BookingSubmitResult result;

  @override
  Widget build(BuildContext context) =>
      Text(bookingSubmitMessage(AppLocalizations.of(context)!, result));
}

/// El aviso de "Guardar cambios" según [outcome] (spec 006, RF-14 a RF-16):
/// la hora ocupada o sin sitio, como en la 005; un texto distinto si ya no
/// es editable, ya no está activo o cambió; y el error, sin detalles.
String editSaveMessage(AppLocalizations l10n, EditSaveOutcome outcome) =>
    switch (outcome) {
      EditSaveOutcome.ok => l10n.bookingEditSavedTitle,
      EditSaveOutcome.slotTaken => l10n.bookingSlotTaken,
      EditSaveOutcome.doesNotFit => l10n.bookingSlotNoLongerFits,
      EditSaveOutcome.notEditable => l10n.bookingEditNotEditable,
      EditSaveOutcome.notActive => l10n.bookingEditNotActive,
      EditSaveOutcome.changed => l10n.bookingEditChangedMeanwhile,
      EditSaveOutcome.failed => l10n.bookingEditSaveError,
    };

/// Muestra el resultado de "Guardar cambios" en un `SnackBar`, que traduce
/// en su `build`, y lo anuncia al lector de pantalla. El error va sobre el
/// color de peligro (RF-16).
void showEditSaveResult(BuildContext context, EditSaveOutcome outcome) {
  ScaffoldMessenger.of(context).showSnackBar(
    _resultSnackBar(
      context,
      _EditSaveText(outcome),
      isError: outcome == EditSaveOutcome.failed,
    ),
  );
  SemanticsService.sendAnnouncement(
    View.of(context),
    editSaveMessage(AppLocalizations.of(context)!, outcome),
    Directionality.of(context),
  );
}

class _EditSaveText extends StatelessWidget {
  const _EditSaveText(this.outcome);

  final EditSaveOutcome outcome;

  @override
  Widget build(BuildContext context) =>
      Text(editSaveMessage(AppLocalizations.of(context)!, outcome));
}
