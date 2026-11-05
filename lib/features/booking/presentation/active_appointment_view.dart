import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/capitalize.dart';
import '../../../data/models/appointment_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../logic/salon_time.dart';
import 'booking_notices.dart';

/// El turno activo de la clienta, en lugar del formulario: lo reservado con
/// sus adicionales, el día, la franja en hora del salón, el total y el
/// estado (spec 005, RF-33, RF-34, RF-46). Si la cuenta está bloqueada,
/// también su aviso (RF-37).
class ActiveAppointmentView extends StatelessWidget {
  const ActiveAppointmentView({
    super.key,
    required this.appointment,
    this.isBlocked = false,
  });

  final AppointmentModel appointment;
  final bool isBlocked;

  @override
  Widget build(BuildContext context) {
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
      ],
    );
  }
}
