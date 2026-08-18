import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/theme_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';

class LoginView extends ConsumerWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text("Autenticacion"),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios),
          onPressed: () => context.go('/home'),
        ),
      ),
      backgroundColor: ThemeColors.bone,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 34, vertical: 40),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Monograma dentro del aro dorado
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: ThemeColors.gold),
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    "D'S",
                    style: AppText.serif(
                      size: 34,
                      color: ThemeColors.gold,
                      spacing: 1,
                      height: 1,
                    ),
                  ),
                ),
                const SizedBox(height: 34),
                Text(
                  l10n.brandFullName,
                  style: AppText.serif(
                    size: 46,
                    color: ThemeColors.darkGreen,
                    height: 1,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.loginTagline,
                  textAlign: TextAlign.center,
                  style: AppText.eyebrow(
                    size: 10,
                    color: ThemeColors.gold,
                    spacing: 3.4,
                  ),
                ),
                const SizedBox(height: 30),
                Container(
                  width: 34,
                  height: 1,
                  color: ThemeColors.gold.withValues(alpha: 0.6),
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: 250,
                  child: Text(
                    l10n.loginSubtitle,
                    textAlign: TextAlign.center,
                    style: AppText.sans(
                      size: 16,
                      weight: FontWeight.w300,
                      color: ThemeColors.olive,
                      height: 1.6,
                    ),
                  ),
                ),
                const SizedBox(height: 40),
                if (authState.isLoading)
                  const SizedBox(
                    height: 56,
                    child: Center(
                      child: CircularProgressIndicator(
                        color: ThemeColors.darkGreen,
                        strokeWidth: 2,
                      ),
                    ),
                  )
                else
                  _GoogleSignInButton(
                    onPressed: () => ref
                        .read(authControllerProvider.notifier)
                        .signInWithGoogle(),
                  ),
                if (authState.hasError) ...[
                  const SizedBox(height: 24),
                  Text(
                    '${authState.error}',
                    textAlign: TextAlign.center,
                    style: AppText.sans(
                      size: 12,
                      color: ThemeColors.danger,
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

class _GoogleSignInButton extends StatelessWidget {
  final VoidCallback onPressed;

  const _GoogleSignInButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return SizedBox(
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: ThemeColors.white,
          foregroundColor: ThemeColors.black,
          padding: const EdgeInsets.symmetric(vertical: 17, horizontal: 24),
          side: BorderSide(
            color: ThemeColors.darkGreen.withValues(alpha: 0.14),
          ),
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
              errorBuilder: (context, error, stack) => const Icon(
                Icons.g_mobiledata,
                size: 22,
                color: ThemeColors.darkGreen,
              ),
            ),
            const SizedBox(width: 12),
            Text(
              l10n.continueWithGoogle,
              style: AppText.sans(size: 16, color: ThemeColors.black),
            ),
          ],
        ),
      ),
    );
  }
}
