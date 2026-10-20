import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/preferences_logic.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/preferences_provider.dart';

/// Selector de idioma de Web: dos opciones "ES" y "PT" con la activa rellena y
/// en negrita (RF-19, RF-27). Se manejan con Tab y Espacio o Intro (RNF-4).
class LanguageSwitch extends ConsumerWidget {
  const LanguageSwitch({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    // Se marca el idioma que se ve, aunque no haya ninguno guardado.
    final current = parseLanguage(Localizations.localeOf(context).languageCode);
    final options = {
      AppLanguage.es: (l10n.languageCodeEs, l10n.languageSpanish),
      AppLanguage.pt: (l10n.languageCodePt, l10n.languagePortuguese),
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final MapEntry(key: language, value: (code, name))
            in options.entries)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2),
            child: _LanguagePill(
              code: code,
              semanticsLabel: '${l10n.languageSwitchLabel}: $name',
              selected: language == current,
              onSelected: () => ref
                  .read(languagePreferenceProvider.notifier)
                  .select(language),
            ),
          ),
      ],
    );
  }
}

class _LanguagePill extends StatelessWidget {
  const _LanguagePill({
    required this.code,
    required this.semanticsLabel,
    required this.selected,
    required this.onSelected,
  });

  final String code;
  final String semanticsLabel;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return ChoiceChip(
      label: Text(code, semanticsLabel: semanticsLabel),
      selected: selected,
      onSelected: (_) => onSelected(),
      showCheckmark: false,
      // Rellena y en negrita: la activa no se distingue solo por el color.
      labelStyle: AppText.sans(
        size: 12,
        weight: selected ? FontWeight.w700 : FontWeight.w400,
        spacing: 1.2,
        color: selected ? brand.onBrand : brand.ink,
      ),
      backgroundColor: brand.surface,
      selectedColor: brand.brand,
      side: BorderSide(color: brand.goldHairline),
      shape: const StadiumBorder(),
      materialTapTargetSize: MaterialTapTargetSize.padded,
    );
  }
}
