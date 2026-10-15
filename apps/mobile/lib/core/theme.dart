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

/// Corner radii, in one place so every surface rounds consistently.
///
/// The [card]/[input]/[banner]/[hero] helpers return ready-made
/// [BorderRadius] values so a call site never spells out a number.
abstract final class AppRadius {
  static const double sm = 12;
  static const double md = 16;
  static const double lg = 20;
  static const double xl = 28;
  static const double pill = 999;

  static const BorderRadius card = BorderRadius.all(Radius.circular(md));
  static const BorderRadius input = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius banner = BorderRadius.all(Radius.circular(sm));

  /// A generic rounded box for small inner panels and tinted wells.
  static const BorderRadius box = BorderRadius.all(Radius.circular(sm));
  static const BorderRadius chip = BorderRadius.all(Radius.circular(pill));
  static const BorderRadius hero = BorderRadius.all(Radius.circular(lg));
  static const BorderRadius sheet =
      BorderRadius.vertical(top: Radius.circular(xl));
}

/// Soft, low-contrast elevation. Government software should read as calm and
/// trustworthy, so depth comes from a wide, faint shadow plus a hairline border
/// rather than a hard drop shadow.
abstract final class AppShadows {
  /// The resting shadow for a card or tile.
  static const List<BoxShadow> card = [
    BoxShadow(
      color: Color(0x0F0B1220),
      blurRadius: 16,
      offset: Offset(0, 4),
    ),
    BoxShadow(
      color: Color(0x0A0B1220),
      blurRadius: 2,
      offset: Offset(0, 1),
    ),
  ];

  /// A stronger shadow for elevated surfaces (dialogs, sheets, heroes).
  static const List<BoxShadow> raised = [
    BoxShadow(
      color: Color(0x1A0B1220),
      blurRadius: 28,
      offset: Offset(0, 10),
    ),
  ];
}

/// Brand gradients, kept together so the identity is applied identically.
abstract final class AppGradients {
  /// The deep-purple authority gradient used on the home hero and headers.
  static const LinearGradient hero = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF33207A), Color(0xFF1B0F4E)],
  );

  /// The gold "seal" gradient for accents.
  static const LinearGradient gold = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF7D274), Color(0xFFE3A81C)],
  );
}

/// Quiet Civic government palette — Sangguniang Bayan ng Mabini identity.
///
/// Deep purple = authority, gold = official seal, neutrals dominate.
/// Palette share ≈ 83% neutral / 12% purple / 5% red+gold.
/// Colour is semantic only: never decorative.
abstract final class AppColors {
  // --- Core brand ---
  static const Color primary = Color(0xFF271564);
  static const Color primaryDark = Color(0xFF1B0F4E);
  static const Color primaryBright = Color(0xFF4A38A0);
  static const Color primarySoft = Color(0xFF3D2D72);
  static const Color primaryTint = Color(0xFFF1EFF9);
  static const Color primaryTintStrong = Color(0xFFE3DFF2);

  // --- Gold accent (seal / pending) ---
  static const Color accent = Color(0xFFF2C749);
  static const Color accentStrong = Color(0xFFE0A800);
  static const Color accentTint = Color(0xFFFEF8E7);
  static const Color accentTintStrong = Color(0xFFFBEEC4);

