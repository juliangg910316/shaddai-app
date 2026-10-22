import 'package:flutter/material.dart';

import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../landing_content.dart';
import '../landing_layout.dart';
import 'section_header.dart';

/// Combos Shaddai: tres paquetes con precio cerrado, sobre la superficie de
/// marca (RF-3).
class CombosSection extends StatelessWidget {
  const CombosSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final wide = landingIsWide(context);
    final combos = LandingContent.combos;

    return ColoredBox(
      color: brand.brandSurface,
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: wide ? 80 : 24,
          vertical: wide ? 64 : 48,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LandingSectionHeader(
              eyebrow: l10n.landingCombosEyebrow,
              title: l10n.landingCombosTitle,
              titleEm: l10n.landingCombosTitleEm,
              note: l10n.landingCombosNote,
              onBrandSurface: true,
            ),
            const SizedBox(height: 32),
            if (wide)
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < combos.length; i++) ...[
                      if (i > 0) ...[
                        VerticalDivider(
                          width: 1,
                          color: brand.brandSurfaceHairline,
                        ),
                        const SizedBox(width: 24),
                      ],
                      Expanded(child: _ComboView(combo: combos[i])),
                    ],
                  ],
                ),
              )
            else
              for (var i = 0; i < combos.length; i++) ...[
                if (i > 0)
                  Divider(height: 33, color: brand.brandSurfaceHairline),
                _ComboView(combo: combos[i]),
              ],
          ],
        ),
      ),
    );
  }
}

class _ComboView extends StatelessWidget {
  const _ComboView({required this.combo});

  final Combo combo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return Padding(
      padding: const EdgeInsets.only(right: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            combo.price,
            style: AppText.serif(size: 34, color: brand.onBrandSurfaceAccent),
          ),
          const SizedBox(height: 8),
          Text(
            combo.name(l10n),
            style: AppText.serif(size: 20, color: brand.onBrandSurface),
          ),
          const SizedBox(height: 4),
          Text(
            combo.description(l10n),
            style: AppText.sans(
              size: 13,
              color: brand.onBrandSurfaceMuted,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
