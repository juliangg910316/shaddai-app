import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_text.dart';
import '../../../core/theme/brand_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/calendar_settings_model.dart';
import '../../../l10n/app_localizations.dart';
import '../../booking/logic/edit_margin.dart';
import '../../booking/presentation/booking_notices.dart';
import '../../booking/providers/booking_provider.dart';
import '../providers/admin_provider.dart';

class AdminSettingsView extends ConsumerStatefulWidget {
  const AdminSettingsView({super.key});

  @override
  ConsumerState<AdminSettingsView> createState() => _AdminSettingsViewState();
}

class _AdminSettingsViewState extends ConsumerState<AdminSettingsView> {
  final Map<String, DaySchedule> _tempHours = {};
  bool _isLoading = false;

  final List<String> _daysOrder = [
    'monday',
    'tuesday',
    'wednesday',
    'thursday',
    'friday',
    'saturday',
    'sunday',
  ];

  Map<String, String> _dayNames(AppLocalizations l10n) => {
    'monday': l10n.weekdayMonday,
    'tuesday': l10n.weekdayTuesday,
    'wednesday': l10n.weekdayWednesday,
    'thursday': l10n.weekdayThursday,
    'friday': l10n.weekdayFriday,
    'saturday': l10n.weekdaySaturday,
    'sunday': l10n.weekdaySunday,
  };

  /// Si ya se copió el horario guardado a [_tempHours]. Se copia una sola
  /// vez, cuando llega el calendario, para no pisar lo que se está editando.
  bool _loaded = false;

  /// Un día que no está en el horario guardado sale cerrado, como lo trata
  /// la reserva.
  static final _closedDay = DaySchedule(
    open: '09:00',
    close: '18:00',
    isClosed: true,
  );

  /// El margen elegido mientras se guarda; después manda el guardado
  /// (RF-38, RF-39).
  int? _savingMargin;

  /// Cuántos guardados del margen terminaron: rehace el desplegable para
  /// que muestre el margen de verdad, aunque el guardado falle enseguida.
  int _marginSaves = 0;

  /// Guarda solo el margen (RF-38, RF-41). Si falla, lo dice y vuelve a
  /// mostrar el que había (RF-39).
  Future<void> _saveMargin(int minutes) async {
    setState(() => _savingMargin = minutes);
    var saved = true;
    try {
      await ref.read(adminControllerProvider).updateEditMargin(minutes);
    } catch (error) {
      debugPrint('No se pudo guardar el margen: $error');
      saved = false;
    }
    if (!mounted) return;
    setState(() {
      _savingMargin = null;
      _marginSaves++;
    });
    showBookingMessage(
      context,
      (l10n) =>
          saved ? l10n.settingsEditMarginSaved : l10n.settingsEditMarginError,
      isError: !saved,
    );
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    final l10n = AppLocalizations.of(context)!;
    final currentSettings = ref.read(calendarSettingsProvider).value;
    if (currentSettings != null) {
      final newSettings = CalendarSettingsModel(
        openingHours: _tempHours,
        globalSlotDurationMinutes: currentSettings.globalSlotDurationMinutes,
        blockedDates: currentSettings.blockedDates,
      );

      await ref.read(adminControllerProvider).updateSettings(newSettings);

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(l10n.settingsSavedSuccess)));
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final settingsAsync = ref.watch(calendarSettingsProvider);

    if (!_loaded) {
      final settings = settingsAsync.value;
      if (settings == null) {
        return Scaffold(
          appBar: AppBar(title: Text(l10n.scheduleSettingsTitle)),
          // Tras un error, Riverpod reintenta solo: el error manda.
          body: settingsAsync.hasError
              ? const Padding(
                  padding: EdgeInsets.all(20),
                  child: BookingLoadErrorNotice(schedule: true),
                )
              : const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        );
      }
      for (final day in _daysOrder) {
        _tempHours[day] = settings.openingHours[day] ?? _closedDay;
      }
      _loaded = true;
    }

