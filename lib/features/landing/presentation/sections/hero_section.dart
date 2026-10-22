import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/platform/external_links.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../navigation/presentation/web_top_bar.dart';
import '../../landing_content.dart';
import '../landing_layout.dart';
import '../widgets/landing_image.dart';

/// Hero de la landing: presentación del salón, "Reservar cita", "Ver lista de
/// precios", cifras, dirección y foto de Beidis (spec 002).
class HeroSection extends StatelessWidget {
  const HeroSection({super.key, required this.onPricesTap});

  /// Lleva a la lista de precios (RF-5).
  final VoidCallback onPricesTap;

  @override
  Widget build(BuildContext context) {
    final wide = landingIsWide(context);
    final left = _HeroText(onPricesTap: onPricesTap);

    return ColoredBox(
      color: context.brand.brandSurface,
      child: wide
          ? Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: left),
                Expanded(
                  // La foto ocupa al menos la ventana visible bajo la barra.
                  child: _HeroPhoto(
                    height: math.max(
                      560,
                      MediaQuery.sizeOf(context).height - WebTopBar.height,
                    ),
                  ),
                ),
              ],
            )
          : Column(children: [const _HeroPhoto(height: 420), left]),
    );
  }
}

class _HeroText extends ConsumerWidget {
  const _HeroText({required this.onPricesTap});

  final VoidCallback onPricesTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final wide = landingIsWide(context);
    final titleStyle = AppText.serif(
      size: wide ? 56 : 40,
      color: brand.onBrandSurface,
      height: 1.1,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(wide ? 80 : 24, 48, wide ? 48 : 24, 48),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(width: 28, height: 1, color: brand.accent),
              const SizedBox(width: 12),
              Flexible(
                child: Text(
                  l10n.landingHeroKicker.toUpperCase(),
                  style: AppText.eyebrow(
                    size: 11,
                    spacing: 2,
                    color: brand.onBrandSurfaceMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            l10n.landingHeroScript,
            style: AppText.serif(
              size: 24,
              color: brand.onBrandSurfaceAccent,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 4),
          Text(l10n.landingHeroTitleLine1, style: titleStyle),
          Text(
            l10n.landingHeroTitleLine2Em,
            style: titleStyle.copyWith(
              fontStyle: FontStyle.italic,
              fontWeight: FontWeight.w300,
            ),
          ),
          const SizedBox(height: 20),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Text(
              l10n.landingHeroDesc,
              style: AppText.sans(
                size: 15,
                color: brand.onBrandSurfaceMuted,
                height: 1.7,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              ElevatedButton(
                onPressed: () => context.go('/booking'),
                style: ElevatedButton.styleFrom(
                  // Verde sobre dorado: el mismo par en los dos temas (5,1:1).
                  backgroundColor: brand.accent,
                  foregroundColor: brand.brand,
                  elevation: 0,
                  minimumSize: const Size(48, 48),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                ),
                child: Text(
                  l10n.landingHeroCtaReserve.toUpperCase(),
                  style: AppText.sans(
                    size: 12,
                    weight: FontWeight.w600,
                    spacing: 1,
                    color: brand.brand,
                  ),
                ),
              ),
              OutlinedButton(
                onPressed: onPricesTap,
                style: OutlinedButton.styleFrom(
                  foregroundColor: brand.onBrandSurface,
                  side: BorderSide(color: brand.onBrandSurfaceMuted),
                  minimumSize: const Size(48, 48),
                  shape: const StadiumBorder(),
                  padding: const EdgeInsets.symmetric(horizontal: 26),
                ),
                child: Text(
                  l10n.landingHeroCtaPrices.toUpperCase(),
                  style: AppText.sans(
                    size: 12,
                    spacing: 1,
                    color: brand.onBrandSurface,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Container(height: 1, color: brand.brandSurfaceHairline),
          const SizedBox(height: 20),
          Wrap(
            spacing: 36,
            runSpacing: 16,
            children: [
              _Stat(
                number: LandingContent.statServices,
                label: l10n.landingHeroStatServicesLabel,
              ),
              _Stat(
                number: LandingContent.statFollowers,
                label: l10n.landingHeroStatFollowersLabel,
              ),
              _Stat(
                number: LandingContent.statNotice,
                label: l10n.landingHeroStatNoticeLabel,
              ),
            ],
          ),
          const SizedBox(height: 20),
          // Dirección: abre la ubicación en Google Maps (RF-9).
          InkWell(
            onTap: () => ref.read(externalLinkLauncherProvider)(
              Uri.parse(LandingContent.mapsUrl),
            ),
            child: Container(
              constraints: const BoxConstraints(maxWidth: 460, minHeight: 48),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
              decoration: BoxDecoration(
                border: Border.all(color: brand.onBrandSurfaceMuted),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.landingHeroAddressLabel.toUpperCase(),
                          style: AppText.eyebrow(
                            size: 11,
                            spacing: 1.5,
                            color: brand.onBrandSurfaceAccent,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          LandingContent.addressFull,
                          style: AppText.serif(
                            size: 19,
                            color: brand.onBrandSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    l10n.landingHeroAddressCta,
                    style: AppText.eyebrow(
                      size: 11,
                      color: brand.onBrandSurfaceMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.number, required this.label});

  final String number;
  final String label;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          number,
          style: AppText.serif(size: 28, color: brand.onBrandSurface),
        ),
        const SizedBox(height: 4),
        Text(
          label.toUpperCase(),
          style: AppText.eyebrow(
            size: 11,
            spacing: 1.5,
            color: brand.onBrandSurfaceMuted,
          ),
        ),
      ],
    );
  }
}

/// Foto de Beidis con la insignia de la francesa gratis en la 1ª visita.
class _HeroPhoto extends StatelessWidget {
  const _HeroPhoto({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return SizedBox(
      height: height,
      child: Stack(
        fit: StackFit.expand,
        children: [
          LandingImage(
            asset: LandingContent.heroPhoto,
            description: l10n.landingHeroImageAlt,
            fit: BoxFit.cover,
            alignment: Alignment.topCenter,
          ),
          Positioned(
            top: 24,
            right: 24,
            child: Container(
              width: 104,
              height: 104,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: brand.accent,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: brand.photoScrimStart,
                    blurRadius: 24,
                    offset: const Offset(0, 10),
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: Text(
                '${l10n.landingHeroBadgeLine1}\n'
                '${l10n.landingHeroBadgeLine2}\n'
                '${l10n.landingHeroBadgeLine3}',
                textAlign: TextAlign.center,
                style: AppText.sans(
                  size: 11,
                  weight: FontWeight.w700,
                  spacing: 0.4,
                  height: 1.35,
                  // Verde sobre dorado: 5,1:1 en los dos temas.
                  color: brand.brand,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
