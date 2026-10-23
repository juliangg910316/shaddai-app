import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/logic/price_list_form_logic.dart';
import '../providers/admin_services_provider.dart';

/// Id de las rutas de los formularios para crear un elemento nuevo.
const newElementId = 'new';

/// Ejecuta [action] y avisa del resultado: guardado (RF-34), error con
/// "Reintentar" (RF-33), elemento que ya no existe o categoría con
/// elementos. Nunca el error técnico (RNF-6). Si se guarda, llama antes a
/// [onSaved] (p. ej. para cerrar el formulario).
Future<void> runAdminServicesAction(
  BuildContext context,
  Future<AdminServicesResult> Function() action, {
  VoidCallback? onSaved,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context)!;
  final result = await action();
  if (result == AdminServicesResult.ok) onSaved?.call();

  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(switch (result) {
    AdminServicesResult.ok => SnackBar(content: Text(l10n.adminServicesSaved)),
    AdminServicesResult.itemGone => SnackBar(
      content: Text(l10n.adminServicesItemGone),
    ),
    AdminServicesResult.categoryNotEmpty => SnackBar(
      content: Text(l10n.adminServicesCategoryNotEmpty),
    ),
    AdminServicesResult.failed => SnackBar(
      content: Text(l10n.adminServicesSaveError),
      action: SnackBarAction(
        label: l10n.pricesRetry.toUpperCase(),
        onPressed: () {
          if (context.mounted) {
            runAdminServicesAction(context, action, onSaved: onSaved);
          }
        },
      ),
    ),
  });
}

/// Vuelve de un formulario a la gestión: atrás si se llegó desde ella; si
/// se abrió la dirección directamente (Web), a `/admin/services`.
void closeAdminServicesForm(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go('/admin/services');
  }
}

/// El texto de [error] para un campo de longitud máxima [maxLength].
String? adminFieldErrorText(
  AppLocalizations l10n,
  PriceFormError? error, {
  int? maxLength,
}) => switch (error) {
  null => null,
  PriceFormError.required => l10n.adminFieldRequired,
  PriceFormError.missingTranslation => l10n.adminFieldMissingTranslation,
  PriceFormError.invalidPrice => l10n.adminFieldInvalidPrice,
  PriceFormError.invalidDuration => l10n.adminFieldInvalidDuration,
  PriceFormError.tooLong => l10n.adminFieldTooLong(maxLength ?? 0),
};

/// Un campo de texto de los formularios de la gestión, con su error.
class AdminTextField extends StatelessWidget {
  const AdminTextField({
    super.key,
    required this.controller,
    required this.label,
    this.errorText,
    this.multiline = false,
    this.keyboardType,
  });

  final TextEditingController controller;
  final String label;
  final String? errorText;
  final bool multiline;
  final TextInputType? keyboardType;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextField(
        controller: controller,
        keyboardType: multiline ? TextInputType.multiline : keyboardType,
        minLines: multiline ? 2 : 1,
        maxLines: multiline ? null : 1,
        cursorColor: brand.accentIcon,
        style: AppText.sans(size: 16, color: brand.inkStrong),
        decoration: InputDecoration(
          labelText: label,
          errorText: errorText,
          errorMaxLines: 3,
        ),
      ),
    );
  }
}

/// "Cancelar" y "Guardar" al pie de un formulario de la gestión.
class AdminFormActions extends StatelessWidget {
  const AdminFormActions({
    super.key,
    required this.onCancel,
    required this.onSave,
  });

  final VoidCallback onCancel;

  /// `null` mientras se guarda.
  final VoidCallback? onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    return Wrap(
      alignment: WrapAlignment.end,
      spacing: 12,
      runSpacing: 8,
      children: [
        TextButton(
          onPressed: onCancel,
          style: TextButton.styleFrom(
            foregroundColor: brand.ink,
            minimumSize: const Size(48, 48),
          ),
          child: Text(l10n.cancelAction),
        ),
        ElevatedButton(
          onPressed: onSave,
          style: ElevatedButton.styleFrom(
            backgroundColor: brand.brand,
            foregroundColor: brand.onBrand,
            elevation: 0,
            minimumSize: const Size(48, 48),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 24),
          ),
          child: Text(
            l10n.adminSave.toUpperCase(),
            style: AppText.sans(
              size: 12,
              weight: FontWeight.w600,
              spacing: 1,
              color: brand.onBrand,
            ),
          ),
        ),
      ],
    );
  }
}
