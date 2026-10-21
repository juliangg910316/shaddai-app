import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/auth_failure.dart';
import '../providers/auth_provider.dart';
import 'widgets/google_brand_button.dart';
import 'widgets/google_signin_button.dart';

class LoginView extends ConsumerWidget {
  const LoginView({super.key});

  /// Texto de la app para el error de inicio de sesión, nunca el mensaje
  /// técnico (RF-22). Al cancelar no se muestra nada.
  static String? _errorMessage(Object? error, AppLocalizations l10n) {
    return switch (error) {
      null || AuthFailure.cancelled => null,
      AuthFailure.blocked => l10n.authBlockedError,
      _ => l10n.authGenericError,
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);
    final brand = context.brand;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.loginAppBarTitle),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios),
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          onPressed: () => context.go('/home'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 96),
                const SizedBox(height: 34),
                Text(
                  l10n.brandFullName,
                  style: AppText.serif(
                    size: 46,
                    color: brand.inkStrong,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.loginTagline,
                  textAlign: TextAlign.center,
                  style: AppText.eyebrow(
                    size: 10,
                    color: brand.accentText,
                    spacing: 3.4,
                  ),
                ),
                const SizedBox(height: 30),
                Container(width: 34, height: 1, color: brand.goldHairline),
                const SizedBox(height: 30),
                SizedBox(
                  width: 250,
                  child: Text(
                    l10n.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: AppText.sans(
                      size: 16,
                      weight: FontWeight.w300,
                      color: brand.inkMuted,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                if (authState.isLoading)
                  const SizedBox(
                    height: 56,
                    child: Center(
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  )
                else if (kIsWeb)
                  // Web must use Google's own rendered button: GIS does not
                  // allow a custom button to trigger sign-in imperatively.
                  SizedBox(height: 44, child: buildWebGoogleSignInButton())
                else
                  GoogleBrandButton(
                    onPressed: () => ref
                        .read(authControllerProvider.notifier)
                        .signInWithGoogle(),
                  ),
                if (_errorMessage(authState.error, l10n)
                    case final message?) ...[
                  const SizedBox(height: 24),
                  Text(
                    message,
                    textAlign: TextAlign.center,
                    style: AppText.sans(
                      size: 12,
                      color: brand.danger,
                      height: 1.5,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
