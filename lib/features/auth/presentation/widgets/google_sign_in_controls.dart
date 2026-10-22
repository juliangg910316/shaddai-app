import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../auth_error_text.dart';
import 'google_brand_button.dart';
import 'google_signin_button.dart';

/// Inicio de sesión con Google: el botón (o una rueda mientras se inicia) y,
/// si falla, el mensaje de la app. Lo usan la pantalla de inicio de sesión y
/// el aviso de la pestaña Reservas (spec 003, RF-16 a RF-19).
class GoogleSignInControls extends ConsumerWidget {
  const GoogleSignInControls({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final authState = ref.watch(authControllerProvider);
    final message = authErrorMessage(authState.error, l10n);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (authState.isLoading)
          const SizedBox(
            height: 56,
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (kIsWeb)
          // Web must use Google's own rendered button: GIS does not
          // allow a custom button to trigger sign-in imperatively.
          SizedBox(height: 44, child: buildWebGoogleSignInButton())
        else
          GoogleBrandButton(
            onPressed: () =>
                ref.read(authControllerProvider.notifier).signInWithGoogle(),
          ),
        if (message != null) ...[
          const SizedBox(height: 24),
          Text(
            message,
            textAlign: TextAlign.center,
            style: AppText.sans(size: 12, color: brand.danger, height: 1.5),
          ),
        ],
      ],
    );
  }
}
