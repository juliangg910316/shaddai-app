import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/providers/price_list_provider.dart';
import '../logic/bookable_catalog.dart';
import '../logic/free_slots.dart';
import '../logic/salon_time.dart';
import '../providers/booking_provider.dart';
import 'booking_notices.dart';
import 'booking_section_title.dart';

/// Las horas libres del día elegido, en hora del salón (spec 005, RF-4 a
/// RF-7). Con un servicio elegido, las que no alcanzan se ven desactivadas,
/// pero se pueden tocar y avisan (RF-15, D-11). Si no se pudieron cargar el
/// calendario o los turnos ocupados, el aviso con "Reintentar" (RF-48).
class SlotGrid extends ConsumerWidget {
  const SlotGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final settingsAsync = ref.watch(calendarSettingsProvider);
    final busyAsync = ref.watch(busyRangesProvider);
    final selection = ref.watch(bookingSelectionProvider).selection;
    final catalog = ref.watch(bookableCatalogProvider);
    final now =
        ref.watch(salonNowProvider).value ?? toSalon(ref.read(clockProvider)());
    final inSalonZone = deviceIsInSalonZone(ref.watch(deviceUtcOffsetProvider));

    // Tras un error, Riverpod reintenta solo: el error manda sobre la carga.
    final Widget content;
    final settings = settingsAsync.value;
    final busy = busyAsync.value;
    final day = selection.day;
    if (settingsAsync.hasError || busyAsync.hasError) {
      content = const BookingLoadErrorNotice(schedule: true);
    } else if (settings == null || busy == null || day == null) {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else {
      final slots = freeSlots(
        day: day,
        settings: settings,
        busy: busy,
        nowSalon: now,
      );
      final item = selection.item;
      final duration = item == null
          ? null
          : switch (catalog) {
              PriceViewReady(:final value) => findBookable(
                value,
                item,
              )?.durationMinutes,
              _ => null,
            };
      content = slots.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.bookingNoFreeSlots,
                style: AppText.sans(size: 15, color: brand.ink, height: 1.5),
              ),
            )
          : Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final slot in slots)
                  _SlotChip(
                    slot: slot,
                    selected: slot.start == selection.start,
                    enabled: duration == null || fits(duration, slot),
                    onTap: () => ref
                        .read(bookingSelectionProvider.notifier)
                        .selectSlot(slot),
                  ),
              ],
            );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        BookingSectionTitle(l10n.bookingStepTime),
        if (!inSalonZone) ...[
          const SizedBox(height: 4),
          Text(
            l10n.bookingSalonTimeNote,
            style: AppText.sans(size: 13, color: brand.inkMuted),
          ),
        ],
        const SizedBox(height: 12),
        content,
      ],
    );
  }
}

class _SlotChip extends StatelessWidget {
  const _SlotChip({
    required this.slot,
    required this.selected,
    required this.enabled,
    required this.onTap,
  });

  final FreeSlot slot;
  final bool selected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final time = DateFormat.Hm(l10n.localeName).format(slot.start);

    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: enabled ? time : '$time, ${l10n.bookingUnavailableLabel}',
      excludeSemantics: true,
      child: Material(
        color: selected ? brand.brand : brand.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(
            color: selected ? brand.brand : brand.hairlineStrong,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          // Desactivada también se puede tocar: avisa de por qué (D-11).
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 76, minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              child: Center(
                widthFactor: 1,
                heightFactor: 1,
                child: Text(
                  time,
                  style: AppText.sans(
                    size: 15,
                    weight: enabled ? FontWeight.w500 : FontWeight.w300,
                    color: selected
                        ? brand.onBrand
                        : enabled
                        ? brand.inkStrong
                        : brand.inkMuted,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
