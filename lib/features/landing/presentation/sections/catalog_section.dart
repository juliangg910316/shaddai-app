import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/platform/external_links.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../landing_content.dart';
import '../landing_layout.dart';
import '../widgets/landing_image.dart';
import 'section_header.dart';

/// Catálogo de servicios: las nueve páginas del catálogo del estudio en una
/// fila con desplazamiento horizontal y una tarjeta final que lleva a
/// Instagram. Cada página se amplía al pulsarla (RF-6, RF-7, RF-8).
class CatalogSection extends StatelessWidget {
  const CatalogSection({super.key});

  static const _cardHeight = 300.0;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final wide = landingIsWide(context);
    final sidePadding = wide ? 80.0 : 24.0;

    return ColoredBox(
      color: brand.background,
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: wide ? 96 : 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: EdgeInsets.symmetric(horizontal: sidePadding),
              child: LandingSectionHeader(
                eyebrow: l10n.landingCatalogEyebrow,
                title: l10n.landingCatalogTitle,
                titleEm: l10n.landingCatalogTitleEm,
                note: l10n.landingCatalogNote,
              ),
            ),
            const SizedBox(height: 32),
            // Todas las páginas se construyen (son pocas): así el foco del
            // teclado puede llegar a cada una y desplazar la fila hasta ella.
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: EdgeInsets.symmetric(horizontal: sidePadding),
              child: SizedBox(
                height: _cardHeight,
                child: Row(
                  children: [
                    for (
                      var i = 0;
                      i < LandingContent.catalogImages.length;
                      i++
                    )
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: _CatalogPage(
                          asset: LandingContent.catalogImages[i],
                          description: LandingContent.catalogDescriptions[i](
                            l10n,
                          ),
                        ),
                      ),
                    const _MoreOnInstagram(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatalogPage extends StatelessWidget {
  const _CatalogPage({required this.asset, required this.description});

  final String asset;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: description,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => _showEnlarged(context),
        borderRadius: BorderRadius.circular(4),
        child: AspectRatio(
          aspectRatio: 3 / 4,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LandingImage(asset: asset, description: description),
          ),
        ),
      ),
    );
  }

  /// La página ampliada sobre la landing. Se cierra con su botón, al pulsar
  /// fuera o con Esc; la landing no se mueve (RF-6, RF-7).
  void _showEnlarged(BuildContext context) {
    final brand = context.brand;
    showDialog<void>(
      context: context,
      barrierColor: brand.photoScrimEnd,
      builder: (dialogContext) => Dialog(
        insetPadding: const EdgeInsets.all(24),
        backgroundColor: brand.surface,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            InteractiveViewer(
              child: LandingImage(
                asset: asset,
                description: description,
                fit: BoxFit.contain,
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton.filled(
                tooltip: MaterialLocalizations.of(
                  dialogContext,
                ).closeButtonTooltip,
                onPressed: () => Navigator.of(dialogContext).pop(),
                style: IconButton.styleFrom(
                  backgroundColor: brand.surface,
                  foregroundColor: brand.ink,
                ),
                icon: const Icon(Icons.close),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Última tarjeta: más páginas del catálogo en Instagram (RF-8).
class _MoreOnInstagram extends ConsumerWidget {
  const _MoreOnInstagram();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return InkWell(
      onTap: () => ref.read(externalLinkLauncherProvider)(
        Uri.parse(LandingContent.instagramUrl),
      ),
      borderRadius: BorderRadius.circular(4),
      child: AspectRatio(
        aspectRatio: 3 / 4,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            border: Border.all(color: brand.hairlineStrong),
            borderRadius: BorderRadius.circular(4),
          ),
          // La tarjeta tiene alto fijo: con el texto grande, su contenido se
          // reduce en vez de desbordarse (RNF-4).
          child: LayoutBuilder(
            builder: (context, constraints) => FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: constraints.maxWidth,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ExcludeSemantics(
                      child: Text(
                        '+',
                        style: AppText.serif(size: 34, color: brand.accentText),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l10n.landingCatalogMoreCta,
                      textAlign: TextAlign.center,
                      style: AppText.sans(size: 13, color: brand.ink),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
