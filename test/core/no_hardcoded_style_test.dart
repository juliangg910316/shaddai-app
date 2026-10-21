import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Carpetas de interfaz que deben usar solo los tokens del tema (RF-15).
const _uiDirectories = ['lib/features', 'lib/core/widgets'];

/// *Excepciones de color* de la spec (D-12): elementos que mantienen los
/// colores de su marca y no siguen el tema.
const _colorExceptions = {
  // Botón de Google: colores de la guía de marca de Google.
  'lib/features/auth/presentation/widgets/google_brand_button.dart',
};

/// Usos de color o fuente fuera del tema.
final _forbidden = <String, RegExp>{
  'ThemeColors': RegExp(r'\bThemeColors\.'),
  'theme_colors.dart': RegExp(r'constants/theme_colors\.dart'),
  'Color(0x…)': RegExp(r'\bColor\(0x'),
  'Colors.* (salvo transparent)': RegExp(r'\bColors\.(?!transparent\b)'),
  'fontFamily': RegExp(r'\bfontFamily:'),
};

List<String> _dartFiles() {
  return [
    for (final dir in _uiDirectories)
      for (final entity in Directory(dir).listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart')) entity.path,
  ]..sort();
}

void main() {
  test('hay archivos de interfaz que revisar', () {
    expect(_dartFiles(), isNotEmpty);
  });

  for (final path in _dartFiles()) {
    if (_colorExceptions.contains(path)) continue;

    test('$path no usa colores ni fuentes fuera del tema (RF-15)', () {
      final lines = File(path).readAsLinesSync();
      final problems = <String>[];

      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].trimLeft();
        if (code.startsWith('//')) continue;
        for (final MapEntry(key: name, value: pattern) in _forbidden.entries) {
          if (pattern.hasMatch(code)) problems.add('línea ${i + 1}: $name');
        }
      }

      expect(problems, isEmpty);
    });
  }

  test('las excepciones de color existen (no son rutas obsoletas)', () {
    for (final path in _colorExceptions) {
      expect(File(path).existsSync(), isTrue, reason: path);
    }
  });
}
