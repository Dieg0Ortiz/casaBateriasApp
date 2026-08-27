import 'package:flutter/material.dart';

/// Sistema de diseño "Ultramarine Industrial" para Casa Baterías ERP.
/// Inspirado en el diseño Stitch con paleta de tonos ultramarine, índigo y cobalto,
/// alta densidad de datos, tipografía clara y componentes ergonómicos de 56px.
class AppTheme {
  AppTheme._();

  // Colores de la paleta "Ultramarine Industrial"
  static const primaryLight = Color(0xFF3E32D3); // Ultramarine Primario
  static const primaryContainerLight = Color(0xFF5850EC);
  static const onPrimaryLight = Colors.white;

  static const secondaryLight = Color(0xFF5654A8); // Iris / Violeta Profundo
  static const secondaryContainerLight = Color(0xFFE2DFFF);
  static const onSecondaryLight = Colors.white;

  static const tertiaryLight = Color(0xFF3C4C8C); // Azul Medianoche
  static const tertiaryContainerLight = Color(0xFF5564A6);
  static const onTertiaryLight = Colors.white;

  static const backgroundLight = Color(0xFFF7F9FB);
  static const surfaceLight = Color(0xFFF7F9FB);
  static const surfaceContainerLowLight = Color(0xFFF2F4F6);
  static const surfaceContainerLight = Color(0xFFECEEF0);
  static const surfaceContainerHighLight = Color(0xFFE6E8EA);
  static const surfaceContainerHighestLight = Color(0xFFE0E3E5);

  static const onBackgroundLight = Color(0xFF191C1E);
  static const onSurfaceLight = Color(0xFF191C1E);
  static const onSurfaceVariantLight = Color(0xFF464555);
  static const outlineVariantLight = Color(0xFFC7C4D8);
  static const outlineLight = Color(0xFF777587);

  // Acentos de estado
  static const cascoAmber = Color(0xFFEE9800); // Para cascos/chatarra
  static const cascoAmberContainer = Color(0xFFFFDDB8);
  static const successMint = Color(0xFF10B981);
  static const errorRed = Color(0xFFBA1A1A);

  // Dark Mode Tokens
  static const primaryDark = Color(0xFFC3C0FF);
  static const primaryContainerDark = Color(0xFF3E32D3);
  static const onPrimaryDark = Color(0xFF0F0069);

  static const secondaryDark = Color(0xFFD2BBFF);
  static const secondaryContainerDark = Color(0xFF3E3C8F);
  static const onSecondaryDark = Color(0xFF100563);

  static const backgroundDark = Color(0xFF0B1326);
  static const surfaceDark = Color(0xFF0B1326);
  static const surfaceContainerLowDark = Color(0xFF131B2E);
  static const surfaceContainerDark = Color(0xFF171F33);
  static const surfaceContainerHighDark = Color(0xFF222A3D);
  static const surfaceContainerHighestDark = Color(0xFF2D3449);

  static const onBackgroundDark = Color(0xFFDAE2FD);
  static const onSurfaceDark = Color(0xFFDAE2FD);
  static const onSurfaceVariantDark = Color(0xFFBBCABF);
  static const outlineVariantDark = Color(0xFF3C4A42);

  static ThemeData get light {
    final scheme = const ColorScheme.light(
      primary: primaryLight,
      primaryContainer: primaryContainerLight,
      onPrimary: onPrimaryLight,
      secondary: secondaryLight,
      secondaryContainer: secondaryContainerLight,
      onSecondary: onSecondaryLight,
      tertiary: tertiaryLight,
      tertiaryContainer: tertiaryContainerLight,
      onTertiary: onTertiaryLight,
      surface: surfaceLight,
      onSurface: onSurfaceLight,
      onSurfaceVariant: onSurfaceVariantLight,
      outline: outlineLight,
      outlineVariant: outlineVariantLight,
      error: errorRed,
      onError: Colors.white,
    );
    return _buildTheme(scheme, isDark: false);
  }

  static ThemeData get dark {
    final scheme = const ColorScheme.dark(
      primary: primaryDark,
      primaryContainer: primaryContainerDark,
      onPrimary: onPrimaryDark,
      secondary: secondaryDark,
      secondaryContainer: secondaryContainerDark,
      onSecondary: onSecondaryDark,
      surface: surfaceDark,
      onSurface: onSurfaceDark,
      onSurfaceVariant: onSurfaceVariantDark,
      outlineVariant: outlineVariantDark,
      error: errorRed,
      onError: Colors.white,
    );
    return _buildTheme(scheme, isDark: true);
  }

  static ThemeData _buildTheme(ColorScheme scheme, {required bool isDark}) {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: isDark ? backgroundDark : backgroundLight,
      fontFamily: 'sans-serif',
    );

    final textColor = scheme.onSurface;
    final cardBg = isDark ? surfaceContainerDark : surfaceContainerLowLight;
    final cardBorder = isDark ? const Color(0xFF2D3449) : outlineVariantLight;

    return base.copyWith(
      cardTheme: CardThemeData(
        color: cardBg,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: cardBorder, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: isDark ? backgroundDark : backgroundLight,
        foregroundColor: textColor,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: textColor,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: -0.01,
        ),
      ),
      textTheme: base.textTheme.copyWith(
        displayLarge: TextStyle(
          fontSize: 32,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: -0.02,
        ),
        titleLarge: TextStyle(
          fontSize: 22,
          fontWeight: FontWeight.bold,
          color: textColor,
          letterSpacing: -0.01,
        ),
        titleMedium: TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        titleSmall: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
        bodyLarge: TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w400,
          color: textColor,
        ),
        bodyMedium: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant,
        ),
        bodySmall: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w400,
          color: scheme.onSurfaceVariant,
        ),
        labelLarge: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.02,
        ),
        labelSmall: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.05,
          color: scheme.onSurfaceVariant,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          minimumSize: const Size(64, 56),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.02,
          ),
          elevation: 0,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: scheme.primary,
          minimumSize: const Size(64, 56),
          side: BorderSide(color: scheme.primary, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isDark ? surfaceContainerHighDark : surfaceContainerLight,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cardBorder),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: cardBorder),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        labelStyle: TextStyle(color: scheme.onSurfaceVariant),
        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.6)),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: isDark ? surfaceContainerHighestDark : surfaceContainerLight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        side: BorderSide(color: cardBorder),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    );
  }
}
