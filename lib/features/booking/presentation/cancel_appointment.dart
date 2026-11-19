import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/capitalize.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/appointment_model.dart';
import '../../../l10n/app_localizations.dart';
import '../logic/cancel_appointment.dart';
import '../logic/salon_time.dart';
import '../providers/booking_cancel_provider.dart';
import 'booking_notices.dart';

/// "Cancelar turno" del turno activo [appointment] (spec 009, RF-8): solo
/// mientras se puede cancelar, también si la clienta está bloqueada (plan
/// D-5). Lo usan la vista del turno activo en Reservas y el perfil (D-13).
class CancelAppointmentButton extends ConsumerWidget {
  const CancelAppointmentButton({super.key, required this.appointment});

  final AppointmentModel appointment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availability = ref.watch(
      cancelAvailabilityProvider(appointment.startTime),
    );
    if (availability != CancelAvailability.cancellable) {
      return const SizedBox.shrink();
    }
    return OutlinePillButton(
      label: AppLocalizations.of(context)!.cancelAppointmentAction
          .toUpperCase(),
      onPressed: () => showCancelAppointmentDialog(context, appointment),
    );
  }
}

/// Pide confirmar la cancelación de [appointment] y, si se confirma, la
/// hace (RF-9 a RF-16). El resultado se muestra desde el propio diálogo,
/// antes de cerrarlo: al cancelar, la vista que lo abrió puede desaparecer.
Future<void> showCancelAppointmentDialog(
  BuildContext context,
  AppointmentModel appointment,
) => showDialog<void>(
  context: context,
  builder: (context) => _CancelAppointmentDialog(appointment),
);

class _CancelAppointmentDialog extends ConsumerStatefulWidget {
  const _CancelAppointmentDialog(this.appointment);

  final AppointmentModel appointment;

  @override
  ConsumerState<_CancelAppointmentDialog> createState() =>
      _CancelAppointmentDialogState();
}

class _CancelAppointmentDialogState
    extends ConsumerState<_CancelAppointmentDialog> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await ref
        .read(appointmentCancelProvider)
        .cancel(widget.appointment);
    if (!mounted) return;
    showCancelResult(context, outcome);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Los textos se leen aquí: si cambia el idioma con el diálogo abierto,
    // cambian también.
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final locale = l10n.localeName;
    final start = toSalon(widget.appointment.startTime);
    final end = toSalon(widget.appointment.endTime);
    final hm = DateFormat.Hm(locale);
    final service = widget.appointment.booked?.name.of(locale);
    final body = AppText.sans(size: 15, color: brand.ink, height: 1.5);

    return PopScope(
      // Mientras cancela, no se cierra (RF-16).
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l10n.cancelDialogTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                capitalizeFirst(DateFormat.yMMMMEEEEd(locale).format(start)),
                style: body,
              ),
              Text(
                l10n.bookingTimeRange(hm.format(start), hm.format(end)),
                style: body,
              ),
              if (service != null && service.isNotEmpty)
                Text(
                  service,
                  style: AppText.serif(size: 18, color: brand.inkStrong),
                ),
              if (_busy) ...[
                const SizedBox(height: 16),
                const Center(child: CircularProgressIndicator(strokeWidth: 2)),
              ],
            ],
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          TextButton(
            onPressed: _busy ? null : () => Navigator.of(context).pop(),
            child: Text(
              l10n.cancelKeep,
              style: AppText.sans(
                size: 13,
                weight: FontWeight.w500,
                color: brand.inkMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _busy ? null : _confirm,
            style: ElevatedButton.styleFrom(
              backgroundColor: brand.danger,
              foregroundColor: brand.background,
              disabledBackgroundColor: brand.placeholder,
              disabledForegroundColor: brand.inkMuted,
            ),
            child: Text(
              l10n.cancelConfirm,
              style: AppText.sans(size: 13, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
