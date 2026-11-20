import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/l10n/app_localizations_es.dart';
import 'package:shaddai/l10n/app_localizations_pt.dart';

/// Las claves nuevas de la reserva (spec 005, plan § 6).
/// Claves de la spec 008 que quitó la 010: los choques de un cierre usan el
/// diálogo de cancelar de la agenda (spec 010, plan D-3).
const _removedBySpec010 = {
  'adminCancelAppointmentBody',
  'adminCancelAppointmentKeep',
  'adminCancelAppointmentConfirm',
};

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
  'bookingLoadError',
  'bookingRetry',
  'bookingDuration',
  'bookingTotal',
  'bookingTimeRange',
  // Spec 006, plan § 6.
  'bookingEditItemChanged',
  'bookingEditItemDoesNotFit',
  'bookingEditAddonsUnavailable',
  'bookingEditNotActive',
  'bookingEditAction',
  'bookingEditClosed',
  'bookingEditTitle',
  'bookingSaveChangesAction',
  'bookingEditConfirmTitle',
  'bookingEditBefore',
  'bookingEditAfter',
  'bookingEditChangedLabel',
  'bookingEditStart',
  'bookingEditEnd',
  'bookingEditNoAddons',
  'bookingEditConfirmPending',
  'bookingEditMarginWarning',
  'bookingEditChangeLine',
  'bookingEditSavedTitle',
  'bookingEditSavedPending',
  'bookingEditNoChanges',
  'bookingEditNotEditable',
  'bookingEditChangedMeanwhile',
  'bookingEditSaveError',
  // Spec 007, plan § 6.
  'bookingAdminTitle',
  'bookingStepRecipient',
  'bookingRecipientSearchLabel',
  'bookingRecipientSearchHint',
  'bookingRecipientNoResults',
  'bookingRecipientLoadError',
  'bookingRecipientGuestAction',
  'bookingRecipientSearchAction',
  'bookingRecipientChange',
  'bookingRecipientActive',
  'bookingGuestNameLabel',
  'bookingGuestPhoneLabel',
  'bookingGuestConsent',
  'bookingGuestNameError',
  'bookingGuestPhoneError',
  'bookingGuestConsentError',
  'bookingGuestPhoneHasAccount',
  'bookingGuestChooseAccount',
  'bookingGuestKeepGuest',
  'bookingGuestPhoneBlocked',
  'bookingMissingRecipient',
  'bookingMissingSeveral',
  'bookingSummaryFor',
  'bookingSummaryGuest',
  'bookingAdminConfirmNote',
  'bookingAdminMarginWarning',
  'bookingAdminCreated',
  'bookingRecipientBlocked',
  'adminAppointmentGuest',
  'adminAppointmentByAdmin',
  'adminAppointmentWhatsApp',
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

  test('todas las claves del plan § 6 de la spec 006 están en español y en '
      'portugués (RNF-3)', () {
    final plan = File('specs/006-editar-turno/plan.md').readAsStringSync();
    final start = plan.indexOf('## 6.');
    final section = plan.substring(start, plan.indexOf('Se reutilizan', start));
    final keys = {
      for (final match in RegExp(r'`(booking[A-Za-z]+)`').allMatches(section))
        match.group(1)!,
    };
    expect(keys, hasLength(greaterThanOrEqualTo(24)));
    for (final arb in ['app_es.arb', 'app_pt.arb']) {
      final texts = _arb(arb);
      for (final key in keys) {
        expect(texts[key], isA<String>(), reason: '$arb: $key');
        expect((texts[key] as String).trim(), isNotEmpty, reason: key);
      }
    }
  });

  test('todas las claves del plan § 6 de la spec 008, y las que se añadieron '
      'al implementarla, están en español y en portugués (RNF-3)', () {
    final plan = File('specs/008-agenda-admin/plan.md').readAsStringSync();
    final start = plan.indexOf('## 6.');
    final section = plan.substring(start, plan.indexOf('## 7.', start));
    final keys = {
      for (final match in RegExp(
        r'^\| `([A-Za-z]+)` \|',
        multiLine: true,
      ).allMatches(section))
        match.group(1)!,
      // Añadidas en las tareas (T7 y T17).
      'adminCancelAppointmentError',
      'closureDeleteFor',
      'adminAgendaPreviousDay',
      'adminAgendaNextDay',
    }..removeAll(_removedBySpec010);
    expect(keys, hasLength(greaterThanOrEqualTo(40)));
    final es = _arb('app_es.arb');
    final pt = _arb('app_pt.arb');
    for (final key in keys) {
      for (final (name, texts) in [('es', es), ('pt', pt)]) {
        expect(texts[key], isA<String>(), reason: '$name: $key');
        expect((texts[key] as String).trim(), isNotEmpty, reason: key);
      }
    }
  });

  test('los textos con duración y franja la incluyen', () {
    final es = AppLocalizationsEs();
    final pt = AppLocalizationsPt();
    expect(es.bookingServiceNeedsLongerSlot('1 h 30 min'), contains('1 h 30'));
    expect(pt.bookingSlotTooShortFor('45 min'), contains('45 min'));
    expect(es.bookingTimeRange('9:00', '9:45'), '9:00 – 9:45');
  });

  test('el servicio que no cabe en la edición nombra el servicio, su '
      'duración y el tiempo libre (spec 006, RF-29)', () {
    for (final text in [
      AppLocalizationsEs().bookingEditItemDoesNotFit(
        'Pedicura',
        '1 h 30 min',
        '1 h',
      ),
      AppLocalizationsPt().bookingEditItemDoesNotFit(
        'Pedicure',
        '1 h 30 min',
        '1 h',
      ),
    ]) {
      expect(text, contains('1 h 30 min'));
      expect(text, contains(' 1 h '));
      expect(text, contains('Pedicur'));
    }
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
