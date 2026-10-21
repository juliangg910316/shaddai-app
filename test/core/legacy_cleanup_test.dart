import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Cierre de la spec 001 (T14): lo que sustituyó el design system ya no está.
void main() {
  test('ya no existen los colores ni las fechas fijas antiguas', () {
    expect(File('lib/core/constants/theme_colors.dart').existsSync(), isFalse);
    expect(File('lib/core/constants/spanish_dates.dart').existsSync(), isFalse);
  });

  test('Jost ya no está en los assets ni en pubspec.yaml (RF-13)', () {
    expect(File('assets/fonts/Jost-Variable.ttf').existsSync(), isFalse);
    expect(File('assets/fonts/OFL-Jost.txt').existsSync(), isFalse);
    expect(File('pubspec.yaml').readAsStringSync(), isNot(contains('Jost')));
  });

  test('las fuentes de la marca siguen incluidas en la app (RNF-5)', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final asset in [
      'assets/fonts/CormorantGaramond-Variable.ttf',
      'assets/fonts/Inter-Variable.ttf',
    ]) {
      expect(File(asset).existsSync(), isTrue, reason: asset);
      expect(pubspec, contains(asset));
    }
    expect(File('assets/fonts/OFL-CormorantGaramond.txt').existsSync(), isTrue);
    expect(File('assets/fonts/OFL-Inter.txt').existsSync(), isTrue);
  });
}
