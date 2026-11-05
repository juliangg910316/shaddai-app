import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Lo que solo usaba la reserva antigua ya no está (spec 005, plan,
/// "Limpieza").
void main() {
  final sources = [
    for (final file in Directory('lib').listSync(recursive: true))
      if (file is File &&
          file.path.endsWith('.dart') &&
          !file.path.contains('lib/l10n/'))
        file,
  ];

  for (final name in [
    '_ServiceOption',
    '_serviceOptions',
    '_ServiceChip',
    'availableSlotsProvider',
    'selectedDateProvider',
    'appointmentsForDateProvider',
    'getActiveAppointmentsForDate',
  ]) {
    test('$name ya no existe', () {
      final word = RegExp('(^|[^A-Za-z0-9_])${RegExp.escape(name)}\\b');
      final uses = [
        for (final file in sources)
          if (word.hasMatch(file.readAsStringSync())) file.path,
      ];
      expect(uses, isEmpty);
    });
  }

  const keys = [
    'serviceOptionClassicChip',
    'serviceOptionClassicSummary',
    'serviceOptionSemipermChip',
    'serviceOptionSemipermSummary',
    'serviceOptionAcrylicChip',
    'serviceOptionAcrylicSummary',
    'stepServiceLabel',
    'stepDateLabel',
    'stepTimeLabel',
    'chooseTimeSlotAction',
    'confirmAtTimeAction',
    'confirmBookingDialogTitle',
    'confirmBookingDialogBody',
    'slotsLoadError',
    'noSlotsAvailable',
    'bookingPendingNoticePrefix',
    'bookingPendingNoticeHighlight',
    'bookingPendingNoticeSuffix',
  ];
  for (final arb in ['lib/l10n/app_es.arb', 'lib/l10n/app_pt.arb']) {
    test('$arb ya no tiene los textos de la reserva antigua', () {
      final texts = jsonDecode(File(arb).readAsStringSync()) as Map;
      expect(
        keys.where(
          (key) => texts.containsKey(key) || texts.containsKey('@$key'),
        ),
        isEmpty,
      );
    });
  }
}
