import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../l10n/app_localizations.dart';
import 'widgets/google_sign_in_controls.dart';

class LoginView extends StatelessWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
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
                  textAlign: TextAlign.center,
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
                const GoogleSignInControls(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
