import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/spanish_dates.dart';
import '../../../core/constants/theme_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/booking_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/appointment_model.dart';
import 'package:uuid/uuid.dart';

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

  Future<void> _confirmBooking(DateTime slot) async {
    final l10n = AppLocalizations.of(context)!;
    final user = ref.read(currentUserProvider).value;
    if (user == null) return;

    final dateStr = DateFormat('dd/MM/yyyy').format(slot);
    final timeStr = DateFormat('HH:mm').format(slot);
    final settings = ref.read(calendarSettingsProvider).value;
    final slotDuration = settings?.globalSlotDurationMinutes ?? 60;

    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
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
                  color: ThemeColors.olive,
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
                  color: ThemeColors.gold,
                ),
              ),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
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
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(l10n.bookingCreatedSuccess)));
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(l10n.bookingCreateError(e)),
              backgroundColor: ThemeColors.danger,
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
    final l10n = AppLocalizations.of(context)!;
    final selectedDate = ref.watch(selectedDateProvider);
    final availableSlots = ref.watch(availableSlotsProvider);
    final serviceOptions = _serviceOptions(l10n);

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      body: Stack(
        children: [
          ListView(
            padding: EdgeInsets.zero,
            children: [
              // Cabecera + pasos 1 y 2, sobre el fondo claro
              Container(
                color: ThemeColors.white,
                padding: EdgeInsets.only(
                  top: MediaQuery.of(context).padding.top + 14,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Text(
                        l10n.bookAppointment,
                        style: AppText.serif(
                          size: 24,
                          color: ThemeColors.darkGreen,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Text(
                        l10n.stepServiceLabel,
                        style: AppText.eyebrow(),
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
                      child: Text(l10n.stepDateLabel, style: AppText.eyebrow()),
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
                            color: ThemeColors.darkGreen,
                          ),
                        ),
                        const Spacer(),
                        Flexible(
                          child: Text(
                            '${SpanishDates.weekdayShort(selectedDate)} '
                            '${selectedDate.day} · '
                            '${serviceOptions[_selectedService].summaryLabel}',
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            style: AppText.sans(
                              size: 12,
                              weight: FontWeight.w300,
                              color: ThemeColors.olive,
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
                          child: CircularProgressIndicator(
                            color: ThemeColors.darkGreen,
                            strokeWidth: 2,
                          ),
                        ),
                      ),
                      error: (err, stack) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 30),
                        child: Text(
                          l10n.slotsLoadError(err),
                          style: AppText.sans(
                            size: 13,
                            color: ThemeColors.danger,
                          ),
                        ),
                      ),
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
                              DateFormat('HH:mm').format(_selectedSlot!),
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
                                color: ThemeColors.gold,
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
                          color: ThemeColors.olive,
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
              color: ThemeColors.darkGreen.withValues(alpha: 0.45),
              child: const Center(
                child: CircularProgressIndicator(
                  color: ThemeColors.gold,
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
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? ThemeColors.darkGreen : Colors.transparent,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: selected
                ? ThemeColors.darkGreen
                : ThemeColors.darkGreen.withValues(alpha: 0.20),
          ),
        ),
        child: Text(
          label,
          style: AppText.sans(
            size: 12.5,
            weight: selected ? FontWeight.w500 : FontWeight.w400,
            color: selected ? ThemeColors.gold : ThemeColors.olive,
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

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 4, 18, 14),
      child: TableCalendar(
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
          leftChevronIcon: const Icon(
            Icons.chevron_left,
            color: ThemeColors.gold,
          ),
          rightChevronIcon: const Icon(
            Icons.chevron_right,
            color: ThemeColors.gold,
          ),
          leftChevronPadding: EdgeInsets.zero,
          rightChevronPadding: EdgeInsets.zero,
          titleTextFormatter: (date, locale) => SpanishDates.monthAndYear(date),
          titleTextStyle: AppText.serif(
            size: 18,
            color: ThemeColors.darkGreen,
            spacing: 0.5,
          ),
        ),
        daysOfWeekStyle: DaysOfWeekStyle(
          dowTextFormatter: (date, locale) => SpanishDates.weekdayInitial(date),
          weekdayStyle: AppText.sans(
            size: 10,
            color: ThemeColors.olive,
            spacing: 0.8,
          ),
          weekendStyle: AppText.sans(
            size: 10,
            color: ThemeColors.gold,
            spacing: 0.8,
          ),
        ),
        calendarStyle: CalendarStyle(
          cellMargin: const EdgeInsets.all(4),
          defaultTextStyle: AppText.sans(size: 14, color: ThemeColors.black),
          weekendTextStyle: AppText.sans(
            size: 14,
            color: ThemeColors.gold.withValues(alpha: 0.75),
          ),
          outsideTextStyle: AppText.sans(
            size: 14,
            color: ThemeColors.olive.withValues(alpha: 0.35),
          ),
          disabledTextStyle: AppText.sans(
            size: 14,
            color: ThemeColors.olive.withValues(alpha: 0.35),
          ),
          todayDecoration: BoxDecoration(
            color: ThemeColors.gold.withValues(alpha: 0.28),
            shape: BoxShape.circle,
          ),
          todayTextStyle: AppText.sans(size: 14, color: ThemeColors.darkGreen),
          selectedDecoration: const BoxDecoration(
            color: ThemeColors.darkGreen,
            shape: BoxShape.circle,
          ),
          selectedTextStyle: AppText.sans(
            size: 14,
            weight: FontWeight.w500,
            color: ThemeColors.gold,
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
              color: ThemeColors.olive,
            ),
          ),
        ),
      );
    }

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
              color: selected ? ThemeColors.darkGreen : ThemeColors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: selected
                    ? ThemeColors.darkGreen
                    : ThemeColors.darkGreen.withValues(alpha: 0.35),
              ),
            ),
            child: Text(
              DateFormat('HH:mm').format(slot),
              style: AppText.sans(
                size: 15,
                weight: FontWeight.w500,
                color: selected ? ThemeColors.gold : ThemeColors.darkGreen,
              ),
            ),
          ),
        );
      },
    );
  }
}
