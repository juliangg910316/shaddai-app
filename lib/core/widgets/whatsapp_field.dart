import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../theme/app_text.dart';
import '../theme/brand_colors.dart';
import 'app_widgets.dart';

/// El campo del WhatsApp de la clienta, igual al registrarse y al cambiarlo
/// desde el perfil (spec 009, RF-26, RF-27, plan D-7): su etiqueta, el campo
/// con el icono, el error junto al campo y el texto de consentimiento.
///
/// No valida: quien lo usa decide el error ([errorText]) con
/// `isValidWhatsApp`.
class WhatsAppField extends StatelessWidget {
  const WhatsAppField({
    super.key,
    required this.controller,
    this.errorText,
    this.onSubmitted,
  });

  final TextEditingController controller;

  /// El error que se muestra junto al campo, o `null`.
  final String? errorText;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.whatsappFieldLabel,
          style: AppText.eyebrow(color: brand.inkMuted),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          cursorColor: brand.accentIcon,
          style: AppText.sans(size: 16, color: brand.inkStrong),
          onSubmitted: onSubmitted,
          decoration: InputDecoration(
            hintText: l10n.phoneHintExample,
            prefixIcon: const Padding(
              padding: EdgeInsets.only(left: 16, right: 10),
              child: WhatsAppIcon(),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 0,
              minHeight: 0,
            ),
            // El rojo por defecto no llega a AA sobre el fondo.
            errorText: errorText,
            errorStyle: AppText.sans(
              size: 12,
              weight: FontWeight.w500,
              color: brand.danger,
            ),
            errorMaxLines: 3,
          ),
        ),
        const SizedBox(height: 9),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 2),
          child: Text(
            l10n.whatsappDisclaimer,
            style: AppText.sans(
              size: 12,
              weight: FontWeight.w300,
              color: brand.inkMuted,
              height: 1.6,
            ),
          ),
        ),
      ],
    );
  }
}
