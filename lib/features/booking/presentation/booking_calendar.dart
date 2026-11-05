import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/capitalize.dart';
import '../../../l10n/app_localizations.dart';
import '../../services/presentation/price_list_notices.dart';
import '../logic/booking_window.dart';
import '../logic/salon_time.dart';
import '../providers/booking_provider.dart';

/// El día del salón como fecha local, que es con lo que trabaja
/// `TableCalendar`: así el día no depende de la zona del dispositivo (plan,
/// "Hora del salón en la vista").
DateTime _local(DateTime salonDay) =>
    DateTime(salonDay.year, salonDay.month, salonDay.day);

/// La fecha local de `TableCalendar` como día del salón.
DateTime _salon(DateTime local) =>
    DateTime.utc(local.year, local.month, local.day);

/// El calendario de la reserva: solo deja elegir los días de la ventana que
/// abren y no están bloqueados (spec 005, RF-1 a RF-3). Sin ninguno, un
/// texto y WhatsApp en su lugar.
class BookingCalendar extends ConsumerStatefulWidget {
  const BookingCalendar({super.key});

  @override
  ConsumerState<BookingCalendar> createState() => _BookingCalendarState();
}

class _BookingCalendarState extends ConsumerState<BookingCalendar> {
  /// El mes que se ve; sigue al día elegido cuando cambia.
  DateTime? _focused;

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(calendarSettingsProvider).value;
    final day = ref.watch(
      bookingSelectionProvider.select((state) => state.selection.day),
    );
    final today = ref.watch(
      salonNowProvider.select(
        (now) => salonDay(now.value ?? toSalon(ref.read(clockProvider)())),
      ),
    );
    ref.listen(
      bookingSelectionProvider.select((state) => state.selection.day),
      (_, next) {
        if (next != null) setState(() => _focused = next);
      },
    );
    if (settings == null) return const SizedBox.shrink();

    final l10n = AppLocalizations.of(context)!;
    final window = bookingWindow(today);
    if (!window.days.any((d) => isSelectableDay(d, settings, window))) {
      return AppNotice(
        message: l10n.bookingNoDaysAvailable,
        actions: const [WhatsappNoticeButton()],
      );
    }

    final brand = context.brand;
    final material = MaterialLocalizations.of(context);
    var focused = _focused ?? day ?? window.first;
    if (!window.contains(focused)) focused = day ?? window.first;

    return TableCalendar(
      locale: l10n.localeName,
      firstDay: _local(window.first),
      lastDay: _local(window.last),
      focusedDay: _local(focused),
      startingDayOfWeek: StartingDayOfWeek.monday,
      availableGestures: AvailableGestures.horizontalSwipe,
      rowHeight: 48,
      daysOfWeekHeight: 22,
      selectedDayPredicate: (d) => day != null && isSameDay(_local(day), d),
      enabledDayPredicate: (d) => isSelectableDay(_salon(d), settings, window),
      onDaySelected: (selected, _) {
        final next = _salon(selected);
        setState(() => _focused = next);
        ref.read(bookingSelectionProvider.notifier).selectDay(next);
      },
      onPageChanged: (page) => _focused = _salon(page),
      // Flechas y mes de al menos 48 px de alto, para tocarlos (RNF-2).
      headerStyle: HeaderStyle(
        formatButtonVisible: false,
        titleCentered: true,
        headerPadding: const EdgeInsets.only(bottom: 8),
        leftChevronIcon: Icon(
          Icons.chevron_left,
          color: brand.accentIcon,
          semanticLabel: material.previousMonthTooltip,
        ),
        rightChevronIcon: Icon(
          Icons.chevron_right,
          color: brand.accentIcon,
          semanticLabel: material.nextMonthTooltip,
        ),
        leftChevronPadding: const EdgeInsets.all(12),
        rightChevronPadding: const EdgeInsets.all(12),
        leftChevronMargin: EdgeInsets.zero,
        rightChevronMargin: EdgeInsets.zero,
      ),
      calendarBuilders: CalendarBuilders(
        // "Noviembre de 2026" / "Novembro de 2026".
        headerTitleBuilder: (context, month) => SizedBox(
          height: 48,
          child: Center(
            child: Text(
              capitalizeFirst(DateFormat.yMMMM(l10n.localeName).format(month)),
              textAlign: TextAlign.center,
              style: AppText.serif(
                size: 18,
                color: brand.inkStrong,
                spacing: 0.5,
              ),
            ),
          ),
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
        // Días de otro mes y días que no se pueden elegir: más suaves, pero
        // legibles.
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
    );
  }
}
