import 'package:flutter/material.dart';

/// Spacing constants on an 8px grid. Every padding and gap in the app is a
/// multiple of [unit] so the interface stays visually consistent.
abstract final class AppSpacing {
  static const double unit = 8;
  static const double xs = 8; // 1 unit
  static const double sm = 16; // 2 units
  static const double md = 24; // 3 units
  static const double lg = 32; // 4 units
  static const double xl = 48; // 6 units
}

/// Desaturated government palette. Deliberately muted rather than saturated so
/// the interface reads as official rather than promotional.
abstract final class AppColors {
  static const Color primary = Color(0xFF3D4E6C); // desaturated municipal blue
  static const Color primaryDark = Color(0xFF2A3750);
  static const Color accent = Color(0xFF8A6D3B); // desaturated gold
  static const Color surface = Color(0xFFF7F8FA);
  static const Color background = Color(0xFFFFFFFF);
  static const Color textPrimary = Color(0xFF1F2430);
  static const Color textSecondary = Color(0xFF5A6272);
  static const Color line = Color(0xFFE2E5EB);
  static const Color success = Color(0xFF3E7C59);
  static const Color warning = Color(0xFF9A6B2F);
  static const Color danger = Color(0xFF8C3B3B);
}

/// The application theme. Material 3, with explicit styling for text fields,
/// filled buttons and outlined buttons so the three input/button styles are
/// consistent across every screen.
abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      surface: AppColors.background,
      error: AppColors.danger,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.surface,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
        bodyMedium: TextStyle(color: AppColors.textPrimary),
        bodySmall: TextStyle(color: AppColors.textSecondary),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.background,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: AppSpacing.sm,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.unit),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.unit),
          borderSide: const BorderSide(color: AppColors.line),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.unit),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        labelStyle: const TextStyle(color: AppColors.textSecondary),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.unit),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.unit),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.unit),
          ),
        ),
      ),
    );
  }
}
