import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/spanish_dates.dart';
import '../../../core/constants/theme_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/admin_provider.dart';
import '../../../data/models/appointment_model.dart';

class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(adminSelectedDateProvider);
    final appointmentsAsync = ref.watch(adminAppointmentsProvider);
    final appointments = appointmentsAsync.value ?? const <AppointmentModel>[];

    final waitingCount = appointments
        .where((a) => a.status == 'waiting_confirmation')
        .length;

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      body: Column(
        children: [
          _AdminHeader(
            selectedDate: selectedDate,
            totalCount: appointments.length,
            waitingCount: waitingCount,
            onPreviousDay: () =>
                ref.read(adminSelectedDateProvider.notifier).state =
                    selectedDate.subtract(const Duration(days: 1)),
            onNextDay: () =>
                ref.read(adminSelectedDateProvider.notifier).state =
                    selectedDate.add(const Duration(days: 1)),
          ),
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
                    'No pudimos cargar la agenda: $err',
                    textAlign: TextAlign.center,
                    style: AppText.sans(size: 13, color: ThemeColors.danger),
                  ),
                ),
              ),
              data: (items) {
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      'No hay reservas para este día.',
                      style: AppText.sans(
                        size: 13,
                        weight: FontWeight.w300,
                        color: ThemeColors.olive,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _AppointmentCard(appointment: items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
  final DateTime selectedDate;
  final int totalCount;
  final int waitingCount;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  const _AdminHeader({
    required this.selectedDate,
    required this.totalCount,
    required this.waitingCount,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Cabecera verde oscuro: la barra de estado necesita iconos claros.
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: ThemeColors.darkGreen,
        statusBarIconBrightness: Brightness.light,
        statusBarBrightness: Brightness.dark,
      ),
      child: Container(
        width: double.infinity,
        color: ThemeColors.darkGreen,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (context.canPop())
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: const Icon(
                        Icons.arrow_back,
                        size: 22,
                        color: ThemeColors.bone,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Agenda',
                        style: AppText.serif(size: 24, color: ThemeColors.gold),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'PANEL DE BEIDIS',
                        style: AppText.eyebrow(
                          size: 11,
                          weight: FontWeight.w300,
                          color: ThemeColors.bone.withValues(alpha: 0.6),
                        ),
                      ),
                    ],
                  ),
                ),
                GestureDetector(
                  onTap: () => context.push('/admin/users'),
                  child: const Icon(
                    Icons.group_outlined,
                    size: 22,
                    color: ThemeColors.bone,
                  ),
                ),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: () => context.push('/admin/settings'),
                  child: const Icon(
                    Icons.settings_outlined,
                    size: 22,
                    color: ThemeColors.bone,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: ThemeColors.bone.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: ThemeColors.gold.withValues(alpha: 0.4),
                ),
              ),
              child: Row(
                children: [
                  IconButton(
                    onPressed: onPreviousDay,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.chevron_left,
                      color: ThemeColors.gold,
                    ),
                  ),
                  Expanded(
                    child: Text(
                      SpanishDates.longDate(selectedDate),
                      textAlign: TextAlign.center,
                      style: AppText.serif(
                        size: 17,
                        color: ThemeColors.bone,
                        spacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: onNextDay,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.chevron_right,
                      color: ThemeColors.gold,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatTile(value: totalCount, label: 'TURNOS HOY'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    value: waitingCount,
                    label: 'POR CONFIRMAR',
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final int value;
  final String label;

  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: ThemeColors.bone.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: AppText.serif(size: 22, color: ThemeColors.gold),
          ),
          Text(
            label,
            style: AppText.eyebrow(
              size: 10,
              spacing: 1.2,
              weight: FontWeight.w300,
              color: ThemeColors.bone.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  final AppointmentModel appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = AppointmentStatusStyle.forAdmin(appointment.status);
    final waiting = appointment.status == 'waiting_confirmation';
    final startStr = DateFormat('HH:mm').format(appointment.startTime);
    final endStr = DateFormat('HH:mm').format(appointment.endTime);

    return FlatCard(
      borderColor: waiting ? ThemeColors.goldHairline : ThemeColors.hairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '$startStr — $endStr',
                style: AppText.serif(size: 19, color: ThemeColors.darkGreen),
              ),
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
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 14),
            color: ThemeColors.hairline,
          ),
          Row(
            children: [
              InitialsAvatar(
                photoUrl: appointment.clientPhotoUrl,
                name: appointment.clientName,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.clientName,
                      style: AppText.sans(
                        size: 15,
                        weight: FontWeight.w500,
                        color: ThemeColors.black,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appointment.clientPhone,
                      style: AppText.sans(
                        size: 12,
                        weight: FontWeight.w300,
                        color: ThemeColors.olive,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: ThemeColors.hairlineStrong),
                ),
                alignment: Alignment.center,
                child: const WhatsAppIcon(size: 18),
              ),
            ],
          ),
          if (appointment.status != 'cancelled') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinePillButton(
                    label: 'CANCELAR',
                    color: ThemeColors.danger,
                    onPressed: () => ref
                        .read(adminControllerProvider)
                        .updateAppointmentStatus(appointment.id, 'cancelled'),
                  ),
                ),
                if (waiting) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => ref
                            .read(adminControllerProvider)
                            .updateAppointmentStatus(
                              appointment.id,
                              'confirmed',
                            ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: ThemeColors.darkGreen,
                          foregroundColor: ThemeColors.gold,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Text(
                          'CONFIRMAR',
                          style: AppText.sans(
                            size: 12,
                            weight: FontWeight.w500,
                            spacing: 1.2,
                            color: ThemeColors.gold,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}
