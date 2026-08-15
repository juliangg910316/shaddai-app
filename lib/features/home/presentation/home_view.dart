import 'package:flutter/material.dart';
import '../../../core/constants/theme_colors.dart';
import 'package:go_router/go_router.dart';
import '../../../l10n/app_localizations.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20.0,
                  vertical: 10.0,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Icon(
                      Icons.account_circle,
                      size: 32,
                      color: ThemeColors.darkGreen,
                    ),
                    Text(
                      l10n.appTitle,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.gold,
                        fontFamily: 'serif',
                      ),
                    ),
                    const Icon(
                      Icons.notifications_none,
                      size: 28,
                      color: ThemeColors.gold,
                    ),
                  ],
                ),
              ),

              // Hero Section
              Container(
                margin: const EdgeInsets.all(20),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: ThemeColors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "D'Shaddai\nNail Salon",
                      style: TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.bold,
                        color: ThemeColors.darkGreen,
                        fontFamily: 'serif',
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      "Cuidado de Lujo para tus Uñas",
                      style: TextStyle(fontSize: 16, color: ThemeColors.olive),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          // Navegar a la pantalla de Reservas (índice 2 en el bottom nav)
                          context.go('/booking');
                        },
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          backgroundColor: ThemeColors.darkGreen,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(30),
                          ),
                        ),
                        child: Text(
                          l10n.bookAppointment.toUpperCase(),
                          style: const TextStyle(
                            color: ThemeColors.gold,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              // Welcome Message
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: Text(
                  l10n.welcomeBack(
                    "Invitada",
                  ), // TODO: Reemplazar con nombre del Auth
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                    color: ThemeColors.black,
                  ),
                ),
              ),

              // Aca se pueden añadir más secciones del Home (Servicios Destacados, Galería, etc)
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
