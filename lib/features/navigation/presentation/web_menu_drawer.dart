import 'package:flutter/material.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../landing/presentation/landing_navigation.dart';
import '../../preferences/presentation/language_switch.dart';
import '../../preferences/presentation/theme_menu_button.dart';
import 'web_top_bar.dart';

/// Menú lateral de Web en ancho estrecho: selectores de tema e idioma y
/// enlaces de sección (spec 002, RF-15). Elegir una sección lo cierra
/// (RF-16); cambiar tema o idioma no, para poder hacer los dos seguidos.
class WebMenuDrawer extends StatelessWidget {
  const WebMenuDrawer({super.key});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = AppLocalizations.of(context)!;

    return Drawer(
      backgroundColor: brand.brandSurface,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: IconButton(
                tooltip: l10n.webMenuCloseLabel,
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close, color: brand.onBrandSurface),
              ),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [ThemeMenuButton(), LanguageSwitch()],
            ),
            const SizedBox(height: 16),
            for (final (section, label) in webSectionLinks(l10n)) ...[
              Divider(color: brand.brandSurfaceHairline, height: 1),
              ListTile(
                minTileHeight: 56,
                title: Text(
                  label.toUpperCase(),
                  style: AppText.eyebrow(
                    size: 13,
                    spacing: 1.5,
                    color: brand.onBrandSurface,
                  ),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  goToLandingSection(context, section);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }
}
