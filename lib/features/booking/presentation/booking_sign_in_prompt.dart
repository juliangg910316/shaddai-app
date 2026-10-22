import 'package:flutter/material.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/presentation/widgets/google_sign_in_controls.dart';

/// Aviso de la pestaña Reservas sin sesión: explica por qué hace falta iniciar
/// sesión y ofrece el botón de Google, sin salir de las pestañas (spec 003,
/// RF-16). Al iniciar sesión, la pestaña muestra la reserva (RF-17).
class BookingSignInPrompt extends StatelessWidget {
  const BookingSignInPrompt({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return Scaffold(
      backgroundColor: brand.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const BrandLogo(size: 76),
                  const SizedBox(height: 28),
                  Text(
                    l10n.bookingSignInTitle,
                    textAlign: TextAlign.center,
                    style: AppText.serif(size: 30, color: brand.inkStrong),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.bookingSignInBody,
                    textAlign: TextAlign.center,
                    style: AppText.sans(
                      size: 15,
                      weight: FontWeight.w300,
                      color: brand.inkMuted,
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 36),
                  const GoogleSignInControls(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
