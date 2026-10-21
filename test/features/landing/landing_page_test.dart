import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/features/landing/landing_content.dart';
import 'package:shaddai/features/landing/landing_section.dart';
import 'package:shaddai/features/landing/presentation/landing_page.dart';

import '../../helpers/pump_web_app.dart';

Finder _section(LandingSection section) => find.byWidgetPredicate(
  (widget) => widget is LandingSectionFrame && widget.section == section,
);

/// Un texto de cada sección, en español y en portugués (contenido de
/// referencia de shaddai-web).
const _sectionTexts = {
  LandingSection.hero: ('Más que uñas,', 'Mais que unhas,'),
  // La franja va en mayúsculas y repite las palabras para el bucle continuo.
  LandingSection.marquee: ('ESMALTADO EN GEL', 'ESMALTAÇÃO EM GEL'),
  LandingSection.prices: ('Lista de precios', 'Tabela de preços'),
  LandingSection.combos: ('Ventajas', 'Vantagens'),
  LandingSection.catalog: ('Material del estudio', 'Material do estúdio'),
  LandingSection.info: ('Información importante', 'Informação importante'),
  LandingSection.gallery: ('Mi trabajo', 'Meu trabalho'),
  LandingSection.about: ('Mi historia', 'Minha história'),
  LandingSection.contact: ('Hablemos', 'Vamos conversar'),
  LandingSection.footer: (
    'La belleza también es cuidarte ♡',
    'A beleza também é cuidar de você ♡',
  ),
};

void main() {
  testWidgets('la landing muestra las diez secciones en orden (RF-1)', (
    tester,
  ) async {
    await pumpWebApp(tester);

    double? previousTop;
    for (final section in LandingSection.values) {
      final finder = _section(section);
      expect(finder, findsOneWidget, reason: section.name);
      final top = tester.getTopLeft(finder).dy;
      if (previousTop != null) {
        expect(top, greaterThan(previousTop), reason: section.name);
      }
      previousTop = top;
    }
  });

  for (final (language, index) in [('es', 0), ('pt', 1)]) {
    testWidgets('cada sección tiene su texto en $language (RF-2, RNF-6)', (
      tester,
    ) async {
      await pumpWebApp(tester, stored: {'language': language});

      for (final MapEntry(key: section, value: texts)
          in _sectionTexts.entries) {
        final text = index == 0 ? texts.$1 : texts.$2;
        expect(
          find.descendant(of: _section(section), matching: find.text(text)),
          findsWidgets,
          reason: '${section.name}: $text',
        );
      }
    });

    testWidgets('la pestaña del navegador se titula con el texto de los .arb '
        '($language)', (tester) async {
      await pumpWebApp(tester, stored: {'language': language});

      expect(
        tester.widget<Title>(find.byType(Title)).title,
        'Studio Shaddai · Nail Designer',
      );
    });
  }

  testWidgets('las 19 imágenes de la landing están en los assets de la app', (
    tester,
  ) async {
    final images = [
      LandingContent.heroPhoto,
      ...LandingContent.catalogImages,
      ...LandingContent.galleryImages,
    ];
    expect(images, hasLength(19));
    expect(images.toSet(), hasLength(19), reason: 'sin repetidas');

    for (final image in images) {
      final bytes = await tester.runAsync(() => rootBundle.load(image));
      expect(bytes!.lengthInBytes, greaterThan(0), reason: image);
    }
  });
}
