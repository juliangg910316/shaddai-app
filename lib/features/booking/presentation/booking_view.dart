import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/theme_colors.dart';
import '/l10n/app_localizations.dart';
import '../providers/booking_provider.dart';
import '../../auth/providers/auth_provider.dart';
import '../../../data/models/appointment_model.dart';
import 'package:uuid/uuid.dart';

class BookingView extends ConsumerStatefulWidget {
  const BookingView({super.key});

  @override
  ConsumerState<BookingView> createState() => _BookingViewState();
}

class _BookingViewState extends ConsumerState<BookingView> {
  bool _isBooking = false;

  Future<void> _confirmBooking(DateTime slot) async {
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
          backgroundColor: ThemeColors.bone,
          title: const Text(
            'Confirmar Reserva',
            style: TextStyle(color: ThemeColors.darkGreen),
          ),
          content: Text(
            '¿Deseas reservar tu turno para el día $dateStr a las $timeStr?',
            style: const TextStyle(color: ThemeColors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text(
                'CANCELAR',
                style: TextStyle(color: ThemeColors.olive),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: ThemeColors.darkGreen,
              ),
              child: const Text(
                'CONFIRMAR',
                style: TextStyle(color: ThemeColors.gold),
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
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                '¡Reserva creada exitosamente! Esperando confirmación del administrador.',
              ),
              backgroundColor: ThemeColors.darkGreen,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al crear la reserva: $e'),
              backgroundColor: Colors.red,
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
    final selectedDate = ref.watch(selectedDateProvider);
    final availableSlots = ref.watch(availableSlotsProvider);
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      appBar: AppBar(title: Text(l10n.bookAppointment)),
      body: Stack(
        children: [
          Column(
            children: [
              // Calendario (table_calendar)
              Container(
                color: ThemeColors.white,
                child: TableCalendar(
                  firstDay: DateTime.now(),
                  lastDay: DateTime.now().add(const Duration(days: 90)),
                  focusedDay: selectedDate,
                  selectedDayPredicate: (day) => isSameDay(selectedDate, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    ref.read(selectedDateProvider.notifier).state = selectedDay;
                  },
                  calendarStyle: const CalendarStyle(
                    selectedDecoration: BoxDecoration(
                      color: ThemeColors.darkGreen,
                      shape: BoxShape.circle,
                    ),
                    todayDecoration: BoxDecoration(
                      color: ThemeColors.gold,
                      shape: BoxShape.circle,
                    ),
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Slots Header
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 20.0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Horarios Disponibles',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: ThemeColors.darkGreen,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              // Slots Grid
              Expanded(
                child: availableSlots.when(
                  loading: () => const Center(
                    child: CircularProgressIndicator(
                      color: ThemeColors.darkGreen,
                    ),
                  ),
                  error: (err, stack) => Center(child: Text('Error: $err')),
                  data: (slots) {
                    if (slots.isEmpty) {
                      return const Center(
                        child: Text(
                          'No hay horarios disponibles para esta fecha.',
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            childAspectRatio: 2.5,
                            crossAxisSpacing: 10,
                            mainAxisSpacing: 10,
                          ),
                      itemCount: slots.length,
                      itemBuilder: (context, index) {
                        final slot = slots[index];
                        final timeStr = DateFormat('HH:mm').format(slot);
                        return InkWell(
                          onTap: () => _confirmBooking(slot),
                          child: Container(
                            decoration: BoxDecoration(
                              color: ThemeColors.white,
                              border: Border.all(color: ThemeColors.darkGreen),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            alignment: Alignment.center,
                            child: Text(
                              timeStr,
                              style: const TextStyle(
                                color: ThemeColors.darkGreen,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
          if (_isBooking)
            Container(
              color: Colors.black54,
              child: const Center(
                child: CircularProgressIndicator(color: ThemeColors.gold),
              ),
            ),
        ],
      ),
    );
  }
}
