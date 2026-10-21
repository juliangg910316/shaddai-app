import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';

class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell navigationShell;

  const MainScaffold({super.key, required this.navigationShell});

  void _onTap(BuildContext context, int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // Solo Android/iOS: Web usa `WebShell`, con la barra superior (spec 002).
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: navigationShell.currentIndex,
        onTap: (index) => _onTap(context, index),
        type: BottomNavigationBarType.fixed,
        // Colores del tema (bottomNavigationBarTheme). El diseño usa iconos de trazo y etiquetas pequeñas, siempre visibles.
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
