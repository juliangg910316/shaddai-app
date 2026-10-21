import 'package:flutter/material.dart';

import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../navigation/presentation/web_shell.dart';
import '../../landing_content.dart';
import 'section_header.dart';

/// Sobre mí: la cita de Beidis, su historia y sus valores.
class AboutSection extends StatelessWidget {
  const AboutSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final wide = WebShell.isWide(context);

    final quote = Container(
      constraints: const BoxConstraints(minHeight: 340),
      padding: const EdgeInsets.all(28),
      color: brand.brandSurface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            l10n.landingAboutQuoteLabel.toUpperCase(),
            style: AppText.eyebrow(
              size: 11,
              spacing: 3,
              color: brand.onBrandSurfaceAccent,
            ),
          ),
          const SizedBox(height: 32),
          Text(
            l10n.landingAboutQuote,
            style: AppText.serif(
              size: 28,
              color: brand.onBrandSurface,
              height: 1.35,
            ).copyWith(fontStyle: FontStyle.italic),
          ),
          const SizedBox(height: 32),
          Text(
            LandingContent.founderRole.toUpperCase(),
            style: AppText.eyebrow(
              size: 11,
              spacing: 1,
              color: brand.onBrandSurfaceMuted,
            ),
          ),
        ],
      ),
    );

    final values = [
      l10n.landingAboutValue1,
      l10n.landingAboutValue2,
      l10n.landingAboutValue3,
      l10n.landingAboutValue4,
    ];
    final paragraphStyle = AppText.sans(
      size: 15,
      color: brand.inkMuted,
      height: 1.85,
    );

    final story = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LandingSectionHeader(
          eyebrow: l10n.landingAboutEyebrow,
          title: l10n.landingAboutTitle,
          titleEm: LandingContent.founderName,
        ),
        const SizedBox(height: 20),
        Text(l10n.landingAboutParagraph1, style: paragraphStyle),
        const SizedBox(height: 16),
        Text(l10n.landingAboutParagraph2, style: paragraphStyle),
        const SizedBox(height: 24),
        Container(height: 1, color: brand.hairline),
        for (final value in values)
          Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: brand.hairline)),
            ),
            child: Row(
              children: [
                ExcludeSemantics(
                  child: Text(
                    '+',
                    style: AppText.serif(size: 20, color: brand.accentText),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    value,
                    style: AppText.sans(size: 15, color: brand.ink),
                  ),
                ),
              ],
            ),
          ),
      ],
    );

    return ColoredBox(
      color: brand.surface,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: wide ? 80 : 24,
          vertical: wide ? 96 : 56,
        ),
        child: wide
            ? Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: quote),
                  const SizedBox(width: 48),
                  Expanded(flex: 2, child: story),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [quote, const SizedBox(height: 32), story],
              ),
      ),
    );
  }
}
