import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../data/models/booked_service_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../../services/providers/price_list_provider.dart';
import '../logic/bookable_catalog.dart';
import '../providers/booking_provider.dart';
import 'booking_section_title.dart';

/// Los adicionales de la categoría del servicio elegido, para marcar los que
/// se quiera (spec 005, RF-18, RF-20, RF-21). Con un combo o sin servicio,
/// no aparece (RF-19).
class AddonPicker extends ConsumerWidget {
  const AddonPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(bookingSelectionProvider).selection;
    final item = selection.item;
    final catalog = ref.watch(bookableCatalogProvider);
    if (item == null ||
        item.kind != BookedKind.service ||
        catalog is! PriceViewReady<BookableCatalog>) {
      return const SizedBox.shrink();
    }
    final addons = availableAddons(catalog.value, item);
    if (addons.isEmpty) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        BookingSectionTitle(l10n.bookingStepAddons),
        const SizedBox(height: 4),
        for (final addon in addons)
          CheckboxListTile(
            value: selection.addonIds.contains(addon.id),
            onChanged: (_) => ref
                .read(bookingSelectionProvider.notifier)
                .toggleAddon(addon.id),
            contentPadding: EdgeInsets.zero,
            controlAffinity: ListTileControlAffinity.leading,
            activeColor: brand.brand,
            checkColor: brand.onBrand,
            title: Text(
              addon.name.of(l10n.localeName),
              style: AppText.sans(size: 15, color: brand.ink),
            ),
            secondary: Text(
              formatPrice(addon.priceCents, addon: true),
              style: AppText.sans(size: 14, color: brand.inkMuted),
            ),
          ),
      ],
    );
  }
}
