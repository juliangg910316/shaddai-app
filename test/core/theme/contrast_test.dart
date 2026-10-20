import 'package:flutter_test/flutter_test.dart';
import 'package:shaddai/core/theme/contrast.dart';

const _black = 0xFF000000;
const _white = 0xFFFFFFFF;

void main() {
  group('relativeLuminance', () {
    test('negro es 0 y blanco es 1', () {
      expect(relativeLuminance(_black), 0);
      expect(relativeLuminance(_white), closeTo(1, 1e-9));
    });
  });

  group('contrastRatio (WCAG 2.1)', () {
    test('negro sobre blanco es 21:1', () {
      expect(contrastRatio(_black, _white), closeTo(21, 0.01));
    });

    test('un color sobre sí mismo es 1:1', () {
      expect(contrastRatio(0xFF2E3D28, 0xFF2E3D28), closeTo(1, 1e-9));
    });

    test('no depende del orden texto/fondo con colores opacos', () {
      expect(
        contrastRatio(0xFF2E3D28, 0xFFF5F1E8),
        closeTo(contrastRatio(0xFFF5F1E8, 0xFF2E3D28), 1e-9),
      );
    });

    test('#767676 sobre blanco da 4,54:1 (valor de referencia WCAG)', () {
      expect(contrastRatio(0xFF767676, _white), closeTo(4.54, 0.01));
    });

    test('un texto semitransparente se mide ya compuesto sobre su fondo', () {
      const halfBlack = 0x80000000;
      expect(
        contrastRatio(halfBlack, _white),
        closeTo(contrastRatio(composite(halfBlack, _white), _white), 1e-9),
      );
    });
  });

  group('composite', () {
    test('un color opaco tapa el fondo', () {
      expect(composite(0xFF2E3D28, _white), 0xFF2E3D28);
    });

    test('negro al 50 % sobre blanco da gris medio opaco', () {
      // 0x80 es 128/255 = 50,2 %: 255 × (1 − 0,502) = 127 = 0x7F.
      expect(composite(0x80000000, _white), 0xFF7F7F7F);
    });

    test('un color transparente deja el fondo', () {
      expect(composite(0x00000000, 0xFFF5F1E8), 0xFFF5F1E8);
    });
  });

  group('isLargeText (RNF-1)', () {
    test('24 px o más es texto grande', () {
      expect(isLargeText(24), isTrue);
      expect(isLargeText(23.9), isFalse);
    });

    test('18,66 px o más en negrita es texto grande', () {
      expect(isLargeText(18.66, bold: true), isTrue);
      expect(isLargeText(18.65, bold: true), isFalse);
      expect(isLargeText(18.66), isFalse);
    });
  });

  group('prefersLightIcons (RF-23)', () {
    test('sobre fondos oscuros usa iconos claros', () {
      expect(prefersLightIcons(0xFF2E3D28), isTrue);
      expect(prefersLightIcons(0xFF17170F), isTrue);
    });

    test('sobre fondos claros usa iconos oscuros', () {
      expect(prefersLightIcons(0xFFF5F1E8), isFalse);
      expect(prefersLightIcons(_white), isFalse);
    });
  });
}
