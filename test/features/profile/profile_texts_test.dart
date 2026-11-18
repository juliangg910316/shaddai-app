import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Las claves nuevas del perfil y de cancelar (spec 009, plan § 8). Cada
/// tarea añade aquí las suyas.
const _keys = [
  // T5: cancelar el turno.
  'cancelAppointmentAction',
  'cancelDialogTitle',
  'cancelConfirm',
  'cancelKeep',
  'cancelDone',
  'cancelNotCancellable',
  'cancelNotActive',
  'cancelChanged',
  'cancelFailed',
];

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  for (final arb in ['app_es.arb', 'app_pt.arb']) {
    test('$arb tiene los textos del perfil (RC-1)', () {
      final texts = _arb(arb);
      expect(_keys.where((key) => !texts.containsKey(key)), isEmpty);
      for (final key in _keys) {
        expect((texts[key] as String).trim(), isNotEmpty, reason: key);
      }
    });
  }
}
