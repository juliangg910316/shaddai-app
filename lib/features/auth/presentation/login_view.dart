import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/theme_colors.dart';
import '../providers/auth_provider.dart';

class LoginView extends ConsumerWidget {
  const LoginView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authControllerProvider);

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.spa,
                  size: 80,
                  color: ThemeColors.darkGreen,
                ),
                const SizedBox(height: 24),
                const Text(
                  "D'Shaddai",
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.gold,
                    fontFamily: 'serif',
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  "Inicia sesión para agendar tu turno",
                  style: TextStyle(
                    fontSize: 16,
                    color: ThemeColors.olive,
                  ),
                ),
                const SizedBox(height: 48),
                if (authState.isLoading)
                  const CircularProgressIndicator(color: ThemeColors.darkGreen)
                else
                  ElevatedButton.icon(
                    onPressed: () {
                      ref.read(authControllerProvider.notifier).signInWithGoogle();
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                      backgroundColor: ThemeColors.white,
                      foregroundColor: ThemeColors.black,
                      elevation: 2,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(30),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    icon: Image.network(
                      'https://upload.wikimedia.org/wikipedia/commons/c/c1/Google_%22G%22_logo.svg',
                      height: 24,
                      errorBuilder: (context, error, stackTrace) => const Icon(Icons.login),
                    ),
                    label: const Text(
                      "Continuar con Google",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                    ),
                  ),
                if (authState.hasError) ...[
                  const SizedBox(height: 24),
                  Text(
                    'Error: ${authState.error}',
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ]
              ],
            ),
          ),
        ),
      ),
    );
  }
}