  // --- Surfaces ---
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFFAFAFC);
  static const Color background = Color(0xFFF5F6FA);
  static const Color border = Color(0xFFE7E8EF);
  static const Color borderStrong = Color(0xFFD7D9E4);
  static const Color greyFill = Color(0xFFF0F1F5);

  // --- Ink ---
  static const Color inkStrong = Color(0xFF14131E);
  static const Color ink = Color(0xFF3B3A46);
  static const Color inkMuted = Color(0xFF6B6B7B);

  // --- Semantic (always paired with icon + label) ---
  static const Color success = Color(0xFF0E7C4A);
  static const Color successTint = Color(0xFFE8F7EF);
  static const Color warning = Color(0xFF8A6100);
  static const Color warningTint = Color(0xFFFBF3E0);
  static const Color danger = Color(0xFFB42318);
  static const Color dangerTint = Color(0xFFFDEEEC);
  static const Color dangerFill = Color(0xFFD4271D);
  static const Color info = Color(0xFF1D4ED8);
  static const Color infoTint = Color(0xFFEBF1FE);

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
      primaryContainer: AppColors.primaryTint,
      onPrimaryContainer: AppColors.primaryDark,
      secondary: AppColors.accent,
      onSecondary: AppColors.inkStrong,
      secondaryContainer: AppColors.accentTint,
      onSecondaryContainer: AppColors.inkStrong,
      surface: AppColors.surface,
      onSurface: AppColors.inkStrong,
      onSurfaceVariant: AppColors.inkMuted,
      surfaceContainerLowest: AppColors.surface,
      surfaceContainerLow: AppColors.surfaceMuted,
      surfaceContainer: AppColors.greyFill,
      error: AppColors.danger,
      onError: Colors.white,
      outline: AppColors.border,
      outlineVariant: AppColors.border,
      surfaceTint: Colors.transparent,
    );

    const textTheme = TextTheme(
      displaySmall: TextStyle(
        color: AppColors.inkStrong,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.4,
      ),
      headlineMedium: TextStyle(
        color: AppColors.inkStrong,
        fontSize: 24,
        fontWeight: FontWeight.w700,
        height: 1.25,
        letterSpacing: -0.3,
      ),
      headlineSmall: TextStyle(
        color: AppColors.inkStrong,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.3,
        letterSpacing: -0.2,
      ),
      titleLarge: TextStyle(
        color: AppColors.inkStrong,
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 1.3,
      ),
      titleMedium: TextStyle(
        color: AppColors.inkStrong,
        fontSize: 16,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      titleSmall: TextStyle(
        color: AppColors.inkStrong,
        fontSize: 15,
        fontWeight: FontWeight.w600,
        height: 1.35,
      ),
      bodyLarge: TextStyle(
        color: AppColors.inkStrong,
        fontSize: 16,
        height: 1.55,
      ),
      bodyMedium: TextStyle(
        color: AppColors.inkStrong,
        fontSize: 14,
        height: 1.5,
      ),
      bodySmall: TextStyle(
        color: AppColors.inkMuted,
        fontSize: 13,
        height: 1.45,
      ),
      labelLarge: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.1,
      ),
      labelMedium: TextStyle(
        color: AppColors.inkMuted,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.3,
      ),
      labelSmall: TextStyle(
        color: AppColors.inkMuted,
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
      ),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.background,
      textTheme: textTheme,
      primaryTextTheme: textTheme,
      splashFactory: InkSparkle.splashFactory,

      // --- AppBar: white bar, hairline bottom border, left-aligned title ---
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        foregroundColor: AppColors.inkStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleSpacing: AppSpacing.sm,
        titleTextStyle: TextStyle(
          color: AppColors.inkStrong,
          fontSize: 18,
          fontWeight: FontWeight.w700,
          height: 1.3,
        ),
        shape: Border(
          bottom: BorderSide(color: AppColors.border, width: 1),
        ),
        iconTheme: IconThemeData(color: AppColors.inkStrong, size: 24),
      ),

      // --- Text inputs: white fill, 12dp radius, 52dp min ---
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.sm,
          vertical: 15,
        ),
        border: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: AppRadius.input,
          borderSide: const BorderSide(color: AppColors.danger, width: 1.6),
        ),
        labelStyle: const TextStyle(
          color: AppColors.inkMuted,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        hintStyle: const TextStyle(
          color: AppColors.inkMuted,
          fontSize: 14,
        ),
        errorStyle: const TextStyle(
          color: AppColors.danger,
          fontSize: 12,
        ),
        prefixIconColor: AppColors.inkMuted,
        suffixIconColor: AppColors.inkMuted,
        constraints: const BoxConstraints(minHeight: 52),
      ),

      // --- Primary button: full-width, 52dp, 12dp radius ---
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          disabledBackgroundColor: AppColors.primary.withAlpha(90),
          disabledForegroundColor: Colors.white.withAlpha(190),
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 15,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.input),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // --- Secondary button: hairline border, inkStrong label ---
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.borderStrong),
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 15,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.input),
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
        ),
      ),

      // --- Elevated button: same as filled for consistency ---
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(52),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 15,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.input),
          elevation: 0,
          textStyle: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
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
          shape: const RoundedRectangleBorder(borderRadius: AppRadius.input),
        ),
      ),

      // --- Card: white, soft shadow, 16dp radius, hairline border ---
      cardTheme: CardThemeData(
        color: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        shadowColor: const Color(0x1A0B1220),
        elevation: 3,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.card,
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
          letterSpacing: 0.4,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      ),

      // --- Dialog ---
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shadowColor: const Color(0x330B1220),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.hero),
        titleTextStyle: const TextStyle(
          color: AppColors.inkStrong,
          fontSize: 18,
          fontWeight: FontWeight.w700,
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
        surfaceTintColor: Colors.transparent,
        elevation: 3,
        shape: RoundedRectangleBorder(borderRadius: AppRadius.sheet),
        dragHandleColor: AppColors.borderStrong,
        showDragHandle: true,
      ),

      // --- Snack bar ---
      snackBarTheme: SnackBarThemeData(
        backgroundColor: AppColors.inkStrong,
        contentTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 14,
          height: 1.4,
        ),
        actionTextColor: AppColors.accent,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.all(AppSpacing.sm),
        shape: const RoundedRectangleBorder(borderRadius: AppRadius.input),
      ),

      // --- List tiles ---
      listTileTheme: const ListTileThemeData(
        iconColor: AppColors.inkMuted,
        titleTextStyle: TextStyle(
          color: AppColors.inkStrong,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        subtitleTextStyle: TextStyle(
          color: AppColors.inkMuted,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(borderRadius: AppRadius.input),
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
