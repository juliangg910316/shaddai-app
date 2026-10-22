import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../core/platform/platform_provider.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/capitalize.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/booking_provider.dart';
import 'booking_sign_in_prompt.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/appointment_model.dart';
import 'package:uuid/uuid.dart';
import '../../navigation/providers/tab_scroll_provider.dart';

/// Opciones del paso "1 · Servicio". Por ahora son fijas y solo decorativas:
/// la duración real del turno la sigue definiendo `globalSlotDurationMinutes`.
class _ServiceOption {
  final String chipLabel;
  final String summaryLabel;

  const _ServiceOption(this.chipLabel, this.summaryLabel);
}

List<_ServiceOption> _serviceOptions(AppLocalizations l10n) => [
  _ServiceOption(
    l10n.serviceOptionClassicChip,
    l10n.serviceOptionClassicSummary,
  ),
  _ServiceOption(
    l10n.serviceOptionSemipermChip,
    l10n.serviceOptionSemipermSummary,
  ),
  _ServiceOption(
    l10n.serviceOptionAcrylicChip,
    l10n.serviceOptionAcrylicSummary,
  ),
];

class BookingView extends ConsumerStatefulWidget {
  const BookingView({super.key});

  @override
  ConsumerState<BookingView> createState() => _BookingViewState();
}

class _BookingViewState extends ConsumerState<BookingView> {
  bool _isBooking = false;
  int _selectedService = 1;
  DateTime? _selectedSlot;

