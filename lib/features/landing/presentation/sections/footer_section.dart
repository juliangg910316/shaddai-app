import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/external_links.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../core/widgets/brand_logo.dart';
import '../../../../l10n/app_localizations.dart';
import '../../landing_content.dart';
import '../landing_layout.dart';

/// Pie de la landing: marca, lema, redes sociales (RF-10) y copyright.
class FooterSection extends ConsumerWidget {
  const FooterSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final wide = landingIsWide(context);

    final identity = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const BrandLogo(size: 54),
        const SizedBox(width: 12),
        Flexible(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.brandFullName.toUpperCase(),
                style: AppText.serif(
                  size: 18,
                  spacing: 1.5,
                  color: brand.onBrandSurface,
                ),
              ),
              Text(
                l10n.landingFooterTagline,
                style: AppText.serif(
                  size: 16,
                  color: brand.onBrandSurfaceMuted,
                ).copyWith(fontStyle: FontStyle.italic),
              ),
            ],
          ),
        ),
      ],
    );

    final social = Wrap(
      spacing: 8,
      runSpacing: 4,
      alignment: WrapAlignment.center,
      children: [
        for (final (name, url) in LandingContent.socialLinks)
          TextButton(
            onPressed: () =>
                ref.read(externalLinkLauncherProvider)(Uri.parse(url)),
            style: TextButton.styleFrom(
              foregroundColor: brand.onBrandSurface,
              minimumSize: const Size(48, 48),
            ),
            child: Text(
              name.toUpperCase(),
              style: AppText.eyebrow(
                size: 11,
                spacing: 1.2,
                color: brand.onBrandSurfaceMuted,
              ),
            ),
          ),
      ],
    );

    return ColoredBox(
      color: brand.brandSurface,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: wide ? 80 : 24,
              vertical: 32,
            ),
            child: wide
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(child: identity),
                      const SizedBox(width: 24),
                      social,
                    ],
                  )
                : Column(
                    children: [identity, const SizedBox(height: 20), social],
                  ),
          ),
          Container(height: 1, color: brand.brandSurfaceHairline),
          Padding(
            // Abajo, sitio para el botón flotante de WhatsApp: al final de la
            // landing no tapa el copyright.
            padding: const EdgeInsets.fromLTRB(24, 16, 24, 96),
            child: Text(
              LandingContent.copyright,
              textAlign: TextAlign.center,
              style: AppText.sans(size: 12, color: brand.onBrandSurfaceMuted),
            ),
          ),
        ],
      ),
    );
  }
}
