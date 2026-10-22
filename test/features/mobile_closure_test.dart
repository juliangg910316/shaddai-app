import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Carpetas de interfaz que toca la spec 003.
const _mobileUiDirectories = [
  'lib/features/home',
  'lib/features/services',
  'lib/features/navigation',
  'lib/features/booking/presentation',
  'lib/features/auth/presentation',
];

List<File> _dartFiles(List<String> directories) => [
  for (final dir in directories)
    for (final entity in Directory(dir).listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart')) entity,
];

/// Un literal de texto con alguna letra: texto de interfaz que debería estar
/// en los `.arb`. Los símbolos decorativos no cuentan.
final _uiLiteral = RegExp(
  r'''(?:Text\(|label:|tooltip:|semanticsLabel:|message:)\s*['"][^'"]*[A-Za-zÀ-ÿ][^'"]*['"]''',
);

/// Líneas de código (sin comentarios) que cumplen [pattern].
List<String> _matches(List<File> files, RegExp pattern) => [
  for (final file in files)
    for (final (i, line) in file.readAsLinesSync().indexed)
      if (!line.trimLeft().startsWith('//') && pattern.hasMatch(line))
        '${file.path}:${i + 1}',
];

void main() {
  test('Inicio, Servicios, Reservas y la barra no tienen textos de interfaz '
      'fuera de los .arb (criterio de finalización)', () {
    expect(_matches(_dartFiles(_mobileUiDirectories), _uiLiteral), isEmpty);
  });

  test('las secciones de la landing no dependen del ancho de la ventana '
      '(D-4)', () {
    expect(
      _matches(
        _dartFiles(['lib/features/landing/presentation/sections']),
        RegExp(r'WebShell\.isWide|MediaQuery\.sizeOf\(context\)\.width'),
      ),
      isEmpty,
    );
  });

  test('ya no queda la barra inferior antigua (RNF-1)', () {
    expect(
      _matches(_dartFiles(['lib']), RegExp(r'\bBottomNavigationBar')),
      isEmpty,
    );
  });

  test('la spec 003 no añade excepciones de color', () {
    final styleTest = File(
      'test/core/no_hardcoded_style_test.dart',
    ).readAsStringSync();
    final start = styleTest.indexOf('_colorExceptions = {');
    final exceptions = styleTest.substring(
      start,
      styleTest.indexOf('};', start),
    );

    for (final dir in [
      'lib/features/home',
      'lib/features/services',
      'lib/features/navigation',
    ]) {
      expect(exceptions, isNot(contains(dir)), reason: dir);
    }
  });
}
