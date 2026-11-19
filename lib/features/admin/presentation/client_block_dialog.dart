import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/admin_provider.dart';

/// Pide a la admin confirmar el bloqueo o el desbloqueo de [client] (spec
/// 010, RF-25, RF-29, RF-31). Nada cambia hasta confirmar.
Future<void> showClientBlockDialog(BuildContext context, UserModel client) =>
    showDialog<void>(
      context: context,
      builder: (context) => _ClientBlockDialog(client),
    );

class _ClientBlockDialog extends ConsumerWidget {
  const _ClientBlockDialog(this.client);

  final UserModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Los textos se leen aquí: cambian de idioma con el diálogo abierto.
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final block = !client.isBlocked;
    final name = client.displayName;

    return AlertDialog(
      title: Text(
        block ? l10n.adminBlockTitle(name) : l10n.adminUnblockTitle(name),
      ),
      content: Text(
        block ? l10n.adminBlockBody : l10n.adminUnblockBody,
        style: AppText.sans(size: 15, color: brand.ink, height: 1.5),
      ),
      actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
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
          onPressed: () {
            ref
                .read(adminControllerProvider)
                .setClientBlocked(client.uid, block);
            Navigator.of(context).pop();
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: block ? brand.danger : brand.brand,
            foregroundColor: block ? brand.background : brand.onBrand,
          ),
          child: Text(
            block ? l10n.adminBlockConfirm : l10n.adminUnblockConfirm,
            style: AppText.sans(size: 13, weight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
