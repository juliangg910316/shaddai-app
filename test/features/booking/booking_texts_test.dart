import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/l10n/app_localizations_es.dart';
import 'package:shaddai/l10n/app_localizations_pt.dart';

/// Las claves nuevas de la reserva (spec 005, plan § 6).
const _keys = [
  'bookingStepDate',
  'bookingStepTime',
  'bookingStepService',
  'bookingStepAddons',
  'bookingStepSummary',
  'bookingSalonTimeNote',
  'bookingNoDaysAvailable',
  'bookingNoFreeSlots',
  'bookingServiceNeedsLongerSlot',
  'bookingSlotTooShortFor',
  'bookingSlotGone',
  'bookingSlotNoLongerFits',
  'bookingItemUnavailable',
  'bookingDateMoved',
  'bookingUnavailableLabel',
  'bookingMissingSlot',
  'bookingMissingService',
  'bookingMissingBoth',
  'bookingAction',
  'bookingConfirmTitle',
  'bookingConfirmPending',
  'bookingSlotTaken',
  'bookingAlreadyActive',
  'bookingActiveTitle',
  'bookingOnlyOneActive',
  'bookingBlocked',
  'bookingAdminNotice',
  'bookingLoadError',
  'bookingRetry',
  'bookingDuration',
  'bookingTotal',
  'bookingTimeRange',
];

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  for (final arb in ['app_es.arb', 'app_pt.arb']) {
    test('$arb tiene los textos de la reserva (RNF-4, RC-1)', () {
      final texts = _arb(arb);
      expect(_keys.where((key) => !texts.containsKey(key)), isEmpty);
      for (final key in _keys) {
        expect((texts[key] as String).trim(), isNotEmpty, reason: key);
      }
    });
  }

  test('los textos con duración y franja la incluyen', () {
    final es = AppLocalizationsEs();
    final pt = AppLocalizationsPt();
    expect(es.bookingServiceNeedsLongerSlot('1 h 30 min'), contains('1 h 30'));
    expect(pt.bookingSlotTooShortFor('45 min'), contains('45 min'));
    expect(es.bookingTimeRange('9:00', '9:45'), '9:00 – 9:45');
  });

  test('en portugués se dice "horário" (decisión del autor)', () {
    final pt = AppLocalizationsPt();
    expect(pt.bookingStepTime, 'Horário');
    expect(pt.bookingAction, 'Agendar horário');
    expect(pt.bookingActiveTitle, 'Seu horário');
  });

  test('el aviso nombra la confirmación de Beidis (decisión del autor)', () {
    expect(
      AppLocalizationsEs().bookingConfirmPending,
      contains('la confirmación de Beidis'),
    );
    expect(
      AppLocalizationsPt().bookingConfirmPending,
      contains('a confirmação da Beidis'),
    );
  });
}
