import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/theme_colors.dart';
import '../providers/admin_provider.dart';

class AdminUsersView extends ConsumerWidget {
  const AdminUsersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      appBar: AppBar(
        title: const Text('Gestión de Clientes'),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: ThemeColors.darkGreen)),
        error: (err, stack) => Center(child: Text('Error: $err')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No hay clientes registrados.'));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final user = users[index];
              return ListTile(
                tileColor: ThemeColors.white,
                leading: user.photoUrl != null
                    ? CircleAvatar(backgroundImage: NetworkImage(user.photoUrl!))
                    : const CircleAvatar(child: Icon(Icons.person)),
                title: Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text(user.phoneNumber ?? user.email),
                trailing: Switch(
                  value: user.isBlocked,
                  activeColor: Colors.red,
                  onChanged: (val) {
                    ref.read(adminControllerProvider).toggleUserBlock(user.uid, val);
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
