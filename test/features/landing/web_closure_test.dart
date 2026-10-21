import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Carpetas de interfaz de la spec 002.
const _webUiDirectories = ['lib/features/landing', 'lib/features/navigation'];

List<File> _dartFiles(List<String> directories) => [
  for (final dir in directories)
    for (final entity in Directory(dir).listSync(recursive: true))
      if (entity is File && entity.path.endsWith('.dart')) entity,
];

/// Un literal de texto con alguna letra: texto de interfaz que debería estar
/// en los `.arb`. Los símbolos decorativos ("+", "✦") no cuentan.
final _uiLiteral = RegExp(
  r'''(?:Text\(|label:|tooltip:|semanticsLabel:|message:)\s*['"][^'"]*[A-Za-zÀ-ÿ][^'"]*['"]''',
);

void main() {
  test('la landing y la barra no tienen textos de interfaz fuera de los .arb '
      '(criterio de finalización, RNF-6)', () {
    final problems = <String>[];
    for (final file in _dartFiles(_webUiDirectories)) {
      final lines = file.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final code = lines[i].trimLeft();
        if (code.startsWith('//')) continue;
        if (_uiLiteral.hasMatch(code)) problems.add('${file.path}:${i + 1}');
      }
    }

    expect(problems, isEmpty);
  });

  test('la spec 002 no añade excepciones de color', () {
    final styleTest = File(
      'test/core/no_hardcoded_style_test.dart',
    ).readAsStringSync();
    final exceptions = styleTest.substring(
      styleTest.indexOf('_colorExceptions = {'),
      styleTest.indexOf('};', styleTest.indexOf('_colorExceptions = {')),
    );

    for (final dir in _webUiDirectories) {
      expect(exceptions, isNot(contains(dir)), reason: dir);
    }
  });

  test('la pestaña del navegador se titula Studio Shaddai también mientras '
      'carga la app (antes de que Flutter ponga el de los .arb)', () {
    final html = File('web/index.html').readAsStringSync();

    expect(html, contains('<title>Studio Shaddai · Nail Designer</title>'));
    expect(html, isNot(contains('<title>Shaddai</title>')));
    expect(
      html,
      contains(
        '<meta name="description" '
        'content="Studio Shaddai · Nail Designer · Beidis Viera">',
      ),
    );
  });
}
