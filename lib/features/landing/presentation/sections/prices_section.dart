import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../data/models/price_list_model.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../services/logic/price_list_view_logic.dart';
import '../../../services/presentation/price_list_notices.dart';
import '../../../services/providers/price_list_provider.dart';
import '../landing_layout.dart';
import 'section_header.dart';

/// Lista de precios, desde la base de datos (spec 004, RF-1 a RF-10): de
/// tres en tres bloques en ancho y uno debajo de otro en estrecho. La
/// cabecera se ve siempre; debajo, la lista, la carga o su aviso.
class PricesSection extends ConsumerWidget {
  const PricesSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final wide = landingIsWide(context);
    final view = ref.watch(publicPriceListProvider(l10n.localeName));

    final Widget content = switch (view) {
      PriceViewLoading() => const PriceListLoadingIndicator(),
      PriceViewUnavailable() => const PriceListUnavailableNotice(),
      PriceViewReady(:final value) when value.isEmpty =>
        const PriceListEmptyNotice(),
      PriceViewReady(:final value) when wide => _WideCards(value.categories),
      PriceViewReady(:final value) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final category in value.categories) ...[
            _PriceCardView(category: category),
            const SizedBox(height: 32),
          ],
        ],
      ),
    };

    return ColoredBox(
      color: brand.surface,
      // Superficie para el resaltado de las filas que se pueden abrir: sin
      // ella, lo taparía el color de la sección (RF-41).
      child: Material(
        type: MaterialType.transparency,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: wide ? 80 : 24,
            vertical: wide ? 96 : 56,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LandingSectionHeader(
                eyebrow: l10n.landingServicesEyebrow,
                title: l10n.landingServicesTitle,
                titleEm: l10n.landingServicesTitleEm,
                note: l10n.landingServicesNote,
              ),
              const SizedBox(height: 48),
              content,
            ],
          ),
        ),
      ),
    );
  }
}

/// En ancho, filas de tres bloques separadas por una línea. Una última fila
/// incompleta mantiene el ancho de cada bloque.
class _WideCards extends StatelessWidget {
  const _WideCards(this.categories);

  final List<PublicCategory> categories;

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final rows = [
      for (var i = 0; i < categories.length; i += 3)
        categories.skip(i).take(3).toList(),
    ];

    return Column(
      children: [
        for (var r = 0; r < rows.length; r++) ...[
          if (r > 0)
            Container(
              height: 1,
              color: brand.hairline,
              margin: const EdgeInsets.symmetric(vertical: 24),
            ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var c = 0; c < 3; c++)
                Expanded(
                  child: c < rows[r].length
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: _PriceCardView(category: rows[r][c]),
                        )
                      : const SizedBox.shrink(),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _PriceCardView extends StatelessWidget {
  const _PriceCardView({required this.category});

  final PublicCategory category;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final language = l10n.localeName;
    final brand = context.brand;
    final subtitle = category.category.subtitle.of(language);
    final note = category.category.note.of(language);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          category.number,
          style: AppText.sans(
            size: 13,
            weight: FontWeight.w600,
            color: brand.accentText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          category.category.name.of(language),
          style: AppText.serif(size: 28, color: brand.ink),
        ),
        if (subtitle.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            subtitle.toUpperCase(),
            style: AppText.eyebrow(size: 11, spacing: 1, color: brand.inkMuted),
          ),
        ],
        const SizedBox(height: 16),
        for (final block in category.blocks) ...[
          if (!block.group.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                block.group.of(language).toUpperCase(),
                style: AppText.eyebrow(
                  size: 11,
                  spacing: 1,
                  weight: FontWeight.w600,
                  color: brand.accentText,
                ),
              ),
            ),
          for (final item in block.items) _PriceLineView(item: item),
        ],
        if (note.trim().isNotEmpty) ...[
          const SizedBox(height: 14),
          Text(
            note,
            style: AppText.sans(size: 12, color: brand.inkMuted, height: 1.6),
          ),
        ],
      ],
    );
  }
}

/// Una línea de precio. Un servicio se puede abrir: lleva una flecha, se
/// resalta al pasar el ratón o al pulsarlo y el lector de pantalla lo anuncia
/// como botón con su nombre y su precio (RF-13, RF-41, RNF-5). Un adicional
/// solo se lee (RF-18).
class _PriceLineView extends StatelessWidget {
  const _PriceLineView({required this.item});

  final PriceItemModel item;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final name = item.name.of(l10n.localeName);
    final price = formatPrice(
      item.priceCents,
      addon: !item.isService,
      from: item.isService && item.priceFrom ? l10n.priceFrom : null,
    );

    final row = Container(
      // Al menos 48 px de alto: también es el objetivo táctil (RNF-4).
      constraints: const BoxConstraints(minHeight: 48),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: brand.hairline)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              name,
              style: AppText.sans(size: 13, color: brand.inkMuted),
            ),
          ),
          const SizedBox(width: 8),
          Text(price, style: AppText.serif(size: 19, color: brand.ink)),
          if (item.isService) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 16, color: brand.accentIcon),
          ],
        ],
      ),
    );

    if (!item.isService) return row;

    void open() => context.go('/services/service/${item.id}');
    return Semantics(
      button: true,
      label: l10n.priceLineSemantics(name, price),
      hint: l10n.priceDetailOpenHint,
      onTap: open,
      excludeSemantics: true,
      child: InkWell(onTap: open, child: row),
    );
  }
}
