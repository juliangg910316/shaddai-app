import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/theme/system_bars.dart';
import '../../../core/utils/capitalize.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../l10n/app_localizations.dart';
import '../providers/admin_provider.dart';
import '../../../data/models/appointment_model.dart';

class AdminDashboardView extends ConsumerWidget {
  const AdminDashboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final selectedDate = ref.watch(adminSelectedDateProvider);
    final appointmentsAsync = ref.watch(adminAppointmentsProvider);
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
                if (items.isEmpty) {
                  return Center(
                    child: Text(
                      l10n.adminNoAppointmentsToday,
                      style: AppText.sans(
                        size: 13,
                        weight: FontWeight.w300,
                        color: brand.inkMuted,
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: items.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) =>
                      _AppointmentCard(appointment: items[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _AdminHeader extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
                GestureDetector(
                  onTap: () => context.push('/admin/users'),
                  child: Icon(
                    Icons.group_outlined,
                    size: 22,
                    color: brand.onBrand,
                  ),
                ),
                const SizedBox(width: 18),
                GestureDetector(
                  onTap: () => context.push('/admin/settings'),
                  child: Icon(
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
                  IconButton(
                    onPressed: onPreviousDay,
                    visualDensity: VisualDensity.compact,
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
                    onPressed: onNextDay,
                    visualDensity: VisualDensity.compact,
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
    final hours = DateFormat.Hm(l10n.localeName);
    final startStr = hours.format(appointment.startTime);
    final endStr = hours.format(appointment.endTime);

    return FlatCard(
      borderColor: waiting ? brand.goldHairline : brand.hairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
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
                  ],
                ),
              ),
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: brand.hairlineStrong),
                ),
                alignment: Alignment.center,
                child: const WhatsAppIcon(size: 18),
              ),
            ],
          ),
          if (appointment.status != 'cancelled') ...[
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinePillButton(
                    label: l10n.cancelAction,
                    color: brand.danger,
                    onPressed: () => ref
                        .read(adminControllerProvider)
                        .updateAppointmentStatus(appointment.id, 'cancelled'),
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
                            .updateAppointmentStatus(
                              appointment.id,
                              'confirmed',
                            ),
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
