import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_radius.dart';

/// Custom ThemeData for Examination Booklet System (Zero default Material demo look)
class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: AppColors.darkBg,
      primaryColor: AppColors.sealGoldLight,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.sealGoldLight,
        onPrimary: AppColors.darkBg,
        secondary: AppColors.accent,
        onSecondary: Colors.white,
        surface: AppColors.darkCard,
        onSurface: AppColors.darkTextPrimary,
        error: AppColors.danger,
        onError: Colors.white,
        outline: AppColors.darkBorder,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.darkIcon,
        size: 22,
      ),
      primaryIconTheme: const IconThemeData(
        color: AppColors.sealGoldLight,
        size: 22,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.roundedBase,
          side: const BorderSide(color: AppColors.darkBorder, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.darkCard,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.darkIcon),
        actionsIconTheme: IconThemeData(color: AppColors.darkIcon),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.darkBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: AppColors.lightBg,
      primaryColor: AppColors.primary,
      colorScheme: const ColorScheme.light(
        primary: AppColors.primary,
        onPrimary: Colors.white,
        secondary: AppColors.sealGold,
        onSecondary: Colors.white,
        surface: AppColors.lightCard,
        onSurface: AppColors.lightTextPrimary,
        error: AppColors.danger,
        onError: Colors.white,
        outline: AppColors.lightBorder,
      ),
      iconTheme: const IconThemeData(
        color: AppColors.lightIcon,
        size: 22,
      ),
      primaryIconTheme: const IconThemeData(
        color: AppColors.primary,
        size: 22,
      ),
      cardTheme: CardThemeData(
        color: AppColors.lightCard,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadius.roundedBase,
          side: const BorderSide(color: AppColors.lightBorder, width: 1.2),
        ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.lightCard,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: AppColors.lightIcon),
        actionsIconTheme: IconThemeData(color: AppColors.lightIcon),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.lightBorder,
        thickness: 1,
        space: 1,
      ),
    );
  }
}
