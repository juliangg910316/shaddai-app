import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/platform_provider.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../logic/push_notices.dart';
import '../providers/admin_push_provider.dart';

/// Arriba de la agenda, mientras este teléfono tiene denegado el permiso de
/// notificaciones: explica cómo activarlo en los ajustes, sin volver a
/// pedirlo (spec 011, RF-17; plan D-8, § 6). Se lee como una frase. Fuera
/// de ese caso (otro permiso, Web, otra sesión) no ocupa nada.
class AdminPushDisabledCard extends ConsumerWidget {
  const AdminPushDisabledCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final show = showPushDisabled(
      isWeb: ref.watch(isWebProvider),
      user: ref.watch(currentUserProvider).value,
      permission: ref.watch(pushPermissionProvider),
    );
    if (!show) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    return Padding(
      key: const Key('admin-push-disabled'),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: MergeSemantics(
        child: FlatCard(
          padding: const EdgeInsets.all(14),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.notifications_off_outlined, color: brand.accentIcon),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.adminPushDisabledTitle,
                      style: AppText.sans(
                        size: 14,
                        weight: FontWeight.w700,
                        color: brand.inkStrong,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.adminPushDisabledBody,
                      style: AppText.sans(
                        size: 13,
                        color: brand.ink,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
