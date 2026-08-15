import 'package:flutter/material.dart';

class ThemeColors {
  // Paleta de colores oficial de la web D'Shaddai
  static const Color bone = Color(0xFFF5F1E8);
  static const Color white = Color(0xFFFAFAF8);
  static const Color black = Color(0xFF1A1A1A);
  static const Color darkGreen = Color(0xFF2E3D28);
  static const Color gold = Color(0xFFC7A86D);
  static const Color olive = Color(0xFF7A8264);

  // Tema global de la aplicación
  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: bone,
      colorScheme: ColorScheme.fromSeed(
        seedColor: darkGreen,
        primary: darkGreen,
        secondary: gold,
        surface: white,
        onSurface: black,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: darkGreen,
        elevation: 0,
        centerTitle: true,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: darkGreen,
          foregroundColor: white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: darkGreen,
        selectedItemColor: gold,
        unselectedItemColor: bone,
      ),
    );
  }
}
