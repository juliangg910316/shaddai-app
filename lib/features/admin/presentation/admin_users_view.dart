import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/admin_provider.dart';

class AdminUsersView extends ConsumerWidget {
  const AdminUsersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final usersAsync = ref.watch(adminUsersProvider);
    final brand = context.brand;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminClientsTitle)),
      body: usersAsync.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (err, stack) {
          debugPrint('Error al cargar las clientas: $err');
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                l10n.adminClientsLoadError,
                textAlign: TextAlign.center,
                style: AppText.sans(size: 13, color: brand.danger),
              ),
            ),
          );
        },
        data: (users) {
          if (users.isEmpty) {
            return Center(
              child: Text(
                l10n.adminNoClientsRegistered,
                style: AppText.sans(
                  size: 13,
                  weight: FontWeight.w300,
                  color: brand.inkMuted,
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
                    ? brand.danger.withValues(alpha: 0.4)
                    : brand.hairline,
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
                              color: brand.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            user.phoneNumber ?? user.email,
                            style: AppText.sans(
                              size: 12,
                              weight: FontWeight.w300,
                              color: brand.inkMuted,
                            ),
                          ),
                          const SizedBox(height: 5),
                          Text(
                            user.isBlocked
                                ? l10n.userStatusBlocked
                                : l10n.userStatusActive,
                            style: AppText.eyebrow(
                              size: 10,
                              spacing: 1.6,
                              color: user.isBlocked
                                  ? brand.danger
                                  : brand.inkStrong,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: user.isBlocked,
                      activeThumbColor: brand.danger,
                      inactiveThumbColor: brand.inkMuted,
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
