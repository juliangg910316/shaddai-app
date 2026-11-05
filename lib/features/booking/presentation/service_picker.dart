import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../../services/presentation/price_list_notices.dart';
import '../../services/providers/price_list_provider.dart';
import '../logic/bookable_catalog.dart';
import '../logic/free_slots.dart';
import '../providers/booking_provider.dart';
import 'booking_section_title.dart';

/// Los servicios que se pueden reservar, por categoría y en el orden de la
/// lista de precios, y después los combos (spec 005, RF-10, RF-11). Con una
/// hora elegida, los que no caben se ven desactivados, pero se pueden tocar
/// y avisan (RF-12, RF-13, D-11). Sin lista de precios, su aviso (RF-47).
class ServicePicker extends ConsumerWidget {
  const ServicePicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    final Widget content;
    switch (ref.watch(bookableCatalogProvider)) {
      case PriceViewLoading():
        content = const PriceListLoadingIndicator();
      case PriceViewUnavailable():
        content = const PriceListUnavailableNotice();
      case PriceViewReady(value: final catalog) when catalog.isEmpty:
        content = const PriceListEmptyNotice();
      case PriceViewReady(value: final catalog):
        final locale = l10n.localeName;
        final selected = ref.watch(
          bookingSelectionProvider.select((state) => state.selection.item),
        );
        final slot = ref.watch(selectedFreeSlotProvider);
        Widget tile(Bookable bookable) => _BookableTile(
          bookable: bookable,
          selected: bookable.ref == selected,
          enabled: slot == null || fits(bookable.durationMinutes, slot),
          onTap: () => ref
              .read(bookingSelectionProvider.notifier)
              .selectItem(bookable.ref),
        );
        content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final entry in catalog.categories) ...[
              Padding(
                padding: const EdgeInsets.only(top: 12, bottom: 6),
                child: Text(
                  entry.category.name.of(locale),
                  style: AppText.serif(size: 19, color: brand.inkStrong),
                ),
              ),
              for (final item in entry.services)
                tile(BookableService(item: item, category: entry.category)),
            ],
            if (catalog.combos.isNotEmpty) const SizedBox(height: 12),
            for (final combo in catalog.combos) tile(BookableCombo(combo)),
          ],
        );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        BookingSectionTitle(l10n.bookingStepService),
        const SizedBox(height: 4),
        content,
      ],
    );
  }
}

class _BookableTile extends StatelessWidget {
  const _BookableTile({
    required this.bookable,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final Bookable bookable;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final name = bookable.name.of(l10n.localeName);
    final price = formatPrice(
      bookable.priceCents,
      from: bookable.priceFrom ? l10n.priceFrom : null,
    );
    final detail = '$price · ${formatDuration(bookable.durationMinutes)}';
    final ink = selected
        ? brand.onBrand
        : enabled
        ? brand.inkStrong
        : brand.inkMuted;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Semantics(
        button: true,
        selected: selected,
        enabled: enabled,
        label: enabled
            ? '$name, $detail'
            : '$name, $detail, ${l10n.bookingUnavailableLabel}',
        excludeSemantics: true,
        child: Material(
          color: selected ? brand.brand : brand.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(
              color: selected ? brand.brand : brand.hairlineStrong,
            ),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            // Desactivado también se puede tocar: avisa de por qué (D-11).
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 10,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: AppText.sans(
                        size: 15,
                        weight: enabled ? FontWeight.w500 : FontWeight.w300,
                        color: ink,
                      ),
                    ),
                    Text(
                      detail,
                      style: AppText.sans(
                        size: 13,
                        color: selected ? brand.onBrandMuted : brand.inkMuted,
                      ),
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
