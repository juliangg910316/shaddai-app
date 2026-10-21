import 'package:flutter/material.dart';

import '../../../../core/theme/app_text.dart';
import '../../../../l10n/app_localizations.dart';

/// Botón "Continuar con Google" de Android/iOS.
///
/// *Excepción de color* de la spec 001: usa los colores de la guía de marca de
/// Google (versión clara) en los dos temas, no los de la app.
class GoogleBrandButton extends StatelessWidget {
  final VoidCallback onPressed;

  const GoogleBrandButton({super.key, required this.onPressed});

  static const _fill = Color(0xFFFFFFFF);
  static const _stroke = Color(0xFF747775);
  static const _text = Color(0xFF1F1F1F);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: _fill,
          foregroundColor: _text,
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
          side: const BorderSide(color: _stroke),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.network(
              'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
              height: 20,
              width: 20,
              errorBuilder: (context, error, stack) =>
                  const Icon(Icons.g_mobiledata, size: 22, color: _text),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.continueWithGoogle,
              style: AppText.sans(size: 16, color: _text),
            ),
          ],
        ),
      ),
    );
  }
}
