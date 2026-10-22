import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/platform/external_links.dart';
import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../landing_content.dart';
import '../landing_layout.dart';
import 'section_header.dart';

/// Contacto: "Reservar cita" (RF-32), "Agenda por WhatsApp" y los datos del
/// salón, cada uno con su enlace (RF-9, RF-10, RF-12).
///
/// En Android/iOS, que no tienen pie, añade las redes sociales y el mapa del
/// salón (spec 003, RF-10, RF-11).
class ContactSection extends ConsumerWidget {
  const ContactSection({super.key, this.map, this.showSocialLinks = false});

  /// Mapa con la ubicación, debajo de los datos y las redes.
  final Widget? map;

  /// Muestra las redes del pie (Instagram, TikTok, Facebook y YouTube).
  final bool showSocialLinks;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final wide = landingIsWide(context);
    void open(String url) =>
        ref.read(externalLinkLauncherProvider)(Uri.parse(url));

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LandingSectionHeader(
          eyebrow: l10n.landingContactEyebrow,
          title: l10n.landingContactTitle,
          titleEm: l10n.landingContactTitleEm,
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Text(
            l10n.landingContactDesc,
            style: AppText.sans(size: 15, color: brand.inkMuted, height: 1.8),
          ),
        ),
        const SizedBox(height: 24),
        // "Reservar cita" es la acción principal y WhatsApp la secundaria
        // (RF-32). Con poco ancho o texto grande, uno debajo del otro.
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
              onPressed: () => open(LandingContent.whatsappUrl),
              style: OutlinedButton.styleFrom(
                foregroundColor: brand.ink,
                side: BorderSide(color: brand.inkMuted),
                minimumSize: const Size(48, 48),
                shape: const StadiumBorder(),
                padding: const EdgeInsets.symmetric(horizontal: 26),
              ),
              child: Text(
                l10n.landingContactCtaWhatsapp.toUpperCase(),
                style: AppText.sans(size: 12, spacing: 1, color: brand.ink),
              ),
            ),
          ],
        ),
      ],
    );

    final rows = [
      (
        l10n.landingContactPhoneLabel,
        LandingContent.phoneDisplay,
        LandingContent.phoneUri,
      ),
      (
        l10n.landingContactEmailLabel,
        LandingContent.emailDisplay,
        LandingContent.emailUri,
      ),
      (
        l10n.landingContactAddressLabel,
        LandingContent.addressDisplay,
        LandingContent.mapsUrl,
      ),
      (
        l10n.landingContactInstagramLabel,
        LandingContent.instagramHandle,
        LandingContent.instagramUrl,
      ),
    ];

    final details = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (label, value, url) in rows)
          InkWell(
            onTap: () => open(url),
            child: Container(
              constraints: const BoxConstraints(minHeight: 48),
              padding: const EdgeInsets.symmetric(vertical: 18),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: brand.hairline)),
              ),
              child: Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 16,
                runSpacing: 4,
                children: [
                  Text(
                    label.toUpperCase(),
                    style: AppText.eyebrow(
                      size: 11,
                      spacing: 1.5,
                      color: brand.inkMuted,
                    ),
                  ),
                  Text(value, style: AppText.serif(size: 19, color: brand.ink)),
                ],
              ),
            ),
          ),
        if (showSocialLinks) ...[
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final (name, url) in LandingContent.socialLinks)
                TextButton(
                  onPressed: () => open(url),
                  style: TextButton.styleFrom(
                    foregroundColor: brand.ink,
                    minimumSize: const Size(48, 48),
                  ),
                  child: Text(
                    name.toUpperCase(),
                    style: AppText.eyebrow(
                      size: 11,
                      spacing: 1.2,
                      color: brand.inkMuted,
                    ),
                  ),
                ),
            ],
          ),
        ],
        if (map case final map?) ...[
          const SizedBox(height: 24),
          Semantics(container: true, label: l10n.salonMapLabel, child: map),
        ],
      ],
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        color: brand.surface,
        border: Border(top: BorderSide(color: brand.hairline)),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: wide ? 80 : 24,
          vertical: wide ? 96 : 56,
        ),
        child: wide
            ? Row(
                children: [
                  Expanded(child: intro),
                  const SizedBox(width: 48),
                  Expanded(child: details),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [intro, const SizedBox(height: 32), details],
              ),
      ),
    );
  }
}
