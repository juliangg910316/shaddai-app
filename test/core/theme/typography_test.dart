import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/app_text.dart';
import 'package:shaddai/core/theme/app_theme.dart';
import 'package:shaddai/core/theme/brand_colors.dart';

const _serif = 'Cormorant Garamond';
const _sans = 'Inter';

void main() {
  for (final (name, theme, brand, brightness) in [
    ('claro', AppTheme.light, BrandColors.light, Brightness.light),
    ('oscuro', AppTheme.dark, BrandColors.dark, Brightness.dark),
  ]) {
    group('tema $name', () {
      test('tiene el brillo y los tokens de marca que le tocan', () {
        expect(theme.brightness, brightness);
        expect(theme.extension<BrandColors>(), brand);
      });

      test('los títulos usan Cormorant Garamond (RF-13)', () {
        final t = theme.textTheme;
        for (final style in [
          t.displayLarge,
          t.displayMedium,
          t.displaySmall,
          t.headlineLarge,
          t.headlineMedium,
          t.headlineSmall,
          t.titleLarge,
        ]) {
          expect(style?.fontFamily, _serif);
        }
      });

      test('el resto del texto usa Inter (RF-13)', () {
        final t = theme.textTheme;
        for (final style in [
          t.titleMedium,
          t.titleSmall,
          t.bodyLarge,
          t.bodyMedium,
          t.bodySmall,
          t.labelLarge,
          t.labelMedium,
          t.labelSmall,
        ]) {
          expect(style?.fontFamily, _sans);
        }
      });

      test('el texto toma los colores de tinta del tema', () {
        expect(theme.textTheme.bodyMedium?.color, brand.ink);
        expect(theme.textTheme.headlineSmall?.color, brand.inkStrong);
      });

      test('los componentes toman sus colores de BrandColors (RF-15)', () {
        expect(theme.scaffoldBackgroundColor, brand.background);
        expect(theme.colorScheme.surface, brand.surface);
        expect(theme.colorScheme.error, brand.danger);
        expect(theme.appBarTheme.backgroundColor, brand.surface);
        expect(theme.appBarTheme.foregroundColor, brand.inkStrong);
        expect(theme.cardTheme.color, brand.surface);
        expect(theme.dialogTheme.backgroundColor, brand.background);
        expect(theme.snackBarTheme.backgroundColor, brand.brand);
        expect(theme.inputDecorationTheme.fillColor, brand.surface);
        // Barra inferior de Android/iOS (spec 003).
        final bar = theme.navigationBarTheme;
        expect(bar.backgroundColor, brand.brand);
        expect(
          bar.iconTheme!.resolve({WidgetState.selected})!.color,
          brand.onBrand,
        );
        expect(bar.iconTheme!.resolve({})!.color, brand.onBrandMuted);
        expect(
          bar.labelTextStyle!.resolve({WidgetState.selected})!.color,
          brand.onBrand,
        );
        expect(bar.labelTextStyle!.resolve({})!.color, brand.onBrandMuted);
        expect(theme.progressIndicatorTheme.color, brand.inkStrong);

        final elevated = theme.elevatedButtonTheme.style!;
        expect(elevated.backgroundColor?.resolve({}), brand.brand);
        expect(elevated.foregroundColor?.resolve({}), brand.onBrand);

        final text = theme.textButtonTheme.style!;
        expect(text.foregroundColor?.resolve({}), brand.inkMuted);
      });

      test('la barra superior ajusta los iconos del sistema a su fondo', () {
        final style = theme.appBarTheme.systemOverlayStyle!;
        expect(
          style.statusBarIconBrightness,
          brightness == Brightness.dark ? Brightness.light : Brightness.dark,
        );
      });
    });
  }

  group('AppText', () {
    test('sin color no fija ninguno', () {
      expect(AppText.sans().color, isNull);
      expect(AppText.serif().color, isNull);
      expect(AppText.eyebrow().color, isNull);
    });

    test('serif es Cormorant y sans es Inter', () {
      expect(AppText.serif().fontFamily, _serif);
      expect(AppText.sans().fontFamily, _sans);
      expect(AppText.eyebrow().fontFamily, _sans);
    });

    test('respeta el color y el tamaño que se le pasan', () {
      const red = Color(0xFFFF0000);
      final style = AppText.sans(size: 18, color: red);
      expect(style.color, red);
      expect(style.fontSize, 18);
    });

    for (final (name, theme, brand) in [
      ('claro', AppTheme.light, BrandColors.light),
      ('oscuro', AppTheme.dark, BrandColors.dark),
    ]) {
      testWidgets('sin color hereda la tinta del tema $name', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Material(child: Text('Hola', style: AppText.sans())),
          ),
        );

        final rich = tester.widget<RichText>(find.byType(RichText));
        expect(rich.text.style?.color, brand.ink);
        expect(rich.text.style?.fontFamily, _sans);
      });
    }
  });
}
