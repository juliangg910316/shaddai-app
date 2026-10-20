import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/preferences/preferences_logic.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/preferences_provider.dart';

/// Sección "Preferencias" de Perfil en Android/iOS: tema e idioma (RF-17 a
/// RF-19). Cambiar una opción no navega a ningún sitio.
class PreferencesSection extends ConsumerWidget {
  const PreferencesSection({super.key});

  /// A partir de este escalado de texto las opciones van una debajo de otra,
  /// para que no se corten (RNF-6).
  static const _verticalTextScale = 1.3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final theme = ref.watch(themePreferenceProvider);
    // Se marca el idioma que se ve, aunque no haya ninguno guardado (RF-19).
    final language = parseLanguage(
      Localizations.localeOf(context).languageCode,
    );
    final direction =
        MediaQuery.textScalerOf(context).scale(1) >= _verticalTextScale
        ? Axis.vertical
        : Axis.horizontal;

    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: 18, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: AppText.eyebrow(size: 11, color: brand.inkMuted),
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.preferencesTitle,
          style: AppText.serif(size: 21, color: brand.inkStrong),
        ),
        label(l10n.themeLabel),
        SegmentedButton<ThemePreference>(
          direction: direction,
          segments: [
            ButtonSegment(
              value: ThemePreference.light,
              label: Text(l10n.themeLight),
            ),
            ButtonSegment(
              value: ThemePreference.dark,
              label: Text(l10n.themeDark),
            ),
            ButtonSegment(
              value: ThemePreference.system,
              label: Text(l10n.themeSystem),
            ),
          ],
          selected: {theme},
          onSelectionChanged: (selection) => ref
              .read(themePreferenceProvider.notifier)
              .select(selection.single),
        ),
        label(l10n.languageLabel),
        SegmentedButton<AppLanguage>(
          direction: direction,
          segments: [
            ButtonSegment(
              value: AppLanguage.es,
              label: Text(l10n.languageSpanish),
            ),
            ButtonSegment(
              value: AppLanguage.pt,
              label: Text(l10n.languagePortuguese),
            ),
          ],
          selected: {?language},
          emptySelectionAllowed: language == null,
          onSelectionChanged: (selection) {
            if (selection.isEmpty) return;
            ref
                .read(languagePreferenceProvider.notifier)
                .select(selection.single);
          },
        ),
      ],
    );
  }
}