  /// En Web, la reserva creada se confirma en un diálogo que ofrece volver a
  /// la landing (spec 002, RF-22): un aviso que se va solo no es fiable con
  /// teclado ni con lector de pantalla.
  Future<void> _showBookedDialog() {
    return showDialog<void>(
      context: context,
      builder: (dialogContext) {
        final l10n = AppLocalizations.of(dialogContext)!;
        final brand = dialogContext.brand;
        return AlertDialog(
          title: Text(l10n.bookingCreatedWebTitle),
          content: Text(l10n.bookingCreatedSuccess),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(
                MaterialLocalizations.of(dialogContext).closeButtonLabel,
                style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  spacing: 1.2,
                  color: brand.inkMuted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                context.go('/');
              },
              child: Text(
                l10n.bookingBackToLanding,
                style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w600,
                  spacing: 1.2,
                  color: brand.onBrand,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _confirmBooking(DateTime slot) async {
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final settings = ref.read(calendarSettingsProvider).value;
    final slotDuration = settings?.globalSlotDurationMinutes ?? 60;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        // Textos y fecha dentro del builder: si cambia el idioma con el
        // diálogo abierto, el diálogo también cambia (RF-10).
        final l10n = AppLocalizations.of(context)!;
        final brand = context.brand;
        final dateStr = DateFormat.yMMMMEEEEd(l10n.localeName).format(slot);
        final timeStr = DateFormat.Hm(l10n.localeName).format(slot);
        return AlertDialog(
          title: Text(l10n.confirmBookingDialogTitle),
          content: Text(l10n.confirmBookingDialogBody(dateStr, timeStr)),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                l10n.cancelAction,
                style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  spacing: 1.2,
                  color: brand.inkMuted,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(
                l10n.confirmAction,
                style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w600,
                  spacing: 1.2,
                  color: brand.onBrand,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true && mounted) {
      final l10n = AppLocalizations.of(context)!;
      setState(() => _isBooking = true);

      try {
        final appointment = AppointmentModel(
          id: const Uuid().v4(),
          clientId: user.uid,
          clientName: user.displayName,
          clientPhone: user.phoneNumber ?? '',
          clientPhotoUrl: user.photoUrl,
          startTime: slot,
          endTime: slot.add(Duration(minutes: slotDuration)),
          status: 'waiting_confirmation',
          createdAt: DateTime.now(),
        );

        await ref
            .read(bookingRepositoryProvider)
            .createAppointment(appointment);

        if (mounted) {
          setState(() => _selectedSlot = null);
          if (ref.read(isWebProvider)) {
            await _showBookedDialog();
          } else {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(SnackBar(content: Text(l10n.bookingCreatedSuccess)));
          }
        }
      } catch (e) {
        // El detalle técnico solo va al log; la persona ve un texto de la app.
        debugPrint('Error al crear la reserva: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.bookingCreateError),
              backgroundColor: context.brand.danger,
            ),
          );
        }
      } finally {
        if (mounted) {
          setState(() => _isBooking = false);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sin sesión, la pestaña muestra el aviso para iniciarla (spec 003,
    // RF-16). En Web no se llega aquí sin sesión: la redirección pide antes
    // iniciarla.
    final userAsync = ref.watch(currentUserProvider);
    if (userAsync.value == null) {
      if (userAsync.isLoading) {
        return const Scaffold(
          body: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      return const BookingSignInPrompt();
    }

    final l10n = AppLocalizations.of(context)!;
    final selectedDate = ref.watch(selectedDateProvider);
    final availableSlots = ref.watch(availableSlotsProvider);
    final serviceOptions = _serviceOptions(l10n);
    final brand = context.brand;
    final weekdayShort = capitalizeFirst(
      DateFormat.E(l10n.localeName).format(selectedDate),
    );

    return Scaffold(
      body: Stack(
        children: [
          ListView(
            controller: ref.watch(
              tabScrollControllerProvider(MobileTab.booking),
            ),
            padding: EdgeInsets.zero,
            children: [
              // Cabecera + pasos 1 y 2, sobre el fondo claro
              Container(
                color: brand.surface,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        l10n.bookAppointment,
                        style: AppText.serif(size: 24, color: brand.inkStrong),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        l10n.stepServiceLabel,
                        style: AppText.eyebrow(color: brand.inkMuted),
                      ),
                    ),
                    const SizedBox(height: 9),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 7,
                        runSpacing: 7,
                        children: [
                          for (var i = 0; i < serviceOptions.length; i++)
                            _ServiceChip(
                              label: serviceOptions[i].chipLabel,
                              selected: i == _selectedService,
                              onTap: () => setState(() => _selectedService = i),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        l10n.stepDateLabel,
                        style: AppText.eyebrow(color: brand.inkMuted),
                      ),
                    ),
                    _BookingCalendar(
                      selectedDate: selectedDate,
                      onDaySelected: (day) {
                        ref.read(selectedDateProvider.notifier).state = day;
                        setState(() => _selectedSlot = null);
                      },
                    ),
                  ],
                ),
              ),

              // Paso 3, sobre el fondo hueso
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.baseline,
                      textBaseline: TextBaseline.alphabetic,
                      children: [
                        Text(
                          l10n.stepTimeLabel,
                          style: AppText.serif(
                            size: 21,
                            color: brand.inkStrong,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            '$weekdayShort '
                            '${selectedDate.day} · '
                            '${serviceOptions[_selectedService].summaryLabel}',
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.sans(
                              size: 12,
                              weight: FontWeight.w300,
                              color: brand.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    availableSlots.when(
                      loading: () => const Padding(
                        padding: EdgeInsets.symmetric(vertical: 40),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (err, stack) {
                        debugPrint('Error al cargar los horarios: $err');
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 30),
                          child: Text(
                            l10n.slotsLoadError,
                            style: AppText.sans(size: 13, color: brand.danger),
                          ),
                        );
                      },
                      data: (slots) => _SlotSection(
                        slots: slots,
                        selectedSlot: _selectedSlot,
                        onSelect: (slot) =>
                            setState(() => _selectedSlot = slot),
                      ),
                    ),
                    const SizedBox(height: 16),
                    GoldPillButton(
                      label: _selectedSlot == null
                          ? l10n.chooseTimeSlotAction
                          : l10n.confirmAtTimeAction(
                              DateFormat.Hm(
                                l10n.localeName,
                              ).format(_selectedSlot!),
                            ),
                      onPressed: _selectedSlot == null
                          ? null
                          : () => _confirmBooking(_selectedSlot!),
                    ),
                    const SizedBox(height: 9),
                    Center(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: l10n.bookingPendingNoticePrefix),
                            TextSpan(
                              text: l10n.bookingPendingNoticeHighlight,
                              style: AppText.sans(
                                size: 11.5,
                                weight: FontWeight.w300,
                                color: brand.accentText,
                                height: 1.5,
                              ),
                            ),
                            TextSpan(text: l10n.bookingPendingNoticeSuffix),
                          ],
                        ),
                        textAlign: TextAlign.center,
                        style: AppText.sans(
                          size: 11.5,
                          weight: FontWeight.w300,
                          color: brand.inkMuted,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (_isBooking)
            Container(
              color: brand.brand.withValues(alpha: 0.45),
              child: Center(
                child: CircularProgressIndicator(
                  color: brand.onBrand,
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ServiceChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _ServiceChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? brand.brand : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected ? brand.brand : brand.hairlineStrong,
          ),
        ),
        child: Text(
          label,
          style: AppText.sans(
            size: 12.5,
            weight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? brand.onBrand : brand.inkMuted,
          ),
        ),
      ),
    );
  }
}

class _BookingCalendar extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDaySelected;

  const _BookingCalendar({
    required this.selectedDate,
    required this.onDaySelected,
  });

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    // Medianoche de hoy: `focusedDay` nunca puede quedar antes de `firstDay`.
    final firstDay = DateTime(now.year, now.month, now.day);
    final brand = context.brand;
    final locale = AppLocalizations.of(context)!.localeName;

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      child: TableCalendar(
        locale: locale,
        firstDay: firstDay,
        lastDay: firstDay.add(const Duration(days: 90)),
        focusedDay: selectedDate,
        startingDayOfWeek: StartingDayOfWeek.monday,
        rowHeight: 40,
        daysOfWeekHeight: 22,
        selectedDayPredicate: (day) => isSameDay(selectedDate, day),
        onDaySelected: (day, focusedDay) => onDaySelected(day),
        headerStyle: HeaderStyle(
          formatButtonVisible: false,
          titleCentered: true,
          headerPadding: const EdgeInsets.fromLTRB(6, 6, 6, 14),
          leftChevronIcon: Icon(Icons.chevron_left, color: brand.accentIcon),
          rightChevronIcon: Icon(Icons.chevron_right, color: brand.accentIcon),
          leftChevronPadding: EdgeInsets.zero,
          rightChevronPadding: EdgeInsets.zero,
          // "Octubre de 2026" / "Outubro de 2026" (RF-21).
          titleTextFormatter: (date, locale) =>
              capitalizeFirst(DateFormat.yMMMM(locale).format(date)),
          titleTextStyle: AppText.serif(
            size: 18,
            color: brand.inkStrong,
            spacing: 0.5,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          // Inicial del día en el idioma activo: L M X… / S T Q…
          dowTextFormatter: (date, locale) =>
              DateFormat.E(locale).format(date)[0].toUpperCase(),
          weekdayStyle: AppText.sans(
            size: 10,
            color: brand.inkMuted,
            spacing: 0.8,
          ),
          weekendStyle: AppText.sans(
            size: 10,
            color: brand.accentText,
            spacing: 0.8,
          ),
        ),
        calendarStyle: CalendarStyle(
          cellMargin: const EdgeInsets.all(4),
          defaultTextStyle: AppText.sans(size: 14, color: brand.ink),
          weekendTextStyle: AppText.sans(size: 14, color: brand.accentText),
          // Días de otro mes y días pasados: más suaves, pero legibles.
          outsideTextStyle: AppText.sans(size: 14, color: brand.inkMuted),
          disabledTextStyle: AppText.sans(
            size: 14,
            weight: FontWeight.w300,
            color: brand.inkMuted,
          ),
          todayDecoration: BoxDecoration(
            color: brand.accent.withValues(alpha: 0.28),
            shape: BoxShape.circle,
          ),
          todayTextStyle: AppText.sans(size: 14, color: brand.inkStrong),
          selectedDecoration: BoxDecoration(
            color: brand.brand,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: AppText.sans(
            size: 14,
            weight: FontWeight.w500,
            color: brand.onBrand,
          ),
        ),
      ),
    );
  }
}

class _SlotSection extends StatelessWidget {
  final List<DateTime> slots;
  final DateTime? selectedSlot;
  final ValueChanged<DateTime> onSelect;

  const _SlotSection({
    required this.slots,
    required this.selectedSlot,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    if (slots.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 26),
        child: Center(
          child: Text(
            AppLocalizations.of(context)!.noSlotsAvailable,
            style: AppText.sans(
              size: 13,
              weight: FontWeight.w300,
              color: context.brand.inkMuted,
            ),
          ),
        ),
      );
    }

    final brand = context.brand;
    final locale = AppLocalizations.of(context)!.localeName;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        mainAxisExtent: 46,
      ),
      itemCount: slots.length,
      itemBuilder: (context, index) {
        final slot = slots[index];
        final selected = selectedSlot != null && selectedSlot == slot;

        return GestureDetector(
          onTap: () => onSelect(slot),
          child: Container(
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? brand.brand : brand.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected ? brand.brand : brand.hairlineStrong,
              ),
            ),
            child: Text(
              DateFormat.Hm(locale).format(slot),
              style: AppText.sans(
                size: 15,
                weight: FontWeight.w500,
                color: selected ? brand.onBrand : brand.inkStrong,
              ),
            ),
          ),
        );
      },
    );
  }
}
