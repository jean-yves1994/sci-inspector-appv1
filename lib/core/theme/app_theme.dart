import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();
  static const Color primary = Color(0xFF2747AA);
  static const Color primaryDark = Color(0xFF1B3178);
  static const Color primaryLight = Color(0xFF4C6BD4);
  static const List<Color> authHeroGradient = <Color>[
    Color(0xFF3A5FD0), Color(0xFF2747AA), Color(0xFF1B3178),
  ];
  static const Color surfaceLight = Color(0xFFF6F7FB);
  static const Color surfaceDark = Color(0xFF0E1116);
  static const Color cardDark = Color(0xFF171B22);
  static const Color textPrimary = Color(0xFF10151F);
  static const Color textSecondary = Color(0xFF5C6579);
  static const Color success = Color(0xFF1E9E5A);
  static const Color warning = Color(0xFFE07C24);
  static const Color danger = Color(0xFFD1344B);
  static const Color offline = Color(0xFF8A93A6);
  static const Color violet = Color(0xFF7A5AF8);
  static const Color teal = Color(0xFF0E7C86);
}

class AppSpacing {
  const AppSpacing._();
  static const double xxs = 4, xs = 8, sm = 12, md = 16, lg = 20, xl = 24,
      xxl = 32, xxxl = 40, touchTarget = 48;
}

class AppRadius {
  const AppRadius._();
  static const double sm = 10, md = 14, lg = 16, xl = 20, xxl = 24,
      authCard = 32;
}

class AppTheme {
  const AppTheme._();
  static ThemeData light() => _build(Brightness.light);
  static ThemeData dark() => _build(Brightness.dark);

  static ThemeData _build(Brightness brightness) {
    final isLight = brightness == Brightness.light;
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.primary, brightness: brightness),
      scaffoldBackgroundColor:
          isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        backgroundColor:
            isLight ? AppColors.surfaceLight : AppColors.surfaceDark,
        foregroundColor: isLight ? AppColors.textPrimary : Colors.white,
        titleTextStyle: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: isLight ? AppColors.textPrimary : Colors.white,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: isLight ? Colors.white : AppColors.cardDark,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          side: BorderSide(
            color: isLight
                ? Colors.black.withValues(alpha: 0.06)
                : Colors.white.withValues(alpha: 0.07),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: isLight
            ? const Color(0xFFF2F4F9)
            : Colors.white.withValues(alpha: 0.05),
        contentPadding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md, vertical: AppSpacing.md),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(54),
          textStyle:
              const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppRadius.xxl)),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.primary),
      ),
      snackBarTheme: const SnackBarThemeData(
          behavior: SnackBarBehavior.floating),
    );
  }
}
