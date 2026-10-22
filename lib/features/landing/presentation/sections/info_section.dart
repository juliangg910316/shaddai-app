import 'package:flutter/material.dart';

import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../landing_layout.dart';
import 'section_header.dart';

/// Cómo funciona la atención: las cuatro normas del estudio (reposición,
/// plazo de mantenimiento, retrasos y cancelaciones).
class InfoSection extends StatelessWidget {
  const InfoSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final wide = landingIsWide(context);

    final intro = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        LandingSectionHeader(
          eyebrow: l10n.landingInfoEyebrow,
          title: l10n.landingInfoTitle,
          titleEm: l10n.landingInfoTitleEm,
        ),
        const SizedBox(height: 16),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 340),
          child: Text(
            l10n.landingInfoDesc,
            style: AppText.sans(size: 15, color: brand.inkMuted, height: 1.8),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          l10n.landingInfoScript,
          style: AppText.serif(
            size: 20,
            color: brand.accentText,
          ).copyWith(fontStyle: FontStyle.italic),
        ),
      ],
    );

    final rules = [
      (l10n.landingInfo1Title, l10n.landingInfo1Body),
      (l10n.landingInfo2Title, l10n.landingInfo2Body),
      (l10n.landingInfo3Title, l10n.landingInfo3Body),
      (l10n.landingInfo4Title, l10n.landingInfo4Body),
    ];

    final list = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(height: 1, color: brand.hairline),
        for (final (title, body) in rules)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: brand.hairline)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: AppText.serif(size: 21, color: brand.ink)),
                const SizedBox(height: 6),
                Text(
                  body,
                  style: AppText.sans(
                    size: 13,
                    color: brand.inkMuted,
                    height: 1.7,
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
                  Expanded(child: intro),
                  const SizedBox(width: 48),
                  Expanded(flex: 2, child: list),
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [intro, const SizedBox(height: 32), list],
              ),
      ),
    );
  }
}
