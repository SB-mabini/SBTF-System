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

/// Quiet Civic government palette — Sangguniang Bayan ng Mabini identity.
///
/// Deep purple = authority, gold = official seal, neutrals dominate.
/// Palette share ≈ 83% neutral / 12% purple / 5% red+gold.
/// Color is semantic only: never decorative.
abstract final class AppColors {
  // --- Core brand ---
  static const Color primary = Color(0xFF271564);
  static const Color primaryDark = Color(0xFF1E1050);
  static const Color primarySoft = Color(0xFF3D2D72);
  static const Color primaryTint = Color(0xFFF2F0F8);
  static const Color primaryTintStrong = Color(0xFFE3DFF0);

  // --- Gold accent (seal / pending) ---
  static const Color accent = Color(0xFFF2C749);
  static const Color accentTint = Color(0xFFFEF9E9);
  static const Color accentTintStrong = Color(0xFFFDF1CD);

  // --- Surfaces ---
  static const Color surface = Color(0xFFFFFFFF);
  static const Color background = Color(0xFFF7F7F8);
  static const Color border = Color(0xFFE5E7EB);
  static const Color greyFill = Color(0xFFF3F4F6);

  // --- Ink ---
  static const Color inkStrong = Color(0xFF161213);
  static const Color inkMuted = Color(0xFF6B7280);

  // --- Semantic (always paired with icon + label) ---
  static const Color success = Color(0xFF0F7A4A);
  static const Color successTint = Color(0xFFECFDF3);
  static const Color warning = Color(0xFFA67C17);
  static const Color danger = Color(0xFFB31F16);
  static const Color dangerTint = Color(0xFFFDF2F1);
  static const Color dangerFill = Color(0xFFD4271D);

  // --- Legacy aliases (keep names stable, map to new values) ---
  static const Color textPrimary = inkStrong;
  static const Color textSecondary = inkMuted;
  static const Color line = border;
}

/// The application theme. Material 3, with explicit component themes so that
/// every button, input, card, chip, dialog, sheet and snackbar draws from the
/// single token set above — no per-widget overrides needed in screen code.
abstract final class AppTheme {
  static ThemeData get light {
    final colorScheme = ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.accent,
      onSecondary: AppColors.inkStrong,
      surface: AppColors.surface,
      onSurface: AppColors.inkStrong,
      onSurfaceVariant: AppColors.inkMuted,
      error: AppColors.danger,
      onError: Colors.white,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      surfaceTint: Colors.transparent,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,

      // --- AppBar: white bar, bottom border, left-aligned title ---
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: AppColors.inkStrong,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        shape: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
        iconTheme: IconThemeData(color: AppColors.inkStrong, size: 24),
      ),

      // --- Typography ---
      textTheme: const TextTheme(
        titleLarge: TextStyle(
          color: AppColors.inkStrong,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: AppColors.inkStrong,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        bodyLarge: TextStyle(
          color: AppColors.inkStrong,
          fontSize: 16,
          height: 1.5,
        ),
        bodyMedium: TextStyle(
          color: AppColors.inkStrong,
          fontSize: 14,
          height: 1.5,
        ),
        bodySmall: TextStyle(
          color: AppColors.inkMuted,
          fontSize: 13,
          height: 1.4,
        ),
        labelSmall: TextStyle(
          color: AppColors.inkMuted,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
      ),

      // --- Text inputs: white fill, border, 48dp min ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.unit),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.unit),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.unit),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.unit),
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.unit),
          borderSide: const BorderSide(color: AppColors.danger, width: 1.5),
        ),
        labelStyle: const TextStyle(
          color: AppColors.inkMuted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: AppColors.inkMuted,
          fontSize: 12,
        ),
        errorStyle: const TextStyle(
          color: AppColors.danger,
          fontSize: 12,
        ),
        constraints: const BoxConstraints(minHeight: 48),
      ),

      // --- Primary button: full-width style, 48dp, 8dp radius ---
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withAlpha(115),
          disabledForegroundColor: Colors.white.withAlpha(200),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.unit),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // --- Secondary button: border hairline, inkStrong label ---
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.inkStrong,
          side: const BorderSide(color: AppColors.border),
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.unit),
          ),
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // --- Elevated button: same as filled for consistency ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 14,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppSpacing.unit),
          ),
          elevation: 0,
        ),
      ),

      // --- Text button ---
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
          minimumSize: const Size(48, 48),
        ),
      ),

      // --- Card: white, 1px border, 10dp radius, elevation 0 ---
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: AppColors.border),
        ),
      ),

      // --- Chip: pill-shaped ---
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.greyFill,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        labelStyle: const TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // --- Dialog ---
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        titleTextStyle: const TextStyle(
          color: AppColors.inkStrong,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: AppColors.inkMuted,
          fontSize: 14,
          height: 1.5,
        ),
      ),

      // --- Bottom sheet ---
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        elevation: 1,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
        ),
        dragHandleColor: AppColors.border,
        showDragHandle: true,
      ),

      // --- Snack bar ---
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inkStrong,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
        ),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.unit),
        ),
      ),

      // --- Divider ---
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
        space: 1,
      ),

      // --- Progress indicator ---
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.primary,
      ),
    );
  }
}
