import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/whatsapp_field.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/presentation/booking_notices.dart';
import '../providers/whatsapp_change_provider.dart';

/// Abre el cambio del WhatsApp con el número [current] escrito (spec 009,
/// RF-26).
Future<void> showChangeWhatsAppDialog(BuildContext context, String current) =>
    showDialog<void>(
      context: context,
      builder: (_) => ChangeWhatsAppDialog(current: current),
    );

/// El diálogo para cambiar el WhatsApp (spec 009, RF-26 a RF-30): el campo
/// compartido con el registro, "Guardar" y "Cancelar". Si no es válido o no
/// se pudo guardar, lo dice junto al campo y conserva lo escrito; al
/// guardarlo, se cierra y lo avisa.
class ChangeWhatsAppDialog extends ConsumerStatefulWidget {
  const ChangeWhatsAppDialog({super.key, required this.current});

  final String current;

  @override
  ConsumerState<ChangeWhatsAppDialog> createState() =>
      _ChangeWhatsAppDialogState();
}

class _ChangeWhatsAppDialogState extends ConsumerState<ChangeWhatsAppDialog> {
  late final _controller = TextEditingController(text: widget.current);
  bool _busy = false;
  WhatsAppChangeOutcome? _problem;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _problem = null;
    });
    final outcome = await ref
        .read(whatsAppChangeProvider)
        .save(_controller.text);
    if (!mounted) return;
    if (outcome == WhatsAppChangeOutcome.ok) {
      showBookingMessage(context, (l10n) => l10n.whatsAppSaved);
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _busy = false;
      _problem = outcome;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Los textos se leen aquí: si cambia el idioma con el diálogo abierto,
    // cambian también.
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return PopScope(
      // Mientras guarda, no se cierra.
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l10n.changeWhatsAppTitle),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              WhatsAppField(
                controller: _controller,
                errorText: switch (_problem) {
                  WhatsAppChangeOutcome.invalid => l10n.whatsAppInvalid,
                  WhatsAppChangeOutcome.failed => l10n.whatsAppSaveFailed,
                  _ => null,
                },
                onSubmitted: (_) => _save(),
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
              l10n.cancelAction,
              style: AppText.sans(
                size: 13,
                weight: FontWeight.w500,
                color: brand.inkMuted,
              ),
            ),
          ),
          ElevatedButton(
            onPressed: _busy ? null : _save,
            child: Text(
              l10n.whatsAppSaveAction.toUpperCase(),
              style: AppText.sans(size: 13, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
