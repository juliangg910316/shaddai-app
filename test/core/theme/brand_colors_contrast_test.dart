import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/brand_colors.dart';
import 'package:shaddai/core/theme/contrast.dart';

/// Mínimos de RNF-1 (WCAG 2.1 AA).
const _normalText = 4.5;
const _iconOrLargeText = 3.0;

double _ratio(Color fg, Color bg) =>
    contrastRatio(fg.toARGB32(), bg.toARGB32());

void main() {
  for (final (name, brand) in [
    ('claro', BrandColors.light),
    ('oscuro', BrandColors.dark),
  ]) {
    group('tema $name', () {
      final textTokens = {
        'ink': brand.ink,
        'inkStrong': brand.inkStrong,
        // También cubre las pistas y textos de ejemplo de los campos.
        'inkMuted': brand.inkMuted,
        'accentText': brand.accentText,
        'danger': brand.danger,
      };
      final backgrounds = {
        'background': brand.background,
        'surface': brand.surface,
      };

      for (final text in textTokens.entries) {
        for (final bg in backgrounds.entries) {
          test('${text.key} sobre ${bg.key} ≥ 4,5:1', () {
            expect(
              _ratio(text.value, bg.value),
              greaterThanOrEqualTo(_normalText),
            );
          });
        }
      }

      for (final bg in backgrounds.entries) {
        test('accentIcon sobre ${bg.key} ≥ 3:1', () {
          expect(
            _ratio(brand.accentIcon, bg.value),
            greaterThanOrEqualTo(_iconOrLargeText),
          );
        });
      }

      test('onBrand sobre brand ≥ 4,5:1', () {
        expect(
          _ratio(brand.onBrand, brand.brand),
          greaterThanOrEqualTo(_normalText),
        );
      });

      test('onBrandMuted sobre brand ≥ 4,5:1', () {
        expect(
          _ratio(brand.onBrandMuted, brand.brand),
          greaterThanOrEqualTo(_normalText),
        );
      });

      test('texto claro sobre el velo de foto, en el peor caso ≥ 4,5:1', () {
        // Peor caso: foto blanca al 50 % sobre el verde de marca, con la parte
        // más transparente del velo encima.
        final photo = composite(0x80FFFFFF, brand.brand.toARGB32());
        final behindText = composite(brand.photoScrimStart.toARGB32(), photo);

        for (final text in [brand.onPhoto, const Color(0xFFFFFFFF)]) {
          expect(
            contrastRatio(text.toARGB32(), behindText),
            greaterThanOrEqualTo(_normalText),
          );
        }
      });

      test('el velo se oscurece hacia abajo', () {
        expect(brand.photoScrimEnd.a, greaterThan(brand.photoScrimStart.a));
      });
    });
  }
}
