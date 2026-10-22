import 'package:flutter/material.dart';

import '../../../../core/theme/app_text.dart';
import '../../../../core/theme/brand_colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../landing_content.dart';
import '../landing_layout.dart';
import 'section_header.dart';

/// Lista de precios: los seis bloques de shaddai-web, de tres en tres en
/// ancho amplio y uno debajo de otro en estrecho (RF-3).
class PricesSection extends StatelessWidget {
  const PricesSection({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final wide = landingIsWide(context);
    final cards = LandingContent.priceCards;

    return ColoredBox(
      color: brand.surface,
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
            if (wide) ...[
              _CardRow(cards: cards.take(3).toList()),
              Container(
                height: 1,
                color: brand.hairline,
                margin: const EdgeInsets.symmetric(vertical: 24),
              ),
              _CardRow(cards: cards.skip(3).toList()),
            ] else
              for (final card in cards) ...[
                _PriceCardView(card: card),
                const SizedBox(height: 32),
              ],
          ],
        ),
      ),
    );
  }
}

class _CardRow extends StatelessWidget {
  const _CardRow({required this.cards});

  final List<PriceCard> cards;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final card in cards)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _PriceCardView(card: card),
            ),
          ),
      ],
    );
  }
}

class _PriceCardView extends StatelessWidget {
  const _PriceCardView({required this.card});

  final PriceCard card;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          card.number,
          style: AppText.sans(
            size: 13,
            weight: FontWeight.w600,
            color: brand.accentText,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          card.title(l10n),
          style: AppText.serif(size: 28, color: brand.ink),
        ),
        const SizedBox(height: 2),
        Text(
          card.subtitle(l10n).toUpperCase(),
          style: AppText.eyebrow(size: 11, spacing: 1, color: brand.inkMuted),
        ),
        const SizedBox(height: 16),
        for (final line in card.lines)
          switch (line) {
            PriceGroup(:final label) => Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 6),
              child: Text(
                label(l10n).toUpperCase(),
                style: AppText.eyebrow(
                  size: 11,
                  spacing: 1,
                  weight: FontWeight.w600,
                  color: brand.accentText,
                ),
              ),
            ),
            PriceItem(:final label, :final price) => Container(
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: brand.hairline)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label(l10n),
                      style: AppText.sans(size: 13, color: brand.inkMuted),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(price, style: AppText.serif(size: 19, color: brand.ink)),
                ],
              ),
            ),
          },
        const SizedBox(height: 14),
        Text(
          card.note(l10n),
          style: AppText.sans(size: 12, color: brand.inkMuted, height: 1.6),
        ),
      ],
    );
  }
}
