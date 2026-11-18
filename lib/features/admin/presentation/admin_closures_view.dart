import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/capitalize.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/logic/closures.dart';
import '../../booking/providers/booking_provider.dart';
import '../../services/presentation/price_list_notices.dart';
import '../providers/admin_closures_provider.dart';

/// Los cierres próximos de la agenda, con "Quitar" y "Nuevo cierre" (spec
/// 008, RF-1, RF-2, RF-7, RF-8, RF-10, RF-11). Igual en Web y en
/// Android/iOS.
class AdminClosuresView extends ConsumerWidget {
  const AdminClosuresView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final entries = ref.watch(adminClosureEntriesProvider);

    final Widget content;
    if (entries.hasError) {
      // Sin "Nuevo cierre": no se sabe qué hay (RF-10).
      content = AppNotice(
        message: l10n.adminClosuresLoadError,
        actions: [
          AppNoticeButton(
            label: l10n.bookingRetry,
            onPressed: () {
              ref.invalidate(closuresProvider);
              ref.invalidate(calendarSettingsProvider);
            },
          ),
        ],
      );
    } else if (entries.value case final list?) {
      content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (list.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                l10n.adminClosuresEmpty,
                style: AppText.sans(size: 15, color: brand.ink, height: 1.6),
              ),
            ),
          for (final entry in list)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _ClosureTile(entry: entry),
            ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              onPressed: () => context.push('/admin/closures/new'),
              icon: const Icon(Icons.add),
              label: Text(
                l10n.adminClosuresNew.toUpperCase(),
                style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w600,
                  spacing: 1,
                  color: brand.ink,
                ),
              ),
              style: TextButton.styleFrom(
                foregroundColor: brand.ink,
                minimumSize: const Size(48, 48),
              ),
            ),
          ),
        ],
      );
    } else {
      content = const Padding(
        padding: EdgeInsets.symmetric(vertical: 32),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: brand.background,
      appBar: AppBar(title: Text(l10n.adminClosuresTitle)),
      body: SingleChildScrollView(
        // Margen inferior para que el último cierre pueda subir por encima
        // de un aviso (`SnackBar`).
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        child: content,
      ),
    );
  }
}

/// Las fechas de [entry] y, debajo, sus horas o "Todo el día" (RF-1).
({String dates, String hours}) closureLabels(
  AppLocalizations l10n,
  ClosureEntry entry,
) {
  final locale = l10n.localeName;
  final date = DateFormat.yMMMMEEEEd(locale);
  final first = entry.start;
  final last = entry.kind == ClosureKind.days
      ? entry.end.subtract(const Duration(days: 1))
      : entry.end;
  final sameDay =
      first.year == last.year &&
      first.month == last.month &&
      first.day == last.day;
  final dates = sameDay
      ? capitalizeFirst(date.format(first))
      : l10n.closureDaysRange(date.format(first), date.format(last));
  final hm = DateFormat.Hm(locale);
  final hours = entry.kind == ClosureKind.days
      ? l10n.closureAllDay
      : l10n.bookingTimeRange(hm.format(entry.start), hm.format(entry.end));
  return (dates: dates, hours: hours);
}

String _keyOf(ClosureSource source) => switch (source) {
  StoredClosureSource(:final id) => id,
  BlockedDateSource(:final key) => key,
};

/// Un cierre de la lista, con "Quitar" (RF-7, RF-8).
class _ClosureTile extends ConsumerWidget {
  const _ClosureTile({required this.entry});

  final ClosureEntry entry;

  Future<void> _remove(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        // Textos leídos aquí dentro: el diálogo cambia de idioma con la app.
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.closureDeleteTitle),
          content: Text(l10n.closureDeleteBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.cancelAction),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.closureDeleteAction.toUpperCase()),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final ok = await ref.read(closureControllerProvider).delete(entry);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(ok ? l10n.closureDeleted : l10n.closureDeleteError),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final labels = closureLabels(l10n, entry);

    return FlatCard(
      key: ValueKey('closure-${_keyOf(entry.source)}'),
      borderColor: brand.hairline,
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  labels.dates,
                  style: AppText.serif(size: 18, color: brand.inkStrong),
                ),
                const SizedBox(height: 4),
                Text(
                  labels.hours,
                  style: AppText.sans(size: 14, color: brand.ink),
                ),
              ],
            ),
          ),
          IconButton(
            // Dice qué cierre quita: todos los botones son iguales (RNF-2).
            tooltip: l10n.closureDeleteFor(labels.dates, labels.hours),
            icon: const Icon(Icons.delete_outline),
            color: brand.ink,
            onPressed: () => _remove(context, ref),
          ),
        ],
      ),
    );
  }
}
