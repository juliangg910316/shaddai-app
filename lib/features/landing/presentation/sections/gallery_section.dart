import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/external_links.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../navigation/presentation/web_shell.dart';
import '../../landing_content.dart';
import '../widgets/landing_image.dart';
import 'section_header.dart';

/// Galería de diseños: nueve trabajos de Instagram en una rejilla (3 columnas
/// en ancho amplio, 2 en estrecho). Cada foto y "Ver más en Instagram" abren
/// el Instagram del salón (RF-8).
class GallerySection extends ConsumerWidget {
  const GallerySection({super.key});

  static const _spacing = 8.0;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final wide = WebShell.isWide(context);
    final columns = wide ? 3 : 2;
    void openInstagram() => ref.read(externalLinkLauncherProvider)(
      Uri.parse(LandingContent.instagramUrl),
    );

    return ColoredBox(
      color: brand.brandSurface,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: wide ? 80 : 24,
          vertical: wide ? 96 : 56,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LandingSectionHeader(
              eyebrow: l10n.landingGalleryEyebrow,
              title: l10n.landingGalleryTitle,
              titleEm: l10n.landingGalleryTitleEm,
              onBrandSurface: true,
              trailing: TextButton(
                onPressed: openInstagram,
                style: TextButton.styleFrom(
                  foregroundColor: brand.onBrandSurface,
                  minimumSize: const Size(48, 48),
                ),
                child: Text(
                  l10n.landingGalleryMoreLink,
                  style: AppText.sans(size: 13, color: brand.onBrandSurface),
                ),
              ),
            ),
            const SizedBox(height: 32),
            LayoutBuilder(
              builder: (context, constraints) {
                final tileSize =
                    (constraints.maxWidth - _spacing * (columns - 1)) / columns;
                return Wrap(
                  spacing: _spacing,
                  runSpacing: _spacing,
                  children: [
                    for (
                      var i = 0;
                      i < LandingContent.galleryImages.length;
                      i++
                    )
                      SizedBox.square(
                        dimension: tileSize,
                        child: _GalleryTile(
                          asset: LandingContent.galleryImages[i],
                          description: l10n.landingGalleryItemLabel(i + 1),
                          onTap: openInstagram,
                        ),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GalleryTile extends StatelessWidget {
  const _GalleryTile({
    required this.asset,
    required this.description,
    required this.onTap,
  });

  final String asset;
  final String description;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: description,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            child: LandingImage(asset: asset, description: description),
          ),
        ),
      ),
    );
  }
}
