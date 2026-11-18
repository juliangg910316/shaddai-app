import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/platform/platform_provider.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';
import '../../preferences/presentation/preferences_section.dart';
import '../../booking/logic/salon_time.dart';
import '../../booking/providers/booking_provider.dart';
import '../../navigation/providers/tab_scroll_provider.dart';
import '../../services/presentation/price_list_notices.dart';
import '../providers/profile_provider.dart';
import '../logic/account_deletion.dart';
import 'change_whatsapp_dialog.dart';
import 'delete_account_dialog.dart';
import 'profile_cards.dart';

/// El perfil (spec 009): cabecera con "Cerrar sesión", identidad, acceso al
/// panel (solo la admin), el turno activo o la invitación a reservar, el
/// historial y, en Android/iOS, las preferencias. Todo va en una sola lista
/// con desplazamiento (D-12): un error al cargar los turnos no oculta lo
/// demás (RF-24), y con el texto grande se llega a todo (RNF-3).
class ProfileView extends ConsumerWidget {
  const ProfileView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;
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
        // Una sola columna con desplazamiento, construida entera: el perfil
        // es corto, y así la cuenta y las preferencias existen aunque estén
        // fuera de la pantalla (para el lector de pantalla y para los tests).
        child: SingleChildScrollView(
          controller: ref.watch(tabScrollControllerProvider(MobileTab.profile)),
          padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Cabecera: título centrado y salida a la derecha
              Row(
                children: [
                  const SizedBox(width: 48),
                  Expanded(
                    child: Text(
                      l10n.myProfileTitle,
                      textAlign: TextAlign.center,
                      style: AppText.serif(size: 24, color: brand.inkStrong),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.accountSignOut,
                    icon: Icon(Icons.logout, size: 22, color: brand.inkMuted),
                    onPressed: () {
                      // En Web, primero a la landing: el perfil sin sesión
                      // llevaría al login (spec 002, RF-28).
                      if (isWeb) context.go('/');
                      ref.read(authControllerProvider.notifier).signOut();
                    },
                  ),
                ],
              ),

              // Identidad
              Padding(
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 18),
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
                    // El WhatsApp va en "Tu cuenta", con "Cambiar".
                    Text(
                      user.email,
                      textAlign: TextAlign.center,
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
                  padding: const EdgeInsets.only(bottom: 20),
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

              SectionHeading(l10n.profileNextAppointmentTitle),
              const SizedBox(height: 16),
              const _ProfileAppointments(),

              // Tu cuenta: el WhatsApp con "Cambiar" (spec 009, RF-25).
              const SizedBox(height: 28),
              SectionHeading(l10n.profileAccountTitle),
              const SizedBox(height: 16),
              _WhatsAppRow(phone: user.phoneNumber ?? ''),
              // Eliminar la cuenta: la clienta; bloqueada, el aviso; la admin,
              // nada (spec 009, RF-31, RF-40).
              switch (accountDeletionAccess(
                role: user.role,
                isBlocked: user.isBlocked,
              )) {
                AccountDeletionAccess.hidden => const SizedBox.shrink(),
                AccountDeletionAccess.blocked => Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: AppNotice(
                    message: l10n.deleteAccountBlocked,
                    actions: const [WhatsappNoticeButton()],
                  ),
                ),
                AccountDeletionAccess.allowed => Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: OutlinePillButton(
                      key: const ValueKey('profile-delete-account'),
                      label: l10n.deleteAccountAction.toUpperCase(),
                      color: brand.danger,
                      onPressed: () => showDeleteAccountDialog(context),
                    ),
                  ),
                ),
              },

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
    );
  }
}

/// El turno activo (o la invitación a reservar) y el historial; si no se
/// pudieron cargar, el error con "Reintentar" en su lugar (RF-1, RF-5,
/// RF-20 a RF-24).
class _ProfileAppointments extends ConsumerWidget {
  const _ProfileAppointments();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final appointments = ref.watch(profileAppointmentsProvider);
    final isBlocked = ref.watch(
      currentUserProvider.select((user) => user.value?.isBlocked ?? false),
    );

    if (appointments.hasError) {
      debugPrint('Error al cargar mis reservas: ${appointments.error}');
      return AppNotice(
        message: l10n.myAppointmentsLoadError,
        actions: [
          AppNoticeButton(
            label: l10n.profileAppointmentsRetry,
            onPressed: () => ref.invalidate(myAppointmentsProvider),
          ),
        ],
      );
    }
    final value = appointments.value;
    if (value == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    }
    final now = fromSalon(
      ref.watch(salonNowProvider).value ?? toSalon(ref.read(clockProvider)()),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (value.active case final active?)
          ProfileActiveCard(appointment: active, isBlocked: isBlocked)
        else
          const ProfileNoUpcoming(),
        // Sin historial no hay sección (RF-22).
        if (value.history.isNotEmpty) ...[
          const SizedBox(height: 28),
          SectionHeading(l10n.profileHistoryTitle),
          const SizedBox(height: 16),
          for (final appointment in value.history) ...[
            ProfileHistoryCard(
              key: ValueKey('history-${appointment.id}'),
              appointment: appointment,
              now: now,
            ),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

/// Perfil sin sesión: solo Preferencias y el botón para iniciar sesión
/// (RF-25, RF-26).
class _GuestProfile extends ConsumerWidget {
  const _GuestProfile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          controller: ref.watch(tabScrollControllerProvider(MobileTab.profile)),
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

/// El WhatsApp de la clienta con "Cambiar" (spec 009, RF-25).
class _WhatsAppRow extends StatelessWidget {
  const _WhatsAppRow({required this.phone});

  final String phone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return FlatCard(
      key: const ValueKey('profile-whatsapp'),
      borderColor: brand.hairline,
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 10,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  l10n.profileWhatsAppLabel.toUpperCase(),
                  style: AppText.eyebrow(color: brand.inkMuted),
                ),
                const SizedBox(height: 4),
                Text(
                  phone,
                  style: AppText.sans(size: 16, color: brand.inkStrong),
                ),
              ],
            ),
          ),
          OutlinePillButton(
            key: const ValueKey('profile-whatsapp-change'),
            label: l10n.changeAction.toUpperCase(),
            onPressed: () => showChangeWhatsAppDialog(context, phone),
          ),
        ],
      ),
    );
  }
}
