import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/capitalize.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/appointment_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/logic/salon_time.dart';
import '../../booking/presentation/active_appointment_view.dart';
import '../../services/logic/price_list_view_logic.dart';

/// El turno activo en el perfil (spec 009, RF-1 a RF-4, RF-8, RF-44): el
/// estado, el día y la fecha, la franja en hora del salón, el servicio y los
/// adicionales (sin servicio si es anterior a la spec 005), y debajo las
/// mismas acciones que en Reservas. "Editar turno" lleva a Reservas.
class ProfileActiveCard extends ConsumerWidget {
  const ProfileActiveCard({
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

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: brand.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: appointment.status == 'confirmed'
              ? brand.hairline
              : brand.goldHairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(status, style: AppText.eyebrow(color: brand.accentText)),
          const SizedBox(height: 10),
          Text(
            capitalizeFirst(DateFormat.yMMMMEEEEd(locale).format(start)),
            style: AppText.serif(size: 20, color: brand.inkStrong),
          ),
          Text(
            l10n.bookingTimeRange(hm.format(start), hm.format(end)),
            style: body,
          ),
          if (booked != null) ...[
            const SizedBox(height: 10),
            Text(
              booked.name.of(locale),
              style: AppText.sans(
                size: 15,
                weight: FontWeight.w600,
                color: brand.inkStrong,
              ),
            ),
            for (final addon in booked.addons)
              Text(
                '${addon.name.of(locale)} · '
                '${formatPrice(addon.priceCents, addon: true)}',
                style: body,
              ),
          ],
          ActiveAppointmentActions(
            appointment: appointment,
            isBlocked: isBlocked,
            // La edición está en Reservas: en Android/iOS cambia de pestaña,
            // en Web va a /booking.
            onEdit: () => context.go('/booking'),
          ),
        ],
      ),
    );
  }
}

/// Sin turno activo (RF-5): lo dice y ofrece reservar.
class ProfileNoUpcoming extends StatelessWidget {
  const ProfileNoUpcoming({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.profileNoUpcoming,
          textAlign: TextAlign.center,
          style: AppText.sans(size: 14, color: brand.inkMuted, height: 1.5),
        ),
        const SizedBox(height: 14),
        OutlinePillButton(
          key: const ValueKey('profile-book'),
          label: l10n.profileBookAction.toUpperCase(),
          onPressed: () => context.go('/booking'),
        ),
      ],
    );
  }
}
