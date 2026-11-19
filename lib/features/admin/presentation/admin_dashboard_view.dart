import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/platform/external_links.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/system_bars.dart';
import '../../../core/utils/capitalize.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/logic/salon_time.dart';
import '../../booking/logic/whatsapp.dart';
import '../../booking/logic/closures.dart';
import '../../booking/providers/booking_provider.dart';
import '../../services/presentation/price_list_notices.dart';
import '../providers/admin_closures_provider.dart';
import '../providers/admin_provider.dart';
import 'admin_closures_view.dart';
import 'admin_navigation.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/booked_service_model.dart';

class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selectedDate = ref.watch(adminSelectedDateProvider);
    final appointmentsAsync = ref.watch(adminAppointmentsProvider);
    // Los cierres del día, entre los turnos (spec 008, RF-9).
    final closuresAsync = ref.watch(adminDayClosuresProvider);
    final closures = closuresAsync.hasError
        ? const <ClosureEntry>[]
        : closuresAsync.value ?? const <ClosureEntry>[];
    final appointments = appointmentsAsync.value ?? const <AppointmentModel>[];

    final waitingCount = appointments
        .where((a) => a.status == 'waiting_confirmation')
        .length;

    final brand = context.brand;

    return Scaffold(
      body: Column(
        children: [
          _AdminHeader(
            selectedDate: selectedDate,
            totalCount: appointments.length,
            waitingCount: waitingCount,
            onPreviousDay: () =>
                ref.read(adminSelectedDateProvider.notifier).state =
                    selectedDate.subtract(const Duration(days: 1)),
            onNextDay: () =>
                ref.read(adminSelectedDateProvider.notifier).state =
                    selectedDate.add(const Duration(days: 1)),
          ),
          Expanded(
            child: appointmentsAsync.when(
              loading: () => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              error: (err, stack) {
                debugPrint('Error al cargar la agenda: $err');
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Text(
                      l10n.adminAgendaLoadError,
                      textAlign: TextAlign.center,
                      style: AppText.sans(size: 13, color: brand.danger),
                    ),
                  ),
                );
              },
              data: (items) {
                // Turnos y cierres, por su inicio (hora de pared del salón).
                final cards = <(DateTime, Widget)>[
                  for (final appointment in items)
                    (
                      toSalon(appointment.startTime),
                      _AppointmentCard(appointment: appointment),
                    ),
                  for (final closure in closures)
                    (closure.start, _ClosureCard(entry: closure)),
                ]..sort((a, b) => a.$1.compareTo(b.$1));
                final notice = closuresAsync.hasError
                    ? Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 0),
                        child: AppNotice(
                          message: l10n.adminClosuresLoadError,
                          actions: [
                            AppNoticeButton(
                              label: l10n.bookingRetry,
                              onPressed: () {
                                ref.invalidate(adminAgendaClosuresProvider);
                                ref.invalidate(calendarSettingsProvider);
                              },
                            ),
                          ],
                        ),
                      )
                    : null;
                if (cards.isEmpty) {
                  final empty = Center(
                    child: Text(
                      l10n.adminNoAppointmentsToday,
                      style: AppText.sans(
                        size: 13,
                        weight: FontWeight.w300,
                        color: brand.inkMuted,
                      ),
                    ),
                  );
                  if (notice == null) return empty;
                  return Column(
                    children: [
                      notice,
                      Expanded(child: empty),
                    ],
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: cards.length + (notice == null ? 0 : 1),
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    if (notice != null) {
                      if (index == 0) return notice;
                      index--;
                    }
                    return cards[index].$2;
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminHeader extends ConsumerWidget {
  final DateTime selectedDate;
  final int totalCount;
  final int waitingCount;
  final VoidCallback onPreviousDay;
  final VoidCallback onNextDay;

  const _AdminHeader({
    required this.selectedDate,
    required this.totalCount,
    required this.waitingCount,
    required this.onPreviousDay,
    required this.onNextDay,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final longDate = capitalizeFirst(
      DateFormat.yMMMMEEEEd(l10n.localeName).format(selectedDate),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      // Cabecera verde de marca: iconos de la barra de estado según su fondo
      // (RF-23).
      value: systemBarsStyleFor(brand.brand),
      child: Container(
        width: double.infinity,
        color: brand.brand,
        padding: EdgeInsets.only(
          top: MediaQuery.of(context).padding.top + 10,
          left: 20,
          right: 20,
          bottom: 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (context.canPop())
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: GestureDetector(
                      onTap: () => context.pop(),
                      child: Icon(
                        Icons.arrow_back,
                        size: 22,
                        color: brand.onBrand,
                      ),
                    ),
                  ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.adminAgendaTitle,
                        style: AppText.serif(size: 24, color: brand.onBrand),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.adminPanelEyebrow,
                        style: AppText.eyebrow(
                          size: 11,
                          weight: FontWeight.w300,
                          color: brand.onBrandMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                // Cierres de la agenda (spec 008, RF-1).
                IconButton(
                  tooltip: l10n.adminClosuresTitle,
                  onPressed: () =>
                      openAdminPage(context, ref, '/admin/closures'),
                  icon: Icon(
                    Icons.event_busy_outlined,
                    size: 22,
                    color: brand.onBrand,
                  ),
                ),
                // Gestión de servicios y precios (spec 004, RF-19).
                IconButton(
                  tooltip: l10n.adminServicesTitle,
                  onPressed: () => context.push('/admin/services'),
                  icon: Icon(
                    Icons.spa_outlined,
                    size: 22,
                    color: brand.onBrand,
                  ),
                ),
                // Clientas y horarios: botones de 48 px con nombre, como los
                // de arriba (spec 008, RNF-2).
                IconButton(
                  tooltip: l10n.adminClientsTitle,
                  onPressed: () => context.push('/admin/users'),
                  icon: Icon(
                    Icons.group_outlined,
                    size: 22,
                    color: brand.onBrand,
                  ),
                ),
                IconButton(
                  tooltip: l10n.scheduleSettingsTitle,
                  onPressed: () => context.push('/admin/settings'),
                  icon: Icon(
                    Icons.settings_outlined,
                    size: 22,
                    color: brand.onBrand,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              // Solo borde, sin relleno: el texto queda sobre el verde de
              // marca y mantiene el contraste (RNF-1).
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: brand.goldHairline),
              ),
              child: Row(
                children: [
                  // 48 px y con nombre (spec 008, RNF-2).
                  IconButton(
                    tooltip: l10n.adminAgendaPreviousDay,
                    onPressed: onPreviousDay,
                    icon: Icon(Icons.chevron_left, color: brand.onBrand),
                  ),
                  Expanded(
                    child: Text(
                      longDate,
                      textAlign: TextAlign.center,
                      style: AppText.serif(
                        size: 17,
                        color: brand.onBrand,
                        spacing: 0.5,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.adminAgendaNextDay,
                    onPressed: onNextDay,
                    icon: Icon(Icons.chevron_right, color: brand.onBrand),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatTile(
                    value: totalCount,
                    label: l10n.adminStatAppointmentsToday,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatTile(
                    value: waitingCount,
                    label: l10n.pendingConfirmationLabel,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final int value;
  final String label;

  const _StatTile({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      // Solo borde, sin relleno, por el mismo motivo que el selector de día.
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: brand.goldHairlineSoft),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$value', style: AppText.serif(size: 22, color: brand.onBrand)),
          Text(
            label,
            style: AppText.eyebrow(
              size: 10,
              spacing: 1.2,
              weight: FontWeight.w300,
              color: brand.onBrandMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppointmentCard extends ConsumerWidget {
  final AppointmentModel appointment;

  const _AppointmentCard({required this.appointment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final status = AppointmentStatusStyle.forAdmin(
      l10n,
      appointment.status,
      context.brand,
    );
    final brand = context.brand;
    final waiting = appointment.status == 'waiting_confirmation';
    // "Editar" en los turnos activos que no han terminado, también en curso
    // (spec 008, RF-18).
    final now =
        ref.watch(salonNowProvider).value ?? toSalon(ref.read(clockProvider)());
    final editable =
        (waiting || appointment.status == 'confirmed') &&
        toSalon(appointment.endTime).isAfter(now);
    // En hora del salón, esté donde esté el dispositivo (spec 005).
    final hours = DateFormat.Hm(l10n.localeName);
    final startStr = hours.format(toSalon(appointment.startTime));
    final endStr = hours.format(toSalon(appointment.endTime));
    final whatsApp = whatsAppLink(appointment.clientPhone);
    // Sin cuenta y creado por la admin (spec 007, RF-22, RF-23); cancelado
    // por la clienta y de una cuenta eliminada (spec 009, RF-18, RF-35).
    final marks = [
      if (!appointment.hasAccount) l10n.adminAppointmentGuest,
      if (appointment.accountDeleted) l10n.adminAppointmentAccountDeleted,
      if (appointment.createdByAdmin) l10n.adminAppointmentByAdmin,
      if (appointment.status == 'cancelled' && appointment.cancelledByClient)
        l10n.adminAppointmentCancelledByClient,
    ];

    return FlatCard(
      key: ValueKey('agenda-appointment-${appointment.id}'),
      borderColor: waiting ? brand.goldHairline : brand.hairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Con el texto grande, el estado baja bajo las horas en lugar de
          // desbordarse.
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 4,
            children: [
              Text(
                '$startStr — $endStr',
                style: AppText.serif(size: 19, color: brand.inkStrong),
              ),
              Text(
                status.label,
                style: AppText.eyebrow(
                  size: 10,
                  spacing: 1.6,
                  color: status.color,
                ),
              ),
            ],
          ),
          Container(
            height: 1,
            margin: const EdgeInsets.symmetric(vertical: 14),
            color: brand.hairline,
          ),
          Row(
            children: [
              InitialsAvatar(
                photoUrl: appointment.clientPhotoUrl,
                name: appointment.clientName,
                size: 40,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      appointment.clientName,
                      style: AppText.sans(
                        size: 15,
                        weight: FontWeight.w500,
                        color: brand.ink,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      appointment.clientPhone,
                      style: AppText.sans(
                        size: 12,
                        weight: FontWeight.w300,
                        color: brand.inkMuted,
                      ),
                    ),
                    for (final mark in marks) ...[
                      const SizedBox(height: 4),
                      Text(
                        mark.toUpperCase(),
                        style: AppText.eyebrow(
                          size: 10,
                          spacing: 1.2,
                          color: brand.accentText,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              // Abre su chat de WhatsApp, también en los turnos con cuenta
              // (spec 007, RF-22, D-6).
              IconButton(
                tooltip: l10n.adminAppointmentWhatsApp(appointment.clientName),
                onPressed: whatsApp == null
                    ? null
                    : () => ref.read(externalLinkLauncherProvider)(whatsApp),
                style: IconButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  shape: CircleBorder(
                    side: BorderSide(color: brand.hairlineStrong),
                  ),
                ),
                icon: const WhatsAppIcon(size: 18),
              ),
            ],
          ),
          // Lo reservado y sus adicionales, en el idioma activo (spec 005,
          // RF-52). Los turnos sin esa copia no la muestran.
          if (appointment.booked case final booked?) ...[
            const SizedBox(height: 12),
            Text(
              bookedLabel(booked, l10n.localeName),
              style: AppText.sans(size: 14, color: brand.ink, height: 1.4),
            ),
          ],
          if (appointment.status != 'cancelled') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                if (editable) ...[
                  Expanded(
                    child: OutlinePillButton(
                      label: l10n.adminAppointmentEdit.toUpperCase(),
                      onPressed: () =>
                          openAdminEdit(context, ref, appointment.id),
                    ),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: OutlinePillButton(
                    label: l10n.cancelAction,
                    color: brand.danger,
                    onPressed: () => ref
                        .read(adminControllerProvider)
                        .cancelAppointment(appointment.id),
                  ),
                ),
                if (waiting) ...[
                  const SizedBox(width: 10),
                  Expanded(
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => ref
                            .read(adminControllerProvider)
                            .confirmAppointment(appointment.id),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: brand.brand,
                          foregroundColor: brand.onBrand,
                          elevation: 0,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Text(
                          l10n.confirmAction,
                          style: AppText.sans(
                            size: 12,
                            weight: FontWeight.w500,
                            spacing: 1.2,
                            color: brand.onBrand,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Lo reservado en un turno: el servicio o combo y sus adicionales, en el
/// idioma [language]. Lo comparten la agenda y los cierres (spec 008, RF-5).
String bookedLabel(BookedServiceModel booked, String language) => [
  booked.name.of(language),
  if (booked.addons.isNotEmpty)
    booked.addons.map((addon) => addon.name.of(language)).join(', '),
].join(' · ');

/// Un cierre en la agenda del día: "CERRADO" y sus horas o "Todo el día"
/// (spec 008, RF-9).
class _ClosureCard extends StatelessWidget {
  const _ClosureCard({required this.entry});

  final ClosureEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final labels = closureLabels(l10n, entry);
    final id = switch (entry.source) {
      StoredClosureSource(:final id) => id,
      BlockedDateSource(:final key) => key,
    };

    return FlatCard(
      key: ValueKey('agenda-closure-$id'),
      borderColor: brand.hairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.adminAgendaClosed.toUpperCase(),
            style: AppText.sans(
              size: 12,
              weight: FontWeight.w600,
              spacing: 1.2,
              color: brand.inkMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            labels.hours,
            style: AppText.serif(size: 19, color: brand.inkStrong),
          ),
          // Un cierre de varios días dice cuáles.
          if (entry.kind == ClosureKind.days &&
              entry.end.difference(entry.start).inDays > 1) ...[
            const SizedBox(height: 4),
            Text(
              labels.dates,
              style: AppText.sans(size: 14, color: brand.ink, height: 1.4),
            ),
          ],
        ],
      ),
    );
  }
}
