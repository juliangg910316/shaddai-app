import 'package:flutter/material.dart';

/// Colores de la marca Studio Shaddai como tokens con versión clara y oscura
/// (spec 001, RF-14).
///
/// Las vistas los leen con `context.brand` en lugar de usar colores fijos, así
/// cambian con el tema. Los textos e iconos cumplen el contraste de RNF-1 (ver
/// `brand_colors_contrast_test`): donde el color de la web no llegaba, se usa
/// una variante del mismo tono.
@immutable
class BrandColors extends ThemeExtension<BrandColors> {
  const BrandColors({
    required this.background,
    required this.surface,
    required this.placeholder,
    required this.placeholderStrong,
    required this.ink,
    required this.inkStrong,
    required this.inkMuted,
    required this.accent,
    required this.accentIcon,
    required this.accentText,
    required this.sage,
    required this.brand,
    required this.onBrand,
    required this.onBrandMuted,
    required this.onPhoto,
    required this.photoScrimStart,
    required this.photoScrimEnd,
    required this.hairline,
    required this.hairlineStrong,
    required this.goldHairline,
    required this.goldHairlineSoft,
    required this.danger,
  });

  /// Fondo de pantalla.
  final Color background;

  /// Tarjetas, barras y campos.
  final Color surface;

  /// Fondos de foto mientras carga o si falta.
  final Color placeholder;
  final Color placeholderStrong;

  /// Texto principal.
  final Color ink;

  /// Títulos.
  final Color inkStrong;

  /// Texto secundario y pistas de los campos.
  final Color inkMuted;

  /// Dorado de marca, solo para adornos y líneas decorativas: no cumple el
  /// contraste de texto ni de icono en el tema claro.
  final Color accent;

  /// Dorado para iconos con significado (≥ 3:1).
  final Color accentIcon;

  /// Dorado para texto (≥ 4,5:1).
  final Color accentText;

  /// Salvia, acento secundario.
  final Color sage;

  /// Verde de marca: barra inferior, botón principal, cabecera de admin.
  final Color brand;

  /// Texto e iconos sobre [brand].
  final Color onBrand;

  /// Texto secundario sobre [brand] (pestañas sin seleccionar).
  final Color onBrandMuted;

  /// Texto sobre foto, siempre encima del velo.
  final Color onPhoto;

  /// Velo bajo el texto sobre foto, de arriba ([photoScrimStart]) a abajo.
  final Color photoScrimStart;
  final Color photoScrimEnd;

  /// Bordes finos de 1 px.
  final Color hairline;
  final Color hairlineStrong;
  final Color goldHairline;
  final Color goldHairlineSoft;

  /// Cancelados, acciones destructivas y errores.
  final Color danger;

  static const light = BrandColors(
    background: Color(0xFFF5F1E8),
    surface: Color(0xFFFAFAF8),
    placeholder: Color(0xFFEDE7D9),
    placeholderStrong: Color(0xFFE4DFD0),
    ink: Color(0xFF201F18),
    inkStrong: Color(0xFF2E3D28),
    inkMuted: Color(0xFF5F6650),
    accent: Color(0xFFC7A86D),
    accentIcon: Color(0xFF9A7B40),
    accentText: Color(0xFF856933),
    sage: Color(0xFFBFC8B3),
    brand: Color(0xFF2E3D28),
    onBrand: Color(0xFFC7A86D),
    onBrandMuted: Color(0x99F5F1E8),
    onPhoto: Color(0xFFF5F1E8),
    photoScrimStart: Color(0x59000000),
    photoScrimEnd: Color(0x8C000000),
    hairline: Color(0x1A2E3D28),
    hairlineStrong: Color(0x402E3D28),
    goldHairline: Color(0x80C7A86D),
    goldHairlineSoft: Color(0x59C7A86D),
    danger: Color(0xFF9C4A41),
  );

