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
import '../logic/profile_appointments.dart';

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

/// Un turno del historial (spec 009, RF-20, RF-21, RF-23): el chip de la
/// fecha, el día y la hora en hora del salón, el servicio y su etiqueta, sin
/// acciones. Los cancelados y los no confirmados se distinguen por la
/// etiqueta y el tono, nunca bajando la opacidad (RNF-1). Se lee como una
/// sola frase (RNF-2).
class ProfileHistoryCard extends StatelessWidget {
  const ProfileHistoryCard({
    super.key,
    required this.appointment,
    required this.now,
  });

  final AppointmentModel appointment;

  /// "Ahora" (instante), para saber si ya terminó.
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final locale = l10n.localeName;
    final start = toSalon(appointment.startTime);
    final label = historyLabel(
      status: appointment.status,
      cancelledByClient: appointment.cancelledByClient,
      end: appointment.endTime,
      now: now,
    );
    final (text, color) = switch (label) {
      HistoryLabel.cancelledByYou => (l10n.historyCancelledByYou, brand.danger),
      HistoryLabel.cancelledBySalon => (
        l10n.historyCancelledBySalon,
        brand.danger,
      ),
      HistoryLabel.done => (l10n.historyDone, brand.inkStrong),
      HistoryLabel.notConfirmed => (l10n.historyNotConfirmed, brand.inkMuted),
      HistoryLabel.upcoming =>
        appointment.status == 'confirmed'
            ? (l10n.statusConfirmedClient, brand.inkStrong)
            : (l10n.statusWaitingConfirmationClient, brand.accentText),
    };
    final faded =
        label == HistoryLabel.cancelledByYou ||
        label == HistoryLabel.cancelledBySalon;
    final dateInk = faded ? brand.inkMuted : brand.inkStrong;
    final service = appointment.booked?.name.of(locale);

    return MergeSemantics(
      child: FlatCard(
        color: faded ? brand.background : brand.surface,
        borderColor: brand.hairline,
        child: Row(
          children: [
            // Chip de la fecha
            Container(
              constraints: const BoxConstraints(minWidth: 52, minHeight: 52),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: brand.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    DateFormat.MMM(locale).format(start).toUpperCase(),
                    style: AppText.eyebrow(
                      size: 9,
                      spacing: 1,
                      weight: FontWeight.w300,
                      color: dateInk,
                    ),
                  ),
                  Text(
                    start.day.toString().padLeft(2, '0'),
                    style: AppText.serif(size: 20, height: 1, color: dateInk),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${capitalizeFirst(DateFormat.EEEE(locale).format(start))}'
                    ' · ${DateFormat.Hm(locale).format(start)}',
                    style: AppText.serif(
                      size: 17,
                      color: faded ? brand.inkMuted : brand.ink,
                    ),
                  ),
                  if (service != null && service.isNotEmpty)
                    Text(
                      service,
                      style: AppText.sans(size: 14, color: brand.inkMuted),
                    ),
                  const SizedBox(height: 5),
                  Text(
                    text,
                    style: AppText.eyebrow(
                      size: 10,
                      spacing: 1.6,
                      color: color,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
