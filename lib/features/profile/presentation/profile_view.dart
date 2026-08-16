import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/spanish_dates.dart';
import '../../../core/constants/theme_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/appointment_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final appointmentsAsync = ref.watch(clientAppointmentsProvider);

    if (user == null) {
      return const Scaffold(
        backgroundColor: ThemeColors.bone,
        body: Center(
          child: CircularProgressIndicator(
            color: ThemeColors.darkGreen,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThemeColors.bone,
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
                      'Mi Perfil',
                      textAlign: TextAlign.center,
                      style: AppText.serif(
                        size: 24,
                        color: ThemeColors.darkGreen,
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () =>
                        ref.read(authControllerProvider.notifier).signOut(),
                    child: const Icon(
                      Icons.logout,
                      size: 22,
                      color: ThemeColors.olive,
                    ),
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
                    style: AppText.serif(
                      size: 26,
                      color: ThemeColors.darkGreen,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.phoneNumber ?? user.email,
                    style: AppText.sans(
                      size: 14,
                      weight: FontWeight.w300,
                      color: ThemeColors.olive,
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
                    icon: const Icon(
                      Icons.admin_panel_settings_outlined,
                      color: ThemeColors.gold,
                      size: 18,
                    ),
                    label: Text(
                      'PANEL DE ADMINISTRADOR',
                      style: AppText.sans(
                        size: 12,
                        weight: FontWeight.w500,
                        spacing: 2,
                        color: ThemeColors.gold,
                      ),
                    ),
                  ),
                ),
              ),

            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: SectionHeading('Mis reservas'),
            ),
            const SizedBox(height: 16),

            Expanded(
              child: appointmentsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: ThemeColors.darkGreen,
                    strokeWidth: 2,
                  ),
                ),
                error: (err, stack) => Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      'No pudimos cargar tus reservas: $err',
                      textAlign: TextAlign.center,
                      style: AppText.sans(size: 13, color: ThemeColors.danger),
                    ),
                  ),
                ),
                data: (appointments) => ListView(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                  children: [
                    if (appointments.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 26),
                        child: Center(
                          child: Text(
                            'Todavía no tienes reservas.',
                            style: AppText.sans(
                              size: 13,
                              weight: FontWeight.w300,
                              color: ThemeColors.olive,
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
                      label: 'RESERVAR OTRO TURNO',
                      onPressed: () => context.go('/booking'),
                    ),
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

class _AppointmentCard extends StatelessWidget {
  final AppointmentModel appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context) {
    final status = AppointmentStatusStyle.forClient(appointment.status);
    final cancelled = appointment.status == 'cancelled';
    final start = appointment.startTime;
    final timeStr =
        '${start.hour.toString().padLeft(2, '0')}:'
        '${start.minute.toString().padLeft(2, '0')}';

    final card = FlatCard(
      color: cancelled
          ? ThemeColors.white.withValues(alpha: 0.55)
          : ThemeColors.white,
      borderColor: switch (appointment.status) {
        'waiting_confirmation' => ThemeColors.goldHairline,
        'cancelled' => ThemeColors.darkGreen.withValues(alpha: 0.08),
        _ => ThemeColors.hairline,
      },
      child: Row(
        children: [
          // Chip de fecha
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: ThemeColors.bone,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  SpanishDates.monthShort(start),
                  style: AppText.eyebrow(
                    size: 9,
                    spacing: 1,
                    weight: FontWeight.w300,
                    color: cancelled
                        ? ThemeColors.olive
                        : ThemeColors.darkGreen,
                  ),
                ),
                Text(
                  start.day.toString().padLeft(2, '0'),
                  style: AppText.serif(
                    size: 20,
                    height: 1,
                    color: cancelled
                        ? ThemeColors.olive
                        : ThemeColors.darkGreen,
                  ),
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
                  '${SpanishDates.weekday(start)} · $timeStr',
                  style: AppText.serif(
                    size: 17,
                    color: cancelled ? ThemeColors.olive : ThemeColors.black,
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

    return cancelled ? Opacity(opacity: 0.72, child: card) : card;
  }
}
