import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/theme_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../providers/admin_provider.dart';

class AdminUsersView extends ConsumerWidget {
  const AdminUsersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final usersAsync = ref.watch(adminUsersProvider);

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      appBar: AppBar(title: const Text('Clientes')),
      body: usersAsync.when(
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
              'No pudimos cargar los clientes: $err',
              textAlign: TextAlign.center,
              style: AppText.sans(size: 13, color: ThemeColors.danger),
            ),
          ),
        ),
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Text(
                'No hay clientes registrados.',
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
            itemCount: users.length,
            separatorBuilder: (_, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              final user = users[index];

              return FlatCard(
                borderColor: user.isBlocked
                    ? ThemeColors.danger.withValues(alpha: 0.4)
                    : ThemeColors.hairline,
                child: Row(
                  children: [
                    InitialsAvatar(
                      photoUrl: user.photoUrl,
                      name: user.displayName,
                      size: 40,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.displayName,
                            style: AppText.sans(
                              size: 15,
                              weight: FontWeight.w500,
                              color: ThemeColors.black,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.phoneNumber ?? user.email,
                            style: AppText.sans(
                              size: 12,
                              weight: FontWeight.w300,
                              color: ThemeColors.olive,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            user.isBlocked ? 'BLOQUEADA' : 'ACTIVA',
                            style: AppText.eyebrow(
                              size: 10,
                              spacing: 1.6,
                              color: user.isBlocked
                                  ? ThemeColors.danger
                                  : ThemeColors.darkGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: user.isBlocked,
                      activeThumbColor: ThemeColors.danger,
                      inactiveThumbColor: ThemeColors.olive,
                      onChanged: (val) => ref
                          .read(adminControllerProvider)
                          .toggleUserBlock(user.uid, val),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
