import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/platform/external_links.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/user_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/logic/whatsapp.dart';
import '../../services/presentation/price_list_notices.dart';
import '../providers/admin_provider.dart';
import 'client_block_dialog.dart';

/// Las clientas del salón (spec 010, RF-19 a RF-24): sin admins, por
/// nombre, con su WhatsApp y el interruptor de bloqueo.
class AdminUsersView extends ConsumerWidget {
  const AdminUsersView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final clients = ref.watch(adminClientsProvider);
    final brand = context.brand;

    return Scaffold(
      appBar: AppBar(title: Text(l10n.adminClientsTitle)),
      body: clients.when(
        loading: () =>
            const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        error: (err, stack) {
          debugPrint('Error al cargar las clientas: $err');
          // Texto de la app y "Reintentar" (RF-24).
          return Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: AppNotice(
                message: l10n.adminClientsLoadError,
                actions: [
                  AppNoticeButton(
                    label: l10n.bookingRetry,
                    onPressed: () => ref.invalidate(adminUsersProvider),
                  ),
                ],
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
            itemBuilder: (context, index) => _ClientRow(client: users[index]),
          );
        },
      ),
    );
  }
}

class _ClientRow extends ConsumerWidget {
  const _ClientRow({required this.client});

  final UserModel client;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final phone = client.phoneNumber;
    final whatsApp = phone == null ? null : whatsAppLink(phone);
    // Sin WhatsApp (ficha antigua), su correo (RF-21).
    final contact = phone == null || phone.trim().isEmpty
        ? client.email
        : phone;
    final status = client.isBlocked
        ? l10n.userStatusBlocked
        : l10n.userStatusActive;

    return FlatCard(
      key: ValueKey('client-${client.uid}'),
      borderColor: client.isBlocked
          ? brand.danger.withValues(alpha: 0.4)
          : brand.hairline,
      child: Row(
        children: [
          InitialsAvatar(
            photoUrl: client.photoUrl,
            name: client.displayName,
            size: 40,
          ),
          const SizedBox(width: 12),
          // Se lee como una frase: nombre, contacto y estado (RNF-2).
          Expanded(
            child: Semantics(
              key: ValueKey('client-text-${client.uid}'),
              container: true,
              label: '${client.displayName}, $contact, $status',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    client.displayName,
                    style: AppText.sans(
                      size: 15,
                      weight: FontWeight.w500,
                      color: brand.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    contact,
                    style: AppText.sans(
                      size: 12,
                      weight: FontWeight.w300,
                      color: brand.inkMuted,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    status,
                    style: AppText.eyebrow(
                      size: 10,
                      spacing: 1.6,
                      color: client.isBlocked ? brand.danger : brand.inkStrong,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Su conversación de WhatsApp, como en la agenda (RF-22).
          if (whatsApp != null)
            IconButton(
              tooltip: l10n.adminAppointmentWhatsApp(client.displayName),
              onPressed: () => ref.read(externalLinkLauncherProvider)(whatsApp),
              style: IconButton.styleFrom(
                minimumSize: const Size(48, 48),
                shape: CircleBorder(
                  side: BorderSide(color: brand.hairlineStrong),
                ),
              ),
              icon: const WhatsAppIcon(size: 18),
            ),
          // Controlado: muestra siempre la ficha; tocarlo abre el diálogo y
          // solo cambia cuando llega la ficha nueva (plan D-7).
          Semantics(
            container: true,
            label: l10n.adminBlockSwitch(client.displayName),
            child: Switch(
              value: client.isBlocked,
              activeThumbColor: brand.danger,
              inactiveThumbColor: brand.inkMuted,
              onChanged: (_) => showClientBlockDialog(context, client),
            ),
          ),
        ],
      ),
    );
  }
}
