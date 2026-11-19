import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Los textos del panel de la spec 010 (plan § 8, RC-1): las claves nuevas,
/// en español y en portugués y no vacías; la que cambia, con su texto
/// nuevo; y las que se quitan, fuera.
Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

/// Las claves de la tabla del plan § 8.
Set<String> _planKeys() {
  final plan = File('specs/010-admin/plan.md').readAsStringSync();
  final start = plan.indexOf('## 8.');
  final section = plan.substring(start, plan.indexOf('## 9.', start));
  return {
    for (final match in RegExp(
      r'^\| `([A-Za-z]+)` \|',
      multiLine: true,
    ).allMatches(section))
      match.group(1)!,
  };
}

const _removed = [
  'adminCancelAppointmentBody',
  'adminCancelAppointmentKeep',
  'adminCancelAppointmentConfirm',
];

void main() {
  test('el plan § 8 tiene las 20 claves nuevas', () {
    expect(_planKeys(), hasLength(20));
  });

  for (final arb in ['app_es.arb', 'app_pt.arb']) {
    test('$arb tiene los textos del panel (RC-1)', () {
      final texts = _arb(arb);
      for (final key in _planKeys()) {
        expect(texts[key], isA<String>(), reason: key);
        expect((texts[key] as String).trim(), isNotEmpty, reason: key);
      }
      expect(_removed.where(texts.containsKey), isEmpty);
    });
  }

  test('"TURNOS DEL DÍA" en lugar de "TURNOS HOY" (plan D-8)', () {
    expect(_arb('app_es.arb')['adminStatAppointmentsToday'], 'TURNOS DEL DÍA');
    expect(_arb('app_pt.arb')['adminStatAppointmentsToday'], 'HORÁRIOS DO DIA');
  });
}
