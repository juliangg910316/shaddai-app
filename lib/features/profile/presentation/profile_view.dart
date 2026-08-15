import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/theme_colors.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider).value;
    final appointmentsAsync = ref.watch(clientAppointmentsProvider);

    if (user == null) {
      return const Center(
        child: CircularProgressIndicator(color: ThemeColors.darkGreen),
      );
    }

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () {
              ref.read(authControllerProvider.notifier).signOut();
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 24),
            // User Info
            Center(
              child: Column(
                children: [
                  if (user.photoUrl != null)
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(user.photoUrl!),
                    )
                  else
                    const CircleAvatar(
                      radius: 50,
                      backgroundColor: ThemeColors.darkGreen,
                      child: Icon(
                        Icons.person,
                        size: 50,
                        color: ThemeColors.gold,
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: ThemeColors.darkGreen,
                      fontFamily: 'serif',
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.phoneNumber ?? user.email,
                    style: const TextStyle(
                      color: ThemeColors.olive,
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),

            // Admin Panel Button (Hidden for normal users)
            if (user.role == 'admin')
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20.0),
                child: SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      context.push('/admin');
                    },
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: ThemeColors.darkGreen,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    icon: const Icon(
                      Icons.admin_panel_settings,
                      color: ThemeColors.gold,
                    ),
                    label: const Text(
                      'PANEL DE ADMINISTRADOR',
                      style: TextStyle(
                        color: ThemeColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 32),

            // My Appointments Header
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20.0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Mis Reservas',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: ThemeColors.darkGreen,
                    fontFamily: 'serif',
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Appointments List
            Expanded(
              child: appointmentsAsync.when(
                loading: () => const Center(
                  child: CircularProgressIndicator(
                    color: ThemeColors.darkGreen,
                  ),
                ),
                error: (err, stack) => Center(child: Text('Error: $err')),
                data: (appointments) {
                  if (appointments.isEmpty) {
                    return const Center(
                      child: Text('No tienes reservas registradas.'),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: appointments.length,
                    itemBuilder: (context, index) {
                      final app = appointments[index];
                      final dateStr = DateFormat(
                        'dd MMM yyyy',
                      ).format(app.startTime);
                      final timeStr = DateFormat('HH:mm').format(app.startTime);

                      Color statusColor;
                      String statusText;
                      switch (app.status) {
                        case 'confirmed':
                          statusColor = ThemeColors.darkGreen;
                          statusText = 'Confirmada';
                          break;
                        case 'cancelled':
                          statusColor = Colors.red;
                          statusText = 'Cancelada';
                          break;
                        default:
                          statusColor = ThemeColors.gold;
                          statusText = 'En Revisión';
                      }

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: ThemeColors.bone,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.calendar_today,
                              color: ThemeColors.darkGreen,
                            ),
                          ),
                          title: Text(
                            '$dateStr a las $timeStr',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              color: ThemeColors.black,
                            ),
                          ),
                          subtitle: Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              statusText,
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
