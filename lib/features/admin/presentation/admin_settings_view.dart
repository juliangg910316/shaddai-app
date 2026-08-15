import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/constants/theme_colors.dart';
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
    'monday', 'tuesday', 'wednesday', 'thursday', 'friday', 'saturday', 'sunday'
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
    
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    if (_tempHours.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: const Text('Horarios del Local')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      backgroundColor: ThemeColors.bone,
      appBar: AppBar(
        title: const Text('Horarios del Local'),
        actions: [
          _isLoading 
            ? const Padding(
                padding: EdgeInsets.all(16.0),
                child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: ThemeColors.darkGreen)),
              )
            : IconButton(
                icon: const Icon(Icons.save),
                onPressed: _saveSettings,
              ),
        ],
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _daysOrder.length,
        itemBuilder: (context, index) {
          final dayKey = _daysOrder[index];
          final schedule = _tempHours[dayKey]!;
          
          return Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        _esNames[dayKey]!,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ThemeColors.darkGreen),
                      ),
                      Row(
                        children: [
                          const Text('Cerrado'),
                          Switch(
                            value: schedule.isClosed,
                            activeColor: Colors.red,
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
                      )
                    ],
                  ),
                  if (!schedule.isClosed) ...[
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: TextFormField(
                            initialValue: schedule.open,
                            decoration: const InputDecoration(labelText: 'Apertura (HH:MM)', border: OutlineInputBorder()),
                            onChanged: (val) {
                              _tempHours[dayKey] = DaySchedule(open: val, close: schedule.close, isClosed: schedule.isClosed);
                            },
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: TextFormField(
                            initialValue: schedule.close,
                            decoration: const InputDecoration(labelText: 'Cierre (HH:MM)', border: OutlineInputBorder()),
                            onChanged: (val) {
                              _tempHours[dayKey] = DaySchedule(open: schedule.open, close: val, isClosed: schedule.isClosed);
                            },
                          ),
                        ),
                      ],
                    ),
                  ]
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
