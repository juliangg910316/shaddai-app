import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/platform_provider.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../data/repositories/account_repository.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/presentation/booking_notices.dart';
import '../logic/account_deletion.dart';
import '../providers/account_deletion_provider.dart';

/// Abre "Eliminar mi cuenta" (spec 009, RF-32).
Future<void> showDeleteAccountDialog(BuildContext context) => showDialog<void>(
  context: context,
  builder: (_) => const DeleteAccountDialog(),
);

/// "Eliminar mi cuenta" en dos pasos (spec 009, RF-32, RF-33, RF-36, RF-38 a
/// RF-40): (1) qué se borra y qué se conserva; (2) escribir la palabra de
/// confirmación del idioma activo. Cancelar en cualquiera de los dos no
/// borra nada. Mientras borra, no se puede cerrar ni volver a pedir.
class DeleteAccountDialog extends ConsumerStatefulWidget {
  const DeleteAccountDialog({super.key});

  @override
  ConsumerState<DeleteAccountDialog> createState() =>
      _DeleteAccountDialogState();
}

class _DeleteAccountDialogState extends ConsumerState<DeleteAccountDialog> {
  final _word = TextEditingController();
  bool _confirming = false;
  bool _busy = false;
  AccountDeletionFailure? _failure;

  @override
  void dispose() {
    _word.dispose();
    super.dispose();
  }

  Future<void> _delete() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _failure = null;
    });
    final isWeb = ref.read(isWebProvider);
    final failure = await ref
        .read(accountDeletionProvider)
        .delete(
          onDeleted: () {
            // Antes de cerrar la sesión: el aviso, cerrar el diálogo y salir
            // del perfil (en Web, el perfil sin sesión llevaría al login;
            // D-14).
            final router = GoRouter.of(context);
            showBookingMessage(context, (l10n) => l10n.deleteAccountDone);
            Navigator.of(context).pop();
            router.go(isWeb ? '/' : '/home');
          },
        );
    if (!mounted || failure == null) return;
    setState(() {
      _busy = false;
      _failure = failure;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Los textos se leen aquí: si cambia el idioma con el diálogo abierto,
    // cambian también.
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final body = AppText.sans(size: 15, color: brand.ink, height: 1.5);
    final word = l10n.deleteAccountWord;
    final blocked = _failure == AccountDeletionFailure.blocked;
    final matches = deletionWordMatches(_word.text, word);

    final problem = switch (_failure) {
      null => null,
      AccountDeletionFailure.blocked => l10n.deleteAccountBlocked,
      AccountDeletionFailure.notAllowed ||
      AccountDeletionFailure.failed => l10n.deleteAccountFailed,
    };

    return PopScope(
      canPop: !_busy,
      child: AlertDialog(
        title: Text(l10n.deleteAccountAction),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (!_confirming)
                Text(l10n.deleteAccountExplain, style: body)
              else ...[
                Text(l10n.deleteAccountTypeWord(word), style: body),
                const SizedBox(height: 12),
                TextField(
                  controller: _word,
                  autofocus: true,
                  enabled: !_busy && !blocked,
                  textCapitalization: TextCapitalization.characters,
                  autocorrect: false,
                  enableSuggestions: false,
                  style: AppText.sans(size: 16, color: brand.inkStrong),
                  decoration: InputDecoration(hintText: word),
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (problem != null) ...[
                const SizedBox(height: 12),
                Semantics(
                  liveRegion: true,
                  child: Text(
                    problem,
                    style: AppText.sans(
                      size: 14,
                      weight: FontWeight.w500,
                      color: brand.danger,
                    ),
                  ),
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
              l10n.cancelAction,
              style: AppText.sans(
                size: 13,
                weight: FontWeight.w500,
                color: brand.inkMuted,
              ),
            ),
          ),
          if (!_confirming)
            ElevatedButton(
              onPressed: () => setState(() => _confirming = true),
              child: Text(
                l10n.deleteAccountContinue.toUpperCase(),
                style: AppText.sans(size: 13, weight: FontWeight.w600),
              ),
            )
          else if (!blocked)
            ElevatedButton(
              onPressed: _busy || !matches ? null : _delete,
              style: ElevatedButton.styleFrom(
                backgroundColor: brand.danger,
                foregroundColor: brand.background,
                disabledBackgroundColor: brand.placeholder,
                disabledForegroundColor: brand.inkMuted,
              ),
              child: Text(
                (_failure == null
                        ? l10n.deleteAccountAction
                        : l10n.bookingRetry)
                    .toUpperCase(),
                style: AppText.sans(size: 13, weight: FontWeight.w600),
              ),
            ),
        ],
      ),
    );
  }
}
