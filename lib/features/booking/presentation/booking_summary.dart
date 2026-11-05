import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/capitalize.dart';
import '../../../data/models/price_list_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/logic/price_list_view_logic.dart';
import '../../services/providers/price_list_provider.dart';
import '../logic/bookable_catalog.dart';
import '../providers/booking_provider.dart';
import 'booking_section_title.dart';

/// Lo elegido hasta ahora: la fecha, la hora de inicio y de fin, lo
/// reservado, los adicionales, la duración y el total (spec 005, RF-22).
/// Solo aparece con una hora o un servicio elegidos. El diálogo de
/// confirmación lo muestra sin su título ([showTitle]).
class BookingSummary extends ConsumerWidget {
  const BookingSummary({super.key, this.showTitle = true});

  final bool showTitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selection = ref.watch(bookingSelectionProvider).selection;
    final start = selection.start;
    final day = selection.day;
    final item = selection.item;
    if (start == null && item == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final locale = l10n.localeName;
    final catalog = switch (ref.watch(bookableCatalogProvider)) {
      PriceViewReady(:final value) => value,
      _ => null,
    };
    final bookable = item == null || catalog == null
        ? null
        : findBookable(catalog, item);
    final addons = bookable == null
        ? const <PriceItemModel>[]
        : [
            for (final addon in availableAddons(catalog!, bookable.ref))
              if (selection.addonIds.contains(addon.id)) addon,
          ];
    final hm = DateFormat.Hm(locale);
    final body = AppText.sans(size: 15, color: brand.ink, height: 1.5);
    final strong = AppText.sans(
      size: 15,
      weight: FontWeight.w600,
      color: brand.inkStrong,
    );

    Widget row(String label, String value, {TextStyle? style}) => Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: body)),
        const SizedBox(width: 12),
        Text(value, style: style ?? body),
      ],
    );

    return Column(
      key: const ValueKey('bookingSummary'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showTitle) ...[
          BookingSectionTitle(l10n.bookingStepSummary),
          const SizedBox(height: 8),
        ],
        if (day != null)
          Text(
            capitalizeFirst(DateFormat.yMMMMEEEEd(locale).format(day)),
            style: body,
          ),
        if (start != null)
          Text(
            bookable == null
                ? hm.format(start)
                : l10n.bookingTimeRange(
                    hm.format(start),
                    hm.format(
                      start.add(Duration(minutes: bookable.durationMinutes)),
                    ),
                  ),
            style: body,
          ),
        if (bookable != null) ...[
          const SizedBox(height: 8),
          Text(bookable.name.of(locale), style: strong),
          for (final addon in addons)
            Text(
              '${addon.name.of(locale)} · '
              '${formatPrice(addon.priceCents, addon: true)}',
              style: body,
            ),
          const SizedBox(height: 8),
          row(l10n.bookingDuration, formatDuration(bookable.durationMinutes)),
          () {
            final total = totalPrice(bookable, addons);
            return row(
              l10n.bookingTotal,
              formatPrice(
                total.cents,
                from: total.from ? l10n.priceFrom : null,
              ),
              style: strong,
            );
          }(),
        ],
      ],
    );
  }
}
