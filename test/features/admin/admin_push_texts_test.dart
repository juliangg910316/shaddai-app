import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Los textos de los avisos push en la app están en español y portugués
/// (spec 011, RNF-1, RC-1; plan § 8; T9).
const keys = [
  'adminPushExplainTitle',
  'adminPushExplainBody',
  'adminPushExplainContinue',
  'adminPushDisabledTitle',
  'adminPushDisabledBody',
  'adminPushView',
  'adminPushViewLabel',
];

Map<String, Object?> readArb(String language) =>
    jsonDecode(File('lib/l10n/app_$language.arb').readAsStringSync())
        as Map<String, Object?>;

void main() {
  for (final language in ['es', 'pt']) {
    test('las ${keys.length} claves del plan están en app_$language.arb', () {
      final arb = readArb(language);
      for (final key in keys) {
        final value = arb[key];
        expect(value, isA<String>(), reason: key);
        expect((value! as String).trim(), isNotEmpty, reason: key);
      }
    });
  }

  test('en español, cada clave tiene su descripción', () {
    final arb = readArb('es');
    for (final key in keys) {
      expect(arb['@$key'], isA<Map<String, Object?>>(), reason: key);
    }
  });
}
