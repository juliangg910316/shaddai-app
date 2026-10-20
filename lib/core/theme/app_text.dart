import 'package:flutter/material.dart';

/// Familias tipográficas de la marca (RF-13).
/// Cormorant Garamond para títulos (serif editorial), Inter para toda la UI.
class AppFonts {
  static const String serif = 'Cormorant Garamond';
  static const String sans = 'Inter';
}

/// Constructores de estilo tipográfico del diseño.
///
/// [AppText.serif] = Cormorant Garamond (títulos, precios, horas).
/// [AppText.sans]  = Inter (todo el resto de la interfaz).
///
/// Sin `color`, el estilo no fija ninguno y hereda el del tema activo, así el
/// texto se adapta al tema claro y al oscuro.
class AppText {
  static TextStyle serif({
    double size = 20,
    FontWeight weight = FontWeight.w500,
    Color? color,
    double? height,
    double? spacing,
  }) {
    return TextStyle(
      fontFamily: AppFonts.serif,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: spacing,
    );
  }

  static TextStyle sans({
    double size = 14,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? spacing,
    TextDecoration? decoration,
  }) {
    return TextStyle(
      fontFamily: AppFonts.sans,
      fontSize: size,
      fontWeight: weight,
      color: color,
      height: height,
      letterSpacing: spacing,
      decoration: decoration,
      decorationColor: color,
    );
  }

  /// Etiqueta pequeña en versalitas ("TU WHATSAPP", "CONFIRMADA", "1 · SERVICIO").
  static TextStyle eyebrow({
    double size = 10,
    Color? color,
    double spacing = 2,
    FontWeight weight = FontWeight.w400,
  }) {
    return sans(size: size, weight: weight, color: color, spacing: spacing);
  }
}
