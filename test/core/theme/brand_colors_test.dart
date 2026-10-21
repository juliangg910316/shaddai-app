import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/brand_colors.dart';

void main() {
  test('claro y oscuro tienen fondos distintos', () {
    expect(BrandColors.light.background, isNot(BrandColors.dark.background));
  });

  test('copyWith cambia solo el token indicado', () {
    const red = Color(0xFFFF0000);
    final copy = BrandColors.light.copyWith(danger: red);

    expect(copy.danger, red);
    expect(copy.background, BrandColors.light.background);
    expect(copy.ink, BrandColors.light.ink);
  });

  test('lerp va de claro a oscuro', () {
    final start = BrandColors.light.lerp(BrandColors.dark, 0);
    final end = BrandColors.light.lerp(BrandColors.dark, 1);

    expect(start.background, BrandColors.light.background);
    expect(end.background, BrandColors.dark.background);
  });

  test(
    'la superficie de marca cambia entre claro (crema) y oscuro (verde)',
    () {
      expect(BrandColors.light.brandSurface, const Color(0xFFEFE9DA));
      expect(BrandColors.dark.brandSurface, const Color(0xFF2E3D28));
    },
  );

  test('copyWith y lerp incluyen los tokens de la landing', () {
    const red = Color(0xFFFF0000);
    final copy = BrandColors.light.copyWith(
      brandSurface: red,
      onBrandSurface: red,
      onBrandSurfaceMuted: red,
      onBrandSurfaceAccent: red,
      brandSurfaceHairline: red,
    );
    expect([
      copy.brandSurface,
      copy.onBrandSurface,
      copy.onBrandSurfaceMuted,
      copy.onBrandSurfaceAccent,
      copy.brandSurfaceHairline,
    ], everyElement(red));

    final end = BrandColors.light.lerp(BrandColors.dark, 1);
    expect(end.brandSurface, BrandColors.dark.brandSurface);
    expect(end.onBrandSurface, BrandColors.dark.onBrandSurface);
    expect(end.onBrandSurfaceMuted, BrandColors.dark.onBrandSurfaceMuted);
    expect(end.onBrandSurfaceAccent, BrandColors.dark.onBrandSurfaceAccent);
    expect(end.brandSurfaceHairline, BrandColors.dark.brandSurfaceHairline);
  });

  test('lerp con otra extensión devuelve la misma instancia', () {
    expect(BrandColors.light.lerp(null, 0.5), same(BrandColors.light));
  });

  testWidgets('context.brand lee los tokens del tema activo', (tester) async {
    late BrandColors read;
    await tester.pumpWidget(
      Theme(
        data: ThemeData(extensions: const [BrandColors.dark]),
        child: Builder(
          builder: (context) {
            read = context.brand;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(read.background, BrandColors.dark.background);
  });
}
