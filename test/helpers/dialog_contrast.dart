import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/contrast.dart';

/// Contraste de cada texto del diálogo abierto, salvo los botones, sobre
/// su fondo (WCAG AA:
/// 4,5:1, o 3:1 para texto grande). `textContrastGuideline` no mide las
/// filas de la tabla de antes y después: cada una es un solo nodo de
/// semántica con su frase para el lector de pantalla.
void expectDialogTextContrast(WidgetTester tester) {
  final dialog = find.byType(AlertDialog);
  expectTextContrast(
    tester,
    dialog,
    Theme.of(tester.element(dialog)).dialogTheme.backgroundColor!,
  );
}

/// Contraste de cada texto dentro de [area], salvo los botones y lo que
/// está dentro de [skip], sobre [background] (WCAG AA: 4,5:1, o 3:1 para
/// texto grande). Mide los colores exactos, no los píxeles: sirve para una
/// parte de la pantalla cuando el resto no se quiere medir.
void expectTextContrast(
  WidgetTester tester,
  Finder area,
  Color background, {
  List<Finder> skip = const [],
}) {
  final dialog = area;
  // Los botones van sobre su propio fondo: los mide la guía.
  final texts = find.descendant(of: dialog, matching: find.byType(RichText));
  final inButtons = find.descendant(
    of: find.descendant(
      of: dialog,
      matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
    ),
    matching: find.byType(RichText),
  );
  final skipped = {
    ...inButtons.evaluate(),
    for (final finder in skip)
      ...find
          .descendant(
            of: find.descendant(of: area, matching: finder),
            matching: find.byType(RichText),
          )
          .evaluate(),
  };
  final paragraphs = [
    for (final element in texts.evaluate())
      if (!skipped.contains(element)) element.renderObject! as RenderParagraph,
  ];
  expect(paragraphs, isNotEmpty);
  for (final paragraph in paragraphs) {
    void check(InlineSpan span, TextStyle inherited) {
      final style = inherited.merge(span.style);
      if (span is TextSpan) {
        final text = span.text ?? '';
        if (text.trim().isNotEmpty) {
          final bold = (style.fontWeight?.value ?? 400) >= 700;
          final minimum = isLargeText(style.fontSize ?? 14, bold: bold)
              ? 3.0
              : 4.5;
          expect(
            contrastRatio(style.color!.toARGB32(), background.toARGB32()),
            greaterThanOrEqualTo(minimum),
            reason: text,
          );
        }
        for (final child in span.children ?? const <InlineSpan>[]) {
          check(child, style);
        }
      }
    }

    check(paragraph.text, const TextStyle());
  }
}
