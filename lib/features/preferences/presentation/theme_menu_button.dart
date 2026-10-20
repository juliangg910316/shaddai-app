import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/preferences_logic.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/preferences_provider.dart';

/// Selector de tema de Web: un botón que abre un menú con claro, oscuro y
/// sistema, con la opción activa marcada (RF-18, RF-27).
///
/// Con teclado: Tab llega al botón, Intro o Espacio abre el menú, las flechas
/// recorren las opciones, Intro elige y Esc cierra (RNF-4).
class ThemeMenuButton extends ConsumerStatefulWidget {
  const ThemeMenuButton({super.key});

  @override
  ConsumerState<ThemeMenuButton> createState() => _ThemeMenuButtonState();
}

class _ThemeMenuButtonState extends ConsumerState<ThemeMenuButton> {
  // El menú lo usa para devolver el foco al botón y para navegar con flechas.
  final _buttonFocusNode = FocusNode(debugLabel: 'ThemeMenuButton');

  @override
  void dispose() {
    _buttonFocusNode.dispose();
    super.dispose();
  }

  static IconData _iconFor(ThemePreference preference) => switch (preference) {
    ThemePreference.light => Icons.light_mode_outlined,
    ThemePreference.dark => Icons.dark_mode_outlined,
    ThemePreference.system => Icons.brightness_auto_outlined,
  };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final current = ref.watch(themePreferenceProvider);
    final labels = {
      ThemePreference.light: l10n.themeLight,
      ThemePreference.dark: l10n.themeDark,
      ThemePreference.system: l10n.themeSystem,
    };

    return MenuAnchor(
      childFocusNode: _buttonFocusNode,
      menuChildren: [
        for (final preference in ThemePreference.values)
          MenuItemButton(
            // La marca ✓ distingue la opción activa sin depender del color.
            leadingIcon: preference == current
                ? Icon(Icons.check, color: brand.inkStrong)
                : const SizedBox(width: 24),
            onPressed: () =>
                ref.read(themePreferenceProvider.notifier).select(preference),
            // Dentro del botón, para que el lector de pantalla anuncie la
            // opción activa como seleccionada.
            child: Semantics(
              selected: preference == current,
              child: Text(labels[preference]!),
            ),
          ),
      ],
      builder: (context, controller, child) => IconButton(
        focusNode: _buttonFocusNode,
        tooltip: l10n.themeMenuTooltip,
        icon: Icon(_iconFor(current)),
        onPressed: () =>
            controller.isOpen ? controller.close() : controller.open(),
      ),
    );
  }
}
