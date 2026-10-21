import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/brand_logo.dart';
import '../../../l10n/app_localizations.dart';
import '../../landing/landing_section.dart';
import '../../landing/presentation/landing_navigation.dart';
import '../../preferences/presentation/language_switch.dart';
import '../../preferences/presentation/theme_menu_button.dart';
import 'account_button.dart';
import 'web_shell.dart';

/// Enlaces de sección de la barra y del menú lateral, en orden.
List<(LandingSection, String)> webSectionLinks(AppLocalizations l10n) => [
  (LandingSection.prices, l10n.webNavServices),
  (LandingSection.catalog, l10n.webNavCatalog),
  (LandingSection.about, l10n.webNavAbout),
];

/// Barra superior de Web, fija en todas las páginas (spec 002, RF-13).
///
/// En ancho amplio: logotipo con nombre, enlaces de sección, tema, idioma,
/// "Reservar" y cuenta. En estrecho: logotipo, "Reservar", cuenta y el botón
/// del menú lateral, donde van los enlaces y los selectores (RF-15).
class WebTopBar extends StatelessWidget {
  const WebTopBar({super.key});

  /// Alto con el texto a su tamaño normal; con el texto grande, crece.
  static const height = 64.0;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = AppLocalizations.of(context)!;
    final wide = WebShell.isWide(context);

    return Material(
      color: brand.brandSurface,
      child: Container(
        // Con el texto grande la barra crece (sus botones pasan a otra fila)
        // en lugar de reducirlos por debajo de 48 px (RNF-2, RNF-4).
        constraints: const BoxConstraints(minHeight: height),
        padding: EdgeInsets.symmetric(horizontal: wide ? 32 : 8, vertical: 8),
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: brand.brandSurfaceHairline)),
        ),
        child: Row(
          children: [
            // El logotipo ocupa el espacio libre y, si falta, su nombre se
            // recorta antes que los botones.
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                child: _HomeLink(showName: wide),
              ),
            ),
            // Los botones pueden ocupar hasta 3/4 de la barra.
            Flexible(
              flex: 3,
              child: Wrap(
                alignment: WrapAlignment.end,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                runSpacing: 4,
                children: [
                  if (wide) ...[
                    for (final (section, label) in webSectionLinks(l10n))
                      _SectionLink(
                        label: label,
                        onPressed: () => goToLandingSection(context, section),
                      ),
                    const SizedBox(width: 12),
                    const ThemeMenuButton(),
                    const LanguageSwitch(),
                    const SizedBox(width: 12),
                  ],
                  const _ReserveButton(),
                  const AccountButton(),
                  if (!wide)
                    IconButton(
                      tooltip: l10n.webMenuOpenLabel,
                      onPressed: () => Scaffold.of(context).openEndDrawer(),
                      icon: Icon(Icons.menu, color: brand.onBrandSurface),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logotipo (y nombre en ancho amplio) que lleva al comienzo de la landing
/// (RF-14).
class _HomeLink extends StatelessWidget {
  const _HomeLink({required this.showName});

  final bool showName;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = AppLocalizations.of(context)!;

    return Semantics(
      link: true,
      label: l10n.webHomeLinkLabel,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => goToLandingTop(context),
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandLogo(size: 40),
                if (showName) ...[
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      l10n.brandFullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppText.serif(
                        size: 22,
                        color: brand.onBrandSurface,
                        spacing: 1,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionLink extends StatelessWidget {
  const _SectionLink({required this.label, required this.onPressed});

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return TextButton(
      onPressed: onPressed,
      style: TextButton.styleFrom(
        foregroundColor: brand.onBrandSurface,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 14),
      ),
      child: Text(
        label.toUpperCase(),
        style: AppText.eyebrow(
          size: 12,
          spacing: 1.2,
          color: brand.onBrandSurface,
        ),
      ),
    );
  }
}

/// "Reservar": lleva a la reserva; las redirecciones piden antes la sesión y
/// el WhatsApp si faltan (RF-19 a RF-21).
class _ReserveButton extends StatelessWidget {
  const _ReserveButton();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final l10n = AppLocalizations.of(context)!;

    return ElevatedButton(
      onPressed: () => context.go('/booking'),
      style: ElevatedButton.styleFrom(
        // Verde sobre dorado: el mismo par en los dos temas (5,1:1).
        backgroundColor: brand.accent,
        foregroundColor: brand.brand,
        elevation: 0,
        minimumSize: const Size(48, 48),
        padding: const EdgeInsets.symmetric(horizontal: 18),
        shape: const StadiumBorder(),
      ),
      child: Text(
        l10n.webNavReserve.toUpperCase(),
        style: AppText.sans(
          size: 12,
          weight: FontWeight.w600,
          spacing: 1.5,
          color: brand.brand,
        ),
      ),
    );
  }
}
