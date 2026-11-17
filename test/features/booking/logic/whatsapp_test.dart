import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/booking/logic/whatsapp.dart';

/// WhatsApp normalizado, válido y su enlace (spec 007, RF-7, RF-9, RF-10,
/// RF-22; RNF-1; plan § 4.1, D-1 y D-6).
void main() {
  group('normalizeWhatsApp', () {
    const cases = <(String, String, String)>[
      ('41 99999-0000', '41999990000', 'espacios y guion'),
      ('(41) 99999-0000', '41999990000', 'paréntesis'),
      ('+55 41 99999-0000', '41999990000', '+55'),
      ('+55 (41) 3333-4444', '4133334444', '+55 con fijo de 8 dígitos'),
      ('5541999990000', '41999990000', '55 delante, 13 dígitos'),
      ('554133334444', '4133334444', '55 delante, 12 dígitos'),
      ('55 99123-4567', '55991234567', '55 como DDD, 11 dígitos (D-1)'),
      ('55 3333-4444', '5533334444', '55 como DDD, 10 dígitos (D-1)'),
      ('+53 5 1234567', '5351234567', 'otro país: no se toca'),
      ('  41.99999.0000  ', '41999990000', 'puntos y espacios alrededor'),
      ('sin número', '', 'sin dígitos'),
      ('', '', 'vacío'),
    ];
    for (final (raw, expected, why) in cases) {
      test('$why: "$raw" → "$expected"', () {
        expect(normalizeWhatsApp(raw), expected);
      });
    }
  });

  group('isValidWhatsApp (8 a 15 dígitos normalizados)', () {
    const cases = <(String, bool, String)>[
      ('1234567', false, '7 dígitos'),
      ('1234-5678', true, '8 dígitos'),
      ('123456789012345', true, '15 dígitos'),
      ('1234567890123456', false, '16 dígitos'),
      ('+55 41 99999-0000', true, 'número de Brasil con +55'),
      ('+55 1234567', false, '+55 y 7 dígitos: el 55 no se quita y son 9'),
      ('5512345', false, '55 delante con 7 dígitos en total'),
      ('abc', false, 'sin dígitos'),
      ('', false, 'vacío'),
    ];
    for (final (raw, expected, why) in cases) {
      test('$why: "$raw" → $expected', () {
        expect(isValidWhatsApp(raw), expected);
      });
    }
  });

  group('sameWhatsApp', () {
    const cases = <(String, String, bool, String)>[
      ('+55 41 99999-0000', '(41) 99999-0000', true, 'con y sin +55'),
      ('5541999990000', '41 99999 0000', true, '55 delante y sin él'),
      ('41 99999-0000', '41 99999-0001', false, 'otro número'),
      ('55 99123-4567', '99123-4567', false, '55 como DDD no se quita'),
      ('', '', false, 'dos vacíos'),
      ('abc', 'xyz', false, 'sin dígitos'),
    ];
    for (final (a, b, expected, why) in cases) {
      test('$why: "$a" y "$b" → $expected', () {
        expect(sameWhatsApp(a, b), expected);
        expect(sameWhatsApp(b, a), expected);
      });
    }
  });

  group('whatsAppLink (D-6)', () {
    const cases = <(String, String?, String)>[
      ('+55 41 99999-0000', 'https://wa.me/5541999990000', 'con +55'),
      ('5541999990000', 'https://wa.me/5541999990000', 'con 55 delante'),
      ('(41) 99999-0000', 'https://wa.me/5541999990000', 'sin código: +55'),
      ('55 99123-4567', 'https://wa.me/5555991234567', '55 como DDD: +55'),
      ('+53 5 1234567', 'https://wa.me/5351234567', 'otro país con +'),
      ('sin número', null, 'sin dígitos'),
      ('', null, 'vacío'),
    ];
    for (final (raw, expected, why) in cases) {
      test('$why: "$raw" → $expected', () {
        expect(whatsAppLink(raw)?.toString(), expected);
      });
    }
  });

  test('no importa Flutter ni Firebase (RNF-1)', () {
    final source = File('lib/features/booking/logic/whatsapp.dart')
        .readAsStringSync();
    expect(source, isNot(contains('package:flutter')));
    expect(source, isNot(contains('firebase')));
    expect(source, isNot(contains('cloud_firestore')));
  });
}
