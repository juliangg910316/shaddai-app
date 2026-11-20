import 'package:flutter/material.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';

/// Explica a la admin para qué sirven los avisos antes de que el sistema le
/// pida el permiso de notificaciones (spec 011, RF-15; plan D-8). Solo tiene
/// "Continuar": no se cierra tocando fuera ni con "atrás". Termina cuando la
/// admin pulsa "Continuar".
Future<void> showAdminPushDialog(BuildContext context) => showDialog<void>(
  context: context,
  barrierDismissible: false,
  builder: (context) => const _AdminPushDialog(),
);

class _AdminPushDialog extends StatelessWidget {
  const _AdminPushDialog();

  @override
  Widget build(BuildContext context) {
    // Los textos se leen aquí: si cambia el idioma con el diálogo abierto,
    // cambian también (RC-1).
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const Key('admin-push-dialog'),
        icon: Icon(
          Icons.notifications_active_outlined,
          color: brand.accentIcon,
        ),
        title: Text(l10n.adminPushExplainTitle),
        content: SingleChildScrollView(
          child: Text(
            l10n.adminPushExplainBody,
            style: AppText.sans(size: 15, color: brand.ink, height: 1.5),
          ),
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              l10n.adminPushExplainContinue,
              style: AppText.sans(size: 13, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
