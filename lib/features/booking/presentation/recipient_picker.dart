import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/admin_booking_provider.dart';
import 'booking_section_title.dart';

/// "Para quién" de la reserva de la admin (spec 007, RF-1 a RF-11): la
/// búsqueda de clientas con cuenta o la persona sin cuenta.
class RecipientPicker extends ConsumerStatefulWidget {
  const RecipientPicker({super.key});

  @override
  ConsumerState<RecipientPicker> createState() => _RecipientPickerState();
}

class _RecipientPickerState extends ConsumerState<RecipientPicker> {
  /// Empieza con la búsqueda guardada: se conserva al volver a la reserva
  /// (RF-27).
  late final _query = TextEditingController(
    text: ref.read(bookingRecipientProvider).query,
  );

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        BookingSectionTitle(l10n.bookingStepRecipient),
        const SizedBox(height: 12),
        TextField(
          controller: _query,
          cursorColor: brand.accentIcon,
          style: AppText.sans(size: 16, color: brand.inkStrong),
          decoration: InputDecoration(
            labelText: l10n.bookingRecipientSearchLabel,
            prefixIcon: const Icon(Icons.search),
          ),
          onChanged: ref.read(bookingRecipientProvider.notifier).setQuery,
        ),
      ],
    );
  }
}
