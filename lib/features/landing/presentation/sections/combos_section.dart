import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../data/models/price_list_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../services/logic/price_list_view_logic.dart';
import '../../../services/providers/price_list_provider.dart';
import '../landing_layout.dart';
import 'section_header.dart';

/// Combos Shaddai, desde la base de datos, sobre la superficie de marca
/// (spec 004, RF-3). Solo aparece con algún combo visible (RF-11); mientras
/// carga o si falla no se ve: el aviso va en la lista de precios (D-5).
class CombosSection extends ConsumerWidget {
  const CombosSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final view = ref.watch(publicPriceListProvider(l10n.localeName));
    final combos = switch (view) {
      PriceViewReady(:final value) => value.combos,
      _ => const <ComboModel>[],
    };
    if (combos.isEmpty) return const SizedBox.shrink();

    final brand = context.brand;
    final wide = landingIsWide(context);

    return ColoredBox(
      color: brand.brandSurface,
      // Superficie para el resaltado de los combos que se pueden abrir
      // (RF-41).
      child: Material(
        type: MaterialType.transparency,
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
      ),
    );
  }
}

/// Un combo. Se puede abrir: lleva una flecha, se resalta al pasar el ratón
/// o al pulsarlo y el lector de pantalla lo anuncia como botón con su nombre
/// y su precio (RF-13, RF-41, RNF-5).
class _ComboView extends StatelessWidget {
  const _ComboView({required this.combo});

  final ComboModel combo;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final name = combo.name.of(l10n.localeName);
    final price = formatPrice(combo.priceCents);

    void open() => context.go('/services/combo/${combo.id}');
    return Semantics(
      button: true,
      label: l10n.priceLineSemantics(name, price),
      hint: l10n.priceDetailOpenHint,
      onTap: open,
      excludeSemantics: true,
      child: InkWell(
        onTap: open,
        child: Padding(
          padding: const EdgeInsets.only(right: 24, top: 8, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      price,
                      style: AppText.serif(
                        size: 34,
                        color: brand.onBrandSurfaceAccent,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      name,
                      style: AppText.serif(
                        size: 20,
                        color: brand.onBrandSurface,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      combo.description.of(l10n.localeName),
                      style: AppText.sans(
                        size: 13,
                        color: brand.onBrandSurfaceMuted,
                        height: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: brand.onBrandSurfaceAccent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
