import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/theme_colors.dart';
import '../../../core/platform/platform_provider.dart';
import '../../../l10n/app_localizations.dart';
import '../../preferences/presentation/language_switch.dart';
import '../../preferences/presentation/theme_menu_button.dart';

class MainScaffold extends ConsumerWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final isWeb = ref.watch(isWebProvider);

    return Scaffold(
      // Provisional hasta la landing de Web (spec 002): en Web, los selectores
      // de tema e idioma van en una barra superior (RF-27).
      appBar: isWeb
          ? AppBar(
              automaticallyImplyLeading: false,
              actions: const [
                ThemeMenuButton(),
                SizedBox(width: 8),
                LanguageSwitch(),
                SizedBox(width: 16),
              ],
            )
          : null,
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onTap(context, index),
        type: BottomNavigationBarType.fixed,
        backgroundColor: ThemeColors.darkGreen,
        selectedItemColor: ThemeColors.gold,
        unselectedItemColor: ThemeColors.bone.withValues(alpha: 0.6),
        // El diseño usa iconos de trazo y etiquetas pequeñas, siempre visibles.
        elevation: 0,
        iconSize: 22,
        selectedFontSize: 10,
        unselectedFontSize: 10,
        items: _items(l10n),
      ),
    );
  }
}

// Perfil está siempre, también sin sesión: ahí van las Preferencias (RF-24).
List<BottomNavigationBarItem> _items(AppLocalizations l10n) {
  final List<BottomNavigationBarItem> list = [];
  list.add(
    BottomNavigationBarItem(
      icon: const Icon(Icons.home_outlined),
      label: l10n.homeTab,
    ),
  );
  list.add(
    BottomNavigationBarItem(
      icon: const Icon(Icons.spa_outlined),
      label: l10n.servicesTab,
    ),
  );
  list.add(
    BottomNavigationBarItem(
      icon: const Icon(Icons.calendar_today_outlined),
      label: l10n.appointmentsTab,
    ),
  );
  list.add(
    BottomNavigationBarItem(
      icon: const Icon(Icons.person_outline),
      label: l10n.profileTab,
    ),
  );
  return list;
}