    final dayNames = _dayNames(l10n);
    final brand = context.brand;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.scheduleSettingsTitle),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              tooltip: l10n.adminSave,
              icon: Icon(Icons.check, color: brand.inkStrong),
              onPressed: _saveSettings,
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _daysOrder.length + 1,
        separatorBuilder: (_, index) => SizedBox(height: index == 0 ? 24 : 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return _MarginSection(
              key: ValueKey(_marginSaves),
              margin:
                  _savingMargin ?? settingsAsync.value?.editMarginMinutes ?? 0,
              onChanged: _savingMargin == null ? _saveMargin : null,
            );
          }
          final dayKey = _daysOrder[index - 1];
          final schedule = _tempHours[dayKey] ?? _closedDay;

          return FlatCard(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 18),
            borderColor: schedule.isClosed
                ? brand.hairline
                : brand.goldHairlineSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // El día a la izquierda y "Cerrado" con su interruptor al
                // extremo derecho; si no caben (texto grande), "Cerrado" baja
                // a otra línea, también a la derecha. El lector de pantalla
                // lee el día, "Cerrado" y el interruptor juntos (spec 008,
                // RNF-2).
                MergeSemantics(
                  child: _DayHeader(
                    day: Text(
                      dayNames[dayKey]!,
                      style: AppText.serif(size: 19, color: brand.inkStrong),
                    ),
                    closed: Text(
                      l10n.closedLabel,
                      style: AppText.eyebrow(
                        size: 10,
                        spacing: 1.6,
                        color: schedule.isClosed
                            ? brand.danger
                            : brand.inkMuted,
                      ),
                    ),
                    toggle: Switch(
                      value: schedule.isClosed,
                      activeThumbColor: brand.danger,
                      inactiveThumbColor: brand.inkMuted,
                      onChanged: (val) {
                        setState(() {
                          _tempHours[dayKey] = DaySchedule(
                            open: schedule.open,
                            close: schedule.close,
                            isClosed: val,
                          );
                        });
                      },
                    ),
                  ),
                ),
                if (!schedule.isClosed) ...[
                  const SizedBox(height: 10),
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: schedule.open,
                            style: AppText.sans(
                              size: 15,
                              color: brand.inkStrong,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.openingTimeLabel,
                            ),
                            onChanged: (val) {
                              _tempHours[dayKey] = DaySchedule(
                                open: val,
                                close: schedule.close,
                                isClosed: schedule.isClosed,
                              );
                            },
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: TextFormField(
                            initialValue: schedule.close,
                            style: AppText.sans(
                              size: 15,
                              color: brand.inkStrong,
                            ),
                            decoration: InputDecoration(
                              labelText: l10n.closingTimeLabel,
                            ),
                            onChanged: (val) {
                              _tempHours[dayKey] = DaySchedule(
                                open: schedule.open,
                                close: val,
                                isClosed: schedule.isClosed,
                              );
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// El nombre de un margen: "Sin margen", en horas o, si no es una de las
/// opciones, en horas y minutos (RF-36, RF-37).
String marginLabel(AppLocalizations l10n, int minutes) {
  if (minutes == 0) return l10n.settingsEditMarginNone;
  final parts = marginParts(minutes);
  return parts.minutes == 0
      ? l10n.settingsEditMarginHours(parts.hours)
      : l10n.settingsEditMarginCustom(parts.hours, parts.minutes);
}

/// "Margen de edición": su explicación y el desplegable de las opciones
/// (spec 008, RF-36 a RF-39). Sin [onChanged], mientras se guarda, no se
/// puede cambiar.
class _MarginSection extends StatelessWidget {
  const _MarginSection({
    super.key,
    required this.margin,
    required this.onChanged,
  });

  final int margin;
  final ValueChanged<int>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final brand = context.brand;
    final onChanged = this.onChanged;

    return FlatCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
      borderColor: brand.goldHairlineSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.settingsEditMarginTitle,
            style: AppText.serif(size: 19, color: brand.inkStrong),
          ),
          const SizedBox(height: 4),
          Text(
            l10n.settingsEditMarginHelp,
            style: AppText.sans(size: 14, color: brand.inkMuted),
          ),
          const SizedBox(height: 12),
          // Rehace el campo cuando el margen cambia desde fuera: al volver al
          // que había tras un error o al llegar el guardado.
          KeyedSubtree(
            key: ValueKey(margin),
            // Sin etiqueta visible (el título está encima); el lector de
            // pantalla la recibe igual.
            child: Semantics(
              label: l10n.settingsEditMarginTitle,
              child: DropdownButtonFormField<int>(
                key: const ValueKey('edit-margin'),
                initialValue: margin,
                isExpanded: true,
                items: [
                  for (final minutes in marginChoices(margin))
                    DropdownMenuItem(
                      value: minutes,
                      child: Text(
                        marginLabel(l10n, minutes),
                        style: AppText.sans(size: 15, color: brand.inkStrong),
                      ),
                    ),
                ],
                onChanged: onChanged == null
                    ? null
                    : (value) {
                        if (value != null && value != margin) onChanged(value);
                      },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// La cabecera de un día en los ajustes: [day] a la izquierda y [closed]
/// con [toggle] al extremo derecho, en una línea si caben (con al menos
/// 24 px entre ellos). Si no, [closed] y [toggle] bajan a la línea
/// siguiente, también a la derecha (spec 008, RNF-2).
class _DayHeader extends StatelessWidget {
  const _DayHeader({
    required this.day,
    required this.closed,
    required this.toggle,
  });

  final Text day;
  final Text closed;
  final Widget toggle;

  /// Ancho de un `Switch` con su zona táctil de 48 px.
  static const _toggleWidth = 60.0;
  static const _minGap = 24.0;

  double _width(BuildContext context, Text text) {
    final painter = TextPainter(
      text: TextSpan(text: text.data, style: text.style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final end = Row(mainAxisSize: MainAxisSize.min, children: [closed, toggle]);
    return LayoutBuilder(
      builder: (context, constraints) {
        final needed =
            _width(context, day) +
            _minGap +
            _width(context, closed) +
            _toggleWidth;
        if (needed <= constraints.maxWidth) {
          return Row(
            children: [
              Expanded(child: day),
              end,
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            day,
            Align(alignment: AlignmentDirectional.centerEnd, child: end),
          ],
        );
      },
    );
  }
}
