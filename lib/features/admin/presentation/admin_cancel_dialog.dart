import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/capitalize.dart';
import '../../../data/models/appointment_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/logic/salon_time.dart';
import '../../booking/presentation/booking_notices.dart';
import '../providers/admin_appointment_actions_provider.dart';
import 'admin_dashboard_view.dart' show bookedLabel;

/// Pide a la admin confirmar la cancelación de [appointment] y, si confirma,
/// la hace (spec 010, RF-12 a RF-18). Lo usan la agenda y los choques de un
/// cierre (plan D-3). El aviso del resultado sale desde el propio diálogo,
/// antes de cerrarlo. Devuelve cómo terminó, o `null` si no se canceló
/// ("No, mantener" o cerrar).
Future<AdminCancelOutcome?> showAdminCancelDialog(
  BuildContext context,
  AppointmentModel appointment,
) => showDialog<AdminCancelOutcome>(
  context: context,
  builder: (context) => _AdminCancelDialog(appointment),
);

class _AdminCancelDialog extends ConsumerStatefulWidget {
  const _AdminCancelDialog(this.appointment);

  final AppointmentModel appointment;

  @override
  ConsumerState<_AdminCancelDialog> createState() => _AdminCancelDialogState();
}

class _AdminCancelDialogState extends ConsumerState<_AdminCancelDialog> {
  bool _busy = false;

  Future<void> _confirm() async {
    if (_busy) return;
    setState(() => _busy = true);
    final outcome = await ref
        .read(adminAppointmentActionsProvider)
        .cancel(widget.appointment);
    if (!mounted) return;
    showBookingMessage(context, switch (outcome) {
      AdminCancelOutcome.ok => (l10n) => l10n.adminCancelDone,
      AdminCancelOutcome.notActive => (l10n) => l10n.cancelNotActive,
      AdminCancelOutcome.changed => (l10n) => l10n.adminCancelChanged,
      AdminCancelOutcome.failed => (l10n) => l10n.adminCancelAppointmentError,
    }, isError: outcome == AdminCancelOutcome.failed);
    Navigator.of(context).pop(outcome);
  }

  @override
  Widget build(BuildContext context) {
    // Los textos se leen aquí: si cambia el idioma con el diálogo abierto,
    // cambian también (RC-1).
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final locale = l10n.localeName;
    final start = toSalon(widget.appointment.startTime);
    final end = toSalon(widget.appointment.endTime);
    final hm = DateFormat.Hm(locale);
    final booked = widget.appointment.booked;
    final body = AppText.sans(size: 15, color: brand.ink, height: 1.5);

    return PopScope(
      // Mientras cancela, no se cierra (RF-16).
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          l10n.adminCancelAppointmentTitle(widget.appointment.clientName),
        ),
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
              if (booked != null)
                Text(
                  bookedLabel(booked, locale),
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
