import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/theme_colors.dart';
import '../../../core/widgets/app_widgets.dart';
import '../../../data/models/calendar_settings_model.dart';
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

  final Map<String, String> _esNames = {
    'monday': 'Lunes',
    'tuesday': 'Martes',
    'wednesday': 'Miércoles',
    'thursday': 'Jueves',
    'friday': 'Viernes',
    'saturday': 'Sábado',
    'sunday': 'Domingo',
  };

  @override
  void initState() {
    super.initState();
    // Load current values safely
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final settings = ref.read(calendarSettingsProvider).value;
      if (settings != null) {
        setState(() {
          _tempHours.addAll(settings.openingHours);
        });
      }
    });
  }

  Future<void> _saveSettings() async {
    setState(() => _isLoading = true);

    final currentSettings = ref.read(calendarSettingsProvider).value;
    if (currentSettings != null) {
      final newSettings = CalendarSettingsModel(
        openingHours: _tempHours,
        globalSlotDurationMinutes: currentSettings.globalSlotDurationMinutes,
        blockedDates: currentSettings.blockedDates,
      );

      await ref.read(adminControllerProvider).updateSettings(newSettings);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ajustes guardados correctamente.')),
        );
      }
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_tempHours.isEmpty) {
      return Scaffold(
        backgroundColor: ThemeColors.bone,
        appBar: AppBar(title: const Text('Horarios')),
        body: const Center(
          child: CircularProgressIndicator(
            color: ThemeColors.darkGreen,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      appBar: AppBar(
        title: const Text('Horarios'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.only(right: 20),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    color: ThemeColors.darkGreen,
                    strokeWidth: 2,
                  ),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.check, color: ThemeColors.darkGreen),
              onPressed: _saveSettings,
            ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: _daysOrder.length,
        separatorBuilder: (_, index) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          final dayKey = _daysOrder[index];
          final schedule = _tempHours[dayKey]!;

          return FlatCard(
            padding: const EdgeInsets.fromLTRB(18, 14, 12, 18),
            borderColor: schedule.isClosed
                ? ThemeColors.hairline
                : ThemeColors.goldHairlineSoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      _esNames[dayKey]!,
                      style: AppText.serif(
                        size: 19,
                        color: ThemeColors.darkGreen,
                      ),
                    ),
                    Row(
                      children: [
                        Text(
                          'CERRADO',
                          style: AppText.eyebrow(
                            size: 10,
                            spacing: 1.6,
                            color: schedule.isClosed
                                ? ThemeColors.danger
                                : ThemeColors.olive,
                          ),
                        ),
                        Switch(
                          value: schedule.isClosed,
                          activeThumbColor: ThemeColors.danger,
                          inactiveThumbColor: ThemeColors.olive,
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
                      ],
                    ),
                  ],
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
                              color: ThemeColors.darkGreen,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Apertura (HH:MM)',
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
                              color: ThemeColors.darkGreen,
                            ),
                            decoration: const InputDecoration(
                              labelText: 'Cierre (HH:MM)',
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
