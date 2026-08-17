import 'package:flutter/material.dart';

/// Familias tipográficas del diseño.
/// Cormorant Garamond para títulos (serif editorial), Jost para toda la UI.
class AppFonts {
  static const String serif = 'Cormorant Garamond';
  static const String sans = 'Jost';
}

class ThemeColors {
  // Paleta de colores oficial de la web D'Shaddai
  static const Color bone = Color(0xFFF5F1E8);
  static const Color white = Color(0xFFFAFAF8);
  static const Color black = Color(0xFF1A1A1A);
  static const Color darkGreen = Color(0xFF2E3D28);
  static const Color gold = Color(0xFFC7A86D);
  static const Color olive = Color(0xFF7A8264);

  /// Rojo apagado del diseño, para estados cancelados / acciones destructivas.
  static const Color danger = Color(0xFF9C4A41);

  /// Arena: fondo de los placeholders de foto.
  static const Color sand = Color(0xFFEDE7D9);
  static const Color sandDark = Color(0xFFE4DFD0);

  // Bordes finos: el diseño usa líneas de 1px en vez de sombras Material.
  static Color get hairline => darkGreen.withValues(alpha: 0.10);
  static Color get hairlineStrong => darkGreen.withValues(alpha: 0.25);
  static Color get goldHairline => gold.withValues(alpha: 0.50);
  static Color get goldHairlineSoft => gold.withValues(alpha: 0.35);

  // Tema global de la aplicación
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      fontFamily: AppFonts.sans,
      scaffoldBackgroundColor: bone,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkGreen,
        primary: darkGreen,
        secondary: gold,
        surface: white,
        onSurface: black,
        error: danger,
      ),
      textTheme: const TextTheme(
        displayLarge: TextStyle(fontFamily: AppFonts.serif),
        displayMedium: TextStyle(fontFamily: AppFonts.serif),
        displaySmall: TextStyle(fontFamily: AppFonts.serif),
        headlineLarge: TextStyle(fontFamily: AppFonts.serif),
        headlineMedium: TextStyle(fontFamily: AppFonts.serif),
        headlineSmall: TextStyle(fontFamily: AppFonts.serif),
        titleLarge: TextStyle(fontFamily: AppFonts.serif),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: white,
        surfaceTintColor: Colors.transparent,
        foregroundColor: darkGreen,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        titleTextStyle: AppText.serif(
          size: 24,
          weight: FontWeight.w500,
          color: darkGreen,
        ),
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: darkGreen.withValues(alpha: 0.10)),
        ),
      ),
      dividerTheme: DividerThemeData(
        color: darkGreen.withValues(alpha: 0.10),
        thickness: 1,
        space: 1,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkGreen,
          foregroundColor: gold,
          elevation: 0,
          padding: const EdgeInsets.symmetric(vertical: 15, horizontal: 24),
          textStyle: AppText.sans(
            size: 12,
            weight: FontWeight.w600,
            spacing: 2,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: olive,
          textStyle: AppText.sans(
            size: 12,
            weight: FontWeight.w500,
            spacing: 1.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        labelStyle: AppText.sans(size: 14, color: olive),
        hintStyle: AppText.sans(size: 15, color: olive.withValues(alpha: 0.6)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.55)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: gold.withValues(alpha: 0.55)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: darkGreen, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: darkGreen,
        contentTextStyle: AppText.sans(size: 14, color: bone),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: bone,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: gold.withValues(alpha: 0.5)),
        ),
        titleTextStyle: AppText.serif(
          size: 24,
          weight: FontWeight.w500,
          color: darkGreen,
        ),
        contentTextStyle: AppText.sans(size: 14, color: olive, height: 1.5),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: darkGreen,
        selectedItemColor: gold,
        unselectedItemColor: bone.withValues(alpha: 0.6),
        selectedLabelStyle: AppText.sans(
          size: 10,
          weight: FontWeight.w500,
          spacing: 0.6,
        ),
        unselectedLabelStyle: AppText.sans(size: 10),
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: darkGreen,
      ),
    );
  }
}

/// Constructores de estilo tipográfico del diseño.
///
/// [AppText.serif] = Cormorant Garamond (títulos, precios, horas).
/// [AppText.sans]  = Jost (todo el resto de la interfaz).
class AppText {
  static TextStyle serif({
    double size = 20,
    FontWeight weight = FontWeight.w500,
    Color color = ThemeColors.black,
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
    Color color = ThemeColors.black,
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
    Color color = ThemeColors.olive,
    double spacing = 2,
    FontWeight weight = FontWeight.w400,
  }) {
    return sans(size: size, weight: weight, color: color, spacing: spacing);
  }
}
