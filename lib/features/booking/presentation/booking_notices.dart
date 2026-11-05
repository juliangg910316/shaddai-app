import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../../services/presentation/price_list_notices.dart';
import '../logic/booking_selection.dart';
import '../providers/booking_provider.dart';

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

/// La administradora no reserva turnos a su nombre (RF-39).
class BookingAdminNotice extends StatelessWidget {
  const BookingAdminNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return AppNotice(
      message: AppLocalizations.of(context)!.bookingAdminNotice,
      actions: const [],
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
  };
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
    SnackBar(
      content: _SubmitText(result),
      backgroundColor: result == BookingSubmitResult.failed
          ? context.brand.danger
          : null,
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
