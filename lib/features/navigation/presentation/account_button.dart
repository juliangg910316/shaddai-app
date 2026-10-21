import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';

/// Botón de cuenta de la barra superior de Web (spec 002, RF-24 a RF-28).
///
/// Sin sesión: "Entrar". Con sesión: la foto (o la inicial) y un menú con
/// "Mis turnos", "Panel de administración" (solo admin) y "Cerrar sesión".
class AccountButton extends ConsumerWidget {
  const AccountButton({super.key});

  // Con el relleno del botón, 48 px: el mismo alto que el resto de la barra.
  static const _avatarSize = 32.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    if (user == null) {
      // Mientras carga la ficha, se reserva el sitio sin mostrar "Entrar".
      if (userAsync.isLoading) return const SizedBox(width: 48, height: 48);
      return TextButton(
        onPressed: () => context.go('/login'),
        style: TextButton.styleFrom(
          foregroundColor: brand.onBrandSurface,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(horizontal: 12),
        ),
        child: Text(
          l10n.accountSignIn,
          style: AppText.sans(
            size: 13,
            weight: FontWeight.w600,
            color: brand.onBrandSurface,
          ),
        ),
      );
    }

    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.event_note_outlined),
          onPressed: () => context.go('/profile'),
          child: Text(l10n.accountMyAppointments),
        ),
        if (user.role == 'admin')
          MenuItemButton(
            leadingIcon: const Icon(Icons.admin_panel_settings_outlined),
            onPressed: () => context.go('/admin'),
            child: Text(l10n.accountAdminPanel),
          ),
        MenuItemButton(
          leadingIcon: const Icon(Icons.logout),
          // Primero a la landing: así la página de cuenta que se deja no
          // redirige al login al cerrarse la sesión (plan § 4).
          onPressed: () {
            context.go('/');
            ref.read(authControllerProvider.notifier).signOut();
          },
          child: Text(l10n.accountSignOut),
        ),
      ],
      builder: (context, controller, child) => IconButton(
        tooltip: l10n.accountMenuLabel,
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
        icon: _AccountAvatar(
          photoUrl: user.photoUrl,
          name: user.displayName,
          size: _avatarSize,
        ),
      ),
    );
  }
}

/// Foto de la persona o, si no tiene o no carga, la inicial de su nombre.
class _AccountAvatar extends StatelessWidget {
  const _AccountAvatar({
    required this.photoUrl,
    required this.name,
    required this.size,
  });

  final String? photoUrl;
  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    // Solo la inicial del nombre (RF-25), no las dos de nombre y apellido.
    final firstName = name.trim().split(RegExp(r'\s+')).first;
    final initial = InitialsAvatar(name: firstName, size: size);
    final url = photoUrl;
    if (url == null || url.isEmpty) return initial;

    return ClipOval(
      child: Image.network(
        url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        // La etiqueta del botón ya dice qué es: la foto no se anuncia.
        excludeFromSemantics: true,
        errorBuilder: (context, error, stackTrace) => initial,
      ),
    );
  }
}
