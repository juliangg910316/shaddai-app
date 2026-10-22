import 'package:flutter/material.dart';

import 'app_text.dart';
import 'brand_colors.dart';
import 'system_bars.dart';

/// Temas claro y oscuro de la app (spec 001, RF-13 a RF-15).
///
/// Todos los colores salen de [BrandColors], que se registra como extensión
/// para que las vistas lo lean con `context.brand`.
class AppTheme {
  static final ThemeData light = _build(BrandColors.light, Brightness.light);
  static final ThemeData dark = _build(BrandColors.dark, Brightness.dark);

  static ThemeData _build(BrandColors b, Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final base = ThemeData(useMaterial3: true, brightness: brightness);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      scaffoldBackgroundColor: b.background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: b.brand,
        brightness: brightness,
        // En oscuro, el verde de marca casi no se ve sobre el fondo: el color
        // principal de los componentes pasa a ser el dorado.
        primary: isDark ? b.accent : b.brand,
        onPrimary: isDark ? b.background : b.onBrand,
        secondary: b.accent,
        surface: b.surface,
        onSurface: b.ink,
        onSurfaceVariant: b.inkMuted,
        outline: b.hairlineStrong,
        error: b.danger,
        onError: b.background,
      ),
      textTheme: _textTheme(base.textTheme, b),
      extensions: [b],
      appBarTheme: AppBarThemeData(
        backgroundColor: b.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: b.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: true,
        systemOverlayStyle: systemBarsStyleFor(b.surface),
        titleTextStyle: AppText.serif(
          size: 24,
          weight: FontWeight.w500,
          color: b.inkStrong,
        ),
      ),
      cardTheme: CardThemeData(
        color: b.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: b.hairline),
        ),
      ),
      dividerTheme: DividerThemeData(color: b.hairline, thickness: 1, space: 1),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: b.brand,
          foregroundColor: b.onBrand,
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
          foregroundColor: b.inkMuted,
          textStyle: AppText.sans(
            size: 12,
            weight: FontWeight.w500,
            spacing: 1.2,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: b.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 16,
        ),
        // Las pistas cuentan como texto normal para el contraste (RNF-1).
        labelStyle: AppText.sans(size: 14, color: b.inkMuted),
        hintStyle: AppText.sans(size: 15, color: b.inkMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: b.goldHairline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: b.goldHairline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: b.inkStrong, width: 1.4),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: b.brand,
        contentTextStyle: AppText.sans(size: 14, color: b.onBrand),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: b.background,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: BorderSide(color: b.goldHairline),
        ),
        titleTextStyle: AppText.serif(
          size: 24,
          weight: FontWeight.w500,
          color: b.inkStrong,
        ),
        contentTextStyle: AppText.sans(
          size: 14,
          color: b.inkMuted,
          height: 1.5,
        ),
      ),
      // Barra inferior de Android/iOS (spec 003): verde de marca, la pestaña
      // activa en dorado sobre un indicador y la inactiva en crema atenuada.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: b.brand,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: b.onBrand.withValues(alpha: 0.16),
        iconTheme: WidgetStateProperty.resolveWith(
          (states) => IconThemeData(
            size: 24,
            color: states.contains(WidgetState.selected)
                ? b.onBrand
                : b.onBrandMuted,
          ),
        ),
        labelTextStyle: WidgetStateProperty.resolveWith(
          (states) => AppText.sans(
            size: 12,
            weight: states.contains(WidgetState.selected)
                ? FontWeight.w600
                : FontWeight.w400,
            spacing: 0.4,
            color: states.contains(WidgetState.selected)
                ? b.onBrand
                : b.onBrandMuted,
          ),
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: b.inkStrong),
      // Selectores de Preferencias: la opción activa va rellena de verde y con
      // marca ✓, así no depende solo del color (RNF-4).
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: b.surface,
          foregroundColor: b.ink,
          selectedBackgroundColor: b.brand,
          selectedForegroundColor: b.onBrand,
          side: BorderSide(color: b.goldHairline),
          textStyle: AppText.sans(size: 13, weight: FontWeight.w500),
        ),
      ),
    );
  }

  /// Inter con los colores de tinta del tema, y Cormorant Garamond en los
  /// estilos de título (RF-13).
  static TextTheme _textTheme(TextTheme base, BrandColors b) {
    final sans = base.apply(
      fontFamily: AppFonts.sans,
      bodyColor: b.ink,
      displayColor: b.ink,
    );
    TextStyle? title(TextStyle? style) =>
        style?.copyWith(fontFamily: AppFonts.serif, color: b.inkStrong);

    return sans.copyWith(
      displayLarge: title(sans.displayLarge),
      displayMedium: title(sans.displayMedium),
      displaySmall: title(sans.displaySmall),
      headlineLarge: title(sans.headlineLarge),
      headlineMedium: title(sans.headlineMedium),
      headlineSmall: title(sans.headlineSmall),
      titleLarge: title(sans.titleLarge),
    );
  }
}
