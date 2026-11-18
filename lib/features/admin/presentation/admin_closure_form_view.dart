import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/utils/capitalize.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/appointment_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/logic/booking_window.dart';
import '../../booking/logic/closures.dart';
import '../../booking/logic/salon_time.dart';
import '../../booking/providers/admin_edit_provider.dart';
import '../../booking/providers/booking_provider.dart';
import '../providers/admin_closures_provider.dart';
import '../providers/admin_provider.dart';
import 'admin_dashboard_view.dart';
import 'admin_navigation.dart';

/// "Nuevo cierre": una franja o días enteros, con sus errores bajo cada
/// campo y, si hay turnos que chocan, la lista para editarlos o cancelarlos
/// (spec 008, RF-3 a RF-6, RF-11). Igual en Web y en Android/iOS.
class AdminClosureFormView extends ConsumerStatefulWidget {
  const AdminClosureFormView({super.key});

  @override
  ConsumerState<AdminClosureFormView> createState() =>
      _AdminClosureFormViewState();
}

DateTime _addDays(DateTime day, int days) =>
    DateTime.utc(day.year, day.month, day.day + days);

class _AdminClosureFormViewState extends ConsumerState<AdminClosureFormView> {
  late final DateTime _today;
  ClosureKind _kind = ClosureKind.range;
  late DateTime _day;
  int _fromMinutes = 9 * 60;
  int _toMinutes = 10 * 60;
  late DateTime _firstDay;
  late DateTime _lastDay;

  /// Tras el primer "Guardar", los errores se ven y se actualizan solos.
  bool _submitted = false;
  bool _saving = false;

  /// Los turnos que chocaron en el último "Guardar" (RF-5).
  List<AppointmentModel>? _conflicts;

  @override
  void initState() {
    super.initState();
    _today = salonDay(toSalon(ref.read(clockProvider)()));
    _day = _today;
    _firstDay = _today;
    _lastDay = _today;
  }

  ClosureDraft get _draft => switch (_kind) {
    ClosureKind.range => RangeDraft(
      day: _day,
      fromMinutes: _fromMinutes,
      toMinutes: _toMinutes,
    ),
    ClosureKind.days => DaysDraft(firstDay: _firstDay, lastDay: _lastDay),
  };

