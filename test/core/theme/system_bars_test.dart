import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/brand_colors.dart';
import 'package:shaddai/core/theme/contrast.dart';
import 'package:shaddai/core/theme/system_bars.dart';

const _white = 0xFFFFFFFF;
const _black = 0xFF000000;

void main() {
  test('sobre un fondo claro, iconos oscuros (RF-23)', () {
    final style = systemBarsStyleFor(BrandColors.light.background);

    expect(style.statusBarIconBrightness, Brightness.dark);
    // En iOS se indica el brillo del fondo, no el de los iconos.
    expect(style.statusBarBrightness, Brightness.light);
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
  });

  test('sobre un fondo oscuro, iconos claros (RF-23)', () {
    final style = systemBarsStyleFor(BrandColors.dark.background);

    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.statusBarBrightness, Brightness.dark);
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
  });

  test('la barra de navegación del sistema toma el color del fondo', () {
    final background = BrandColors.dark.background;
    expect(systemBarsStyleFor(background).systemNavigationBarColor, background);
  });

  test('la barra de estado es transparente sobre el fondo de la app', () {
    expect(
      systemBarsStyleFor(BrandColors.light.background).statusBarColor,
      const Color(0x00000000),
    );
  });

  for (final background in [
    BrandColors.light.background,
    BrandColors.light.surface,
    BrandColors.dark.background,
    BrandColors.dark.surface,
    BrandColors.light.brand,
  ]) {
    test('los iconos elegidos tienen ≥ 3:1 sobre $background', () {
      final style = systemBarsStyleFor(background);
      final icons = style.statusBarIconBrightness == Brightness.light
          ? _white
          : _black;
      expect(
        contrastRatio(icons, background.toARGB32()),
        greaterThanOrEqualTo(3),
      );
    });
  }
}
