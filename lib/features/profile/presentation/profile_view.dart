import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/platform/platform_provider.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/capitalize.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/appointment_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../../preferences/presentation/preferences_section.dart';
import '../providers/profile_provider.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
    final appointmentsAsync = ref.watch(clientAppointmentsProvider);
    final isWeb = ref.watch(isWebProvider);

    // Sin sesión: Preferencias y acceso al inicio de sesión (RF-25).
    if (user == null && !userAsync.isLoading) {
      return const _GuestProfile();
    }

    if (user == null) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }

    final brand = context.brand;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Cabecera: título centrado y salida a la derecha
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 0),
              child: Row(
                children: [
                  const SizedBox(width: 22),
                  Expanded(
                    child: Text(
                      l10n.myProfileTitle,
                      textAlign: TextAlign.center,
                      style: AppText.serif(size: 24, color: brand.inkStrong),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      // En Web, primero a la landing: el perfil sin sesión
                      // llevaría al login (spec 002, RF-28).
                      if (isWeb) context.go('/');
                      ref.read(authControllerProvider.notifier).signOut();
                    },
                    child: Icon(Icons.logout, size: 22, color: brand.inkMuted),
                  ),
                ],
              ),
            ),

            // Identidad
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 26, 20, 18),
              child: Column(
                children: [
                  InitialsAvatar(
                    photoUrl: user.photoUrl,
                    name: user.displayName,
                    size: 96,
                    goldBorder: true,
                    serifInitials: true,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName,
                    textAlign: TextAlign.center,
                    style: AppText.serif(size: 26, color: brand.inkStrong),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.phoneNumber ?? user.email,
                    style: AppText.sans(
                      size: 14,
                      weight: FontWeight.w300,
                      color: brand.inkMuted,
                    ),
                  ),
                ],
              ),
            ),

            // Acceso al panel (solo visible para admin)
            if (user.role == 'admin')
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () => context.push('/admin'),
                    icon: Icon(
                      Icons.admin_panel_settings_outlined,
                      color: brand.onBrand,
                      size: 18,
                    ),
                    label: Text(
                      l10n.adminPanelButtonLabel,
                      style: AppText.sans(
                        size: 12,
                        weight: FontWeight.w500,
                        spacing: 2,
                        color: brand.onBrand,
                      ),
                    ),
                  ),
                ),
              ),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: SectionHeading(l10n.myAppointmentsTitle),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: appointmentsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                error: (err, stack) {
                  debugPrint('Error al cargar mis reservas: $err');
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        l10n.myAppointmentsLoadError,
                        textAlign: TextAlign.center,
                        style: AppText.sans(size: 13, color: brand.danger),
                      ),
                    ),
                  );
                },
                data: (appointments) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  children: [
                    if (appointments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 26),
                        child: Center(
                          child: Text(
                            l10n.noAppointmentsYet,
                            style: AppText.sans(
                              size: 13,
                              weight: FontWeight.w300,
                              color: brand.inkMuted,
                            ),
                          ),
                        ),
                      )
                    else
                      for (final appointment in appointments) ...[
                        _AppointmentCard(appointment: appointment),
                        const SizedBox(height: 12),
                      ],
                    const SizedBox(height: 10),
                    OutlinePillButton(
                      label: l10n.bookAnotherAppointmentAction,
                      onPressed: () => context.go('/booking'),
                    ),
                    // En Web, tema e idioma están en la barra superior
                    // (spec 002, RF-31).
                    if (!isWeb) ...[
                      const SizedBox(height: 32),
                      const PreferencesSection(),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Perfil sin sesión: solo Preferencias y el botón para iniciar sesión
/// (RF-25, RF-26).
class _GuestProfile extends StatelessWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.profileGuestTitle,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 28),
              const PreferencesSection(),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () => context.go('/login'),
                child: Text(l10n.profileGuestLoginButton),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final status = AppointmentStatusStyle.forClient(
      l10n,
      appointment.status,
      context.brand,
    );
    final brand = context.brand;
    final locale = l10n.localeName;
    final cancelled = appointment.status == 'cancelled';
    final start = appointment.startTime;
    final timeStr = DateFormat.Hm(locale).format(start);
    // Un turno cancelado se distingue por el tono suave y su etiqueta, sin
    // bajar la opacidad: su texto tiene que seguir leyéndose (RNF-1).
    final dateInk = cancelled ? brand.inkMuted : brand.inkStrong;

    return FlatCard(
      color: cancelled ? brand.background : brand.surface,
      borderColor: switch (appointment.status) {
        'waiting_confirmation' => brand.goldHairline,
        _ => brand.hairline,
      },
      child: Row(
        children: [
          // Chip de fecha
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: brand.background,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  DateFormat.MMM(locale).format(start).toUpperCase(),
                  style: AppText.eyebrow(
                    size: 9,
                    spacing: 1,
                    weight: FontWeight.w300,
                    color: dateInk,
                  ),
                ),
                Text(
                  start.day.toString().padLeft(2, '0'),
                  style: AppText.serif(size: 20, height: 1, color: dateInk),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${capitalizeFirst(DateFormat.EEEE(locale).format(start))}'
                  ' · $timeStr',
                  style: AppText.serif(
                    size: 17,
                    color: cancelled ? brand.inkMuted : brand.ink,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  status.label,
                  style: AppText.eyebrow(
                    size: 10,
                    spacing: 1.6,
                    color: status.color,
                  ),
                ),
              ],
            ),
          ),
          if (!cancelled) ...[
            const SizedBox(width: 10),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: status.color,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
