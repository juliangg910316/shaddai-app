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
import '../../booking/presentation/booking_notices.dart';
import '../../booking/providers/booking_provider.dart';
import '../../services/presentation/price_list_notices.dart';
import '../logic/admin_agenda.dart';
import '../providers/admin_appointment_actions_provider.dart';
import '../providers/admin_closures_provider.dart';
import '../providers/admin_provider.dart';
import 'admin_cancel_dialog.dart';
import 'admin_closures_view.dart';
import 'admin_navigation.dart';
import 'admin_push_disabled_card.dart';
import '../../../data/models/appointment_model.dart';
import '../../../data/models/booked_service_model.dart';

class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selectedDate = agendaDay(ref.watch(adminSelectedDateProvider));
    final appointmentsAsync = ref.watch(adminAppointmentsProvider);
    // Los cierres del día, entre los turnos (spec 008, RF-9).
    final closuresAsync = ref.watch(adminDayClosuresProvider);
    final closures = closuresAsync.hasError
        ? const <ClosureEntry>[]
        : closuresAsync.value ?? const <ClosureEntry>[];
    final appointments = appointmentsAsync.value ?? const <AppointmentModel>[];

    // Sin los cancelados (spec 010, RF-6, plan D-8).
    final counts = agendaCounts(appointments);

    final brand = context.brand;

    return Scaffold(
      body: Column(
        children: [
          _AdminHeader(
            selectedDate: selectedDate,
            totalCount: counts.total,
            waitingCount: counts.waiting,
            onPreviousDay: () => _moveDay(ref, selectedDate, -1),
            onNextDay: () => _moveDay(ref, selectedDate, 1),
          ),
          Expanded(
            key: const ValueKey('agenda-body'),
            // Todo se desplaza, también los avisos de arriba: con el texto
            // grande nada se desborda (spec 011, RNF-3).
            child: CustomScrollView(
              slivers: [
                // Avisos desactivados en este teléfono (spec 011, RF-17).
                const SliverToBoxAdapter(child: AdminPushDisabledCard()),
                ...appointmentsAsync.when(
                  loading: () => [
                    const SliverFillRemaining(
                      hasScrollBody: false,
                      child: Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  ],
                  error: (err, stack) {
                    debugPrint('Error al cargar la agenda: $err');
                    return [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            child: Text(
                              l10n.adminAgendaLoadError,
                              textAlign: TextAlign.center,
                              style: AppText.sans(
                                size: 13,
                                color: brand.danger,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ];
                  },
                  data: (items) {
                    // Turnos y cierres, por su inicio (hora de pared del
                    // salón).
                    final cards = <(DateTime, Widget)>[
                      for (final appointment in items)
                        (
                          toSalon(appointment.startTime),
                          _AppointmentCard(appointment: appointment),
                        ),
                      for (final closure in closures)
                        (closure.start, _ClosureCard(entry: closure)),
                    ]..sort((a, b) => a.$1.compareTo(b.$1));
                    return [
                      if (closuresAsync.hasError)
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: EdgeInsets.fromLTRB(
                              20,
                              cards.isEmpty ? 4 : 20,
                              20,
                              0,
                            ),
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
                          ),
                        ),
                      if (cards.isEmpty)
                        SliverFillRemaining(
                          hasScrollBody: false,
                          child: Center(
                            child: Text(
                              l10n.adminNoAppointmentsToday,
                              style: AppText.sans(
                                size: 13,
                                weight: FontWeight.w300,
                                color: brand.inkMuted,
                              ),
                            ),
                          ),
                        )
                      else
                        SliverPadding(
                          padding: EdgeInsets.fromLTRB(
                            20,
                            closuresAsync.hasError ? 12 : 20,
                            20,
                            20,
                          ),
                          sliver: SliverList.separated(
                            itemCount: cards.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, index) => cards[index].$2,
                          ),
                        ),
                    ];
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Va [days] días adelante o atrás desde [day], sin límite (spec 010, RF-5).
void _moveDay(WidgetRef ref, DateTime day, int days) =>
    ref.read(adminSelectedDateProvider.notifier).state = DateTime.utc(
      day.year,
      day.month,
      day.day + days,
    );

/// Abre el calendario entre −365 y +365 días de hoy del salón, en el día
/// mostrado o en el límite más cercano; al elegir, muestra ese día (spec
/// 010, RF-4, plan D-10). Cerrarlo no cambia nada.
Future<void> _pickDay(BuildContext context, WidgetRef ref, DateTime day) async {
  final today = ref.read(adminTodayProvider);
  final bounds = agendaPickerBounds(today);
  DateTime local(DateTime d) => DateTime(d.year, d.month, d.day);
  final picked = await showDatePicker(
    context: context,
    initialDate: local(agendaPickerInitial(day, bounds)),
    firstDate: local(bounds.first),
    lastDate: local(bounds.last),
    currentDate: local(today),
  );
  if (picked == null) return;
  ref.read(adminSelectedDateProvider.notifier).state = agendaDay(picked);
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
        key: const ValueKey('agenda-header'),
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
                      // `onBrand`: `onBrandMuted` no llega a AA en 11 px
                      // (spec 010, RNF-1, plan D-9).
                      Text(
                        l10n.adminPanelEyebrow,
                        style: AppText.eyebrow(
                          size: 11,
                          weight: FontWeight.w400,
                          color: brand.onBrand,
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
                  // La fecha abre el calendario (spec 010, RF-4).
                  Expanded(
                    child: Tooltip(
                      message: l10n.adminAgendaPickDate,
                      child: TextButton(
                        key: const ValueKey('agenda-date'),
                        onPressed: () => _pickDay(context, ref, selectedDate),
                        style: TextButton.styleFrom(
                          foregroundColor: brand.onBrand,
                          minimumSize: const Size(48, 48),
                        ),
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
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('agenda-next-day'),
                    tooltip: l10n.adminAgendaNextDay,
                    onPressed: onNextDay,
                    icon: Icon(Icons.chevron_right, color: brand.onBrand),
                  ),
                ],
              ),
            ),
            // "Hoy", solo en otro día (spec 010, RF-3).
            if (selectedDate != ref.watch(adminTodayProvider))
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: OutlinedButton(
                    key: const ValueKey('agenda-today'),
                    onPressed: () =>
                        ref.read(adminSelectedDateProvider.notifier).state = ref
                            .read(adminTodayProvider),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: brand.onBrand,
                      minimumSize: const Size(48, 48),
                      side: BorderSide(color: brand.goldHairline),
                    ),
                    child: Text(
                      l10n.adminAgendaToday.toUpperCase(),
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
          // Como el subtítulo: `onBrand` a 11 px (plan D-9).
          Text(
            label,
            style: AppText.eyebrow(
              size: 11,
              spacing: 1.2,
              weight: FontWeight.w400,
              color: brand.onBrand,
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
    final brand = context.brand;
    final waiting = appointment.status == 'waiting_confirmation';
    // Botones solo en los turnos activos que no han terminado, también en
    // curso; "ahora" cada 30 s, así desaparecen al terminar (spec 010, RF-7
    // a RF-10).
    final now =
        ref.watch(salonNowProvider).value ?? toSalon(ref.read(clockProvider)());
    final actions = agendaActions(
      status: appointment.status,
      end: appointment.endTime,
      nowSalon: now,
    );
    // Un pasado sin confirmar lleva "Sin confirmar" en lugar de su estado
    // (RF-9).
    final status = actions == AgendaActions.pastUnconfirmed
        ? AppointmentStatusStyle(
            l10n.adminAppointmentUnconfirmed.toUpperCase(),
            brand.inkMuted,
          )
        : AppointmentStatusStyle.forAdmin(l10n, appointment.status, brand);
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
          if (actions == AgendaActions.active) ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinePillButton(
                    label: l10n.adminAppointmentEdit.toUpperCase(),
                    onPressed: () =>
                        openAdminEdit(context, ref, appointment.id),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinePillButton(
                    label: l10n.cancelAction,
                    color: brand.danger,
                    // Pide confirmación (spec 010, RF-12).
                    onPressed: () =>
                        showAdminCancelDialog(context, appointment),
                  ),
                ),
                if (waiting) ...[
                  const SizedBox(width: 10),
                  Expanded(child: _ConfirmButton(id: appointment.id)),
                ],
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// "Confirmar": al momento, sin diálogo (spec 010, RF-11). Mientras guarda,
/// un indicador y desactivado (RF-16); si ya no está activo o falla, un
/// aviso de la app (RF-17, plan D-4). El éxito se ve en la tarjeta.
class _ConfirmButton extends ConsumerStatefulWidget {
  const _ConfirmButton({required this.id});

  final String id;

  @override
  ConsumerState<_ConfirmButton> createState() => _ConfirmButtonState();
}

class _ConfirmButtonState extends ConsumerState<_ConfirmButton> {
  bool _saving = false;

  Future<void> _confirm() async {
    setState(() => _saving = true);
    // El aviso sale en la agenda: el botón desaparece si se confirmó o si
    // llega el turno cancelado.
    final scaffold = Scaffold.of(context).context;
    final outcome = await ref
        .read(adminAppointmentActionsProvider)
        .confirm(widget.id);
    if (mounted) setState(() => _saving = false);
    if (!scaffold.mounted) return;
    switch (outcome) {
      case AdminConfirmOutcome.ok:
        break;
      case AdminConfirmOutcome.notActive:
        showBookingMessage(scaffold, (l10n) => l10n.cancelNotActive);
      case AdminConfirmOutcome.failed:
        showBookingMessage(
          scaffold,
          (l10n) => l10n.adminConfirmFailed,
          isError: true,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: _saving ? null : _confirm,
        style: ElevatedButton.styleFrom(
          backgroundColor: brand.brand,
          foregroundColor: brand.onBrand,
          elevation: 0,
          minimumSize: const Size(48, 48),
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(22),
          ),
        ),
        child: _saving
            ? SizedBox.square(
                dimension: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: brand.inkMuted,
                ),
              )
            : Text(
                l10n.confirmAction,
                style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w500,
                  spacing: 1.2,
                  color: brand.onBrand,
                ),
              ),
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