  /// Cambia lo elegido; los choques de antes ya no valen.
  void _change(VoidCallback change) => setState(() {
    change();
    _conflicts = null;
  });

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    setState(() {
      _submitted = true;
      _saving = true;
      _conflicts = null;
    });
    final result = await ref.read(closureControllerProvider).save(_draft);
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case ClosureSaveInvalid():
        break;
      case ClosureSaveConflicts(:final appointments):
        setState(() => _conflicts = appointments);
      case ClosureSaveOk():
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.closureSaved)));
        if (context.canPop()) {
          context.pop();
        } else {
          context.go('/admin/closures');
        }
      case ClosureSaveFailed():
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(l10n.closureSaveError)));
    }
  }

  /// Cancela [appointment] tras confirmarlo: el turno de la persona se
  /// pierde (constitución, principio 5).
  Future<void> _cancel(AppointmentModel appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        // Textos leídos aquí dentro: el diálogo cambia de idioma con la app.
        final l10n = AppLocalizations.of(context)!;
        return AlertDialog(
          title: Text(l10n.adminCancelAppointmentTitle(appointment.clientName)),
          content: Text(l10n.adminCancelAppointmentBody),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(l10n.adminCancelAppointmentKeep.toUpperCase()),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: Text(l10n.adminCancelAppointmentConfirm.toUpperCase()),
            ),
          ],
        );
      },
    );
    if (confirmed != true || !mounted) return;
    final l10n = AppLocalizations.of(context)!;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref
          .read(adminControllerProvider)
          .updateAppointmentStatus(appointment.id, 'cancelled');
    } catch (error) {
      debugPrint('No se pudo cancelar el turno: $error');
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text(l10n.adminCancelAppointmentError)),
        );
      return;
    }
    if (!mounted) return;
    setState(
      () => _conflicts = [
        for (final a in _conflicts ?? const <AppointmentModel>[])
          if (a.id != appointment.id) a,
      ],
    );
  }

  /// Al terminar la edición de un turno que chocaba, vuelve a pedir los
  /// choques: el turno pudo moverse fuera del cierre (spec 008,
  /// Navegación). Si no se pueden leer, deja la lista como estaba.
  Future<void> _recheckConflicts() async {
    final draft = _draft;
    final conflicts = await ref
        .read(closureControllerProvider)
        .conflicts(draft);
    if (!mounted || conflicts == null || _conflicts == null) return;
    setState(() => _conflicts = conflicts.isEmpty ? null : conflicts);
  }

  Future<void> _pickDay(
    DateTime current,
    ValueChanged<DateTime> onPicked,
  ) async {
    DateTime local(DateTime day) => DateTime(day.year, day.month, day.day);
    final last = _addDays(_today, adminBookingWindowDays);
    final initial = current.isBefore(_today)
        ? _today
        : current.isAfter(last)
        ? last
        : current;
    final picked = await showDatePicker(
      context: context,
      initialDate: local(initial),
      firstDate: local(_today),
      lastDate: local(last),
    );
    if (picked == null || !mounted) return;
    _change(
      () => onPicked(DateTime.utc(picked.year, picked.month, picked.day)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final locale = l10n.localeName;
    final date = DateFormat.yMMMMEEEEd(locale);
    ref.listen(adminEditProvider, (previous, next) {
      if (previous != null && next == null && _conflicts != null) {
        _recheckConflicts();
      }
    });
    final nowSalon =
        ref.watch(salonNowProvider).value ?? toSalon(ref.read(clockProvider)());
    final errors = _submitted
        ? closureErrors(_draft, nowSalon: nowSalon)
        : const <ClosureError>{};

    String message(ClosureError error) => switch (error) {
      ClosureError.endNotAfterStart => l10n.closureErrorEndNotAfterStart,
      ClosureError.daysReversed => l10n.closureErrorDaysReversed,
      ClosureError.past => l10n.closureErrorPast,
      ClosureError.tooFar => l10n.closureErrorTooFar(
        date.format(_addDays(salonDay(nowSalon), adminBookingWindowDays)),
      ),
    };

    List<Widget> errorTexts(Iterable<ClosureError> shown) => [
      for (final error in shown)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text(
            message(error),
            style: AppText.sans(size: 13, color: brand.danger, height: 1.4),
          ),
        ),
    ];

    Widget field(
      String name,
      String label,
      Widget input,
      Set<ClosureError> e,
    ) => Padding(
      key: ValueKey('closure-field-$name'),
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: AppText.sans(
              size: 13,
              weight: FontWeight.w600,
              color: brand.ink,
            ),
          ),
          const SizedBox(height: 6),
          input,
          ...errorTexts(errors.intersection(e)),
        ],
      ),
    );

    Widget dayButton(DateTime day, ValueChanged<DateTime> onPicked) =>
        OutlinedButton(
          onPressed: () => _pickDay(day, onPicked),
          style: OutlinedButton.styleFrom(
            foregroundColor: brand.ink,
            minimumSize: const Size(48, 48),
            alignment: AlignmentDirectional.centerStart,
          ),
          child: Text(
            capitalizeFirst(date.format(day)),
            style: AppText.sans(size: 15, color: brand.ink),
          ),
        );

    final hm = DateFormat.Hm(locale);
    Widget timeDropdown(int value, ValueChanged<int> onChanged) =>
        DropdownButtonFormField<int>(
          initialValue: value,
          isExpanded: true,
          items: [
            for (var m = 0; m < 24 * 60; m += closureStepMinutes)
              DropdownMenuItem(
                value: m,
                child: Text(
                  hm.format(DateTime.utc(2000).add(Duration(minutes: m))),
                ),
              ),
          ],
          onChanged: (m) {
            if (m != null) _change(() => onChanged(m));
          },
        );

    final fields = switch (_kind) {
      ClosureKind.range => [
        field('date', l10n.closureDateLabel, dayButton(_day, (d) => _day = d), {
          ClosureError.past,
          ClosureError.tooFar,
        }),
        field(
          'from',
          l10n.closureFromLabel,
          timeDropdown(_fromMinutes, (m) => _fromMinutes = m),
          const {},
        ),
        field(
          'to',
          l10n.closureToLabel,
          timeDropdown(_toMinutes, (m) => _toMinutes = m),
          {ClosureError.endNotAfterStart},
        ),
      ],
      ClosureKind.days => [
        field(
          'first',
          l10n.closureFirstDayLabel,
          dayButton(_firstDay, (d) => _firstDay = d),
          const {},
        ),
        field(
          'last',
          l10n.closureLastDayLabel,
          dayButton(_lastDay, (d) => _lastDay = d),
          {ClosureError.daysReversed, ClosureError.past, ClosureError.tooFar},
        ),
      ],
    };

    final conflicts = _conflicts;

    return Scaffold(
      backgroundColor: brand.background,
      appBar: AppBar(title: Text(l10n.adminClosuresNew)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SegmentedButton<ClosureKind>(
              segments: [
                ButtonSegment(
                  value: ClosureKind.range,
                  label: Text(l10n.closureKindRange),
                ),
                ButtonSegment(
                  value: ClosureKind.days,
                  label: Text(l10n.closureKindDays),
                ),
              ],
              selected: {_kind},
              onSelectionChanged: (kinds) => _change(() => _kind = kinds.first),
            ),
            const SizedBox(height: 20),
            ...fields,
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: brand.brand,
                foregroundColor: brand.onBrand,
                minimumSize: const Size(48, 48),
                shape: const StadiumBorder(),
              ),
              child: Text(
                l10n.adminSave.toUpperCase(),
                style: AppText.sans(
                  size: 12,
                  weight: FontWeight.w600,
                  spacing: 1.2,
                  color: brand.onBrand,
                ),
              ),
            ),
            if (conflicts != null && conflicts.isNotEmpty) ...[
              const SizedBox(height: 28),
              Text(
                l10n.closureConflictsTitle,
                style: AppText.serif(size: 22, color: brand.inkStrong),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.closureConflictsBody,
                style: AppText.sans(size: 15, color: brand.ink, height: 1.6),
              ),
              const SizedBox(height: 12),
              for (final appointment in conflicts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ConflictCard(
                    appointment: appointment,
                    onEdit: () => openAdminEdit(
                      context,
                      ref,
                      appointment.id,
                      fromClosure: true,
                    ),
                    onCancel: () => _cancel(appointment),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Un turno que choca con el cierre: fecha, hora, persona y lo reservado,
/// con "Editar" y "Cancelar" (RF-5).
class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.appointment,
    required this.onEdit,
    required this.onCancel,
  });

  final AppointmentModel appointment;
  final VoidCallback onEdit;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final locale = l10n.localeName;
    // En hora del salón, esté donde esté el dispositivo (spec 005).
    final start = toSalon(appointment.startTime);
    final end = toSalon(appointment.endTime);
    final hm = DateFormat.Hm(locale);

    return FlatCard(
      key: ValueKey('closure-conflict-${appointment.id}'),
      borderColor: brand.goldHairline,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            capitalizeFirst(DateFormat.yMMMMEEEEd(locale).format(start)),
            style: AppText.sans(size: 14, color: brand.ink),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.bookingTimeRange(hm.format(start), hm.format(end)),
            style: AppText.serif(size: 19, color: brand.inkStrong),
          ),
          const SizedBox(height: 4),
          Text(
            appointment.clientName,
            style: AppText.sans(
              size: 15,
              weight: FontWeight.w600,
              color: brand.inkStrong,
            ),
          ),
          if (appointment.booked case final booked?) ...[
            const SizedBox(height: 4),
            Text(
              bookedLabel(booked, locale),
              style: AppText.sans(size: 14, color: brand.ink, height: 1.4),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinePillButton(
                  label: l10n.adminAppointmentEdit.toUpperCase(),
                  onPressed: onEdit,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinePillButton(
                  label: l10n.cancelAction,
                  color: brand.danger,
                  onPressed: onCancel,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
