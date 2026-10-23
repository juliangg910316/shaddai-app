import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Estructura de `firestore.rules` (spec 004, RNF-2). Lo que permite cada
/// regla se comprueba a mano en el simulador de la consola (plan, A-1;
/// `specs/004-servicios-firestore/rules-check.md`); aquí se fija qué cubre
/// cada `match` para que un cambio no lo rompa sin querer.
void main() {
  final rulesFile = File('firestore.rules');

  /// Cuerpo del bloque `match <path> { … }`, o `null` si no está.
  String? block(String rules, String path) {
    final header = 'match $path {';
    final start = rules.indexOf(header);
    if (start < 0) return null;
    // La llave que abre el bloque es la última de la cabecera, no la de un
    // comodín como `{userId}`.
    var depth = 0;
    for (var i = start + header.length - 1; i < rules.length; i++) {
      if (rules[i] == '{') depth++;
      if (rules[i] == '}' && --depth == 0) {
        return rules.substring(start, i + 1);
      }
    }
    return null;
  }

  test('existe firestore.rules y firebase.json lo usa', () {
    expect(rulesFile.existsSync(), isTrue);
    final firebase =
        jsonDecode(File('firebase.json').readAsStringSync())
            as Map<String, dynamic>;
    expect((firebase['firestore'] as Map)['rules'], 'firestore.rules');
  });

  test('la lista de precios: lectura pública, escritura de la admin y sin '
      'borrado (RNF-2)', () {
    final priceList = block(
      rulesFile.readAsStringSync(),
      '/settings/priceList',
    );
    expect(priceList, isNotNull);
    expect(priceList, contains('allow read: if true;'));
    expect(priceList, contains('allow create, update: if isAdmin();'));
    expect(priceList, contains('allow delete: if false;'));
  });

  test('isAdmin lee el rol de la ficha de la usuaria con sesión', () {
    final rules = rulesFile.readAsStringSync();
    expect(rules, contains('function isAdmin()'));
    expect(rules, contains('request.auth != null'));
    expect(
      rules,
      contains(
        "get(/databases/\$(database)/documents/users/\$(request.auth.uid))"
        ".data.role == 'admin'",
      ),
    );
  });

  test('el resto de datos de la app tiene la regla provisional con sesión, '
      'marcada para la spec 009', () {
    final rules = rulesFile.readAsStringSync();
    for (final path in [
      '/users/{userId}',
      '/appointments/{appointmentId}',
      '/settings/calendar',
    ]) {
      final rule = block(rules, path);
      expect(rule, isNotNull, reason: path);
      expect(
        rule,
        contains('allow read, write: if request.auth != null;'),
        reason: path,
      );
      expect(rule, contains('PROVISIONAL'), reason: path);
      expect(rule, contains('spec 009'), reason: path);
    }
  });

  test('no hay un comodín que abra la lista de precios a cualquier persona '
      'con sesión', () {
    final rules = rulesFile.readAsStringSync();
    expect(rules, isNot(contains('{document=**}')));
    expect(rules, isNot(contains('match /settings/{')));
  });
}
