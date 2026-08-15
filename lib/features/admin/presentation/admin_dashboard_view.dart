import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/constants/theme_colors.dart';
import 'package:intl/intl.dart';
import '../providers/admin_provider.dart';
import '../../../data/models/appointment_model.dart';
import '/l10n/app_localizations.dart';

class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedDate = ref.watch(adminSelectedDateProvider);
    final appointmentsAsync = ref.watch(adminAppointmentsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      appBar: AppBar(
        title: Text(l10n.adminTab),
        actions: [
          IconButton(
            icon: const Icon(Icons.people),
            onPressed: () {
              context.push('/admin/users');
            },
          ),
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () {
              context.push('/admin/settings');
            },
          ),
        ],
      ),
      body: Column(
        children: [
          // Date Selector
          Container(
            padding: const EdgeInsets.all(16),
            color: ThemeColors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(
                    Icons.chevron_left,
                    color: ThemeColors.darkGreen,
                  ),
                  onPressed: () {
                    ref.read(adminSelectedDateProvider.notifier).state =
                        selectedDate.subtract(const Duration(days: 1));
                  },
                ),
                Text(
                  DateFormat('dd MMM yyyy').format(selectedDate),
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.darkGreen,
                  ),
                ),
                IconButton(
                  icon: const Icon(
                    Icons.chevron_right,
                    color: ThemeColors.darkGreen,
                  ),
                  onPressed: () {
                    ref.read(adminSelectedDateProvider.notifier).state =
                        selectedDate.add(const Duration(days: 1));
                  },
                ),
              ],
            ),
          ),
          // Appointments List
          Expanded(
            child: appointmentsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(color: ThemeColors.darkGreen),
              ),
              error: (err, stack) => Center(child: Text('Error: $err')),
              data: (appointments) {
                if (appointments.isEmpty) {
                  return const Center(
                    child: Text('No hay reservas para este día.'),
                  );
                }
                return ListView.builder(
                  itemCount: appointments.length,
                  padding: const EdgeInsets.all(16),
                  itemBuilder: (context, index) {
                    final app = appointments[index];
                    return _AppointmentCard(appointment: app);
                  },
                );
              },
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
    final startTimeStr = DateFormat('HH:mm').format(appointment.startTime);
    final endTimeStr = DateFormat('HH:mm').format(appointment.endTime);

    Color statusColor;
    String statusText;

    switch (appointment.status) {
      case 'confirmed':
        statusColor = ThemeColors.darkGreen;
        statusText = 'Confirmado';
        break;
      case 'cancelled':
        statusColor = Colors.red;
        statusText = 'Cancelado';
        break;
      default:
        statusColor = ThemeColors.gold;
        statusText = 'Por Confirmar';
    }

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '$startTimeStr - $endTimeStr',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.darkGreen,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: statusColor),
                  ),
                  child: Text(
                    statusText,
                    style: TextStyle(
                      color: statusColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            const Divider(),
            Row(
              children: [
                if (appointment.clientPhotoUrl != null)
                  CircleAvatar(
                    backgroundImage: NetworkImage(appointment.clientPhotoUrl!),
                  )
                else
                  const CircleAvatar(child: Icon(Icons.person)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        appointment.clientName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      Text(
                        appointment.clientPhone,
                        style: const TextStyle(color: Colors.grey),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (appointment.status != 'cancelled')
                  TextButton(
                    onPressed: () {
                      ref
                          .read(adminControllerProvider)
                          .updateAppointmentStatus(appointment.id, 'cancelled');
                    },
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                if (appointment.status == 'waiting_confirmation')
                  ElevatedButton(
                    onPressed: () {
                      ref
                          .read(adminControllerProvider)
                          .updateAppointmentStatus(appointment.id, 'confirmed');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ThemeColors.darkGreen,
                    ),
                    child: const Text(
                      'Confirmar',
                      style: TextStyle(color: ThemeColors.gold),
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
