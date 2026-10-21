import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/brand_colors.dart';
import 'package:shaddai/features/home/presentation/google_map_container.dart';
import 'package:shaddai/features/home/presentation/home_view.dart';

import '../../helpers/fake_session.dart';
import '../../helpers/pump_app.dart';

void main() {
  for (final (theme, brand) in [
    ('light', BrandColors.light),
    ('dark', BrandColors.dark),
  ]) {
    testWidgets('el texto sobre la foto del inicio va sobre el velo del tema '
        '($theme, RNF-1)', (tester) async {
      await pumpApp(
        tester,
        stored: {'theme': theme, 'language': 'es'},
        home: const HomeView(map: SizedBox(height: 120)),
        overrides: sessionOverrides(),
      );
      await tester.pump();

      final scrim = tester
          .widgetList<DecoratedBox>(find.byType(DecoratedBox))
          .map((box) => box.decoration)
          .whereType<BoxDecoration>()
          .map((decoration) => decoration.gradient)
          .whereType<LinearGradient>()
          .single;
      expect(scrim.colors, [brand.photoScrimStart, brand.photoScrimEnd]);

      final title = tester.widget<Text>(find.text('Shaddai\nNail Salon'));
      expect(title.style?.color, brand.onPhoto);
    });
  }

  test('por defecto, el inicio muestra el mapa de Google', () {
    expect(const HomeView().map, isA<GoogleMapContainer>());
  });
}
