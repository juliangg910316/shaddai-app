import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/capitalize.dart';
import '../../../data/models/user_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/logic/salon_time.dart';
import '../../booking/presentation/booking_notices.dart';
import '../providers/admin_clients_provider.dart';
import 'admin_dashboard_view.dart' show bookedLabel;

/// Pide a la admin confirmar el bloqueo o el desbloqueo de [client] y, si
/// confirma, lo hace (spec 010, RF-25 a RF-34). Al bloquear muestra, en
/// vivo, el turno activo que se cancelará. El aviso del resultado sale
/// desde el propio diálogo, antes de cerrarlo.
Future<void> showClientBlockDialog(BuildContext context, UserModel client) =>
    showDialog<void>(
      context: context,
      builder: (context) => _ClientBlockDialog(client),
    );

class _ClientBlockDialog extends ConsumerStatefulWidget {
  const _ClientBlockDialog(this.client);

  final UserModel client;

  @override
  ConsumerState<_ClientBlockDialog> createState() => _ClientBlockDialogState();
}

class _ClientBlockDialogState extends ConsumerState<_ClientBlockDialog> {
  bool _busy = false;

  bool get _block => !widget.client.isBlocked;

  Future<void> _confirm() async {
    if (_busy) return;
    final name = widget.client.displayName;
    final uid = widget.client.uid;
    final blocker = ref.read(clientBlockerProvider);
    // El turno tal como se ve ahora en el diálogo (RF-28).
    final shown = ref.read(clientActiveAppointmentProvider(uid));
    setState(() => _busy = true);
    final String Function(AppLocalizations) message;
    var isError = false;
    if (_block) {
      final outcome = await blocker.block(uid, shown);
      message = switch (outcome) {
        BlockOutcome.ok => (l10n) => l10n.adminBlockDone(name),
        BlockOutcome.changed => (l10n) => l10n.adminBlockChanged,
        BlockOutcome.failed => (l10n) => l10n.adminBlockFailed,
      };
      isError = outcome == BlockOutcome.failed;
    } else {
      final ok = await blocker.unblock(uid);
      message = ok
          ? (l10n) => l10n.adminUnblockDone(name)
          : (l10n) => l10n.adminUnblockFailed;
      isError = !ok;
    }
    if (!mounted) return;
    showBookingMessage(context, message, isError: isError);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    // Los textos se leen aquí: cambian de idioma con el diálogo abierto.
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final locale = l10n.localeName;
    final name = widget.client.displayName;
    final block = _block;
    final appointment = block
        ? ref.watch(clientActiveAppointmentProvider(widget.client.uid))
        : null;
    final body = AppText.sans(size: 15, color: brand.ink, height: 1.5);

    return PopScope(
      // Mientras guarda, no se cierra (RF-32).
      canPop: !_busy,
      child: AlertDialog(
        title: Text(
          block ? l10n.adminBlockTitle(name) : l10n.adminUnblockTitle(name),
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                block ? l10n.adminBlockBody : l10n.adminUnblockBody,
                style: body,
              ),
              // Su turno activo, que se cancelará (RF-26).
              if (appointment != null) ...[
                const SizedBox(height: 12),
                Text(l10n.adminBlockCancelsAppointment, style: body),
                Text(
                  capitalizeFirst(
                    DateFormat.yMMMMEEEEd(locale)
                        .format(toSalon(appointment.startTime)),
                  ),
                  style: body,
                ),
                Text(
                  l10n.bookingTimeRange(
                    DateFormat.Hm(locale)
                        .format(toSalon(appointment.startTime)),
                    DateFormat.Hm(locale).format(toSalon(appointment.endTime)),
                  ),
                  style: body,
                ),
                if (appointment.booked case final booked?)
                  Text(
                    bookedLabel(booked, locale),
                    style: AppText.serif(size: 18, color: brand.inkStrong),
                  ),
              ],
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
              l10n.adminDialogBack,
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
              backgroundColor: block ? brand.danger : brand.brand,
              foregroundColor: block ? brand.background : brand.onBrand,
              disabledBackgroundColor: brand.placeholder,
              disabledForegroundColor: brand.inkMuted,
            ),
            child: Text(
              block ? l10n.adminBlockConfirm : l10n.adminUnblockConfirm,
              style: AppText.sans(size: 13, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
