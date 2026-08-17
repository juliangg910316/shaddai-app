import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/theme_colors.dart';
import '../../../data/models/user_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../auth/providers/auth_provider.dart';

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
    final user = ref.watch(currentUserProvider).value;

    return Scaffold(
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
        items: _items(user, l10n),
      ),
    );
  }
}

List<BottomNavigationBarItem> _items(UserModel? user, AppLocalizations l10n) {
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
  if (user != null) {
    list.add(
      BottomNavigationBarItem(
        icon: const Icon(Icons.person_outline),
        label: l10n.profileTab,
      ),
    );
  }
  return list;
}