  static const dark = BrandColors(
    background: Color(0xFF17170F),
    surface: Color(0xFF202018),
    placeholder: Color(0xFF2A2A21),
    placeholderStrong: Color(0xFF33332A),
    ink: Color(0xFFF5F1E8),
    inkStrong: Color(0xFFF5F1E8),
    inkMuted: Color(0xFF9AA184),
    accent: Color(0xFFC7A86D),
    accentIcon: Color(0xFFC7A86D),
    accentText: Color(0xFFC7A86D),
    sage: Color(0xFFBFC8B3),
    brand: Color(0xFF2E3D28),
    onBrand: Color(0xFFC7A86D),
    onBrandMuted: Color(0x99F5F1E8),
    onPhoto: Color(0xFFF5F1E8),
    photoScrimStart: Color(0x59000000),
    photoScrimEnd: Color(0x8C000000),
    hairline: Color(0x1AF5F1E8),
    hairlineStrong: Color(0x40F5F1E8),
    goldHairline: Color(0x80C7A86D),
    goldHairlineSoft: Color(0x59C7A86D),
    danger: Color(0xFFD98A80),
  );

  @override
  BrandColors copyWith({
    Color? background,
    Color? surface,
    Color? placeholder,
    Color? placeholderStrong,
    Color? ink,
    Color? inkStrong,
    Color? inkMuted,
    Color? accent,
    Color? accentIcon,
    Color? accentText,
    Color? sage,
    Color? brand,
    Color? onBrand,
    Color? onBrandMuted,
    Color? onPhoto,
    Color? photoScrimStart,
    Color? photoScrimEnd,
    Color? hairline,
    Color? hairlineStrong,
    Color? goldHairline,
    Color? goldHairlineSoft,
    Color? danger,
  }) {
    return BrandColors(
      background: background ?? this.background,
      surface: surface ?? this.surface,
      placeholder: placeholder ?? this.placeholder,
      placeholderStrong: placeholderStrong ?? this.placeholderStrong,
      ink: ink ?? this.ink,
      inkStrong: inkStrong ?? this.inkStrong,
      inkMuted: inkMuted ?? this.inkMuted,
      accent: accent ?? this.accent,
      accentIcon: accentIcon ?? this.accentIcon,
      accentText: accentText ?? this.accentText,
      sage: sage ?? this.sage,
      brand: brand ?? this.brand,
      onBrand: onBrand ?? this.onBrand,
      onBrandMuted: onBrandMuted ?? this.onBrandMuted,
      onPhoto: onPhoto ?? this.onPhoto,
      photoScrimStart: photoScrimStart ?? this.photoScrimStart,
      photoScrimEnd: photoScrimEnd ?? this.photoScrimEnd,
      hairline: hairline ?? this.hairline,
      hairlineStrong: hairlineStrong ?? this.hairlineStrong,
      goldHairline: goldHairline ?? this.goldHairline,
      goldHairlineSoft: goldHairlineSoft ?? this.goldHairlineSoft,
      danger: danger ?? this.danger,
    );
  }

  @override
  BrandColors lerp(covariant ThemeExtension<BrandColors>? other, double t) {
    if (other is! BrandColors) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return BrandColors(
      background: mix(background, other.background),
      surface: mix(surface, other.surface),
      placeholder: mix(placeholder, other.placeholder),
      placeholderStrong: mix(placeholderStrong, other.placeholderStrong),
      ink: mix(ink, other.ink),
      inkStrong: mix(inkStrong, other.inkStrong),
      inkMuted: mix(inkMuted, other.inkMuted),
      accent: mix(accent, other.accent),
      accentIcon: mix(accentIcon, other.accentIcon),
      accentText: mix(accentText, other.accentText),
      sage: mix(sage, other.sage),
      brand: mix(brand, other.brand),
      onBrand: mix(onBrand, other.onBrand),
      onBrandMuted: mix(onBrandMuted, other.onBrandMuted),
      onPhoto: mix(onPhoto, other.onPhoto),
      photoScrimStart: mix(photoScrimStart, other.photoScrimStart),
      photoScrimEnd: mix(photoScrimEnd, other.photoScrimEnd),
      hairline: mix(hairline, other.hairline),
      hairlineStrong: mix(hairlineStrong, other.hairlineStrong),
      goldHairline: mix(goldHairline, other.goldHairline),
      goldHairlineSoft: mix(goldHairlineSoft, other.goldHairlineSoft),
      danger: mix(danger, other.danger),
    );
  }
}

/// Acceso corto a los tokens del tema activo: `context.brand.ink`.
extension BrandColorsContext on BuildContext {
  BrandColors get brand => Theme.of(this).extension<BrandColors>()!;
}
