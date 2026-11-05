import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../navigation/providers/tab_scroll_provider.dart';
import '../logic/booking_selection.dart';
import '../providers/booking_provider.dart';
import 'addon_picker.dart';
import 'book_button.dart';
import 'booking_calendar.dart';
import 'booking_notices.dart';
import 'booking_section_title.dart';
import 'booking_summary.dart';
import 'service_picker.dart';
import 'slot_grid.dart';

/// El formulario de reserva: calendario, horas, servicios, adicionales,
/// resumen y "Agendar turno" (spec 005, RF-1, RF-23). [onConfirmed] guarda
/// el turno cuando la clienta lo confirma.
class BookingForm extends ConsumerStatefulWidget {
  const BookingForm({super.key, required this.onConfirmed});

  final VoidCallback onConfirmed;

  @override
  ConsumerState<BookingForm> createState() => _BookingFormState();
}

class _BookingFormState extends ConsumerState<BookingForm> {
  /// Tras tocar "Agendar turno" con algo sin elegir: se marca cada parte
  /// que falte mientras siga faltando (RF-24).
  bool _showMissing = false;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final settingsAsync = ref.watch(calendarSettingsProvider);
    final missing = _showMissing
        ? missingParts(ref.watch(bookingSelectionProvider).selection)
        : const <BookingPart>{};

    return ListView(
      controller: ref.watch(tabScrollControllerProvider(MobileTab.booking)),
      padding: EdgeInsets.fromLTRB(
        20,
        MediaQuery.of(context).padding.top + 14,
        20,
        32,
      ),
      children: [
        Center(
          child: Text(
            l10n.bookAppointment,
            style: AppText.serif(size: 24, color: brand.inkStrong),
          ),
        ),
        const SizedBox(height: 18),
        BookingSectionTitle(l10n.bookingStepDate),
        const SizedBox(height: 4),
        // Sin calendario no hay fechas ni horas: un solo aviso (RF-48).
        if (settingsAsync.hasError)
          const BookingLoadErrorNotice(schedule: true)
        else ...[
          const BookingCalendar(),
          const SizedBox(height: 18),
          _MissingFrame(
            message: missing.contains(BookingPart.slot)
                ? l10n.bookingMissingSlot
                : null,
            child: const SlotGrid(),
          ),
        ],
        const SizedBox(height: 24),
        _MissingFrame(
          message: missing.contains(BookingPart.item)
              ? l10n.bookingMissingService
              : null,
          child: const ServicePicker(),
        ),
        const SizedBox(height: 16),
        const AddonPicker(),
        const SizedBox(height: 16),
        const BookingSummary(),
        const SizedBox(height: 24),
        BookButton(
          onMissing: () => setState(() => _showMissing = true),
          onConfirmed: widget.onConfirmed,
        ),
      ],
    );
  }
}

/// Marca una parte sin elegir con un borde y su texto de error (RF-24).
class _MissingFrame extends StatelessWidget {
  const _MissingFrame({required this.message, required this.child});

  /// El texto de lo que falta, o `null` si no falta.
  final String? message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final message = this.message;
    if (message == null) return child;
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brand.danger, width: 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 8),
          Text(
            message,
            style: AppText.sans(
              size: 14,
              weight: FontWeight.w500,
              color: brand.danger,
            ),
          ),
        ],
      ),
    );
  }
}
