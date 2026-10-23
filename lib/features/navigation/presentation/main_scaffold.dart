import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';
import '../providers/tab_scroll_provider.dart';
import '../tab_tap_logic.dart';

/// Estructura de Android/iOS: la pestaña activa y la barra inferior con
/// Inicio, Servicios, Reservas y Perfil, con y sin sesión (spec 003, RF-1).
/// Web usa `WebShell`, con la barra superior (spec 002).
class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  /// Por encima de esta escala de texto, la barra muestra solo los iconos: sus
  /// nombres siguen en el tooltip y en el lector de pantalla (RNF-4, D-3).
  static const _iconsOnlyTextScale = 1.3;

  /// Dirección de la página principal de cada pestaña, en su orden.
  static const _tabRoots = ['/home', '/services', '/booking', '/profile'];

  void _onSelected(BuildContext context, WidgetRef ref, int index) {
    final path = GoRouter.of(
      context,
    ).routerDelegate.currentConfiguration.uri.path;
    final action = tabTapAction(
      isActive: index == navigationShell.currentIndex,
      isAtBranchRoot: path == _tabRoots[index],
    );
    switch (action) {
      case TabTapAction.switchTab:
        navigationShell.goBranch(index);
      case TabTapAction.popToRoot:
        // Con un detalle abierto, se cierra y la lista sigue donde estaba
        // (spec 004, RF-45).
        navigationShell.goBranch(index, initialLocation: true);
      case TabTapAction.scrollToTop:
        // Tocar la pestaña activa la devuelve a su comienzo (RF-4).
        final controller = ref.read(
          tabScrollControllerProvider(MobileTab.values[index]),
        );
        if (controller.hasClients) {
          controller.animateTo(
            0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOut,
          );
        }
        navigationShell.goBranch(index, initialLocation: true);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return Scaffold(
      body: navigationShell,
      // Colores del tema (navigationBarTheme). Cada destino mide al menos
      // 48 px y anuncia si está seleccionado (RF-2, RNF-1).
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => _onSelected(context, ref, index),
        labelBehavior: textScale > _iconsOnlyTextScale
            ? NavigationDestinationLabelBehavior.alwaysHide
            : NavigationDestinationLabelBehavior.alwaysShow,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: l10n.homeTab,
            tooltip: l10n.homeTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.spa_outlined),
            selectedIcon: const Icon(Icons.spa),
            label: l10n.servicesTab,
            tooltip: l10n.servicesTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_today_outlined),
            selectedIcon: const Icon(Icons.calendar_today),
            label: l10n.appointmentsTab,
            tooltip: l10n.appointmentsTab,
          ),
          NavigationDestination(
            icon: const Icon(Icons.person_outline),
            selectedIcon: const Icon(Icons.person),
            label: l10n.profileTab,
            tooltip: l10n.profileTab,
          ),
        ],
      ),
    );
  }
}
