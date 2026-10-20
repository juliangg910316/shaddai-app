/// Cálculo de contraste WCAG 2.1 sobre colores ARGB de 32 bits (RNF-1).
///
/// Dart puro, sin Flutter: los colores entran como enteros (`0xAARRGGBB`),
/// así que se puede usar con `Color.toARGB32()` o con constantes.
library;

import 'dart:math' as math;

int _channel(int argb, int shift) => (argb >> shift) & 0xFF;

double _linear(int channel) {
  final c = channel / 255;
  return c <= 0.03928
      ? c / 12.92
      : math.pow((c + 0.055) / 1.055, 2.4) as double;
}

/// Luminancia relativa de un color opaco (se ignora el canal alfa).
double relativeLuminance(int argb) {
  return 0.2126 * _linear(_channel(argb, 16)) +
      0.7152 * _linear(_channel(argb, 8)) +
      0.0722 * _linear(_channel(argb, 0));
}

/// Color opaco que resulta de pintar [fgArgb], con su alfa, sobre [bgArgb].
///
/// El fondo se trata como opaco.
int composite(int fgArgb, int bgArgb) {
  final alpha = _channel(fgArgb, 24) / 255;
  int mix(int shift) =>
      (_channel(fgArgb, shift) * alpha + _channel(bgArgb, shift) * (1 - alpha))
          .round();
  return 0xFF000000 | (mix(16) << 16) | (mix(8) << 8) | mix(0);
}

/// Contraste entre un texto o icono y su fondo opaco, de 1:1 a 21:1.
///
/// Si [fgArgb] es semitransparente, se compone antes sobre el fondo.
double contrastRatio(int fgArgb, int bgArgb) {
  final fg = relativeLuminance(composite(fgArgb, bgArgb));
  final bg = relativeLuminance(bgArgb);
  return (math.max(fg, bg) + 0.05) / (math.min(fg, bg) + 0.05);
}

/// Texto grande según WCAG: 24 px (18 pt) o más, o 18,66 px (14 pt) o más en
/// negrita. Le basta un contraste de 3:1.
bool isLargeText(double sizePx, {bool bold = false}) {
  return sizePx >= 24 || (bold && sizePx >= 18.66);
}

/// Si sobre [backgroundArgb] se leen mejor los iconos claros que los oscuros
/// (barras del sistema, RF-23).
bool prefersLightIcons(int backgroundArgb) {
  return contrastRatio(0xFFFFFFFF, backgroundArgb) >=
      contrastRatio(0xFF000000, backgroundArgb);
}
