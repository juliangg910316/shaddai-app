import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/capitalize.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/appointment_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../../services/presentation/price_list_notices.dart';
import '../logic/booking_edit.dart';
import '../logic/salon_time.dart';
import '../providers/booking_edit_provider.dart';
import 'booking_notices.dart';
import 'cancel_appointment.dart';

/// El turno activo de la clienta, en lugar del formulario: lo reservado con
/// sus adicionales, el día, la franja en hora del salón, el total y el
/// estado (spec 005, RF-33, RF-34, RF-46). Si la cuenta está bloqueada,
/// también su aviso (RF-37).
///
/// Debajo, según si se puede editar (spec 006, RF-1 a RF-3, RF-22): el botón
/// "Editar turno", la explicación de que ya no se puede cambiar con WhatsApp,
/// o el error del calendario con "Reintentar". Bloqueada, solo su aviso (D-6).
///
/// Al final, "Cancelar turno" mientras se puede cancelar, también si está
/// bloqueada (spec 009, RF-8, D-5).
class ActiveAppointmentView extends ConsumerWidget {
  const ActiveAppointmentView({
    super.key,
    required this.appointment,
    this.isBlocked = false,
  });

  final AppointmentModel appointment;
  final bool isBlocked;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final locale = l10n.localeName;
    final booked = appointment.booked;
    final start = toSalon(appointment.startTime);
    final end = toSalon(appointment.endTime);
    final hm = DateFormat.Hm(locale);
    final status = appointment.status == 'confirmed'
        ? l10n.statusConfirmedClient
        : l10n.statusWaitingConfirmationClient;

    final body = AppText.sans(size: 15, color: brand.ink, height: 1.5);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.bookingActiveTitle,
          style: AppText.serif(size: 24, color: brand.inkStrong),
        ),
        const SizedBox(height: 16),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: brand.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: brand.hairline),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(status, style: AppText.eyebrow(color: brand.accentText)),
              if (booked != null) ...[
                const SizedBox(height: 10),
                Text(
                  booked.name.of(locale),
                  style: AppText.serif(size: 20, color: brand.inkStrong),
                ),
                for (final addon in booked.addons)
                  Text(
                    '${addon.name.of(locale)} · '
                    '${formatPrice(addon.priceCents, addon: true)}',
                    style: body,
                  ),
              ],
              const SizedBox(height: 10),
              Text(
                capitalizeFirst(DateFormat.yMMMMEEEEd(locale).format(start)),
                style: body,
              ),
              Text(
                l10n.bookingTimeRange(hm.format(start), hm.format(end)),
                style: body,
              ),
              if (booked != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(child: Text(l10n.bookingTotal, style: body)),
                    Text(
                      formatPrice(
                        booked.totalCents,
                        from: booked.priceFrom ? l10n.priceFrom : null,
                      ),
                      style: AppText.sans(
                        size: 15,
                        weight: FontWeight.w600,
                        color: brand.inkStrong,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.bookingOnlyOneActive,
          style: AppText.sans(size: 14, color: brand.inkMuted, height: 1.5),
        ),
        if (isBlocked) const BookingBlockedNotice(),
        switch (ref.watch(editAvailabilityProvider)) {
          EditAvailability.editable => Padding(
            padding: const EdgeInsets.only(top: 20),
            child: GoldPillButton(
              label: l10n.bookingEditAction.toUpperCase(),
              // La edición es otra lista, que empieza arriba (RF-4).
              onPressed: () =>
                  ref.read(editTargetProvider.notifier).start(appointment),
            ),
          ),
          EditAvailability.closed => AppNotice(
            message: l10n.bookingEditClosed,
            actions: const [WhatsappNoticeButton()],
          ),
          EditAvailability.error => const BookingLoadErrorNotice(
            schedule: true,
          ),
          EditAvailability.blocked ||
          EditAvailability.loading ||
          null => const SizedBox.shrink(),
        },
        // "Cancelar turno", mientras se puede cancelar; también bloqueada
        // (spec 009, RF-8, D-5).
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: CancelAppointmentButton(appointment: appointment),
        ),
      ],
    );
  }
}
