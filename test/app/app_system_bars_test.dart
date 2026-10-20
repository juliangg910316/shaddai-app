import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/brand_colors.dart';
import 'package:shaddai/core/theme/contrast.dart';

import '../helpers/pump_app.dart';

/// Estilo de barras del sistema que la app pone en su raíz (el
/// `AnnotatedRegion` más alto del árbol).
SystemUiOverlayStyle _rootStyle(WidgetTester tester) {
  return tester
      .widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
        find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
      )
      .first
      .value;
}

void main() {
  for (final (theme, background, icons) in [
    ('light', BrandColors.light.background, Brightness.dark),
    ('dark', BrandColors.dark.background, Brightness.light),
  ]) {
    testWidgets('con tema $theme, iconos del sistema legibles (RF-23)', (
      tester,
    ) async {
      await pumpApp(tester, stored: {'theme': theme});

      final style = _rootStyle(tester);
      expect(style.statusBarIconBrightness, icons);
      expect(style.systemNavigationBarIconBrightness, icons);
      expect(style.systemNavigationBarColor, background);

      final iconColor = icons == Brightness.light ? 0xFFFFFFFF : 0xFF000000;
      expect(
        contrastRatio(iconColor, background.toARGB32()),
        greaterThanOrEqualTo(3),
      );
    });
  }
}
